#!/usr/bin/env python3
"""Check fixtures/text/vectors.txt against the reference codec and the coverage the contract asks for.

Usage: check_vectors.py [vectors] [tables]
Exit 0 when every row is re-derived; non-zero with the first problems printed otherwise.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import textfmt as tf  # noqa: E402

ROOT = os.path.join(HERE, "..", "..")
KINDS = ("short", "varint", "mode", "pad", "code", "cap", "esc", "utf8", "raw", "length")
MIN_ROWS = {"enc": 300, "ref": 4, "bad": 20, "flip": 20}
MAX_PACKET_STRINGS = 64


def unhex(s):
    return b"" if s == "-" else bytes.fromhex(s)


def symbols_of(field, tables):
    """The symbol names written in a compact field, for the coverage check."""
    _, off = tf.read_varint(field, 0)
    if off >= len(field):
        return set(), None
    first = field[off]
    start = (first >> 2) & 7
    if start == 4:
        return set(), 4
    parse_names = set()
    # decode again, recording symbols
    payload = field[off:]
    bits = "".join(format(b, "08b") for b in payload)
    total = 8 * len(payload) - (first >> 5)
    pos, mode = 6, start
    while pos < total:
        code = length = 0
        while True:
            code = (code << 1) | (bits[pos + length] == "1")
            length += 1
            idx = tables.decode[mode].get((length, code))
            if idx is not None:
                break
        pos += length
        sym = tf.SYMBOLS[mode][idx]
        if sym[0] == "SW":
            parse_names.add("SW:%s>%s" % (tf.MODE_NAMES[mode], tf.MODE_NAMES[sym[1]]))
            mode = sym[1]
        elif sym[0] in ("CAP", "LOCK"):
            parse_names.add(sym[0])
        elif sym[0] == "ESC":
            parse_names.add("ESC")
            _, pos = tf._utf8_char(bits, pos, total)
    return parse_names, start


def main():
    vec_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "fixtures", "text", "vectors.txt")
    tab_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "fixtures", "text", "tables.json")
    tables = tf.Tables.load(tab_path)
    errors = []
    counts = {}
    ids = set()
    enc_ids = set()
    seen = set()
    starts = set()
    with open(vec_path, encoding="utf8") as f:
        lines = f.read().split("\n")
    for n, line in enumerate(lines, 1):
        if not line or line.startswith("#"):
            continue
        cols = line.split(" ")
        kind = cols[0]
        if kind not in ("enc", "alt", "bad", "ref", "flip") or len(cols) < 3:
            errors.append("%d: unknown or short row %r" % (n, line[:40]))
            continue
        rid = cols[1]
        if rid in ids:
            errors.append("%d: duplicate id %s" % (n, rid))
        ids.add(rid)
        counts[kind] = counts.get(kind, 0) + 1
        try:
            if kind in ("enc", "alt"):
                if len(cols) != 4:
                    raise ValueError("needs 4 columns")
                text = unhex(cols[2]).decode("utf8")
                field = bytes.fromhex(cols[3])
                got, end = tf.decode(field, 0, tables)
                if got != text or end != len(field):
                    errors.append("%d: %s decodes to a different text or leaves bytes" % (n, rid))
                same = tf.encode(text, tables) == field
                if kind == "enc" and not same:
                    errors.append("%d: %s is not what the encoder writes" % (n, rid))
                if kind == "alt" and same:
                    errors.append("%d: %s is canonical, make it an enc row" % (n, rid))
                if kind == "enc":
                    enc_ids.add(rid)
                    names, start = symbols_of(field, tables)
                    seen |= names
                    if start is not None:
                        starts.add(start)
            elif kind == "bad":
                if len(cols) != 4:
                    raise ValueError("needs 4 columns")
                if cols[2] not in KINDS:
                    errors.append("%d: %s has the unknown kind %s" % (n, rid, cols[2]))
                    continue
                try:
                    tf.decode(bytes.fromhex(cols[3]), 0, tables)
                    errors.append("%d: %s is not refused" % (n, rid))
                except tf.Refusal as e:
                    if e.kind != cols[2]:
                        errors.append("%d: %s is refused as %s, row says %s" % (n, rid, e.kind, cols[2]))
            elif kind == "ref":
                if len(cols) != 3:
                    raise ValueError("needs 3 columns")
                bytes.fromhex(cols[2])
                if cols[2][:2] != "01":
                    errors.append("%d: %s does not start with the type byte 01" % (n, rid))
            elif kind == "flip":
                if len(cols) != 3:
                    raise ValueError("needs 3 columns")
        except (ValueError, tf.Refusal, UnicodeDecodeError) as e:
            errors.append("%d: %s: %s" % (n, rid, e))
    for line in lines:
        cols = line.split(" ")
        if cols[0] == "flip" and len(cols) == 3 and cols[2] not in enc_ids:
            errors.append("flip %s names a missing enc row %s" % (cols[1], cols[2]))
    # ring packets: every string in them is the encoder's output
    for line in lines:
        cols = line.split(" ")
        if cols[0] == "ref" and len(cols) == 3:
            check_ref(cols[1], bytes.fromhex(cols[2]), tables, errors)
    for k, need in MIN_ROWS.items():
        if counts.get(k, 0) < need:
            errors.append("only %d %s rows, need %d" % (counts.get(k, 0), k, need))
    needed = {"CAP", "LOCK", "ESC"} | {"SW:%s>%s" % (tf.MODE_NAMES[a], tf.MODE_NAMES[b]) for a in range(4) for b in range(4) if a != b}
    for name in sorted(needed - seen):
        errors.append("no enc row uses the symbol %s" % name)
    for m in range(5):
        if m not in starts:
            errors.append("no enc row starts in mode %d" % m)
    if errors:
        for e in errors[:30]:
            print("check-vectors: " + e, file=sys.stderr)
        print("check-vectors: %d problem(s)" % len(errors), file=sys.stderr)
        return 1
    print("check-vectors: ok (%s)" % ", ".join("%d %s" % (v, k) for k, v in sorted(counts.items())))
    return 0


def check_ref(rid, packet, tables, errors):
    """Walk a ring packet (user or nested shape) and require canonical strings; the whole packet must be used."""
    try:
        off = 1
        if rid in ("ref.user", "ref.user_ua"):
            _, off = tf.decode(packet, off, tables)
            n = int.from_bytes(packet[off:off + 2], "little")
            off += 2
            for _ in range(n):
                _, off = tf.decode(packet, off, tables)
            pairs = int.from_bytes(packet[off:off + 2], "little")
            off += 2
            for _ in range(pairs):
                _, off = tf.decode(packet, off, tables)
                m = int.from_bytes(packet[off:off + 2], "little")
                off += 2
                for _ in range(m):
                    _, off = tf.decode(packet, off, tables)
        elif rid in ("ref.nested", "ref.nested_mixed"):
            keys = int.from_bytes(packet[off:off + 2], "little")
            off += 2
            for _ in range(keys):
                _, off = tf.decode(packet, off, tables)
                rows = int.from_bytes(packet[off:off + 2], "little")
                off += 2
                for _ in range(rows):
                    pairs = int.from_bytes(packet[off:off + 2], "little")
                    off += 2
                    for _ in range(pairs):
                        _, off = tf.decode(packet, off, tables)
                        _, off = tf.decode(packet, off, tables)
        else:
            errors.append("ref %s: unknown packet shape" % rid)
            return
        if off != len(packet):
            errors.append("ref %s: %d bytes left over" % (rid, len(packet) - off))
    except (tf.Refusal, IndexError, ValueError) as e:
        errors.append("ref %s: %s" % (rid, e))


if __name__ == "__main__":
    sys.exit(main())
