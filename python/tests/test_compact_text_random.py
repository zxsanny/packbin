from __future__ import annotations

import multiprocessing
import random
import time
from typing import Any, Callable

from packbin import BinaryPacker, Scheme, utf8
from packbin._text_decode import TextRefusal, decode_text

import text_vectors
import timing_support

# AZ-2736 (CS-A5, CS-A10; TW-2, TW-3): the random-string round trip and the hostile-payload test the compact text
# codec of Python did not have. Fixed seeds; every item is a pack or an unpack through the public API (and, for a
# hostile payload, the decoder read directly as well).

ONE = Scheme(1, dict, utf8(0, lambda row: row["s"]))
READER = ONE.on(lambda _row: None)
CORPUS = text_vectors.ROOT / "fixtures" / "hostile" / "fuzz" / "corpus.txt"

RANDOM_STRING_COUNT = 3_000
HOSTILE_PAYLOAD_COUNT = 30_000
MAX_TEXT_BYTES = 65_535
# A hang fails a test after this nominal time (times the load factor), the child is killed.
GUARD_SECONDS = 20.0

INTERESTING_BYTES = (0x00, 0x01, 0x10, 0x1F, 0x7F, 0x80, 0x81, 0xBF, 0xC0, 0xC2, 0xE0, 0xED, 0xEF, 0xF0, 0xF4, 0xF5, 0xFF)


def _codes(first: int, last: int) -> list[str]:
    return [chr(code) for code in range(first, last + 1)]


# Characters by script, so a random run keeps to one script the way real text does. The heavy pools are listed twice.
POOLS: list[list[str]] = [
    list("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"),
    list("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"),
    list("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"),
    list("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
    list("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
    list("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"),
    list("abcdefghijklmnopqrstuvwxyz'"),
    list("abcdefghijklmnopqrstuvwxyz'"),
    list("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    list("0123456789.,-: "),
    list("0123456789.,-: "),
    list(" 0123456789,.-:!?;()\"%/@+=*#&_$\n\t"),
    list("éèêëàâäîïôöûüùçßżłńąęśćźñãõøåœæþðİıÿ"),
    list("αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΩ"),
    list("שלוםעולםمرحباالعالمनमस्ते世界สวัสดี"),
    list("中文日本語한국어こんにちは"),
    _codes(0x1F300, 0x1F64F),
    ["‍", "️", "\U0001f1e6", "\U0001f1fa", "\U0001f1e6", "❤", "\U0001f468", "\U0001f469", "\U0001f467"],
    _codes(0x0300, 0x036F),
    ["\x00", "\x01", "\x1f", "\x7f", "\x80", "\x9f", "\xa0", "﻿", "�", "￾", "￿", "", "\U0010ffff", "퟿", ""],
]
UKRAINIAN = POOLS[0]
CJK = _codes(0x4E00, 0x9FFF)
EMOJI = _codes(0x1F300, 0x1F64F)


def _random_text(rng: random.Random, limit: int = 60) -> str:
    """Up to `limit` code points in runs of 1 to 8 characters, each run from one pool."""
    out: list[str] = []
    left = rng.randrange(limit)
    while left > 0:
        pool = POOLS[rng.randrange(len(POOLS))]
        for _ in range(min(left, 1 + rng.randrange(8))):
            out.append(pool[rng.randrange(len(pool))])
            left -= 1
    return "".join(out)


def _text_of_bytes(rng: random.Random, size: int, pool: list[str] | None) -> str:
    """Exactly `size` UTF-8 bytes from one pool (from every pool when `pool` is None); an ASCII tail pads the last bytes."""
    out: list[str] = []
    used = 0
    while used < size:
        chars = pool if pool is not None else POOLS[rng.randrange(len(POOLS))]
        char = chars[rng.randrange(len(chars))]
        width = len(char.encode("utf-8"))
        if used + width > size:
            out.append("a")
            used += 1
            continue
        out.append(char)
        used += width
    return "".join(out)


def _varint_length(count: int) -> int:
    return 1 if count < 0x80 else 2 if count < 0x4000 else 3


def _field_of(payload: bytes) -> bytes:
    """The count (7 bits a byte, low first) then the payload."""
    count = len(payload)
    head = bytearray()
    while True:
        head.append((count & 0x7F) | (0x80 if count > 0x7F else 0))
        count >>= 7
        if not head[-1] & 0x80:
            break
    return bytes(head) + payload


def _header_length(field: bytes) -> int:
    """The count length as the decoder reads it: up to three bytes while the high bit is set."""
    length = 1
    while length < 3 and length < len(field) and field[length - 1] & 0x80:
        length += 1
    return min(length, len(field))


def _run_guarded(work: Callable[[], Any], guard: timing_support.Bound, what: str) -> Any:
    """Runs `work` in a forked child that is killed after the guard, so a hang fails the test and leaves nothing
    spinning behind. A failure in the child comes back as the exception."""
    ctx = multiprocessing.get_context("fork")
    recv, send = ctx.Pipe(duplex=False)

    def child_main() -> None:
        try:
            outcome: Any = work()
        except BaseException as exc:  # reported to the test below
            outcome = exc
        send.send(outcome)

    child = ctx.Process(target=child_main, daemon=True)
    child.start()
    send.close()
    if not recv.poll(float(guard)):
        child.kill()
        child.join()
        raise AssertionError(f"{what} did not finish: {float(guard):.1f}s (nominal {guard.nominal:.1f}s, load factor {guard.factor:.2f})")
    outcome = recv.recv()
    child.join()
    if isinstance(outcome, BaseException):
        raise AssertionError(f"{what} raised {outcome!r}") from outcome
    return outcome


def _describe(text: str) -> str:
    if len(text) <= 40:
        return f"{text!r} ({text.encode('utf-8').hex()})"
    return f"a text of {len(text)} characters"


def _round_trip(texts: list[str]) -> tuple[list[str], int]:
    """The mismatches (at most the first 20) and the number of packets shorter than the raw form."""
    mismatches: list[str] = []
    compact = 0
    for text in texts:
        raw = len(text.encode("utf-8"))
        packet = BinaryPacker.pack(ONE, {"s": text})
        result = BinaryPacker.unpack(packet, READER)
        raw_field = 1 if raw == 0 else _varint_length(1 + raw) + 1 + raw
        if not result.ok or result.value != {"s": text}:
            problem = f"error {type(result.error).__name__}" if not result.ok else "another text"
            mismatches.append(f"{_describe(text)}: {problem}")
        elif len(packet) > 1 + raw_field:
            mismatches.append(f"{_describe(text)}: {len(packet)} bytes, more than the raw form of {1 + raw_field}")
        elif len(packet) < 1 + raw_field:
            compact += 1
    return mismatches[:20], compact


def test_ac2_3000_random_unicode_strings_of_every_script_round_trip_through_pack_and_unpack():
    # Arrange: AZ-2736 AC-2 (CS-A5); the empty string, five texts of exactly 65,535 UTF-8 bytes and 3,000 random ones
    rng = random.Random(2736)
    texts = [""]
    texts.extend(_random_text(rng, 300 if i % 10 == 0 else 60) for i in range(RANDOM_STRING_COUNT))
    texts.append("a" * MAX_TEXT_BYTES)
    texts.append(_text_of_bytes(rng, MAX_TEXT_BYTES, UKRAINIAN + [" "]))
    texts.append(_text_of_bytes(rng, MAX_TEXT_BYTES, CJK))
    texts.append(_text_of_bytes(rng, MAX_TEXT_BYTES, EMOJI))
    texts.append(_text_of_bytes(rng, MAX_TEXT_BYTES, None))
    guard = timing_support.bound(GUARD_SECONDS)

    # Act
    started = time.perf_counter()
    mismatches, compact = _run_guarded(lambda: _round_trip(texts), guard, f"{len(texts)} random strings")
    elapsed = time.perf_counter() - started

    # Assert
    print(f"AZ-2736 AC-2: {len(texts)} strings, {compact} packed shorter than the raw form, {len(mismatches)} mismatches, {elapsed:.2f}s")
    assert mismatches == []
    assert len(texts) >= RANDOM_STRING_COUNT
    assert compact >= 300, f"only {compact} strings used the compact form"
    assert sum(1 for text in texts if len(text.encode("utf-8")) == MAX_TEXT_BYTES) == 5
    assert "" in texts


def _corpus_bodies() -> list[bytes]:
    """The packets of fixtures/hostile/fuzz/corpus.txt without their type byte."""
    bodies = []
    for line in CORPUS.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        packet = bytes.fromhex(line.split()[2])
        if len(packet) > 1:
            bodies.append(packet[1:])
    return bodies


def _damage(rng: random.Random, field: bytes) -> bytes:
    header = _header_length(field)
    head = bytearray(field[:header])
    body = bytearray(field[header:])
    for _ in range(1 + rng.randrange(3)):
        target = head if not body or rng.randrange(8) == 0 else body
        if not target:
            target.append(rng.randrange(256))
            continue
        at = rng.randrange(len(target))
        step = rng.randrange(7)
        if step == 0:
            target[at] ^= 1 << rng.randrange(8)
        elif step == 1:
            target[at] = rng.choice(INTERESTING_BYTES) if rng.randrange(2) == 0 else rng.randrange(256)
        elif step == 2:
            del target[at:]
        elif step == 3:
            target.insert(at, rng.randrange(256))
        elif step == 4:
            del target[at]
        elif step == 5:
            target.extend(rng.randrange(256) for _ in range(1 + rng.randrange(8)))
        else:
            target[at] = target[rng.randrange(len(target))]
    # The count is left as damaged, made right for the damaged payload, or replaced by a random byte.
    how = rng.randrange(3)
    if how == 0:
        return bytes(head + body)
    if how == 1:
        return _field_of(bytes(body)) if body else b"\x00"
    return bytes((rng.randrange(256),)) + bytes(body)


def _hostile_field(rng: random.Random, index: int, valid: list[bytes], vectors: list[bytes], corpus: list[bytes]) -> bytes:
    """One payload of the run: the category follows the index, so every category gets about 5,000 of the 30,000."""
    if index % 3_000 == 7:
        # The longest run of zeros or ones in every start mode: the amplification case of the decoder.
        payload = bytearray(b"\x00" if index // 3_000 % 2 == 0 else b"\xff") * 40_000
        payload[0] = (index // 3_000 % 8) << 2
        return _field_of(bytes(payload))
    category = index % 6
    if category == 0:
        payload = bytearray(rng.randbytes(1 + rng.randrange(80)))
        payload[0] = (payload[0] & (0x03 if rng.randrange(2) == 0 else 0xE3)) | (index // 6 % 8 << 2)
        return _field_of(bytes(payload))
    if category == 1:
        return rng.randbytes(rng.randrange(97))
    if category == 2:
        return _damage(rng, valid[rng.randrange(len(valid))])
    if category == 3:
        return _damage(rng, vectors[rng.randrange(len(vectors))])
    if category == 4:
        return _damage(rng, corpus[rng.randrange(len(corpus))])
    payload = bytearray(rng.randbytes(100 + rng.randrange(401)))
    payload[0] = (payload[0] & 0x03) | (index // 6 % 8 << 2)
    return _field_of(bytes(payload))


def _show(field: bytes) -> str:
    return field[:48].hex() + (f"... ({len(field)} bytes)" if len(field) > 48 else "")


def _examine(field: bytes) -> tuple[str, str | None]:
    """Reads one field directly and as the only field of a packet. Returns ("accepted" | "refused" | "violation",
    what broke a rule). Any exception other than the decoder's own refusal is a violation."""
    try:
        try:
            text, end = decode_text(field, 0)
            accepted = end == len(field)
        except TextRefusal:
            text, end, accepted = "", 0, False
        result = BinaryPacker.unpack(b"\x01" + field, READER)
    except Exception as exc:
        return "violation", f"{type(exc).__name__}: {exc} on {_show(field)}"
    if accepted != result.ok:
        word = "accepts" if accepted else "refuses"
        return "violation", f"direct read {word} but the packet {'unpacks' if result.ok else 'is refused'}: {_show(field)}"
    if not accepted:
        return "refused", None
    try:
        size = len(text.encode("utf-8"))
    except UnicodeEncodeError:
        return "violation", f"accepted a text with a lone surrogate: {_show(field)}"
    payload = end - _header_length(field)
    if result.value != {"s": text} or size > 6 * payload + 8 or size > MAX_TEXT_BYTES:
        return "violation", f"accepted {size} UTF-8 bytes from a {payload}-byte payload (same text {result.value == {'s': text}}): {_show(field)}"
    return "accepted", f"{size / payload:.2f}" if payload else "0.00"


def _hostile_run(seed: int, valid: list[bytes], vectors: list[bytes], corpus: list[bytes]) -> dict[str, Any]:
    rng = random.Random(seed)
    tally: dict[str, Any] = {"accepted": 0, "refused": 0, "violations": [], "most": 0.0}
    for index in range(HOSTILE_PAYLOAD_COUNT):
        outcome, note = _examine(_hostile_field(rng, index, valid, vectors, corpus))
        if outcome == "violation":
            tally["violations"].append(note)
        else:
            tally[outcome] += 1
            if outcome == "accepted":
                tally["most"] = max(tally["most"], float(note or 0))
    return tally


def test_ac3_30000_hostile_text_payloads_never_crash_hang_or_exceed_six_bytes_per_byte_plus_eight():
    # Arrange: AZ-2736 AC-3 (CS-A10); random bytes, damaged valid fields, damaged vector fields, damaged corpus seeds
    rng = random.Random(2737)
    valid = [BinaryPacker.pack(ONE, {"s": _random_text(rng, 120)})[1:] for _ in range(400)]
    vectors = [row.field for row in text_vectors.ROWS if row.kind in ("enc", "alt", "bad")]
    corpus = _corpus_bodies()
    guard = timing_support.bound(GUARD_SECONDS)

    # Act
    started = time.perf_counter()
    tally = _run_guarded(lambda: _hostile_run(2738, valid, vectors, corpus), guard, f"{HOSTILE_PAYLOAD_COUNT} hostile payloads")
    elapsed = time.perf_counter() - started

    # Assert
    print(
        f"AZ-2736 AC-3: {HOSTILE_PAYLOAD_COUNT} payloads, {tally['accepted']} accepted, {tally['refused']} refused, "
        f"{len(corpus)} corpus seeds, {len(vectors)} vector fields, most output bytes per payload byte {tally['most']:.2f}, {elapsed:.2f}s"
    )
    assert tally["violations"][:5] == []
    assert tally["accepted"] + tally["refused"] == HOSTILE_PAYLOAD_COUNT
    assert tally["accepted"] >= 1_000, f"only {tally['accepted']} payloads were accepted"
    assert tally["refused"] >= 1_000, f"only {tally['refused']} payloads were refused"
    assert len(corpus) >= 30, f"only {len(corpus)} corpus seeds"
    assert len(vectors) >= 100, f"only {len(vectors)} vector fields"
