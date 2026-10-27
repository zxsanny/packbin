"""The rows and the comparison of the cross-language frame ring (AZ-3338). Used by .github/workflows/ring-frame.sh.

  ring_frame.py seal-in <dir>                      writes <dir>/seal.in: the seal lines every writer gets
  ring_frame.py open-in <dir> <writer>...           reads <dir>/seal.<writer>.out and writes <dir>/open.in: the
                                                    open lines every reader gets, built on each writer's sealed bytes
  ring_frame.py mac-in <dir>                        writes <dir>/mac.in: the mac lines every writer gets
  ring_frame.py verify-in <dir> <writer>...         reads <dir>/mac.<writer>.out and writes <dir>/verify.in: the
                                                    verify lines every reader gets, built on each writer's tags
  ring_frame.py check <dir> <writer>... -- <reader>...   reads all outputs, compares with the reference codec
                                                    (scripts/frame/framefmt.py), prints one line per pair; exit 1 on mismatch

Rows: the seal and mac rows of fixtures/frame/ring-cases.txt. The environment variables RING_FRAME_CASES names another
file (the self-test of the ring). A row that the reference codec does not confirm is an error of the file, not of a
package: the script stops before any driver result is read.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import framefmt as ff  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")


class FileError(Exception):
    pass


def unhex(token):
    return b"" if token == "-" else bytes.fromhex(token)


def hx(b):
    return b.hex() if len(b) else "-"


def read_lines(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n") for line in f if line.strip()]


class Rows:
    """seal: (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, expected_body);
    mac: (case, key, epoch, label, n, message, expected_tag)."""

    def __init__(self, path):
        self.seal, self.mac, ids = [], [], set()
        with open(path, encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                line = line.rstrip("\n")
                if not line.strip() or line.startswith("#"):
                    continue
                w = line.split()
                if len(w) < 2:
                    raise FileError("%s:%d: malformed row" % (path, number))
                where = "%s:%d" % (path, number)
                if w[1] in ids:
                    raise FileError("%s: duplicate id %s" % (where, w[1]))
                ids.add(w[1])
                try:
                    self._add(w, where)
                except (IndexError, ValueError) as x:
                    raise FileError("%s: malformed row: %s" % (where, x))
        if not self.seal:
            raise FileError("%s: no seal rows" % path)
        if not self.mac:
            raise FileError("%s: no mac rows" % path)

    def _add(self, w, where):
        kind = w[0]
        if kind == "seal":
            case = w[1]
            key, epoch, d = unhex(w[2]), int(w[3]), int(w[4])
            tag_len, msg_id, fkind = int(w[5]), unhex(w[6]), int(w[7])
            ad, clear, plain = unhex(w[8]), unhex(w[9]), unhex(w[10])
            expected = unhex(w[11])
            ref = ff.seal(key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain)
            if ref != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected.hex(), ref.hex()))
            self.seal.append((case, key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain, expected.hex()))
        elif kind == "mac":
            case = w[1]
            key, epoch, label = unhex(w[2]), int(w[3]), unhex(w[4])
            n, message = int(w[5]), unhex(w[6])
            expected = unhex(w[7])
            ref = ff.mac_tag(key, epoch, label, n, [message])
            if ref != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected.hex(), ref.hex()))
            self.mac.append((case, key, epoch, label, n, message, expected.hex()))
        else:
            raise FileError("%s: unknown row kind %s" % (where, kind))


def load():
    path = os.environ.get("RING_FRAME_CASES") or os.path.join(ROOT, "fixtures", "frame", "ring-cases.txt")
    return Rows(path)


def cmd_seal_in(dirname):
    rows = load()
    with open(os.path.join(dirname, "seal.in"), "w") as f:
        for case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _ in rows.seal:
            f.write("seal %s %d %d %d %s %d %s %s %s\n" % (
                key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), hx(clear), hx(plain)))
    print("ring-frame: %d seal rows" % len(rows.seal))


def cmd_open_in(dirname, writers):
    rows = load()
    with open(os.path.join(dirname, "open.in"), "w") as f:
        for writer in writers:
            lines = read_lines(os.path.join(dirname, "seal.%s.out" % writer))
            if lines is None or len(lines) != len(rows.seal):
                for _ in rows.seal:
                    f.write("open-skip\n")
                continue
            for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _), body_hex in zip(rows.seal, lines):
                f.write("open %s %d %d %d %s %d %s %d %s\n" % (
                    key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), len(clear), body_hex))
    print("ring-frame: %d open rows for each of %d writers" % (len(rows.seal), len(writers)))


def cmd_mac_in(dirname):
    rows = load()
    with open(os.path.join(dirname, "mac.in"), "w") as f:
        for case, key, epoch, label, n, message, _ in rows.mac:
            f.write("mac %s %d %s %d %s\n" % (key.hex(), epoch, label.hex(), n, hx(message)))
    print("ring-frame: %d mac rows" % len(rows.mac))


def cmd_verify_in(dirname, writers):
    rows = load()
    with open(os.path.join(dirname, "verify.in"), "w") as f:
        for writer in writers:
            lines = read_lines(os.path.join(dirname, "mac.%s.out" % writer))
            if lines is None or len(lines) != len(rows.mac):
                for _ in rows.mac:
                    f.write("verify-skip\n")
                continue
            for (case, key, epoch, label, n, message, _), tag_hex in zip(rows.mac, lines):
                f.write("verify %s %d %s %d %s %s\n" % (key.hex(), epoch, label.hex(), n, hx(message), tag_hex))
    print("ring-frame: %d verify rows for each of %d writers" % (len(rows.mac), len(writers)))


def cmd_check(dirname, writers, readers):
    rows = load()
    total_wrong = 0
    pairs = 0
    notes = []

    bad_seal_writers = {}
    for writer in writers:
        lines = read_lines(os.path.join(dirname, "seal.%s.out" % writer))
        if lines is None or len(lines) != len(rows.seal):
            bad_seal_writers[writer] = ["%s printed %s seal lines, wanted %d" % (
                writer, "no" if lines is None else len(lines), len(rows.seal))]
            continue
        wrong = []
        for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, want), got in zip(rows.seal, lines):
            if got != want:
                wrong.append("%s: %s seal gave %s, wanted %s" % (writer, case, got[:40], want[:40]))
        if wrong:
            bad_seal_writers[writer] = wrong

    bad_mac_writers = {}
    for writer in writers:
        lines = read_lines(os.path.join(dirname, "mac.%s.out" % writer))
        if lines is None or len(lines) != len(rows.mac):
            bad_mac_writers[writer] = ["%s printed %s mac lines, wanted %d" % (
                writer, "no" if lines is None else len(lines), len(rows.mac))]
            continue
        wrong = []
        for (case, key, epoch, label, n, message, want), got in zip(rows.mac, lines):
            if got != want:
                wrong.append("%s: %s mac gave %s, wanted %s" % (writer, case, got[:40], want[:40]))
        if wrong:
            bad_mac_writers[writer] = wrong

    total_wrong += sum(len(v) for v in bad_seal_writers.values())
    total_wrong += sum(len(v) for v in bad_mac_writers.values())

    for reader in readers:
        open_lines = read_lines(os.path.join(dirname, "open.%s.out" % reader))
        want_open = len(rows.seal) * len(writers)
        if open_lines is None or len(open_lines) != want_open:
            notes.append("%s printed %s open lines, wanted %d" % (
                reader, "no" if open_lines is None else len(open_lines), want_open))
            open_lines = None

        verify_lines = read_lines(os.path.join(dirname, "verify.%s.out" % reader))
        want_verify = len(rows.mac) * len(writers)
        if verify_lines is None or len(verify_lines) != want_verify:
            notes.append("%s printed %s verify lines, wanted %d" % (
                reader, "no" if verify_lines is None else len(verify_lines), want_verify))
            verify_lines = None

        for index, writer in enumerate(writers):
            wrong = list(bad_seal_writers.get(writer, [])) + list(bad_mac_writers.get(writer, []))
            shown = len(wrong)
            seen = len(rows.seal) + len(rows.mac)

            if open_lines is None:
                wrong.append("%s -> %s: no usable open output" % (writer, reader))
            else:
                chunk = open_lines[index * len(rows.seal):(index + 1) * len(rows.seal)]
                for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _), got in zip(rows.seal, chunk):
                    want = hx(plain)
                    if got != want:
                        wrong.append("%s -> %s: %s open gave %s, wanted %s" % (writer, reader, case, got[:50], want[:50]))

            if verify_lines is None:
                wrong.append("%s -> %s: no usable verify output" % (writer, reader))
            else:
                chunk = verify_lines[index * len(rows.mac):(index + 1) * len(rows.mac)]
                for (case, key, epoch, label, n, message, _), got in zip(rows.mac, chunk):
                    if got != "valid":
                        wrong.append("%s -> %s: %s verify gave %s, wanted valid" % (writer, reader, case, got[:50]))

            pairs += 1
            total_wrong += len(wrong) - shown
            print("pair %s -> %s: %d rows, %d mismatched" % (writer, reader, seen, len(wrong)))
            for line in wrong[:5]:
                print("    " + line)

    for line in notes:
        print("ring-frame: " + line)
    print("ring-frame: %d pairs, mismatched: %d" % (pairs, total_wrong + len(notes)))
    return 0 if total_wrong == 0 and not notes else 1


def main(argv):
    try:
        if argv[:1] == ["seal-in"] and len(argv) == 2:
            cmd_seal_in(argv[1])
        elif argv[:1] == ["open-in"] and len(argv) >= 3:
            cmd_open_in(argv[1], argv[2:])
        elif argv[:1] == ["mac-in"] and len(argv) == 2:
            cmd_mac_in(argv[1])
        elif argv[:1] == ["verify-in"] and len(argv) >= 3:
            cmd_verify_in(argv[1], argv[2:])
        elif argv[:1] == ["check"] and "--" in argv:
            cut = argv.index("--")
            return cmd_check(argv[1], argv[2:cut], argv[cut + 1:])
        else:
            print(__doc__)
            return 2
    except FileError as x:
        print("ring-frame: the row files disagree with the reference codec: %s" % x)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
