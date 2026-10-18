#!/usr/bin/env python3
"""packbin compact text format, version 1: reference encoder and decoder.

Written from the contract `_docs/02_document/contracts/library/compact-text.md`.
Python 3.9 or newer, standard library only. Tables come from `fixtures/text/tables.json`.

A string on the wire is `count payload`:
  count    varint (LEB128, 7 bits per byte, little endian), 1 to 3 bytes, minimal form.
  payload  `count` bytes. Count 0 is the empty string and has no payload.
           Bit 0..2 pad bits (unused bits at the end), bit 3..5 start mode, then the symbols.
           Start mode 0 Ukrainian, 1 Russian, 2 English, 3 number, 4 raw UTF-8 (the whole payload
           is the byte 0x10 followed by the UTF-8 bytes), 5..7 undefined.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TABLES = os.path.join(HERE, "..", "..", "fixtures", "text", "tables.json")

MODE_NAMES = ["ua", "ru", "en", "num"]
UA = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"
RU = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
EN = "abcdefghijklmnopqrstuvwxyz'"
ALPHA = [UA, RU, EN]
SHARED = " 0123456789,.-:!?;()\"%/@+=*#&_$\n"
NUMSET = "0123456789.,-: "
MAX_TEXT_BYTES = 65535
MAX_CODE_LEN = 16
RAW_PREFIX = 0x10
INF = 10 ** 9


class Refusal(Exception):
    """A decoder refusal. `kind` is one of the names listed in the contract."""

    def __init__(self, kind, detail=""):
        super().__init__(kind + (": " + detail if detail else ""))
        self.kind = kind


def upper_of(ch):
    """The capital of a letter, or None when it has none (the apostrophe)."""
    up = ch.upper()
    return up if len(up) == 1 and up != ch else None


UPPER = [[upper_of(c) for c in a] for a in ALPHA]


def symbol_list(mode):
    """Symbols of a mode in table order; the index in this list is the symbol index."""
    if mode == 3:
        return [("S", i) for i in range(len(NUMSET))] + [("SW", t) for t in (0, 1, 2)] + [("ESC",)]
    return ([("L", i) for i in range(len(ALPHA[mode]))] + [("S", i) for i in range(len(SHARED))]
            + [("SW", t) for t in range(4) if t != mode] + [("CAP",), ("LOCK",), ("ESC",)])


def symbol_name(mode, sym):
    if sym[0] == "L":
        return "L:" + ALPHA[mode][sym[1]]
    if sym[0] == "S":
        return "S:" + (NUMSET if mode == 3 else SHARED)[sym[1]]
    if sym[0] == "SW":
        return "SW:" + MODE_NAMES[sym[1]]
    return sym[0]


SYMBOLS = [symbol_list(m) for m in range(4)]
SYMBOL_INDEX = [{s: i for i, s in enumerate(SYMBOLS[m])} for m in range(4)]


def canonical_codes(lengths):
    """Canonical Huffman: symbols sorted by (length, index); the first code is 0."""
    order = sorted(range(len(lengths)), key=lambda i: (lengths[i], i))
    codes = [None] * len(lengths)
    code = 0
    prev = 0
    for i in order:
        code <<= lengths[i] - prev
        codes[i] = (code, lengths[i])
        code += 1
        prev = lengths[i]
    return codes


class Tables:
    def __init__(self, lengths):
        self.lengths = lengths
        for m in range(4):
            if len(lengths[m]) != len(SYMBOLS[m]):
                raise ValueError("table %d has %d lengths, needs %d" % (m, len(lengths[m]), len(SYMBOLS[m])))
            kraft = sum(2.0 ** -l for l in lengths[m])
            if kraft != 1.0 or max(lengths[m]) > MAX_CODE_LEN:
                raise ValueError("table %d is not a complete code of length <= %d" % (m, MAX_CODE_LEN))
        self.codes = [canonical_codes(lengths[m]) for m in range(4)]
        self.decode = [{(l, c): i for i, (c, l) in enumerate(self.codes[m])} for m in range(4)]
        self._edges = {}

    @staticmethod
    def load(path=DEFAULT_TABLES):
        with open(path, encoding="utf8") as f:
            data = json.load(f)
        return Tables([data["modes"][n]["lengths"] for n in MODE_NAMES])

    # ---- encoder edges of one character in one mode, cached
    def emission_edges(self, mode, ch, lock):
        """Edges that consume `ch`: list of (first symbol index, [symbol indexes], raw bytes, bits)."""
        key = (mode, ch, lock)
        got = self._edges.get(key)
        if got is not None:
            return got
        idx = SYMBOL_INDEX[mode]
        ln = self.lengths[mode]
        edges = []
        if mode != 3:
            letters = ALPHA[mode]
            if ch in letters:
                i = letters.index(ch)
                if UPPER[mode][i] is None or lock == 0:
                    s = idx[("L", i)]
                    edges.append((s, [s], b"", ln[s]))
            for i, up in enumerate(UPPER[mode]):
                if up == ch:
                    s = idx[("L", i)]
                    if lock:
                        edges.append((s, [s], b"", ln[s]))
                    else:
                        c = idx[("CAP",)]
                        edges.append((c, [c, s], b"", ln[c] + ln[s]))
            if ch in SHARED:
                s = idx[("S", SHARED.index(ch))]
                edges.append((s, [s], b"", ln[s]))
        elif ch in NUMSET:
            s = idx[("S", NUMSET.index(ch))]
            edges.append((s, [s], b"", ln[s]))
        raw = ch.encode("utf8")
        e = idx[("ESC",)]
        edges.append((e, [e], raw, ln[e] + 8 * len(raw)))
        edges.sort(key=lambda t: t[0])
        self._edges[key] = edges
        return edges

    def control_edges(self, mode, lock):
        """Edges that consume no character: list of (symbol index, bits, next mode, next lock)."""
        idx = SYMBOL_INDEX[mode]
        ln = self.lengths[mode]
        out = []
        for t in range(4):
            if t != mode:
                s = idx[("SW", t)]
                out.append((s, ln[s], t, lock))
        if mode != 3:
            s = idx[("LOCK",)]
            out.append((s, ln[s], mode, 1 - lock))
        out.sort(key=lambda t: t[0])
        return out


def varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def read_varint(buf, off):
    n = 0
    for k in range(3):
        if off + k >= len(buf):
            raise Refusal("short", "count")
        b = buf[off + k]
        n |= (b & 0x7F) << (7 * k)
        if not b & 0x80:
            if k > 0 and b == 0:
                raise Refusal("varint", "not minimal")
            return n, off + k + 1
    raise Refusal("varint", "longer than 3 bytes")


def parse(text, tables):
    """Optimal parse: minimal bits, ties to the smallest first-symbol index at every step.
    Returns (bits, symbols, start mode); symbols are (mode, symbol index) or (mode, raw byte)."""
    cps = list(text)
    n = len(cps)
    states = [(m, k) for m in range(4) for k in (0, 1)]
    controls = {s: tables.control_edges(s[0], s[1]) for s in states}
    f = [None] * (n + 1)
    f[n] = {s: 0 for s in states}
    for i in range(n - 1, -1, -1):
        nxt = f[i + 1]
        cur = {}
        for s in states:
            best = INF
            for (_, _, _, bits) in tables.emission_edges(s[0], cps[i], s[1]):
                if bits + nxt[s] < best:
                    best = bits + nxt[s]
            cur[s] = best
        changed = True
        while changed:
            changed = False
            for s in states:
                for (_, bits, tm, tk) in controls[s]:
                    v = bits + cur[(tm, tk)]
                    if v < cur[s]:
                        cur[s] = v
                        changed = True
        f[i] = cur
    start = min(range(4), key=lambda m: (f[0][(m, 0)], m))
    state = (start, 0)
    i = 0
    symbols = []
    total = f[0][state]
    while i < n:
        mode, lock = state
        want = f[i][state]
        cands = []
        for (sym, bits, tm, tk) in controls[state]:
            cands.append((sym, bits + f[i][(tm, tk)], "c", (tm, tk), None, None))
        for (first, syms, raw, bits) in tables.emission_edges(mode, cps[i], lock):
            cands.append((first, bits + f[i + 1][state], "e", state, syms, raw))
        cands.sort(key=lambda c: c[0])
        for (first, value, kind, target, syms, raw) in cands:
            if value != want:
                continue
            if kind == "c":
                symbols.append((mode, first))
                state = target
            else:
                for s in syms:
                    symbols.append((mode, s))
                for b in raw:
                    symbols.append((mode, ("RAW", b)))
                i += 1
            break
        else:
            raise AssertionError("no optimal edge")
    return total, symbols, start


def _bits_of(symbols, tables):
    parts = []
    for mode, s in symbols:
        if isinstance(s, tuple):
            parts.append(format(s[1], "08b"))
        else:
            code, l = tables.codes[mode][s]
            parts.append(format(code, "0%db" % l))
    return "".join(parts)


def encode(text, tables):
    """The wire bytes of one string: count then payload."""
    raw = text.encode("utf8")
    if len(raw) > MAX_TEXT_BYTES:
        raise ValueError("text longer than %d UTF-8 bytes" % MAX_TEXT_BYTES)
    if not raw:
        return b"\x00"
    raw_payload = bytes([RAW_PREFIX]) + raw
    total, symbols, start = parse(text, tables)
    nbits = 6 + total
    size = (nbits + 7) // 8
    if size < len(raw_payload):
        pad = 8 * size - nbits
        stream = format(pad, "03b") + format(start, "03b") + _bits_of(symbols, tables) + "0" * pad
        payload = int(stream, 2).to_bytes(size, "big")
    else:
        payload = raw_payload
    return varint(len(payload)) + payload


def _utf8_char(bits, pos, total):
    """Read one UTF-8 scalar at bit `pos`; returns (char, next pos)."""
    def byte(p):
        if p + 8 > total:
            raise Refusal("esc", "cut short")
        return int(bits[p:p + 8], 2)
    b0 = byte(pos)
    n = 1 if b0 < 0x80 else 2 if b0 >> 5 == 6 else 3 if b0 >> 4 == 14 else 4 if b0 >> 3 == 30 else 0
    if n == 0:
        raise Refusal("utf8", "bad lead byte")
    data = bytes(byte(pos + 8 * j) for j in range(n))
    try:
        ch = data.decode("utf8")
    except UnicodeDecodeError:
        raise Refusal("utf8", "invalid UTF-8")
    return ch, pos + 8 * n


def decode(buf, off, tables):
    """Decode one string at `off`. Returns (text, next offset) or raises Refusal."""
    count, off = read_varint(buf, off)
    if count == 0:
        return "", off
    if off + count > len(buf):
        raise Refusal("short", "payload")
    payload = bytes(buf[off:off + count])
    end = off + count
    first = payload[0]
    mode = (first >> 2) & 7
    if mode == 4:
        if first != RAW_PREFIX:
            raise Refusal("raw", "prefix byte")
        body = payload[1:]
        try:
            text = body.decode("utf8")
        except UnicodeDecodeError:
            raise Refusal("utf8", "invalid UTF-8")
        if len(body) > MAX_TEXT_BYTES:
            raise Refusal("length", "text too long")
        return text, end
    if mode > 4:
        raise Refusal("mode", "start mode %d" % mode)
    pad = first >> 5
    bits = "".join(format(b, "08b") for b in payload)
    total = 8 * count - pad
    if total < 6:
        raise Refusal("pad", "pad bits cover the prefix")
    if "1" in bits[total:]:
        raise Refusal("pad", "pad bits not zero")
    pos = 6
    lock = 0
    cap = 0
    out = []
    size = 0
    while pos < total:
        code = 0
        length = 0
        dec = tables.decode[mode]
        while True:
            if pos + length >= total:
                raise Refusal("code", "stream ends inside a code")
            code = (code << 1) | (bits[pos + length] == "1")
            length += 1
            idx = dec.get((length, code))
            if idx is not None:
                break
            if length > MAX_CODE_LEN:
                raise Refusal("code", "no such code")
        pos += length
        sym = SYMBOLS[mode][idx]
        kind = sym[0]
        if kind == "SW":
            if cap:
                raise Refusal("cap", "CAP not followed by a letter")
            mode = sym[1]
            continue
        if kind == "CAP":
            if lock or cap:
                raise Refusal("cap", "CAP with capital lock or twice")
            cap = 1
            continue
        if kind == "LOCK":
            if cap:
                raise Refusal("cap", "CAP not followed by a letter")
            lock ^= 1
            continue
        if kind == "ESC":
            if cap:
                raise Refusal("cap", "CAP not followed by a letter")
            ch, pos = _utf8_char(bits, pos, total)
        elif kind == "L":
            ch = ALPHA[mode][sym[1]]
            up = UPPER[mode][sym[1]]
            if cap:
                if up is None:
                    raise Refusal("cap", "CAP before a letter without a capital")
                ch = up
                cap = 0
            elif lock and up is not None:
                ch = up
        else:
            ch = (NUMSET if mode == 3 else SHARED)[sym[1]]
            if cap:
                raise Refusal("cap", "CAP not followed by a letter")
        size += len(ch.encode("utf8"))
        if size > MAX_TEXT_BYTES:
            raise Refusal("length", "text too long")
        out.append(ch)
    if cap:
        raise Refusal("cap", "CAP at the end")
    return "".join(out), end


def hexstr(b):
    return b.hex()


def _main(argv):
    """textfmt.py enc TEXT | enc-hex HEX | dec FIELD_HEX : print the field hex or the text (for tests and workers)."""
    if len(argv) != 3 or argv[1] not in ("enc", "enc-hex", "dec"):
        print(_main.__doc__)
        return 2
    tables = Tables.load()
    if argv[1] == "enc":
        print(encode(argv[2], tables).hex())
    elif argv[1] == "enc-hex":
        print(encode(bytes.fromhex(argv[2]).decode("utf8"), tables).hex())
    else:
        text, end = decode(bytes.fromhex(argv[2]), 0, tables)
        print(text)
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(_main(sys.argv))
