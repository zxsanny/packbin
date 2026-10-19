# Run: python3.14 -I -B ecc_worst.py <repo checkout> [seed] [parts abcd]   (AZ-2666 probe (b), Python)
"""Worst-case ECC repair work, and an exhaustive (n, N) sweep against the reference decoder.

Part A times 254-byte buffers at n = 32 built for the most work: a code word with 16 wrong bytes (the longest path
that repairs), 17 wrong bytes (Chien search over every position, then a near-miss root count), random bytes, and the
default limit t = 0 (detect only). It prints the median and the slowest call, through `_ecc.repair` and through
`BinaryPacker.unpack`, and counts the field operations of each path to compare with the contract's 255 x 32.
Part B runs every n = 1..32 and every N = n..254 (and 255) with several inputs each and compares the package with
`scripts/ecc/eccfmt.py`; it also tallies which repair step refused (degree, root count, derivative, verification).
"""

from __future__ import annotations

import importlib.util
import os
import random
import signal
import statistics
import sys
import time

REPO = os.path.abspath(sys.argv[1])
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 2666
sys.path.insert(0, os.path.join(REPO, "python", "src"))

from packbin import BinaryPacker, Scheme, repeat, u8  # noqa: E402
from packbin import _ecc  # noqa: E402

spec = importlib.util.spec_from_file_location("ref_eccfmt", os.path.join(REPO, "scripts", "ecc", "eccfmt.py"))
eccfmt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(eccfmt)

rng = random.Random(SEED)


def corrupt(word: bytes, k: int, positions=None) -> bytes:
    buf = bytearray(word)
    for p in positions if positions is not None else rng.sample(range(len(buf)), k):
        buf[p] ^= rng.randrange(1, 256)
    return bytes(buf)


def codeword(n: int, size: int) -> bytes:
    clear = bytearray(rng.randrange(256) for _ in range(size - n))
    if clear:
        clear[0] = 1
    return eccfmt.protect(bytes(clear), n)


# ------------------------------------------------------------- operation counts

class Counter:
    mul = 0
    synd = 0
    par = 0


_orig_mul = _ecc._mul
_orig_synd = _ecc._syndromes
_orig_parity = _ecc.parity


def _count_mul(a: int, b: int) -> int:
    Counter.mul += 1
    return _orig_mul(a, b)


def _count_synd(word: bytes, n: int):
    Counter.synd += n * (len(word) + 1)  # one multiply-add per byte of [L] + word, per syndrome
    return _orig_synd(word, n)


def _count_parity(clear, n: int):
    Counter.par += n * (len(clear) + 1)  # one feedback row (n multiply-adds) per byte of [L] + clear
    return _orig_parity(clear, n)


def count_ops(received: bytes, n: int, t: int) -> tuple[int, object]:
    Counter.mul = Counter.synd = Counter.par = 0
    _ecc._mul, _ecc._syndromes, _ecc.parity = _count_mul, _count_synd, _count_parity
    try:
        out = _ecc.repair(received, n, t)
    finally:
        _ecc._mul, _ecc._syndromes, _ecc.parity = _orig_mul, _orig_synd, _orig_parity
    return Counter.mul + Counter.synd + Counter.par, out


def timed(fn, reps: int) -> tuple[float, float]:
    times = []
    for _ in range(reps):
        t0 = time.perf_counter()
        fn()
        times.append(time.perf_counter() - t0)
    return statistics.median(times), max(times)


def part_a() -> None:
    n, size = 32, 254
    scheme = Scheme(1, dict, repeat(0, u8(0, lambda row: row["v"]))).with_limits(parity=n)
    handler = scheme.on(lambda row: None)
    cases = []
    word = codeword(n, size)
    _ecc.repair(corrupt(word, 16), n, 16)  # warm the cached tables (generator rows, syndrome rows) so counts are per call
    cases.append(("intact, t=16", word, 16))
    cases.append(("16 wrong (max repair), t=16", corrupt(word, 16), 16))
    cases.append(("16 wrong in the parity, t=16", corrupt(word, 16, range(size - 16, size)), 16))
    cases.append(("17 wrong (near miss), t=16", corrupt(word, 17), 16))
    cases.append(("random bytes, t=16", bytes(rng.randrange(256) for _ in range(size)), 16))
    cases.append(("1 wrong, t=16", corrupt(word, 1), 16))
    cases.append(("16 wrong, default t=0", corrupt(word, 16), 0))
    cases.append(("random bytes, default t=0", bytes(rng.randrange(256) for _ in range(size)), 0))
    # search for the slowest refused 254-byte buffer: many near-misses, keep the one whose locator degree is 16
    near = None
    for _ in range(400):
        cand = corrupt(word, rng.choice([17, 18, 20, 24, 32]))
        lam = _ecc._locator(_ecc._syndromes(cand, n), n)
        if len(lam) - 1 == 16:
            near = cand
            break
    if near is not None:
        cases.append(("17+ wrong, locator degree 16 (full Chien, refused), t=16", near, 16))
    print(f"part A: n={n}, N={size}, load {os.getloadavg()}")
    worst = 0.0
    for name, buf, t in cases:
        ops, out = count_ops(buf, n, t)
        verdict = "refused" if out is None else f"repaired {out[1]}"
        med, slow = timed(lambda: _ecc.repair(buf, n, t), 300)
        pmed, pslow = timed(lambda: BinaryPacker.unpack(buf, handler, limit=t), 300)
        worst = max(worst, slow, pslow)
        print(
            f"  {name:58s} {verdict:12s} ops {ops:6d} ({ops / (255 * 32):.2f} x 255*32)  "
            f"repair median {med * 1e3:.3f} ms slowest {slow * 1e3:.3f} ms; unpack median {pmed * 1e3:.3f} ms slowest {pslow * 1e3:.3f} ms"
        )
    print(f"  slowest single call in part A: {worst * 1e3:.3f} ms, load {os.getloadavg()}")


# ------------------------------------------------------------- sweep against the reference

def ref(received: bytes, n: int, t: int):
    try:
        clear, count = eccfmt.decode(received, n, t)
        return ("ok", clear, count)
    except eccfmt.EccError as e:
        return ("refused", e.kind)


def pkg(received: bytes, n: int, t: int):
    if len(received) > _ecc.MAX_BLOCK:
        return ("refused", "too_long")
    if len(received) < n:
        return ("refused", "short")
    got = _ecc.repair(received, n, t)
    return ("refused", "uncorrectable") if got is None else ("ok", got[0], got[1])


def refusal_step(received: bytes, n: int, t: int) -> str:
    """Which step of the contract's repair refuses (recomputed with the package's own helpers)."""
    size = len(received)
    synd = _ecc._syndromes(received, n)
    if not any(synd):
        return "intact"
    if t == 0:
        return "detect-only"
    lam = _ecc._locator(synd, n)
    deg = len(lam) - 1
    if deg == 0 or deg > t:
        return "degree"
    roots = [p for p in range(size) if _ecc._poly_eval(lam, _ecc._EXP[(255 - (size - 1 - p)) % 255]) == 0]
    if len(roots) != deg:
        return "roots"
    dl = [lam[i] if i % 2 == 1 else 0 for i in range(1, len(lam))]
    for p in roots:
        if _ecc._poly_eval(dl, _ecc._inv(_ecc._EXP[(size - 1 - p) % 255])) == 0:
            return "derivative"
    out = _ecc.repair(received, n, t)
    return "repaired" if out is not None else "verification"


def part_b() -> None:
    t0 = time.perf_counter()
    calls = mismatch = exceptions = 0
    steps: dict[str, int] = {}
    slow = (0.0, "")
    examples: list[str] = []
    for n in range(1, 33):
        for size in list(range(n, 255)) + [255]:
            for kind in range(4):
                t = n // 2 if kind != 3 else rng.randint(0, n // 2)
                if size > 254:
                    buf = bytes(rng.randrange(256) for _ in range(size))
                elif kind == 0:
                    buf = bytes(rng.randrange(256) for _ in range(size))
                else:
                    w = codeword(n, size)
                    k = [max(1, t), t + 1, rng.randint(1, max(1, n))][kind - 1]
                    buf = corrupt(w, min(k, size))
                original = bytes(buf)
                a = time.perf_counter()
                try:
                    got = pkg(buf, n, t)
                except Exception as e:  # noqa: BLE001 - a foreign exception is the finding
                    exceptions += 1
                    if len(examples) < 10:
                        examples.append(f"{type(e).__name__} n={n} N={size} t={t} {buf.hex()}")
                    continue
                dt = time.perf_counter() - a
                calls += 1
                if dt > slow[0]:
                    slow = (dt, f"n={n} N={size} t={t} kind={kind}")
                want = ref(buf, n, t)
                if got[0] != want[0] or (got[0] == "ok" and got[1:] != want[1:]):
                    mismatch += 1
                    if len(examples) < 10:
                        examples.append(f"mismatch n={n} N={size} t={t} pkg={got[0]} ref={want[0]} {buf.hex()}")
                if buf != original:
                    examples.append(f"input written n={n} N={size}")
                if size <= 254 and size >= n and kind in (1, 2) and n >= 2:
                    s = refusal_step(buf, n, t)
                    steps[s] = steps.get(s, 0) + 1
    print(
        f"part B: n 1..32 x N n..255 x 4 inputs: calls {calls}, mismatches vs reference {mismatch}, "
        f"foreign exceptions {exceptions}, slowest {slow[0] * 1e3:.3f} ms ({slow[1]}), {time.perf_counter() - t0:.1f} s, load {os.getloadavg()}"
    )
    print(f"  repair steps reached by the code-word inputs: {dict(sorted(steps.items()))}")
    for e in examples:
        print("  " + e)


def part_c() -> None:
    """Hunt for the rare refusal steps (zero derivative, failed verification) with random buffers near the limit."""
    t0 = time.perf_counter()
    found: dict[str, int] = {}
    tries = 0
    while time.perf_counter() - t0 < 20:
        n = rng.choice([2, 3, 4, 5, 6, 8])
        size = rng.randint(n, 40)
        t = n // 2
        buf = bytes(rng.randrange(256) for _ in range(size))
        s = refusal_step(buf, n, t)
        found[s] = found.get(s, 0) + 1
        tries += 1
    print(f"part C: {tries} random short buffers (n 2..8, N n..40, t = n/2): steps {dict(sorted(found.items()))}, load {os.getloadavg()}")


def part_d() -> None:
    """Poison GF(256) log(0): any log of 0 or inverse of 0 now indexes far outside EXP and raises IndexError. Then
    rerun inputs of every n and many N; an IndexError would mean the decoder took log(0) or inv(0)."""
    saved = _ecc._LOG[0]
    _ecc._LOG[0] = 100_000
    t0 = time.perf_counter()
    calls = errors = 0
    try:
        try:
            _ecc._inv(0)
            print("  poison check: inv(0) did not raise, the probe is not valid")
        except IndexError:
            pass
        for n in range(1, 33):
            for size in range(n, 255, 3):
                for kind in range(3):
                    t = n // 2
                    if kind == 0:
                        buf = bytes(rng.randrange(256) for _ in range(size))
                    else:
                        buf = corrupt(codeword(n, size), min(size, [max(1, t), t + 1][kind - 1]))
                    try:
                        _ecc.repair(buf, n, t)
                        _ecc.parity(buf[: size - n], n)
                    except IndexError as e:
                        errors += 1
                        print(f"  log/inv of 0 taken: n={n} N={size} {e}")
                    calls += 1
            for zeros in (bytes(n), bytes(254)):
                _ecc.repair(zeros, n, n // 2)
                calls += 1
    finally:
        _ecc._LOG[0] = saved
    print(f"part D: log(0) poisoned, {calls} repairs of n 1..32: IndexError {errors}, {time.perf_counter() - t0:.1f} s, load {os.getloadavg()}")


if __name__ == "__main__":
    signal.alarm(115)
    print(f"seed {SEED}, python {sys.version.split()[0]}")
    parts = sys.argv[3] if len(sys.argv) > 3 else "abcd"
    if "a" in parts:
        part_a()
    if "b" in parts:
        part_b()
    if "c" in parts:
        part_c()
    if "d" in parts:
        part_d()
