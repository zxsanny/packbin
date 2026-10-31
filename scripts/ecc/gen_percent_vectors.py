"""Writes fixtures/ecc/percent-vectors.txt with the reference codec (loop 97). Usage: gen_percent_vectors.py [out]
The rows of a scheme that declares a parity percentage live in their own file, so the loaders of vectors.txt stay as they are."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import percent_vectors  # noqa: E402


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fixtures", "ecc", "percent-vectors.txt")
    rows = percent_vectors.rows()
    with open(out, "w") as f:
        f.write(percent_vectors.HEADER + "\n".join(rows) + "\n")
    print("wrote %d rows to %s" % (len(rows), out))


if __name__ == "__main__":
    main()
