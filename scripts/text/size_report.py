#!/usr/bin/env python3
"""Size report of the vectors file (AZ-2657): compact field bytes against today's 2-byte count plus UTF-8.

Usage: size_report.py [vectors] [out.md]
Checks CS-13 on every enc row (never larger than 2 + UTF-8 bytes up to 126 bytes, +1 up to 16,382, +2 above) and
prints a table per row family. Exit 1 when CS-13 fails. The held-out sentence report (CS-1, CS-2, CS-14) is
fixtures/text/tables.report.md, written by train_tables.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")


def main():
    vec = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "fixtures", "text", "vectors.txt")
    out = sys.argv[2] if len(sys.argv) > 2 else None
    fam = {}
    over = []
    with open(vec, encoding="utf8") as f:
        for line in f:
            cols = line.rstrip("\n").split(" ")
            if cols[0] != "enc":
                continue
            raw = b"" if cols[2] == "-" else bytes.fromhex(cols[2])
            field = bytes.fromhex(cols[3])
            today = 2 + len(raw)
            name = ".".join(cols[1].split(".")[1:3]) if cols[1].count(".") >= 2 else cols[1]
            name = name.split("_")[0] if name.startswith("corpus.") else name
            a = fam.setdefault(name, [0, 0, 0])
            a[0] += 1
            a[1] += today
            a[2] += len(field)
            allowed = today + (0 if len(raw) <= 126 else 1 if len(raw) <= 16382 else 2)
            if len(field) > allowed:
                over.append("%s: %d > %d" % (cols[1], len(field), allowed))
    lines = ["# Compact text: size of the vectors", "", "Whole string fields; `today` is the 2-byte count plus UTF-8.", "",
             "| family | rows | today (bytes) | compact (bytes) | compact / today |", "|--------|-----:|--------------:|----------------:|----------------:|"]
    for name in sorted(fam):
        n, t, c = fam[name]
        lines.append("| %s | %d | %d | %d | %.1f %% |" % (name, n, t, c, 100.0 * c / t if t else 0))
    lines += ["", "CS-13 (never larger than today up to 126 UTF-8 bytes, +1 to 16,382, +2 above): %s" % ("PASS" if not over else "FAIL " + "; ".join(over))]
    text = "\n".join(lines) + "\n"
    if out:
        open(out, "w", encoding="utf8").write(text)
    print(text)
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
