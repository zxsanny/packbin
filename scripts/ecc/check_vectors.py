"""Re-derives every row of fixtures/ecc/vectors.txt with the reference codec and checks coverage (AZ-2679).
Usage: check_vectors.py [--percent] [file]. Exit 0 on success, 1 on any mismatch.
Without --percent the file is vectors.txt (fixed counts); with it, percent-vectors.txt (a parity percentage, contract 1.1.0)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eccfmt as e  # noqa: E402


def unhex(s):
    return b"" if s == "-" else bytes.fromhex(s)


def exhaustive():
    """Every percentage against every clear length: the count, the round trip, the largest length and the impossible sent lengths."""
    errors, pairs = [], 0
    largest = {1: 251, 10: 230, 25: 222, 50: 222, 100: 222}
    impossible = {0: 0, 1: 3, 10: 24, 25: 32, 50: 32, 100: 32}
    for p in range(e.MAX_PERCENT + 1):
        top = 254 if p == 0 else e.largest_clear(p)
        if p in largest and top != largest[p]:
            errors.append("largest clear length of %d is %d" % (p, top))
        sizes = set()
        for ln in range(top + 1):
            pairs += 1
            n = min(32, (p * ln + 99) // 100)
            msg = bytes((i * 7 + ln) % 256 for i in range(ln))
            prot = e.protect_percent(msg, p)
            sizes.add(len(prot))
            if len(prot) != ln + n or e.decode_percent(prot, p, 0) != (msg, 0):
                errors.append("round trip of percentage %d, length %d" % (p, ln))
        if len(sizes) != top + 1:
            errors.append("percentage %d: two clear lengths share a sent length" % p)
        if p in impossible and sum(1 for size in range(255) if e.clear_length(p, size) is None) != impossible[p]:
            errors.append("percentage %d: wrong count of impossible sent lengths" % p)
        if p and e.protect_percent_refused(p, top + 1) != e.TOO_LONG:
            errors.append("percentage %d accepts length %d" % (p, top + 1))
    if pairs != 22752:
        errors.append("%d pairs, expected 22752" % pairs)
    return errors


def percent_coverage(seen):
    errors = []
    for word in ("pct", "encp", "inv", "limp", "fixp", "badp", "parp", "lmtp"):
        if word not in seen["words"]:
            errors.append("no %s rows" % word)
    if not {0, 1, 10, 25, 50, 100} <= seen["encp_p"]:
        errors.append("encp rows miss percentages: have %s" % sorted(seen["encp_p"]))
    if not {"none", "length"} <= seen["inv"]:
        errors.append("inv rows miss an outcome: have %s" % sorted(seen["inv"]))
    if not {"ok", "too_long"} <= seen["limp"]:
        errors.append("limp rows miss outcomes")
    if not {"uncorrectable", "too_long"} <= seen["badp"]:
        errors.append("badp rows miss kinds: have %s" % sorted(seen["badp"]))
    if not os.environ.get("PACKBIN_ECC_QUICK"):  # the sweep of 22,752 pairs takes about 15 s; the self-test of the check skips it on its corrupted copies
        errors += exhaustive()
    return errors


def main():
    args = [a for a in sys.argv[1:] if a != "--percent"]
    percent = "--percent" in sys.argv[1:]
    path = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fixtures", "ecc", "percent-vectors.txt" if percent else "vectors.txt")
    errors = []
    seen = {"enc_n": set(), "fix_n": set(), "kinds": set(), "rows": 0, "ids": set(), "lim": set(), "words": set(),
            "encp_p": set(), "inv": set(), "badp": set(), "limp": set()}
    for ln, line in enumerate(open(path), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = line.split(" ")
        kind, rid = f[0], f[1] if len(f) > 1 else ""
        seen["rows"] += 1
        seen["words"].add(kind)
        if rid in seen["ids"]:
            errors.append("%d: duplicate id %s" % (ln, rid))
        seen["ids"].add(rid)
        try:
            if kind == "enc":
                n, clear, prot = int(f[2]), unhex(f[3]), unhex(f[4])
                if e.protect(clear, n) != prot:
                    errors.append("%d: %s protect differs" % (ln, rid))
                seen["enc_n"].add(n)
            elif kind == "fix":
                n, t, recv, clear, cnt = int(f[2]), int(f[3]), unhex(f[4]), unhex(f[5]), int(f[6])
                got, rep = e.decode(recv, n, t)
                if got != clear or rep != cnt:
                    errors.append("%d: %s repair gives %s/%d" % (ln, rid, got.hex(), rep))
                seen["fix_n"].add(n)
            elif kind == "bad":
                n, t, recv, want = int(f[2]), int(f[3]), unhex(f[4]), f[5]
                try:
                    got = e.decode(recv, n, t)
                    errors.append("%d: %s accepted %s" % (ln, rid, got[0].hex()))
                except e.EccError as x:
                    if x.kind != want:
                        errors.append("%d: %s refused as %s, row says %s" % (ln, rid, x.kind, want))
                seen["kinds"].add(want)
            elif kind == "lim":
                n, size, want = int(f[2]), int(f[3]), f[4]
                try:
                    e.protect(bytes(size), n)
                    got = "ok"
                except e.EccError as x:
                    got = x.kind
                if got != want:
                    errors.append("%d: %s gives %s" % (ln, rid, got))
                seen["lim"].add(want)
            elif kind == "par":
                try:
                    e.check_parity(int(f[2]))
                    errors.append("%d: %s accepted" % (ln, rid))
                except e.EccError as x:
                    if x.kind != e.BAD_PARITY:
                        errors.append("%d: %s kind %s" % (ln, rid, x.kind))
            elif kind == "lmt":
                try:
                    e.decode(bytes(int(f[2])), int(f[2]), int(f[3]))
                    errors.append("%d: %s accepted" % (ln, rid))
                except e.EccError as x:
                    if x.kind != e.BAD_LIMIT:
                        errors.append("%d: %s kind %s" % (ln, rid, x.kind))
            elif kind == "pct":
                p, size, n = int(f[2]), int(f[3]), int(f[4])
                if e.parity_count(p, size) != n:
                    errors.append("%d: %s count is %d" % (ln, rid, e.parity_count(p, size)))
            elif kind == "encp":
                p, clear, prot = int(f[2]), unhex(f[3]), unhex(f[4])
                if e.protect_percent(clear, p) != prot:
                    errors.append("%d: %s protect differs" % (ln, rid))
                seen["encp_p"].add(p)
            elif kind == "inv":
                p, size = int(f[2]), int(f[3])
                got = e.clear_length(p, size)
                if ("none" if got is None else str(got)) != f[4]:
                    errors.append("%d: %s clear length is %s" % (ln, rid, got))
                seen["inv"].add("none" if got is None else "length")
            elif kind == "limp":
                p, size, want = int(f[2]), int(f[3]), f[4]
                try:
                    e.protect_percent(bytes(size), p)
                    got = "ok"
                except e.EccError as x:
                    got = x.kind
                if got != want:
                    errors.append("%d: %s gives %s" % (ln, rid, got))
                seen["limp"].add(want)
            elif kind == "fixp":
                p, t, recv, clear, cnt = int(f[2]), int(f[3]), unhex(f[4]), unhex(f[5]), int(f[6])
                got, rep = e.decode_percent(recv, p, t)
                if got != clear or rep != cnt:
                    errors.append("%d: %s repair gives %s/%d" % (ln, rid, got.hex(), rep))
            elif kind == "badp":
                p, t, recv, want = int(f[2]), int(f[3]), unhex(f[4]), f[5]
                try:
                    got = e.decode_percent(recv, p, t)
                    errors.append("%d: %s accepted %s" % (ln, rid, got[0].hex()))
                except e.EccError as x:
                    if x.kind != want:
                        errors.append("%d: %s refused as %s, row says %s" % (ln, rid, x.kind, want))
                seen["badp"].add(want)
            elif kind == "parp":
                try:
                    e.check_percent(int(f[2]), int(f[3]))
                    errors.append("%d: %s accepted" % (ln, rid))
                except e.EccError as x:
                    if x.kind != e.BAD_PARITY:
                        errors.append("%d: %s kind %s" % (ln, rid, x.kind))
            elif kind == "lmtp":
                try:
                    e.decode_percent(b"", 25, int(f[2]))
                    errors.append("%d: %s accepted" % (ln, rid))
                except e.EccError as x:
                    if x.kind != e.BAD_LIMIT:
                        errors.append("%d: %s kind %s" % (ln, rid, x.kind))
            else:
                errors.append("%d: unknown row kind %s" % (ln, kind))
        except (IndexError, ValueError) as x:
            errors.append("%d: %s malformed: %s" % (ln, rid, x))
    if not percent:
        if not {0, 1, 2, 4, 8, 16, 32} <= seen["enc_n"]:
            errors.append("enc rows miss n values: have %s" % sorted(seen["enc_n"]))
        if not {2, 4, 8, 16, 32} <= seen["fix_n"]:
            errors.append("fix rows miss n values: have %s" % sorted(seen["fix_n"]))
        if not {"uncorrectable", "short", "too_long"} <= seen["kinds"]:
            errors.append("bad rows miss kinds: have %s" % sorted(seen["kinds"]))
        if not {"ok", "too_long"} <= seen["lim"]:
            errors.append("lim rows miss outcomes")
    else:
        errors += percent_coverage(seen)
    if seen["rows"] < 100:
        errors.append("only %d rows, expected at least 100" % seen["rows"])
    for x in errors:
        print("FAIL " + x)
    print("%s: %d rows, %d errors" % (path, seen["rows"], len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
