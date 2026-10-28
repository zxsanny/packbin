"""The rows and the comparison of the cross-language frame ring (AZ-3338). Used by .github/workflows/ring-frame.sh.

  ring_frame.py seal-in <dir>                      writes <dir>/seal.in: the seal lines every writer gets
  ring_frame.py open-in <dir> <writer>...           reads <dir>/seal.<writer>.out and writes <dir>/open.in: the
                                                    open lines every reader gets, built on each writer's sealed bytes
  ring_frame.py mac-in <dir>                        writes <dir>/mac.in: the mac lines every writer gets
  ring_frame.py verify-in <dir> <writer>...         reads <dir>/mac.<writer>.out and writes <dir>/verify.in: the
                                                    verify lines every reader gets, built on each writer's tags
  ring_frame.py check <dir> <writer>... -- <reader>...   reads all outputs, compares with the reference codec
                                                    (scripts/frame/framefmt.py), prints one line per pair; exit 1 on mismatch

Rows: the seal, mac, open and verify rows of fixtures/frame/ring-cases.txt, and the refuse-seal, refuse-open and
refuse-mac rows (AZ-3354). The open and verify rows are tampered input: every reader gets them once, after the lines
built on the writers' output, and must refuse them as the row says (TagMismatch or ShortPacket for an open row,
`invalid` for a verify row). A refuse-seal or refuse-mac row is sent to every writer once, after its good rows, and a
refuse-open row to every reader with the open rows; each must give the error name of the row (`dirs` names the
directions the session loaded, `out_len` is the caller's output buffer). The environment variable RING_FRAME_CASES
names another file (the self-test of the ring). A row that the reference codec does not confirm is an error of the file, not of a
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


def is_hex(token):
    return token == "-" or (len(token) % 2 == 0 and all(c in "0123456789abcdef" for c in token))


def usable(lines, good, extra):
    """Whether a writer's output can feed the readers: `good + extra` lines, the first `good` of them hex. A writer that
    printed a word instead (an error name for a good row) is blamed by `check`; its readers get skip lines."""
    return lines is not None and len(lines) == good + extra and all(is_hex(line) for line in lines[:good])


def read_lines(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n") for line in f if line.strip()]


class Rows:
    """seal: (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, expected_body, out_len); a row with an out_len
    is sealed into exactly that buffer and opened into a buffer of exactly its plaintext (the boundary of BufferFull);
    mac: (case, key, epoch, label, n, message, expected_tag);
    refuse_open: (case, key, epoch, d, tag_len, msg_id, kind, ad, clear_len, body, expected_name, dirs, out_len);
    refuse_seal: (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, expected_name, dirs, out_len);
    refuse_mac: (case, key, epoch, label, n, message, expected_name);
    refuse_verify: (case, key, epoch, label, n, message, tag)."""

    def __init__(self, path):
        self.seal, self.mac, self.refuse_open, self.refuse_verify, ids = [], [], [], [], set()
        self.refuse_seal, self.refuse_mac = [], []
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
        if not any(row[11] == "123" and row[12] is None for row in self.refuse_open):
            raise FileError("%s: no open rows" % path)
        if not self.refuse_verify:
            raise FileError("%s: no verify rows" % path)

    @staticmethod
    def _dirs(token, where):
        if not token.isdigit() or any(c not in "123" for c in token):
            raise FileError("%s: dirs %s is not digits of 1 to 3" % (where, token))
        return tuple(int(c) for c in token)

    def _add(self, w, where):
        kind = w[0]
        if kind == "seal":
            case = w[1]
            key, epoch, d = unhex(w[2]), int(w[3]), int(w[4])
            tag_len, msg_id, fkind = int(w[5]), unhex(w[6]), int(w[7])
            ad, clear, plain = unhex(w[8]), unhex(w[9]), unhex(w[10])
            expected = unhex(w[11])
            out_len = int(w[12]) if len(w) > 12 else None
            ref = ff.seal(key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain, out_len=out_len)
            if ref != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected.hex(), ref.hex()))
            self.seal.append((case, key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain, expected.hex(), out_len))
        elif kind == "mac":
            case = w[1]
            key, epoch, label = unhex(w[2]), int(w[3]), unhex(w[4])
            n, message = int(w[5]), unhex(w[6])
            expected = unhex(w[7])
            ref = ff.mac_tag(key, epoch, label, n, [message])
            if ref != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected.hex(), ref.hex()))
            self.mac.append((case, key, epoch, label, n, message, expected.hex()))
        elif kind == "open":
            case = w[1]
            key, epoch, d, tag_len = unhex(w[2]), int(w[3]), int(w[4]), int(w[5])
            msg_id, fkind, ad, clear_len = unhex(w[6]), int(w[7]), unhex(w[8]), int(w[9])
            body, expected = unhex(w[10]), w[11]
            try:
                ff.open_frame(key, epoch, d, tag_len, msg_id, fkind, ad, clear_len, body)
                got = "opened"
            except ff.Fault as x:
                got = x.kind
            if got != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected, got))
            self.refuse_open.append((case, key, epoch, d, tag_len, msg_id, fkind, ad, clear_len, body, expected,
                                     "123", None))
        elif kind == "refuse-seal":
            case = w[1]
            key, epoch, d, tag_len = unhex(w[2]), int(w[3]), int(w[4]), int(w[5])
            msg_id, fkind, ad, clear, plain = unhex(w[6]), int(w[7]), unhex(w[8]), unhex(w[9]), unhex(w[10])
            dirs, out_len, expected = self._dirs(w[11], where), int(w[12]), w[13]
            try:
                ff.seal(key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain, dirs=dirs, out_len=out_len)
                got = "sealed"
            except ff.Fault as x:
                got = x.kind
            if got != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected, got))
            self.refuse_seal.append((case, key, epoch, d, tag_len, msg_id, fkind, ad, clear, plain, expected,
                                     w[11], out_len))
        elif kind == "refuse-open":
            case = w[1]
            key, epoch, d, tag_len = unhex(w[2]), int(w[3]), int(w[4]), int(w[5])
            msg_id, fkind, ad, clear_len, body = unhex(w[6]), int(w[7]), unhex(w[8]), int(w[9]), unhex(w[10])
            dirs, out_len, expected = self._dirs(w[11], where), int(w[12]), w[13]
            try:
                ff.open_frame(key, epoch, d, tag_len, msg_id, fkind, ad, clear_len, body, dirs=dirs, out_len=out_len)
                got = "opened"
            except ff.Fault as x:
                got = x.kind
            if got != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected, got))
            self.refuse_open.append((case, key, epoch, d, tag_len, msg_id, fkind, ad, clear_len, body, expected,
                                     w[11], out_len))
        elif kind == "refuse-mac":
            case = w[1]
            key, epoch, label, n, message, expected = unhex(w[2]), int(w[3]), unhex(w[4]), int(w[5]), unhex(w[6]), w[7]
            try:
                ff.mac_tag(key, epoch, label, n, [message])
                got = "tagged"
            except ff.Fault as x:
                got = x.kind
            if got != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected, got))
            self.refuse_mac.append((case, key, epoch, label, n, message, expected))
        elif kind == "verify":
            case = w[1]
            key, epoch, label, n = unhex(w[2]), int(w[3]), unhex(w[4]), int(w[5])
            message, tag, expected = unhex(w[6]), unhex(w[7]), w[8]
            if expected != "invalid":
                raise FileError("%s: %s a verify row says invalid, not %s" % (where, case, expected))
            try:
                got = "valid" if ff.mac_verify(key, epoch, label, [message], tag) else "invalid"
            except ff.Fault as x:
                raise FileError("%s: %s the reference refuses the row: %s" % (where, case, x.kind))
            if got != expected:
                raise FileError("%s: %s expected %s, reference gives %s" % (where, case, expected, got))
            self.refuse_verify.append((case, key, epoch, label, n, message, tag))
        else:
            raise FileError("%s: unknown row kind %s" % (where, kind))


def tail(dirs, out_len):
    """The optional trailing fields of a seal or open line: nothing for the defaults (123, 300)."""
    return "" if dirs == "123" and out_len is None else " %s %d" % (dirs, 300 if out_len is None else out_len)


def load():
    path = os.environ.get("RING_FRAME_CASES") or os.path.join(ROOT, "fixtures", "frame", "ring-cases.txt")
    return Rows(path)


def cmd_seal_in(dirname):
    rows = load()
    with open(os.path.join(dirname, "seal.in"), "w") as f:
        for case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _, out_len in rows.seal:
            f.write("seal %s %d %d %d %s %d %s %s %s%s\n" % (
                key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), hx(clear), hx(plain),
                "" if out_len is None else tail("123", out_len)))
        for case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _, dirs, out_len in rows.refuse_seal:
            f.write("seal %s %d %d %d %s %d %s %s %s%s\n" % (
                key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), hx(clear), hx(plain), tail(dirs, out_len)))
    print("ring-frame: %d seal rows and %d refusal rows" % (len(rows.seal), len(rows.refuse_seal)))


def cmd_open_in(dirname, writers):
    rows = load()
    with open(os.path.join(dirname, "open.in"), "w") as f:
        for writer in writers:
            lines = read_lines(os.path.join(dirname, "seal.%s.out" % writer))
            if not usable(lines, len(rows.seal), len(rows.refuse_seal)):
                for _ in rows.seal:
                    f.write("open-skip\n")
                continue
            for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _, out_len), body_hex in zip(rows.seal, lines):
                f.write("open %s %d %d %d %s %d %s %d %s%s\n" % (
                    key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), len(clear), body_hex,
                    "" if out_len is None else tail("123", len(plain))))
        for case, key, epoch, d, tag_len, msg_id, kind, ad, clear_len, body, _, dirs, out_len in rows.refuse_open:
            f.write("open %s %d %d %d %s %d %s %d %s%s\n" % (
                key.hex(), epoch, d, tag_len, msg_id.hex(), kind, hx(ad), clear_len, hx(body), tail(dirs, out_len)))
    print("ring-frame: %d open rows for each of %d writers, and %d refusal rows" % (
        len(rows.seal), len(writers), len(rows.refuse_open)))


def cmd_mac_in(dirname):
    rows = load()
    with open(os.path.join(dirname, "mac.in"), "w") as f:
        for case, key, epoch, label, n, message, _ in rows.mac:
            f.write("mac %s %d %s %d %s\n" % (key.hex(), epoch, label.hex(), n, hx(message)))
        for case, key, epoch, label, n, message, _ in rows.refuse_mac:
            f.write("mac %s %d %s %d %s\n" % (key.hex(), epoch, hx(label), n, hx(message)))
    print("ring-frame: %d mac rows and %d refusal rows" % (len(rows.mac), len(rows.refuse_mac)))


def cmd_verify_in(dirname, writers):
    rows = load()
    with open(os.path.join(dirname, "verify.in"), "w") as f:
        for writer in writers:
            lines = read_lines(os.path.join(dirname, "mac.%s.out" % writer))
            if not usable(lines, len(rows.mac), len(rows.refuse_mac)):
                for _ in rows.mac:
                    f.write("verify-skip\n")
                continue
            for (case, key, epoch, label, n, message, _), tag_hex in zip(rows.mac, lines):
                f.write("verify %s %d %s %d %s %s\n" % (key.hex(), epoch, label.hex(), n, hx(message), tag_hex))
        for case, key, epoch, label, n, message, tag in rows.refuse_verify:
            f.write("verify %s %d %s %d %s %s\n" % (key.hex(), epoch, label.hex(), n, hx(message), hx(tag)))
    print("ring-frame: %d verify rows for each of %d writers, and %d refusal rows" % (
        len(rows.mac), len(writers), len(rows.refuse_verify)))


def cmd_check(dirname, writers, readers):
    rows = load()
    total_wrong = 0
    pairs = 0
    notes = []

    # A writer's own refusal rows come after its good rows (seal.in, mac.in); they are counted in its `refusals` line.
    refused_by_writer = {writer: [] for writer in writers}
    skipped_open, skipped_verify = set(), set()
    bad_seal_writers = {}
    for writer in writers:
        lines = read_lines(os.path.join(dirname, "seal.%s.out" % writer))
        if not usable(lines, len(rows.seal), len(rows.refuse_seal)):
            skipped_open.add(writer)
        wanted = len(rows.seal) + len(rows.refuse_seal)
        if lines is None or len(lines) != wanted:
            bad_seal_writers[writer] = ["%s printed %s seal lines, wanted %d" % (
                writer, "no" if lines is None else len(lines), wanted)]
            continue
        wrong = []
        for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, want, _), got in zip(rows.seal, lines):
            if got != want:
                wrong.append("%s: %s seal gave %s, wanted %s" % (writer, case, got[:40], want[:40]))
        if wrong:
            bad_seal_writers[writer] = wrong
        for row, got in zip(rows.refuse_seal, lines[len(rows.seal):]):
            if got != row[10]:
                refused_by_writer[writer].append("%s: %s seal gave %s, wanted %s" % (writer, row[0], got[:50], row[10]))

    bad_mac_writers = {}
    for writer in writers:
        lines = read_lines(os.path.join(dirname, "mac.%s.out" % writer))
        if not usable(lines, len(rows.mac), len(rows.refuse_mac)):
            skipped_verify.add(writer)
        wanted = len(rows.mac) + len(rows.refuse_mac)
        if lines is None or len(lines) != wanted:
            bad_mac_writers[writer] = ["%s printed %s mac lines, wanted %d" % (
                writer, "no" if lines is None else len(lines), wanted)]
            continue
        wrong = []
        for (case, key, epoch, label, n, message, want), got in zip(rows.mac, lines):
            if got != want:
                wrong.append("%s: %s mac gave %s, wanted %s" % (writer, case, got[:40], want[:40]))
        if wrong:
            bad_mac_writers[writer] = wrong
        for row, got in zip(rows.refuse_mac, lines[len(rows.mac):]):
            if got != row[6]:
                refused_by_writer[writer].append("%s: %s mac gave %s, wanted %s" % (writer, row[0], got[:50], row[6]))

    total_wrong += sum(len(v) for v in bad_seal_writers.values())
    total_wrong += sum(len(v) for v in bad_mac_writers.values())

    for reader in readers:
        open_lines = read_lines(os.path.join(dirname, "open.%s.out" % reader))
        want_open = len(rows.seal) * len(writers) + len(rows.refuse_open)
        if open_lines is None or len(open_lines) != want_open:
            notes.append("%s printed %s open lines, wanted %d" % (
                reader, "no" if open_lines is None else len(open_lines), want_open))
            open_lines = None

        verify_lines = read_lines(os.path.join(dirname, "verify.%s.out" % reader))
        want_verify = len(rows.mac) * len(writers) + len(rows.refuse_verify)
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
            elif writer not in skipped_open:
                chunk = open_lines[index * len(rows.seal):(index + 1) * len(rows.seal)]
                for (case, key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, _, _), got in zip(rows.seal, chunk):
                    want = hx(plain)
                    if got != want:
                        wrong.append("%s -> %s: %s open gave %s, wanted %s" % (writer, reader, case, got[:50], want[:50]))

            if verify_lines is None:
                wrong.append("%s -> %s: no usable verify output" % (writer, reader))
            elif writer not in skipped_verify:
                chunk = verify_lines[index * len(rows.mac):(index + 1) * len(rows.mac)]
                for (case, key, epoch, label, n, message, _), got in zip(rows.mac, chunk):
                    if got != "valid":
                        wrong.append("%s -> %s: %s verify gave %s, wanted valid" % (writer, reader, case, got[:50]))

            pairs += 1
            total_wrong += len(wrong) - shown
            print("pair %s -> %s: %d rows, %d mismatched" % (writer, reader, seen, len(wrong)))
            for line in wrong[:5]:
                print("    " + line)

        # The tampered rows come once per reader, after the lines built on the writers' output.
        refused = []
        if open_lines is None:
            refused.append("%s: no usable open output for the refusal rows" % reader)
        else:
            tail = open_lines[len(rows.seal) * len(writers):]
            for row, got in zip(rows.refuse_open, tail):
                case, want = row[0], row[10]
                if got != want:
                    refused.append("%s: %s open gave %s, wanted %s" % (reader, case, got[:50], want))
        if verify_lines is None:
            refused.append("%s: no usable verify output for the refusal rows" % reader)
        else:
            tail = verify_lines[len(rows.mac) * len(writers):]
            for (case, _, _, _, _, _, _), got in zip(rows.refuse_verify, tail):
                if got != "invalid":
                    refused.append("%s: %s verify gave %s, wanted invalid" % (reader, case, got[:50]))
        refused += refused_by_writer.get(reader, [])
        total_wrong += len(refused)
        print("refusals %s: %d rows, %d mismatched" % (
            reader, len(rows.refuse_open) + len(rows.refuse_verify) + len(rows.refuse_seal) + len(rows.refuse_mac),
            len(refused)))
        for line in refused[:5]:
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
