# Run: python3.14 -I -B text_amp.py <repo checkout>   (AZ-2666 probe (c), Python)
"""Compact text amplification and cost in the Python package.

For each payload it prints the packet size, the decoded UTF-8 size, the ratio to the 6N + 8 bound, the time of one
unpack (median of several, without tracing) and the peak of the bytes Python allocates during one unpack
(`tracemalloc`). Cases: the densest text (Russian `о`, 3 bits for 2 bytes) at the 65,535-byte limit, the same text
with one 4-byte character (a UCS-4 `str`), 65,536 bytes (refused), a 2,097,151-byte payload of mode switches only
(no output, so the 65,535 cap never stops it), a raw payload of 2,097,151 bytes (refused by length), lists of many
limit-sized texts, and a dict of 65,535 keys with a duplicate last key.
"""

from __future__ import annotations

import os
import resource
import signal
import statistics
import sys
import time
import tracemalloc

REPO = os.path.abspath(sys.argv[1])
sys.path.insert(0, os.path.join(REPO, "python", "src"))

from packbin import BinaryPacker, Scheme, u8, utf8  # noqa: E402
from packbin import dict as map_field  # noqa: E402
from packbin import list as list_field  # noqa: E402
from packbin import _text_model as M  # noqa: E402
from packbin._text_decode import decode_text, TextRefusal  # noqa: E402

ONE = Scheme(1, dict, utf8(0, lambda row: row["s"]))
LIST = Scheme(1, dict, list_field(lambda row: row["xs"], utf8(0, lambda row: row)))
DICT = Scheme(1, dict, map_field(lambda row: row["d"], u8(0, lambda row: row)))
LIST_U8 = Scheme(1, dict, list_field(lambda row: row["xs"], list_field(lambda row: row, u8(0, lambda row: row))))


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


def stream(start: int, symbols: list[tuple[int, int]]) -> bytes:
    """A compact field: the count, then pad, start mode and the given (code, length) symbols."""
    text = "".join(format(code, f"0{length}b") for code, length in symbols)  # linear; a growing int would be quadratic
    total = 6 + len(text)
    nbytes = (total + 7) // 8
    pad = nbytes * 8 - total
    payload = int(format(pad, "03b") + format(start, "03b") + text + "0" * pad, 2).to_bytes(nbytes, "big")
    return varint(nbytes) + payload


def code_of(mode: int, char: str) -> tuple[int, int]:
    tab = M.decode_mode(mode)
    return M.CODES[mode][tab.low.index(char)]


def switch_code(mode: int, target: int) -> tuple[int, int]:
    return M.CODES[mode][M.SWITCH_AT[mode][target]]


def measure(name: str, scheme: Scheme, packet: bytes, reps: int = 5) -> None:
    times = []
    result = None
    for _ in range(reps):
        t0 = time.perf_counter()
        result = BinaryPacker.unpack(packet, scheme.on(lambda row: None))
        times.append(time.perf_counter() - t0)
    tracemalloc.start()
    tracemalloc.reset_peak()
    BinaryPacker.unpack(packet, scheme.on(lambda row: None))
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    decoded = 0
    if result is not None and result.ok:
        value = result.value
        for v in (value.get("s"), *(value.get("xs") or []), *((value.get("d") or {}).keys())):
            if isinstance(v, str):
                decoded += len(v.encode("utf-8"))
    status = "ok" if result is not None and result.ok else f"refused {type(result.error).__name__}"
    bound = 6 * len(packet) + 8
    print(
        f"  {name:52s} packet {len(packet):9d} B  decoded {decoded:9d} B ({decoded / max(1, len(packet)):.2f}/B, bound {bound})  "
        f"{status:24s} median {statistics.median(times) * 1e3:9.2f} ms  max {max(times) * 1e3:9.2f} ms  "
        f"peak alloc {peak / 1e6:8.2f} MB ({peak / max(1, len(packet)):.1f}/B)"
    )


def main() -> None:
    signal.alarm(115)
    print(f"python {sys.version.split()[0]}, load {os.getloadavg()}")
    # the densest symbol of each mode, from the frozen tables
    for m in range(4):
        tab = M.decode_mode(m)
        best = max(
            (tab.size[i] / M.CODES[m][i][1], tab.low[i]) for i in range(len(tab.kind)) if tab.kind[i] == M.KIND_CHAR
        )
        print(f"  mode {m}: densest character {best[1]!r} {best[0] * 8:.2f} UTF-8 bytes per payload byte")

    o_ru = code_of(1, "о")
    space_ru = code_of(1, " ")
    dense = stream(1, [o_ru] * 32767 + [space_ru])  # 65,535 UTF-8 bytes
    measure("largest text: 32,767 x 'о' + ' ' (65,535 B)", ONE, b"\x01" + dense)
    packed = BinaryPacker.pack(ONE, {"s": "о" * 32767 + " "})
    print(f"  pack of the same text writes {len(packed)} B (stream above {len(dense) + 1} B)")
    esc = M.CODES[1][M.ESC_AT[1]]
    emoji = [esc] + [(b, 8) for b in "😀".encode("utf-8")]
    ucs4 = stream(1, emoji + [o_ru] * 32765 + [space_ru])  # 4 + 65,530 + 1 = 65,535
    measure("largest text with one 4-byte char (UCS-4 str)", ONE, b"\x01" + ucs4)
    over = stream(1, [o_ru] * 32768)  # 65,536 UTF-8 bytes
    measure("65,536 B of 'о' (refused: length)", ONE, b"\x01" + over)

    # mode switches only: ua -> num (8 bits), num -> ua (6 bits); no output
    to_num = switch_code(0, 3)
    to_ua = switch_code(3, 0)
    count = 2_097_151
    pairs, rest = divmod(8 * count - 6, to_num[1] + to_ua[1])
    symbols = [to_num, to_ua] * pairs
    if rest == to_num[1]:
        symbols.append(to_num)
    switches = stream(0, symbols)
    assert len(switches) == 3 + count, len(switches)
    t0 = time.perf_counter()
    text, _ = decode_text(b"\x00" + switches, 1)
    dt = time.perf_counter() - t0
    print(
        f"  2,097,151 B payload of {len(symbols):,} switch symbols (no output): decode_text {dt:.3f} s, "
        f"{dt / count * 1e6:.2f} us per payload byte, text length {len(text)}"
    )
    measure("same, through unpack", ONE, b"\x01" + switches, reps=1)
    lock = M.CODES[0][M.LOCK_AT[0]]
    locks = stream(0, [lock] * ((8 * 20000 - 6) // lock[1]))
    measure("20,000 B of LOCK toggles (no output)", ONE, b"\x01" + locks, reps=3)

    # raw payload above the limit: refused, but after the UTF-8 decode
    raw_body = "😀".encode() + b"a" * (count - 1 - 4)
    raw = varint(count) + b"\x10" + raw_body
    measure("raw payload of 2,097,151 B (refused: length)", ONE, b"\x01" + raw, reps=3)
    raw_ok = varint(65536) + b"\x10" + "😀".encode() + b"a" * (65535 - 4)
    measure("raw payload of 65,535 UTF-8 B (accepted)", ONE, b"\x01" + raw_ok, reps=3)

    # many limit-sized texts in one packet, default limits
    for k in (16, 64, 256):
        packet = b"\x01" + k.to_bytes(2, "little") + dense * k
        measure(f"list of {k} x 65,535-B texts", LIST, packet, reps=2)
    for k in (16, 64, 256):
        packet = b"\x01" + k.to_bytes(2, "little") + ucs4 * k
        measure(f"list of {k} x 65,535-B texts with a 4-byte char", LIST, packet, reps=2)
    # baseline: the same packet size of plain bytes in nested u8 lists
    inner = (65535).to_bytes(2, "little") + bytes(65535)
    for k in (16,):
        packet = b"\x01" + k.to_bytes(2, "little") + inner * k
        measure(f"baseline: {k} lists of 65,535 u8", LIST_U8, packet, reps=2)

    # dict of 65,535 distinct keys (digits), and the same with the last key repeating the first
    keys = [str(i) for i in range(65535)]
    good = BinaryPacker.pack(DICT, {"d": {k: 1 for k in keys}})
    measure("dict of 65,535 keys", DICT, good, reps=3)
    order = sorted(keys, key=lambda k: k.encode())
    first_key = BinaryPacker.pack(ONE, {"s": order[0]})[1:]
    last_key = BinaryPacker.pack(ONE, {"s": order[-1]})[1:]
    # keys are sorted by bytes on pack; find the last pair and swap its key for the first key
    tail = last_key + b"\x01"
    pos = good.rfind(tail)
    if pos > 0:
        dup = good[:pos] + first_key + b"\x01" + good[pos + len(tail):]
        measure("dict of 65,535 keys, last key = first (refused)", DICT, dup, reps=3)
    # many tiny strings
    packet = b"\x01" + (65535).to_bytes(2, "little") + b"\x00" * 65535
    measure("list of 65,535 empty strings", LIST, packet, reps=3)
    one_char = BinaryPacker.pack(ONE, {"s": "я"})[1:]
    packet = b"\x01" + (65535).to_bytes(2, "little") + one_char * 65535
    measure("list of 65,535 one-letter strings", LIST, packet, reps=3)
    # session: the pad is removed from the whole payload before anything is parsed (n = 0 has no 254-byte limit)
    from packbin import PackSession
    for size in (254, 65536, 262144, 1048576):
        receiver = PackSession.load(bytes(range(1, 33)))
        receiver.join(bytes(16))
        payload = os.urandom(size)
        for n in ((0,) if size > 254 else (0, 32)):
            sch = ONE.with_limits(parity=n)
            t0 = time.perf_counter()
            res = receiver.unpack(payload, sch.on(lambda row: None), limit=n // 2)
            dt = time.perf_counter() - t0
            print(f"  session unpack of {size:8d} random bytes, n={n:2d}: {type(res.error).__name__:14s} {dt * 1e3:9.2f} ms ({dt / size * 1e6:.2f} us per byte)")
    rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    print(f"max RSS of the run {rss / 1e6:.1f} MB, load {os.getloadavg()}")


if __name__ == "__main__":
    main()
