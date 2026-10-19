# Run: python3.14 -I -B fuzz_text.py <repo checkout> [seed] [seconds]   (AZ-2666 probe (a), Python, compact text)
"""Seeded grammar-built, random and mutated string fields against the Python compact text decoder.

Each field goes through `decode_text` and through `scripts/text/textfmt.py`: a different accept/refuse answer, text
or end offset is a mismatch. The same field is then read through `BinaryPacker.unpack` as a lone string, inside a list
and as a dictionary key; only an `UnpackResult` may come out. Shared setup is `fuzz_common.py` next to this file.
"""

from __future__ import annotations

import os
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I leaves the script's folder off the path

import fuzz_common as C  # noqa: E402
from fuzz_common import Stats, mutate, note, rng, varint  # noqa: E402
from packbin import Scheme, utf8  # noqa: E402
from packbin import dict as map_field  # noqa: E402
from packbin import list as list_field  # noqa: E402
from packbin import _text_model as M  # noqa: E402
from packbin._text_decode import TextRefusal, decode_text  # noqa: E402

BAD_UTF8 = [
    b"\xc0\x80", b"\xc1\xbf", b"\xe0\x80\x80", b"\xe0\x9f\xbf", b"\xed\xa0\x80", b"\xed\xbf\xbf",
    b"\xf0\x80\x80\x80", b"\xf0\x8f\xbf\xbf", b"\xf4\x90\x80\x80", b"\xf5\x80\x80\x80", b"\xf7\xbf\xbf\xbf",
    b"\xf8", b"\xff", b"\x80", b"\xbf", b"\xc3\x41", b"\xe2\x82\x41", b"\xf0\x9f\x98\x41", b"\xc3", b"\xe2\x82",
]


def utf8_piece() -> bytes:
    """1 to 4 bytes after an ESC: mostly a valid scalar, sometimes a hostile sequence."""
    if rng.random() < 0.75:
        while True:
            band = rng.choice([(0, 0x7F), (0x80, 0x7FF), (0x800, 0xFFFF), (0x10000, 0x10FFFF)])
            cp = rng.randint(*band)
            if not 0xD800 <= cp <= 0xDFFF:
                return chr(cp).encode("utf-8")
    return rng.choice(BAD_UTF8)


def gen_stream() -> bytes:
    """A compact payload built from the frozen codes: mostly legal symbol sequences (CAP and LOCK tracked), so the
    decoder goes deep, with hostile ESC bytes, wrong pads, wrong modes and random symbols mixed in."""
    start = rng.randrange(4)
    mode = start
    lock = False
    cap = False
    chunks: list[tuple[int, int]] = []
    for _ in range(rng.choice([1, 2, 3, 8, 30, 200, 2000])):
        tab = M.decode_mode(mode)
        n = len(tab.kind)
        if rng.random() < 0.08 or (cap and mode == 3):
            idx = rng.randrange(n)  # anything, legal or not (a CAP carried into the number mode has no letter)
        else:
            while True:
                idx = rng.randrange(n)
                k = tab.kind[idx]
                if cap and not (k == M.KIND_CHAR and tab.up[idx] is not None):
                    continue
                if k == M.KIND_CAP and (lock or cap):
                    continue
                break
        chunks.append(M.CODES[mode][idx])
        k = tab.kind[idx]
        if k == M.KIND_CHAR:
            cap = False
        elif k == M.KIND_SWITCH:
            mode = tab.arg[idx]
            cap = False
        elif k == M.KIND_CAP:
            cap = True
        elif k == M.KIND_LOCK:
            lock = not lock
        else:
            chunks.extend((b, 8) for b in utf8_piece())
    bits = sum(length for _, length in chunks)
    if rng.random() < 0.05 and chunks:
        bits -= rng.randint(1, min(7, bits))  # cut a code short
    total = 6 + bits
    nbytes = (total + 7) // 8
    pad = nbytes * 8 - total
    acc = 0
    nb = 0
    for code, length in chunks:
        acc = (acc << length) | code
        nb += length
    acc >>= nb - bits
    header_pad = pad if rng.random() > 0.03 else rng.randrange(8)
    header_mode = start if rng.random() > 0.03 else rng.randrange(8)
    value = (header_pad << (nbytes * 8 - 3)) | (header_mode << (nbytes * 8 - 6)) | (acc << pad)
    if rng.random() < 0.03 and pad:
        value |= 1  # a pad bit set
    return value.to_bytes(nbytes, "big")


def gen_text_field() -> bytes:
    r = rng.random()
    if r < 0.45:
        payload = gen_stream()
        field = varint(len(payload)) + payload
    elif r < 0.6:
        n = rng.choice([1, 2, 3, 5, 17, 300])
        field = varint(n) + bytes(rng.randrange(256) for _ in range(n))
    elif r < 0.7:
        cps = [rng.choice([0x41, 0x430, 0x20AC, 0x1F600, rng.randint(0, 0x10FFFF)]) for _ in range(rng.randint(1, 40))]
        raw = bytearray("".join(map(chr, cps)).encode("utf-8", "surrogatepass"))
        if rng.random() < 0.3:
            raw[rng.randrange(len(raw))] = rng.randrange(256)
        field = varint(len(raw) + 1) + b"\x10" + bytes(raw)
    elif r < 0.95:
        field = mutate(rng.choice(C.TEXT_SEEDS))
    else:
        field = mutate(rng.choice(C.PACKETS)[1:])  # a hostile or ring packet body read as a string
    if rng.random() < 0.2:
        field += bytes(rng.randrange(256) for _ in range(rng.randint(1, 4)))
    return field


def ref_text(buf: bytes):
    try:
        text, nxt = C.textfmt.decode(buf, 0, C.TABLES)
        return ("ok", text, nxt)
    except C.textfmt.Refusal as r:
        return ("refused", r.kind, 0)


def pkg_text(buf: bytes):
    try:
        text, nxt = decode_text(buf, 0)
        return ("ok", text, nxt)
    except TextRefusal as r:
        return ("refused", r.kind, 0)


ONE = Scheme(1, dict, utf8(0, lambda row: row["s"]))
LISTS = Scheme(2, dict, list_field(lambda row: row["xs"], utf8(0, lambda row: row)))
DICTS = Scheme(3, dict, map_field(lambda row: row["d"], utf8(0, lambda row: row)))
HANDLERS = (ONE.on(lambda r: None), LISTS.on(lambda r: None), DICTS.on(lambda r: None))


def packet_of(field: bytes) -> bytes:
    """The field as a lone string, among 1 to 3 strings of a list, or as the key of a dict of 1 to 2 pairs."""
    shape = rng.randrange(3)
    if shape == 0:
        return b"\x01" + field
    if shape == 1:
        k = rng.randint(1, 3)
        return b"\x02" + k.to_bytes(2, "little") + b"".join(gen_text_field() if i else field for i in range(k))
    k = rng.randint(1, 2)
    parts = []
    for i in range(k):
        key = field if i == 0 or rng.random() < 0.3 else gen_text_field()
        parts.append(key + gen_text_field())
    return b"\x03" + k.to_bytes(2, "little") + b"".join(parts)


def run_text(deadline: float) -> None:
    st = Stats("text decode_text vs reference")
    pub = Stats("text public unpack (utf8, list, dict)")
    kinds_differ = 0
    while time.perf_counter() < deadline:
        field = gen_text_field()
        try:
            got = st.timed(field[:40].hex(), lambda: pkg_text(field))
        except Exception as e:  # noqa: BLE001 - a foreign exception is the finding
            st.exceptions += 1
            note(f"text decode_text raised {type(e).__name__}: {e} on {field.hex()[:200]}")
            continue
        want = ref_text(field)
        if got[0] == "ok":
            st.accepted += 1
        else:
            st.refused += 1
        if got[0] != want[0] or (got[0] == "ok" and got[1:] != want[1:]):
            st.mismatch += 1
            note(f"text mismatch pkg={got[0]}:{str(got[1])[:30]} ref={want[0]}:{str(want[1])[:30]} on {field.hex()[:200]}")
        elif got[0] == "refused" and got[1] != want[1]:
            kinds_differ += 1
        packet = packet_of(field)
        try:
            res = pub.timed(packet[:40].hex(), lambda: C.public_unpack(packet, HANDLERS))
            if res.ok:
                pub.accepted += 1
            else:
                pub.refused += 1
        except Exception as e:  # noqa: BLE001
            pub.exceptions += 1
            note(f"public text unpack raised {type(e).__name__}: {e} on {packet.hex()[:200]}")
    print(st.report())
    print(f"  refused by both with another kind name (informational): {kinds_differ}")
    print(pub.report())


def main() -> int:
    signal.alarm(int(C.BUDGET * 2) + 60)  # a hang ends the run (SIGALRM) instead of holding a core
    t0 = C.banner()
    run_text(time.perf_counter() + C.BUDGET)
    return C.finish(t0)


if __name__ == "__main__":
    sys.exit(main())
