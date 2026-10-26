# Run: python3.14 -I -B fuzz_ecc_session.py <repo checkout> [seed] [seconds per part]   (AZ-2666 probe (a), Python, ECC)
"""Seeded ECC inputs against the Python repair and the protected unpack path.

Random buffers, code words with k wrong bytes, cut or extended words, `fixtures/ecc/vectors.txt` rows and protected
corpus packets go through `_ecc.repair` and `scripts/ecc/eccfmt.py` (a different answer is a mismatch), then through
a dispatch of two schemes that share n; the caller's buffer must stay unchanged. The stream session part went with
the stream session (loop 74, ADR-009); the file name stays for the README and the sibling probes. Shared setup is
`fuzz_common.py`.
"""

from __future__ import annotations

import os
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I leaves the script's folder off the path

import fuzz_common as C  # noqa: E402
from fuzz_common import Stats, mutate, note, rng  # noqa: E402
from packbin import Scheme, repeat, u8, utf8  # noqa: E402
from packbin import list as list_field  # noqa: E402
from packbin import _ecc  # noqa: E402


def ref_repair(received: bytes, n: int, t: int):
    try:
        clear, count = C.eccfmt.decode(received, n, t)
        return ("ok", clear, count)
    except C.eccfmt.EccError as e:
        return ("refused", e.kind, 0)


def pkg_repair(received: bytes, n: int, t: int):
    if len(received) > _ecc.MAX_BLOCK:
        return ("refused", "too_long", 0)
    if len(received) < n:
        return ("refused", "short", 0)
    got = _ecc.repair(received, n, t)
    if got is None:
        return ("refused", "uncorrectable", 0)
    return ("ok", got[0], got[1])


def ecc_input(n: int) -> tuple[bytes, str]:
    r = rng.random()
    if r < 0.1:
        clear = rng.choice(C.PACKETS)[: 254 - n]
        return mutate(C.eccfmt.protect(clear, n)), "corpus packet protected, mutated"
    size = rng.choice([n, n + 1, n + 2, 254, 253, 255, 256, rng.randint(n, 254), rng.randint(n, 254)])
    if r < 0.25:
        return bytes(rng.randrange(256) for _ in range(size)), "random"
    clear = bytearray(rng.randrange(256) for _ in range(max(0, min(254 - n, size - n))))
    if clear and rng.random() < 0.7:
        clear[0] = 1  # the repeat-of-u8 scheme reads any clear bytes that start with its type
    word = bytearray(C.eccfmt.protect(bytes(clear), n))
    if r < 0.85:
        k = rng.choice([1, n // 2, n // 2 + 1, n // 2 + 2, n - n // 2, n, rng.randint(1, max(1, n)), rng.randint(1, len(word))])
        k = max(1, min(k, len(word)))
        for p in rng.sample(range(len(word)), k):
            word[p] ^= rng.randrange(1, 256)
        return bytes(word), f"codeword+{k}"
    if r < 0.92:
        return bytes(word[:-1] if word else word) + (b"" if rng.random() < 0.5 else b"\x00\x00"), "cut/extended"
    return mutate(bytes(word)), "mutated"


_SCHEMES: dict[int, tuple] = {}


def ecc_handlers(n: int) -> tuple:
    """Two schemes that share n: a repeat of u8 (type 1), and a string then a list of strings (type 2)."""
    got = _SCHEMES.get(n)
    if got is None:
        s1 = Scheme(1, dict, repeat(0, u8(0, lambda row: row["v"]))).with_limits(parity=n)
        s2 = Scheme(2, dict, utf8(0, lambda row: row["s"]), list_field(lambda row: row["xs"], utf8(0, lambda row: row)))
        got = _SCHEMES[n] = (s1.on(lambda r: None), s2.with_limits(parity=n).on(lambda r: None))
    return got


def next_ecc_case() -> tuple[int, int, bytes, str] | None:
    if rng.random() < 0.15:
        n, t, received = rng.choice(C.ECC_SEEDS)
        if n == 0:
            return None
        if rng.random() < 0.7:
            return n, t, mutate(received), "ecc vector mutated"
        return n, t, received, "ecc vector"
    n = rng.choice([1, 2, 3, 4, 8, 16, 31, 32, rng.randint(1, 32)])
    t = rng.choice([0, n // 2, rng.randint(0, n // 2)])
    received, how = ecc_input(n)
    return n, t, received, how


def run_ecc(deadline: float) -> None:
    st = Stats("ecc repair vs reference (n 1..32, N n..256, t 0..n/2)")
    pub = Stats("ecc public unpack (two schemes, one parity)")
    while time.perf_counter() < deadline:
        case = next_ecc_case()
        if case is None:
            continue
        n, t, received, how = case
        original = bytes(received)
        label = f"n={n} t={t} N={len(received)} {how}"
        try:
            got = st.timed(label, lambda: pkg_repair(received, n, t))
        except Exception as e:  # noqa: BLE001 - a foreign exception is the finding
            st.exceptions += 1
            note(f"ecc repair raised {type(e).__name__}: {e} on {label} {received.hex()}")
            continue
        want = ref_repair(received, n, t)
        if got[0] == "ok":
            st.accepted += 1
        else:
            st.refused += 1
        if got != want:
            st.mismatch += 1
            note(f"ecc mismatch pkg={got[0]}/{got[2]} ref={want[0]}/{want[1] if want[0] == 'refused' else want[2]} on {label} {received.hex()}")
        if received != original:
            note(f"ecc input written on {label}")
        buf = bytearray(received)
        try:
            res = pub.timed(label, lambda: C.public_unpack(buf, ecc_handlers(n), limit=t))
            if res.ok:
                pub.accepted += 1
            else:
                pub.refused += 1
            if bytes(buf) != original:
                note(f"public unpack wrote the caller's buffer on {label}")
        except Exception as e:  # noqa: BLE001
            pub.exceptions += 1
            note(f"public ecc unpack raised {type(e).__name__}: {e} on {label} {received.hex()}")
    print(st.report())
    print(pub.report())


def main() -> int:
    signal.alarm(int(C.BUDGET * 2.5) + 60)  # a hang ends the run (SIGALRM) instead of holding a core
    t0 = C.banner()
    run_ecc(time.perf_counter() + C.BUDGET)
    return C.finish(t0)


if __name__ == "__main__":
    sys.exit(main())
