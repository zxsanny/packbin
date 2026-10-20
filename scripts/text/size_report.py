#!/usr/bin/env python3
"""Size report of the vectors file (AZ-2657, AZ-2740): compact field bytes against today's 2-byte count plus UTF-8.

Usage: size_report.py [vectors] [out.md]
Checks CS-13 on every enc row (never larger than 2 + UTF-8 bytes up to 126 bytes, +1 up to 16,382, +2 above) and
writes the whole report: the run date, the sha256 of the recipe files, the CS-13 result, the held-out sentence table
copied from fixtures/text/tables.report.md (written by train_tables.py, which needs the Tatoeba corpus), and a table
per row family. Exit 1 when CS-13 fails. A rerun on the same tree gives the same file except the line "Run date".
"""
import ast
import datetime
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RECIPE_FILES = [
    ("scripts/text/size_report.py", ""),
    ("scripts/text/textfmt.py", " (reference encoder)"),
    ("scripts/text/train_tables.py", ""),
    ("fixtures/text/tables.json", " (same as the sha256 in `compact-text.md`)"),
    ("fixtures/text/vectors.txt", ""),
    ("fixtures/text/tables.report.md", ""),
]


def sha256(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def corpus_hashes():
    """CORPUS_SHA256 of train_tables.py, read from its source (the module is not imported)."""
    with open(os.path.join(HERE, "train_tables.py"), encoding="utf8") as f:
        for node in ast.parse(f.read()).body:
            if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "CORPUS_SHA256" for t in node.targets):
                return ast.literal_eval(node.value)
    raise SystemExit("train_tables.py has no CORPUS_SHA256")


def held_out_table():
    with open(os.path.join(ROOT, "fixtures", "text", "tables.report.md"), encoding="utf8") as f:
        return [line.rstrip("\n") for line in f if line.startswith("|")]


def measure(vec):
    fam = {}
    over = []
    rows = 0
    with open(vec, encoding="utf8") as f:
        for line in f:
            cols = line.rstrip("\n").split(" ")
            if cols[0] != "enc":
                continue
            rows += 1
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
    return fam, over, rows


def header(vec, rows, fam, over):
    corpus = corpus_hashes()
    today_total = sum(v[1] for v in fam.values())
    compact_total = sum(v[2] for v in fam.values())
    lines = [
        "# Compact text: size report", "",
        "Written by `scripts/text/size_report.py` (AZ-2657 AC-5, AZ-2733 AC-6, AZ-2740 AC-3). Run date: %s." % datetime.date.today().isoformat(), "",
        "Command: `python3 scripts/text/size_report.py %s %s`" % (os.path.relpath(vec, ROOT), "_docs/02_task_plans/compact-strings/size_report.md"), "",
        "## Recipe files (sha256)", "", "| file | sha256 |", "|------|--------|",
    ]
    lines += ["| `%s`%s | `%s` |" % (rel, note, sha256(rel)) for rel, note in RECIPE_FILES]
    lines += [
        "", "The Tatoeba corpus files of the training recipe are not in the repository. Their sha256 are recorded in `scripts/text/train_tables.py` (`CORPUS_SHA256`): "
        + ", ".join("%s `%s`" % (k, corpus[k]) for k in sorted(corpus)) + ". They are not hashed by this script.", "",
        "## CS-13 on every `enc` row", "",
        "%s: the script checked all %d `enc` rows of `vectors.txt` (field never larger than today's 2-byte count plus UTF-8 up to 126 UTF-8 bytes, at most 1 byte larger up to 16,382, at most 2 above). The same %d rows total %d bytes today and %d bytes compact (summed from the table below; the `random.*` and `size.*` rows hold texts that do not compress, so the total is not a measure of CS-1, CS-2 or CS-14)."
        % ("PASS" if not over else "FAIL", rows, rows, today_total, compact_total), "",
        "## Held-out sentence sets (CS-1, CS-2, CS-14): copied, not re-run", "",
        "These sizes need the Tatoeba corpus. The table is copied from `fixtures/text/tables.report.md` (sha256 above, written by `scripts/text/train_tables.py --corpus DIR`); `train_tables.py --corpus DIR --check` and the `OVER` grep are run by the agent with the corpus (`_docs/loops/loop35/smoke35.md` steps 5 and 6), not by CI.", "",
    ]
    return lines + held_out_table() + ["", "## Size of the vectors", ""]


def main():
    vec = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "fixtures", "text", "vectors.txt")
    out = sys.argv[2] if len(sys.argv) > 2 else None
    fam, over, rows = measure(vec)
    lines = header(vec, rows, fam, over)
    lines += ["Whole string fields; `today` is the 2-byte count plus UTF-8.", "",
              "| family | rows | today (bytes) | compact (bytes) | compact / today |", "|--------|-----:|--------------:|----------------:|----------------:|"]
    for name in sorted(fam):
        n, t, c = fam[name]
        lines.append("| %s | %d | %d | %d | %.1f %% |" % (name, n, t, c, 100.0 * c / t if t else 0))
    lines += ["", "CS-13 (never larger than today up to 126 UTF-8 bytes, +1 to 16,382, +2 above): %s" % ("PASS" if not over else "FAIL " + "; ".join(over))]
    text = "\n".join(lines) + "\n"
    if out:
        with open(out, "w", encoding="utf8") as f:
            f.write(text)
    print(text)
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
