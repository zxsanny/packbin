"""Seeded counts of EC-5, EC-6, EC-7 and EC-14 on the reference codec (AZ-2679). Exit 1 when a bound is missed."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eccfmt as e  # noqa: E402

POS = bytes.fromhex("4001000065cd1d00a3e1110100")
rng = random.Random(1)


def wrong_bytes(word, k):
    w = bytearray(word)
    for p in rng.sample(range(len(w)), k):
        w[p] ^= rng.randint(1, 255)
    return bytes(w)


def outcome(word, n, t):
    try:
        clear, rep = e.decode(word, n, t)
        return "row" if clear == POS else "wrong", rep
    except e.EccError:
        return "err", 0


def main():
    bad = []
    # EC-5: all single-byte errors at n = 2 (15 positions x 255 values), then seeded cases up to t
    p2 = e.protect(POS, 2)
    ok = sum(1 for p in range(len(p2)) for v in range(1, 256) if outcome(p2[:p] + bytes([p2[p] ^ v]) + p2[p + 1:], 2, 1) == ("row", 1))
    print("EC-5 n=2 single byte: %d of %d" % (ok, len(p2) * 255))
    bad += [] if ok == len(p2) * 255 else ["EC-5 exhaustive"]
    for n in (4, 8, 16):
        prot, good = e.protect(POS, n), 0
        for _ in range(1000):
            k = rng.randint(1, n // 2)
            good += outcome(wrong_bytes(prot, k), n, n // 2) == ("row", k)
        print("EC-5 n=%d: %d of 1000" % (n, good))
        bad += [] if good == 1000 else ["EC-5 n=%d" % n]
    # EC-6
    p4 = e.protect(POS, 4)
    r1 = [outcome(wrong_bytes(p4, rng.choice((2, 3))), 4, 1)[0] for _ in range(10000)]
    r0 = [outcome(wrong_bytes(p4, rng.randint(1, 4)), 4, 0)[0] for _ in range(10000)]
    print("EC-6 n=4 t=1 (2-3 wrong): refused %d, row/wrong %d" % (r1.count("err"), 10000 - r1.count("err")))
    print("EC-6 n=4 t=0 (1-4 wrong): refused %d, row/wrong %d" % (r0.count("err"), 10000 - r0.count("err")))
    bad += [] if r1.count("err") == 10000 and r0.count("err") == 10000 else ["EC-6"]
    # EC-7
    accepted = sum(1 for _ in range(200000) if outcome(bytes(rng.randrange(256) for _ in range(15)), 2, 0)[0] != "err")
    print("EC-7 garbage n=2 t=0: accepted %d of 200000 (bound 12)" % accepted)
    bad += [] if accepted <= 12 else ["EC-7"]
    # EC-14
    wrong = 0
    for _ in range(10000):
        cut = rng.randint(1, 3)
        w = p4[:-cut] if rng.random() < 0.5 else p4 + bytes(rng.randrange(256) for _ in range(cut))
        wrong += outcome(w, 4, 0)[0] != "err"
    print("EC-14 truncation/extension n=4 t=0: accepted %d of 10000" % wrong)
    bad += [] if wrong == 0 else ["EC-14"]
    for b in bad:
        print("FAIL " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
