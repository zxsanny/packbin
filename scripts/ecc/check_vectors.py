"""Re-derives every row of fixtures/ecc/vectors.txt with the reference codec and checks coverage (AZ-2679).
Usage: check_vectors.py [vectors]. Exit 0 on success, 1 on any mismatch."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eccfmt as e  # noqa: E402


def unhex(s):
    return b"" if s == "-" else bytes.fromhex(s)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fixtures", "ecc", "vectors.txt")
    errors = []
    seen = {"enc_n": set(), "fix_n": set(), "kinds": set(), "rows": 0, "ids": set(), "lim": set()}
    for ln, line in enumerate(open(path), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = line.split(" ")
        kind, rid = f[0], f[1] if len(f) > 1 else ""
        seen["rows"] += 1
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
            else:
                errors.append("%d: unknown row kind %s" % (ln, kind))
        except (IndexError, ValueError) as x:
            errors.append("%d: %s malformed: %s" % (ln, rid, x))
    if not {0, 1, 2, 4, 8, 16, 32} <= seen["enc_n"]:
        errors.append("enc rows miss n values: have %s" % sorted(seen["enc_n"]))
    if not {2, 4, 8, 16, 32} <= seen["fix_n"]:
        errors.append("fix rows miss n values: have %s" % sorted(seen["fix_n"]))
    if not {"uncorrectable", "short", "too_long"} <= seen["kinds"]:
        errors.append("bad rows miss kinds: have %s" % sorted(seen["kinds"]))
    if not {"ok", "too_long"} <= seen["lim"]:
        errors.append("lim rows miss outcomes")
    if seen["rows"] < 100:
        errors.append("only %d rows, expected at least 100" % seen["rows"])
    for x in errors:
        print("FAIL " + x)
    print("%s: %d rows, %d errors" % (path, seen["rows"], len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
