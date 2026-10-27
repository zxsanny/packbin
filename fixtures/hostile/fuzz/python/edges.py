# Run: python3.14 -I -B edges.py <repo checkout>   (AZ-2666 probe (d), Python)
"""The AC-1 and AC-2 edge cases a random run is unlikely to hit, one line each: PASS, FAIL or INFO.

Text: varint boundaries and refusals, a count far above the bytes present, the 65,535 boundary in the compact and
the raw path, ESC cut at every byte, pad and mode refusals, CAP and LOCK rules, a duplicate dictionary key written in
three byte forms. ECC: 254/255 bytes, shorter than n, exactly n, the caller's buffer, the check order of a dispatch
(empty list, duplicate type, parity mix, limit) and a payload of the wrong Python type.
"""

from __future__ import annotations

import os
import signal
import sys
import time

REPO = os.path.abspath(sys.argv[1])
sys.path.insert(0, os.path.join(REPO, "python", "src"))

from packbin import (  # noqa: E402
    BinaryPacker,
    Scheme,
    ShortPacket,
    TooLong,
    TrailingBytes,
    u8,
    utf8,
)
from packbin import dict as map_field  # noqa: E402
from packbin import _ecc  # noqa: E402
from packbin import _text_model as M  # noqa: E402
from packbin._text_decode import TextRefusal, decode_text  # noqa: E402

fails = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global fails
    if not ok:
        fails += 1
    print(f"{'PASS' if ok else 'FAIL'} {name}{(': ' + detail) if detail else ''}")


def info(name: str, detail: str) -> None:
    print(f"INFO {name}: {detail}")


def kind_of(buf: bytes) -> str:
    try:
        text, nxt = decode_text(buf, 0)
        return f"ok:{len(text.encode())}:{nxt}"
    except TextRefusal as r:
        return r.kind
    except Exception as e:  # noqa: BLE001 - a foreign exception is the finding
        return f"EXC {type(e).__name__}: {e}"


def varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def stream(start: int, symbols: list[tuple[int, int]], pad_bits: int | None = None) -> bytes:
    text = "".join(format(code, f"0{length}b") for code, length in symbols)
    total = 6 + len(text)
    nbytes = (total + 7) // 8
    pad = nbytes * 8 - total
    head = pad if pad_bits is None else pad_bits
    payload = int(format(head, "03b") + format(start, "03b") + text + "0" * pad, 2).to_bytes(nbytes, "big")
    return varint(nbytes) + payload


def sym(mode: int, char: str) -> tuple[int, int]:
    return M.CODES[mode][M.decode_mode(mode).low.index(char)]


CAP = lambda m: M.CODES[m][M.CAP_AT[m]]  # noqa: E731
LOCK = lambda m: M.CODES[m][M.LOCK_AT[m]]  # noqa: E731
ESC = lambda m: M.CODES[m][M.ESC_AT[m]]  # noqa: E731
SW = lambda m, t: M.CODES[m][M.SWITCH_AT[m][t]]  # noqa: E731


def text_edges() -> None:
    # varint
    for n in (127, 128, 16383, 16384, 2097151):
        head = varint(n)
        check(f"varint {n} is {len(head)} byte(s), a buffer cut after it is short", kind_of(head) == "short")
    check("varint 4 bytes refused", kind_of(b"\x80\x80\x80\x01") == "varint")
    check("varint 3 bytes all continuation refused", kind_of(b"\x80\x80\x80") == "varint")
    check("varint non-minimal 80 00 refused", kind_of(b"\x80\x00") == "varint")
    check("varint non-minimal 80 80 00 refused", kind_of(b"\x80\x80\x00") == "varint")
    check("varint cut inside (80) short", kind_of(b"\x80") == "short")
    t0 = time.perf_counter()
    k = kind_of(varint(2097151) + b"\x00\x01\x02")
    dt = time.perf_counter() - t0
    check("count 2,097,151 with 3 bytes present: short, nothing sized from the count", k == "short" and dt < 0.01, f"{dt * 1e6:.0f} us")
    check("empty buffer short", kind_of(b"") == "short")
    check("count 0 is the empty text, 1 byte", kind_of(b"\x00") == "ok:0:1")
    # header
    for mode in (5, 6, 7):
        check(f"start mode {mode} refused", kind_of(bytes([1, mode << 2])) == "mode")
    for first in (0x11, 0x12, 0x13, 0x30, 0xF0):
        check(f"raw first byte {first:02x} refused", kind_of(bytes([2, first, 0x41])) == "raw")
    check("pad 7 in a 1-byte payload refused", kind_of(b"\x01\xe0") == "pad")
    check("pad 3 in a 1-byte payload (covers the mode) refused", kind_of(b"\x01\x60") == "pad")
    check("pad 2 in a 1-byte payload is the empty text", kind_of(b"\x01\x40") == "ok:0:2")
    # 65,535 boundary, compact
    o = sym(1, "о")
    sp = sym(1, " ")
    check("compact 65,535 bytes accepted", kind_of(stream(1, [o] * 32767 + [sp])).startswith("ok:65535"))
    check("compact 65,536 bytes refused: length", kind_of(stream(1, [o] * 32768)) == "length")
    e = [ESC(1)] + [(b, 8) for b in "😀".encode()]
    check("compact 65,532 + one 4-byte ESC = 65,536 refused: length", kind_of(stream(1, [o] * 32766 + e)) == "length")
    check("compact 65,531 + one 4-byte ESC = 65,535 accepted", kind_of(stream(1, [o] * 32765 + [sp] + e)).startswith("ok:65535"))
    # 65,535 boundary, raw
    body = b"a" * 65535
    check("raw 65,535 bytes accepted", kind_of(varint(65536) + b"\x10" + body).startswith("ok:65535"))
    check("raw 65,536 bytes refused: length", kind_of(varint(65537) + b"\x10" + body + b"a") == "length")
    k = kind_of(varint(65537) + b"\x10" + body + b"\xff")
    info("raw 65,536 bytes ending in an invalid byte", f"refused as {k!r} (the UTF-8 decode runs before the length check)")
    check("raw bad UTF-8 refused", kind_of(b"\x03\x10\xc3\x28") == "utf8")
    check("raw surrogate refused", kind_of(b"\x04\x10\xed\xa0\x80") == "utf8")
    check("raw above U+10FFFF refused", kind_of(b"\x05\x10\xf4\x90\x80\x80") == "utf8")
    check("raw BOM kept", decode_text(b"\x04\x10\xef\xbb\xbf", 0)[0] == "﻿")
    # ESC cut at each byte of a 4-byte character, with the stream ending right there
    full = "😀".encode()
    for cut in range(0, 4):
        symbols = [ESC(0)] + [(b, 8) for b in full[:cut]]
        check(f"ESC with {cut} of 4 bytes then the end: esc", kind_of(stream(0, symbols)) == "esc")
    for lead in (0x80, 0xBF, 0xF8, 0xFF):
        check(f"ESC lead {lead:02x}: utf8", kind_of(stream(0, [ESC(0), (lead, 8)])) == "utf8")
    for seq, what in ((b"\xc0\x80", "overlong 2"), (b"\xe0\x9f\xbf", "overlong 3"), (b"\xf0\x8f\xbf\xbf", "overlong 4"),
                      (b"\xed\xa0\x80", "surrogate"), (b"\xf4\x90\x80\x80", "above 10FFFF"), (b"\xf5\x80\x80\x80", "lead f5"),
                      (b"\xc3\x41", "bad continuation")):
        check(f"ESC {what}: utf8", kind_of(stream(0, [ESC(0)] + [(b, 8) for b in seq])) == "utf8")
    check("ESC U+10FFFF accepted", kind_of(stream(0, [ESC(0)] + [(b, 8) for b in "\U0010ffff".encode()])).startswith("ok:4"))
    # CAP and LOCK
    a = sym(0, "а")
    ap = sym(0, "'")
    check("CAP at the end: cap", kind_of(stream(0, [CAP(0)])) == "cap")
    check("CAP then apostrophe: cap", kind_of(stream(0, [CAP(0), ap])) == "cap")
    check("CAP CAP: cap", kind_of(stream(0, [CAP(0), CAP(0), a])) == "cap")
    check("CAP then LOCK: cap", kind_of(stream(0, [CAP(0), LOCK(0), a])) == "cap")
    check("LOCK then CAP: cap", kind_of(stream(0, [LOCK(0), CAP(0), a])) == "cap")
    check("CAP then switch: cap", kind_of(stream(0, [CAP(0), SW(0, 2), sym(2, "a")])) == "cap")
    check("CAP then ESC: cap", kind_of(stream(0, [CAP(0), ESC(0), (0x41, 8)])) == "cap")
    check("CAP then space: cap", kind_of(stream(0, [CAP(0), sym(0, " ")])) == "cap")
    got = decode_text(stream(0, [LOCK(0), a, SW(0, 3), sym(3, "1"), SW(3, 0), a, ap]), 0)[0]
    check("LOCK survives the number mode", got == "А1А'", repr(got))
    lock_code, lock_len = LOCK(0)
    cut = stream(0, [(lock_code >> (lock_len - 10), 10)])  # the first 10 of the 15 bits of LOCK, then the end
    check("a code cut by the end of the payload: code", kind_of(cut) == "code", kind_of(cut))
    f = stream(0, [a, a])
    pad = f[1] >> 5
    check(f"pad bit set (pad {pad}): pad", pad > 0 and kind_of(f[:-1] + bytes([f[-1] | 1])) == "pad")
    # duplicate dictionary keys written in three byte forms
    d = Scheme(1, dict, map_field(lambda row: row["d"], u8(0, lambda row: row)))
    compact = BinaryPacker.pack(Scheme(1, dict, utf8(0, lambda r: r["s"])), {"s": "ключ"})[1:]
    raw = varint(1 + len("ключ".encode())) + b"\x10" + "ключ".encode()
    escaped = stream(0, [ESC(0)] + [(b, 8) for b in "к".encode()] + [sym(0, c) for c in "люч"])
    for name, k1, k2 in (("compact + raw", compact, raw), ("raw + escaped", raw, escaped), ("compact + escaped", compact, escaped)):
        packet = b"\x01\x02\x00" + k1 + b"\x05" + k2 + b"\x06"
        res = BinaryPacker.unpack(packet, d.on(lambda r: None))
        check(f"duplicate key, {name}: refused", not res.ok and isinstance(res.error, ShortPacket), str(res.error))
    nfc = "é".encode()
    nfd = "é".encode()
    # Dictionary keys must ascend strictly by UTF-8 bytes: NFD (65 cc 81) sorts before NFC (c3 a9).
    packet = b"\x01\x02\x00" + varint(1 + len(nfd)) + b"\x10" + nfd + b"\x05" + varint(1 + len(nfc)) + b"\x10" + nfc + b"\x06"
    res = BinaryPacker.unpack(packet, d.on(lambda r: None))
    info("keys NFC 'é' and NFD 'e+U+0301'", f"{'accepted as two keys' if res.ok else 'refused'} (no normalization; Swift F47 differs)")


def ecc_edges() -> None:
    s = lambda n, t=1: Scheme(t, dict, u8(0, lambda r: r["v"])).with_limits(parity=n)  # noqa: E731
    for n in (1, 2, 32):
        h = s(n).on(lambda r: None)
        res = BinaryPacker.unpack(bytes(255), h)
        check(f"n={n}: 255 bytes too_long before arithmetic", isinstance(res.error, TooLong) and res.error.length == 255)
        res = BinaryPacker.unpack(bytes(n - 1), h)
        check(f"n={n}: {n - 1} bytes short naming parity", isinstance(res.error, ShortPacket) and res.error.field == "parity" and res.error.needed == n)
        res = BinaryPacker.unpack(bytes(n), h)
        check(f"n={n}: exactly n zero bytes (empty clear) -> short 1", isinstance(res.error, ShortPacket) and res.error.needed == 1, str(res.error))
        clear = bytes([1, 7] + [0] * (254 - n - 2))
        word = clear + _ecc.parity(clear, n)
        res = BinaryPacker.unpack(word, h)
        check(f"n={n}: 254-byte intact message reads to trailing (clear is longer than the row)", isinstance(res.error, TrailingBytes), str(res.error))
    big = s(0).on(lambda r: None)
    res = BinaryPacker.unpack(bytes([1, 5]) + bytes(300), big)
    check("n=0: 302 bytes is not too_long (unprotected rules)", isinstance(res.error, TrailingBytes), str(res.error))
    # caller's buffer is not written
    n = 8
    h = s(n).on(lambda r: None)
    good = bytearray(BinaryPacker.pack(s(n), {"v": 9}))
    bad = bytearray(good)
    bad[0] ^= 0x55
    bad[-1] ^= 0x11
    before = bytes(bad)
    res = BinaryPacker.unpack(bad, h, limit=4)
    check("repair of 2 bytes returns the row, count 2", res.ok and res.repaired == 2 and res.value == {"v": 9}, str(res))
    check("the caller's bytearray is unchanged after a repair", bytes(bad) == before)
    mv = memoryview(bad)
    BinaryPacker.unpack(mv, h, limit=4)
    check("a memoryview of the caller's buffer is unchanged", bytes(bad) == before)
    # check order of a dispatch
    h1 = s(4, 1).on(lambda r: None)
    h1b = s(4, 1).on(lambda r: None)
    h2 = s(2, 2).on(lambda r: None)
    for name, handlers, lim, want in (
        ("duplicate + mix: duplicate named first", (h1, h1b, h2), 0, "duplicate"),
        ("mix + bad limit: mix named first", (h1, h2), 9, "one parity count"),
        ("bad limit", (h1,), 3, "limit"),
        ("negative limit", (h1,), -1, "limit"),
        ("bool limit", (h1,), True, "limit"),
    ):
        try:
            BinaryPacker.unpack(b"\x01", *handlers, limit=lim)
            check(name, False, "accepted")
        except ValueError as e:
            check(name, want in str(e), str(e))
    try:
        BinaryPacker.unpack(b"\x01")
        check("empty handler list refused", False, "accepted")
    except TypeError as e:
        check("empty handler list refused (TypeError)", True, str(e))
    try:
        BinaryPacker.unpack(50_000_000, h1)  # type: ignore[arg-type]
        info("clear unpack: int payload", "accepted?")
    except TypeError as e:
        info("clear unpack: int payload", f"TypeError ({e})")


if __name__ == "__main__":
    signal.alarm(100)
    print(f"python {sys.version.split()[0]}, load {os.getloadavg()}")
    text_edges()
    ecc_edges()
    print(f"{fails} FAIL, load {os.getloadavg()}")
    sys.exit(1 if fails else 0)
