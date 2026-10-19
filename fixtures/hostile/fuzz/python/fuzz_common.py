"""Shared setup of the AZ-2666 fuzz probes (`fuzz_text.py`, `fuzz_ecc_session.py`); not run on its own.

Reads the command line of the runnable probe (`<repo checkout> [seed] [seconds per part]`), puts the checkout's
`python/src` on the path, loads the reference codecs (`scripts/text/textfmt.py`, `scripts/ecc/eccfmt.py`) and the
seed inputs (text and ECC vectors, the hostile corpus and cases), and holds the seeded generator, the findings list,
the per-part statistics, the mutator and the public-unpack check.
"""

from __future__ import annotations

import importlib.util
import os
import random
import statistics
import sys
import time

REPO = os.path.abspath(sys.argv[1])
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else int(time.time())
BUDGET = float(sys.argv[3]) if len(sys.argv) > 3 else 25.0
sys.path.insert(0, os.path.join(REPO, "python", "src"))

import packbin  # noqa: E402
from packbin import BinaryPacker, PackSession, UnpackResult  # noqa: E402


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


textfmt = _load("ref_textfmt", os.path.join(REPO, "scripts", "text", "textfmt.py"))
eccfmt = _load("ref_eccfmt", os.path.join(REPO, "scripts", "ecc", "eccfmt.py"))
TABLES = textfmt.Tables.load(os.path.join(REPO, "fixtures", "text", "tables.json"))

rng = random.Random(SEED)
findings: list[str] = []


def note(msg: str) -> None:
    if len(findings) < 40:
        findings.append(msg)


class Stats:
    def __init__(self, name: str) -> None:
        self.name = name
        self.calls = 0
        self.accepted = 0
        self.refused = 0
        self.times: list[float] = []
        self.slowest = (0.0, "")
        self.mismatch = 0
        self.exceptions = 0

    def timed(self, label: str, fn):
        t0 = time.perf_counter()
        try:
            out = fn()
        finally:
            dt = time.perf_counter() - t0
            self.calls += 1
            self.times.append(dt)
            if dt > self.slowest[0]:
                self.slowest = (dt, label)
        return out

    def report(self) -> str:
        med = statistics.median(self.times) if self.times else 0.0
        return (
            f"{self.name}: calls {self.calls}, accepted {self.accepted}, refused {self.refused}, "
            f"mismatches vs reference {self.mismatch}, foreign exceptions {self.exceptions}, "
            f"median {med * 1e6:.1f} us, slowest {self.slowest[0] * 1e3:.3f} ms ({self.slowest[1][:90]})"
        )


def read_rows(rel: str) -> list[list[str]]:
    rows = []
    with open(os.path.join(REPO, rel), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            rows.append(line.split())
    return rows


TEXT_SEEDS: list[bytes] = []  # every field of fixtures/text/vectors.txt
for row in read_rows("fixtures/text/vectors.txt"):
    if row[0] in ("enc", "alt"):
        TEXT_SEEDS.append(bytes.fromhex(row[3]))
    elif row[0] == "bad":
        TEXT_SEEDS.append(bytes.fromhex(row[3]) if len(row) > 3 else b"")
ECC_SEEDS: list[tuple[int, int, bytes]] = []  # (n, t, received) from fixtures/ecc/vectors.txt
for row in read_rows("fixtures/ecc/vectors.txt"):
    if row[0] in ("fix", "bad") and row[4] != "-" and len(row[4]) <= 2 * 300:
        ECC_SEEDS.append((int(row[2]), int(row[3]), bytes.fromhex(row[4])))
    elif row[0] == "enc" and row[4] != "-":
        ECC_SEEDS.append((int(row[2]), 0, bytes.fromhex(row[4])))
PACKETS: list[bytes] = []  # hostile and ring packets: fixtures/hostile/fuzz/corpus.txt and fixtures/hostile/cases.txt
for row in read_rows("fixtures/hostile/fuzz/corpus.txt"):
    PACKETS.append(bytes.fromhex(row[2]))
for row in read_rows("fixtures/hostile/cases.txt"):
    if len(row) >= 4 and row[3] != "-":
        PACKETS.append(bytes.fromhex(row[3]))


def varint(n: int) -> bytes:
    return textfmt.varint(n)


def mutate(data: bytes) -> bytes:
    """Bit flips, byte changes, inserts, deletes, cuts, extensions and a rewritten count header."""
    buf = bytearray(data)
    for _ in range(rng.choice([1, 1, 2, 3, 8])):
        op = rng.randrange(7)
        if op == 0 and buf:
            i = rng.randrange(len(buf))
            buf[i] ^= 1 << rng.randrange(8)
        elif op == 1 and buf:
            buf[rng.randrange(len(buf))] = rng.randrange(256)
        elif op == 2:
            buf.insert(rng.randrange(len(buf) + 1), rng.randrange(256))
        elif op == 3 and buf:
            del buf[rng.randrange(len(buf))]
        elif op == 4 and buf:
            del buf[rng.randrange(len(buf)):]
        elif op == 5:
            buf += bytes(rng.randrange(256) for _ in range(rng.randint(1, 8)))
        elif op == 6 and buf:
            body = bytes(buf)
            try:
                _, off = textfmt.read_varint(body, 0)
            except textfmt.Refusal:
                off = 1
            count = rng.choice([0, 1, 127, 128, 16383, 16384, 65536, 2097151, rng.randrange(1 << 21)])
            buf = bytearray(varint(count) + body[off:])
    return bytes(buf)


def public_unpack(packet, handlers, limit: int = 0, session: PackSession | None = None) -> UnpackResult:
    """The public call; anything but an `UnpackResult` coming out is the finding."""
    if session is None:
        out = BinaryPacker.unpack(packet, *handlers, limit=limit)
    else:
        out = session.unpack(packet, *handlers, limit=limit)
    if not isinstance(out, UnpackResult):
        raise AssertionError(f"unpack returned {type(out)!r}")
    return out


def banner() -> float:
    print(f"seed {SEED}, budget {BUDGET:.0f} s per part, python {sys.version.split()[0]}, load {os.getloadavg()}")
    print(f"packbin from {os.path.dirname(packbin.__file__)}")
    return time.perf_counter()


def finish(t0: float) -> int:
    print(f"total {time.perf_counter() - t0:.1f} s, load {os.getloadavg()}")
    if findings:
        print(f"FINDINGS ({len(findings)} shown):")
        for f in findings:
            print("  " + f)
        return 1
    print("no findings: only UnpackResult / TextRefusal came out, every result equals the reference")
    return 0
