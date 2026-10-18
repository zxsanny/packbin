"""The rows and the comparison of the message ECC ring (AZ-2689, EC-9). Used by .github/workflows/ring-ecc.sh.

  ring_ecc.py protect-in <dir>                     writes <dir>/protect.in: the `protect` lines every writer gets
  ring_ecc.py repair-in <dir> <writer>...          reads <dir>/protect.<writer>.out and writes <dir>/repair.in: the
                                                   `repair` lines every reader gets, built on each writer's bytes
  ring_ecc.py check <dir> <writer>... -- <reader>...   reads <dir>/repair.<reader>.out, compares every result with the
                                                   reference codec (scripts/ecc/eccfmt.py), prints one line per
                                                   writer -> reader pair and the total; exit 1 on any mismatch

Rows: the position rows of fixtures/ecc/vectors.txt (enc.pos.*, fix/bad.pos.*, the results report rows 7 to 12, trunc,
extend, unprotected, toolong, par, lmt) and fixtures/ecc/ring-cases.txt. The environment variables RING_ECC_VECTORS and
RING_ECC_CASES name other files (the self-test of the ring). A row that the reference codec does not confirm is an
error of the file, not of a package: the script stops before any driver result is read.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eccfmt as e  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
POS = bytes.fromhex("4001000065cd1d00a3e1110100")
VECTOR_IDS = re.compile(r"^(enc\.pos\.|fix\.pos\.|bad\.pos\.|fix\.report\.|bad\.report\.|bad\.trunc\.|bad\.extend\.|bad\.unprotected|bad\.toolong|par\.|lmt\.)")
KINDS = {e.UNCORRECTABLE, e.SHORT, e.TOO_LONG, "trailing"}


class FileError(Exception):
    pass


def unhex(token):
    return b"" if token == "-" else bytes.fromhex(token)


def hx(b):
    return b.hex() if len(b) else "-"


def read_rows(path, pick):
    rows = []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            words = line.split(" ")
            if len(words) < 2:
                raise FileError("%s:%d: malformed row" % (path, number))
            if pick(words[1]):
                rows.append((words, "%s:%d" % (path, number)))
    return rows


class Rows:
    """protect: (id, n, clear, expected hex or kind); repair: (id, n, t, received, clear or None, expected text)."""

    def __init__(self, vectors, cases):
        self.protect, self.repair, ids = [], [], set()
        for words, where in read_rows(vectors, VECTOR_IDS.match) + read_rows(cases, lambda _id: True):
            try:
                self._add(words, where, ids)
            except (IndexError, ValueError) as x:
                raise FileError("%s: malformed row %s: %s" % (where, " ".join(words)[:60], x))
        if not self.protect or not self.repair:
            raise FileError("no rows: %d protect, %d repair" % (len(self.protect), len(self.repair)))

    def _add(self, w, where, ids):
        kind, rid = w[0], w[1]
        if rid in ids:
            raise FileError("%s: duplicate id %s" % (where, rid))
        ids.add(rid)
        if kind == "enc":
            n, clear, prot = int(w[2]), unhex(w[3]), unhex(w[4])
            if clear != POS or e.protect(clear, n) != prot:
                raise FileError("%s: %s is not the reference protection of the position message" % (where, rid))
            self.protect.append((rid, n, clear, prot.hex()))
        elif kind == "par":
            n = int(w[2])
            if not (n > e.MAX_PARITY):
                raise FileError("%s: %s declares n = %d, which is allowed" % (where, rid, n))
            self.protect.append((rid, n, POS, e.BAD_PARITY))
        elif kind == "lmt":
            n, t = int(w[2]), int(w[3])
            if not (t > n // 2):
                raise FileError("%s: %s limit %d is allowed for n = %d" % (where, rid, t, n))
            self.repair.append((rid, n, t, e.protect(POS, n), POS, e.BAD_LIMIT))
        elif kind == "fix":
            n, t, recv, clear, count = int(w[2]), int(w[3]), unhex(w[4]), unhex(w[5]), int(w[6])
            try:
                got = e.decode(recv, n, t)
            except e.EccError as x:
                raise FileError("%s: %s is refused as %s by the reference" % (where, rid, x.kind))
            if got != (clear, count):
                raise FileError("%s: %s gives %s, %d in the reference, the row says %s, %d" % (where, rid, got[0].hex(), got[1], clear.hex(), count))
            self.repair.append((rid, n, t, recv, clear, "%s %d" % (clear.hex(), count)))
        elif kind == "bad":
            n, t, recv, want = int(w[2]), int(w[3]), unhex(w[4]), w[5]
            if want not in KINDS:
                raise FileError("%s: %s names the kind %s" % (where, rid, want))
            if want == "trailing":
                if n != 0 or len(recv) <= len(POS):
                    raise FileError("%s: %s is a trailing row with n = %d and %d bytes" % (where, rid, n, len(recv)))
            else:
                try:
                    got = e.decode(recv, n, t)
                    raise FileError("%s: %s is accepted by the reference as %s" % (where, rid, got[0].hex()))
                except e.EccError as x:
                    if x.kind != want:
                        raise FileError("%s: %s is refused as %s by the reference, the row says %s" % (where, rid, x.kind, want))
            self.repair.append((rid, n, t, recv, None, want))
        else:
            raise FileError("%s: unknown row kind %s" % (where, kind))


def load():
    vectors = os.environ.get("RING_ECC_VECTORS") or os.path.join(ROOT, "fixtures", "ecc", "vectors.txt")
    cases = os.environ.get("RING_ECC_CASES") or os.path.join(ROOT, "fixtures", "ecc", "ring-cases.txt")
    return Rows(vectors, cases)


def rebase(recv, n, written):
    """The row's buffer built on the bytes a writer made for the position message instead of the reference's."""
    ref = e.protect(POS, n)
    if written is None or written == ref:
        return recv
    if len(recv) == len(ref):
        return bytes(a ^ b ^ c for a, b, c in zip(recv, ref, written))
    if ref.startswith(recv):
        return written[:len(recv)]
    if recv.startswith(ref):
        return written + recv[len(ref):]
    return recv


def written_by(dirname, writer, rows):
    """n -> the bytes the writer made for the position message; None for a writer whose output is unusable."""
    lines = read_lines(os.path.join(dirname, "protect.%s.out" % writer))
    if lines is None or len(lines) != len(rows.protect):
        return None
    made = {}
    for (rid, n, clear, want), got in zip(rows.protect, lines):
        if want != e.BAD_PARITY and re.fullmatch(r"[0-9a-f]*", got):
            made[n] = bytes.fromhex(got)
    return made


def read_lines(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n") for line in f if line.strip()]


def cmd_protect_in(dirname):
    rows = load()
    with open(os.path.join(dirname, "protect.in"), "w") as f:
        for rid, n, clear, want in rows.protect:
            f.write("protect %d %s\n" % (n, hx(clear)))
    print("ring-ecc: %d protect rows" % len(rows.protect))


def cmd_repair_in(dirname, writers):
    rows = load()
    with open(os.path.join(dirname, "repair.in"), "w") as f:
        for writer in writers:
            made = written_by(dirname, writer, rows) or {}
            for rid, n, t, recv, clear, want in rows.repair:
                base = made.get(n) if clear == POS or clear is None else None
                f.write("repair %d %d %s\n" % (n, t, hx(rebase(recv, n, base) if base is not None else recv)))
    print("ring-ecc: %d repair rows for each of %d writers" % (len(rows.repair), len(writers)))


def cmd_check(dirname, writers, readers):
    rows = load()
    bad_writers, per_writer = {}, {}
    for writer in writers:
        lines = read_lines(os.path.join(dirname, "protect.%s.out" % writer))
        if lines is None or len(lines) != len(rows.protect):
            bad_writers[writer] = ["%s printed %s protect lines, wanted %d" % (writer, "no" if lines is None else len(lines), len(rows.protect))]
            continue
        wrong = ["%s: %s gave %s, wanted %s" % (writer, rid, got[:40], want[:40]) for (rid, n, clear, want), got in zip(rows.protect, lines) if got != want]
        if wrong:
            bad_writers[writer] = wrong
        per_writer[writer] = len(rows.protect)
    total_rows = pairs = 0
    total_wrong = sum(len(v) for v in bad_writers.values())  # a writer's wrong rows count once, not once per reader
    notes = []
    for reader in readers:
        lines = read_lines(os.path.join(dirname, "repair.%s.out" % reader))
        want_lines = len(rows.repair) * len(writers)
        if lines is None or len(lines) != want_lines:
            notes.append("%s printed %s repair lines, wanted %d" % (reader, "no" if lines is None else len(lines), want_lines))
            lines = None
        for index, writer in enumerate(writers):
            wrong = list(bad_writers.get(writer, []))
            shown = len(wrong)
            seen = per_writer.get(writer, 0) + len(rows.repair)
            if lines is None:
                wrong.append("%s -> %s: no usable output" % (writer, reader))
            else:
                chunk = lines[index * len(rows.repair):(index + 1) * len(rows.repair)]
                for (rid, n, t, recv, clear, want), got in zip(rows.repair, chunk):
                    if got != want:
                        wrong.append("%s -> %s: %s (n=%d t=%d) gave %s, wanted %s" % (writer, reader, rid, n, t, got[:50], want[:50]))
            pairs += 1
            total_rows += seen
            total_wrong += len(wrong) - shown
            print("pair %s -> %s: %d rows, %d mismatched" % (writer, reader, seen, len(wrong)))
            for line in wrong[:5]:
                print("    " + line)
    for line in notes:
        print("ring-ecc: " + line)
    print("ring-ecc: %d pairs, %d rows, mismatched rows: %d" % (pairs, total_rows, total_wrong + len(notes)))
    return 0 if total_wrong == 0 and not notes else 1


def main(argv):
    try:
        if argv[:1] == ["protect-in"] and len(argv) == 2:
            cmd_protect_in(argv[1])
        elif argv[:1] == ["repair-in"] and len(argv) >= 3:
            cmd_repair_in(argv[1], argv[2:])
        elif argv[:1] == ["check"] and "--" in argv:
            cut = argv.index("--")
            return cmd_check(argv[1], argv[2:cut], argv[cut + 1:])
        else:
            print(__doc__)
            return 2
    except FileError as x:
        print("ring-ecc: the row files disagree with the reference codec: %s" % x)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
