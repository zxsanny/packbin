#!/usr/bin/env python3
"""Round-trip fuzz of the reference codec (AZ-2647 AC-2): N random Unicode strings, encode then decode.

Usage: fuzz_reference.py [count] [seed]     (default 100000, 7)
Prints the number of mismatches and exits non-zero when there is one.
"""
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import textfmt as tf  # noqa: E402
import train_tables as tt  # noqa: E402

T = tf.Tables.load()
POOL = ([chr(c) for c in range(32, 127)] + [chr(c) for c in range(0x400, 0x500)] + ["\n", "\t", "\x00", "́", "—", "€",
        "中", "\U0001f600", "\U0010ffff", "퟿", "", "￿"] + list(tf.UA) * 4 + list(tf.RU) * 4 + list(tf.EN) * 4
        + [u for u in "".join(c for c in tf.UA + tf.RU + tf.EN).upper()] * 2 + list(" 0123456789,.-:!?") * 3)


def make(args):
    seed, i = args
    rng = tt.Rng(seed * 1000003 + i)
    text = "".join(rng.choice(POOL) for _ in range(rng.below(80)))
    try:
        got, end = tf.decode(tf.encode(text, T), 0, T)
    except Exception as e:  # noqa: BLE001 - report every failure as a mismatch
        return "%r: %s" % (text, e)
    return None if got == text else "%r != %r" % (text, got)


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    with mp.get_context("fork").Pool(4) as pool:
        bad = [r for r in pool.imap_unordered(make, [(seed, i) for i in range(count)], chunksize=500) if r]
    print("fuzz: %d strings, %d mismatches" % (count, len(bad)))
    for b in bad[:5]:
        print("  " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
