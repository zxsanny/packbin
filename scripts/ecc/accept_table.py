"""Prints the table of the chance that a random buffer of the fixture's length (13 clear bytes + n) is accepted (EC-15).
Usage: accept_table.py            print the markdown table
       accept_table.py --check F  exit 1 unless F contains the printed table verbatim"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eccfmt as e  # noqa: E402


def table():
    lines = ["| n | t | chance a random 13 + n byte buffer is accepted | about 1 in |", "|---|---|---|---|"]
    for n in (1, 2, 4, 8, 16):
        for t in range(0, n // 2 + 1):
            fr = e.accept_fraction(13, n, t)
            inv = 1 / float(fr)
            lines.append("| %d | %d | %.3e | %s |" % (n, t, float(fr), format(round(inv), ",") if inv < 1e9 else "%.2e" % inv))
    return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        sys.exit(0 if table() in open(sys.argv[2]).read() else 1)
    print(table())
