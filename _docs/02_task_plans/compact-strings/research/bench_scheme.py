"""Huffman scheme model of the loop 35 benchmark: trees, symbol sets, the Viterbi tokenizer, bit packing, decoder."""
import heapq

from bench_common import LET, MB, MODES, SHARED_A, textfmt


def huff_lengths(counts):
    """counts: dict sym->weight (>0). returns dict sym->length (deterministic)."""
    if len(counts) == 1:
        return {k: 1 for k in counts}
    heap = [(w, i, [s]) for i, (s, w) in enumerate(sorted(counts.items()))]
    heapq.heapify(heap)
    depth = {s: 0 for s in counts}
    n = len(heap)
    while len(heap) > 1:
        w1, _, s1 = heapq.heappop(heap)
        w2, _, s2 = heapq.heappop(heap)
        for s in s1 + s2:
            depth[s] += 1
        n += 1
        heapq.heappush(heap, (w1 + w2, n, s1 + s2))
    return depth


def canon_codes(lengths):
    """canonical codes: sort by (len, sym). returns sym->(code int, len); the construction is textfmt's"""
    syms = sorted(lengths)
    codes = textfmt.canonical_codes([lengths[s] for s in syms])
    return {s: codes[i] for i, s in enumerate(syms)}


class Tree:
    def __init__(self, lengths):
        self.len = lengths
        self.codes = canon_codes(lengths)
        self.dec = {(c, l): s for s, (c, l) in self.codes.items()}
        self.maxlen = max(lengths.values())


class Scheme:
    """caps: none | shift | table.  overlay: letters share slots across modes."""

    def __init__(self, name, caps="none", shared=SHARED_A, overlay=False, uppercase_letters_table=False):
        self.name, self.caps, self.shared, self.overlay = name, caps, shared, overlay
        self.numset = None  # chars allowed in the number mode, when MODES has 'num'
        self.lock = caps == "shift"
        self.rank = {}
        self.trees = {}
        self.lens = {}

    def symbols(self, m):
        syms = []
        if m == "num":
            return ["S:" + c for c in sorted(self.numset)] + ["SW:" + x for x in MODES if x != "num"] + ["ESC"]
        if self.overlay:
            syms += ["L#%d" % r for r in range(34)]
        else:
            syms += ["L:" + c for c in LET[m]]
        syms += ["S:" + c for c in self.shared]
        syms += ["SW:" + x for x in MODES if x != m] if not self.overlay else ["SW:" + x for x in MODES]
        syms += ["ESC"]
        if self.caps == "shift":
            syms += ["CAP", "LOCK"]
        if self.caps == "table":
            if self.overlay:
                syms += ["U#%d" % r for r in range(34)]
            else:
                syms += ["U:" + c for c in LET[m]]
        return syms

    def treekey(self, m):
        return "all" if self.overlay and m != "num" else m

    def init_lengths(self):
        for m in MODES:
            k = self.treekey(m)
            if k in self.lens:
                continue
            d = {}
            for s in self.symbols(m):
                d[s] = 5 if s[0] in "LS" else (6 if s[0] == "U" else 8)
            self.lens[k] = d
        self.build()

    def build(self):
        self.trees = {k: Tree(v) for k, v in self.lens.items()}

    def cost(self, m, sym):
        return self.lens[self.treekey(m)][sym]

    # ---- letter symbol naming
    def lsym(self, m, ch):
        return ("L#%d" % self.rank[m][ch]) if self.overlay else "L:" + ch

    def usym(self, m, ch):
        return ("U#%d" % self.rank[m][ch]) if self.overlay else "U:" + ch


def classify_upper(ch, m):
    lo = ch.lower()
    return ch != lo and len(lo) == 1 and lo in LET[m]


def tokenize(text, sc):
    """Viterbi over (mode, lock). returns (bits, [(mode, sym)], init_mode)."""
    states = [(m, k) for m in MODES for k in ((0, 1) if sc.lock else (0,))]
    cur = {(m, 0): (0, None, ()) for m in MODES}  # node: (cost, parent_node, emitted tuple)
    shared = set(sc.shared)
    for ch in text:
        # closure of control moves
        for _ in range(2):
            upd = {}
            for (m, k), node in cur.items():
                for m2 in MODES:
                    if m2 != m:
                        c = node[0] + sc.cost(m, "SW:" + m2)
                        st = (m2, k)
                        best = upd.get(st, cur.get(st))
                        if best is None or c < best[0]:
                            upd[st] = (c, node, ((m, "SW:" + m2),))
                if sc.lock and m != "num":
                    st = (m, 1 - k)
                    c = node[0] + sc.cost(m, "LOCK")
                    best = upd.get(st, cur.get(st))
                    if best is None or c < best[0]:
                        upd[st] = (c, node, ((m, "LOCK"),))
            for st, nd in upd.items():
                if st not in cur or nd[0] < cur[st][0]:
                    cur[st] = nd
        nxt = {}
        raw = ch.encode("utf8")
        for (m, k), node in cur.items():
            opts = []
            if ch in LET[m]:
                if not sc.lock or k == 0:
                    s = sc.lsym(m, ch)
                    opts.append((sc.cost(m, s), ((m, s),)))
            elif classify_upper(ch, m):
                lo = ch.lower()
                if sc.caps == "shift":
                    s = sc.lsym(m, lo)
                    if k == 1:
                        opts.append((sc.cost(m, s), ((m, s),)))
                    else:
                        opts.append((sc.cost(m, "CAP") + sc.cost(m, s), ((m, "CAP"), (m, s))))
                elif sc.caps == "table":
                    s = sc.usym(m, lo)
                    opts.append((sc.cost(m, s), ((m, s),)))
            if (ch in sc.numset) if m == "num" else (ch in shared):
                s = "S:" + ch
                opts.append((sc.cost(m, s), ((m, s),)))
            # escape fallback
            esc = ((m, "ESC"),) + tuple((m, ("RAW", b)) for b in raw)
            opts.append((sc.cost(m, "ESC") + 8 * len(raw), esc))
            c, em = min(opts, key=lambda o: o[0])
            st = (m, k)
            nd = (node[0] + c, node, em)
            nxt[st] = nd
        cur = nxt
    best = min(cur.values(), key=lambda n: n[0])
    toks = []
    nd = best
    while nd is not None and nd[1] is not None:
        toks.append(nd[2])
        nd = nd[1]
    toks.reverse()
    flat = [t for grp in toks for t in grp]
    # initial mode: recover from walking back to root; root states are (m,0)
    # find root node reached: need its mode; we track it by replaying
    return best[0], flat


def tokenize_full(text, sc):
    # run tokenization once per initial mode would be slower; instead rely on cur seeding with all modes at cost 0
    bits, flat = tokenize(text, sc)
    # initial mode = mode of the first emitted symbol's tree
    m0 = flat[0][0] if flat else "ua"
    return bits, flat, m0


# ---- bit writing / decoding
def to_bits(flat, sc, m0):
    out = []
    for (m, s) in flat:
        if isinstance(s, tuple):
            out.append(format(s[1], "08b"))
        else:
            c, l = sc.trees[sc.treekey(m)].codes[s]
            out.append(format(c, "0%db" % l))
    return "".join(out)


def pack_bytes(bits, m0):
    pad = (-(3 + MB + len(bits))) % 8
    pre = format(pad, "03b") + format(MODES.index(m0), "0%db" % MB)
    allbits = pre + bits + "0" * pad
    return int(allbits, 2).to_bytes(len(allbits) // 8, "big") if allbits else b""


def decode(data, sc):
    """full decoder (inverse of tokenize+to_bits). returns str or raises ValueError."""
    bitstr = "".join(format(b, "08b") for b in data)
    pad = int(bitstr[:3], 2)
    m0 = int(bitstr[3:3 + MB], 2)
    if m0 >= len(MODES):
        raise ValueError("mode")
    payload = bitstr[3 + MB:len(bitstr) - pad] if pad else bitstr[3 + MB:]
    mode, lock, cap = MODES[m0], 0, 0
    out = []
    i, n = 0, len(payload)
    while i < n:
        tree = sc.trees[sc.treekey(mode)]
        code, l, sym = 0, 0, None
        while True:
            if i + l >= n:
                raise ValueError("short")
            code = (code << 1) | int(payload[i + l])
            l += 1
            if (code, l) in tree.dec:
                sym = tree.dec[(code, l)]
                break
            if l > tree.maxlen:
                raise ValueError("bad code")
        i += l
        if sym == "ESC":
            if i + 8 > n:
                raise ValueError("short raw")
            b0 = int(payload[i:i + 8], 2)
            ln = 1 if b0 < 0x80 else 2 if b0 >> 5 == 6 else 3 if b0 >> 4 == 14 else 4 if b0 >> 3 == 30 else 0
            if ln == 0 or i + 8 * ln > n:
                raise ValueError("raw")
            raw = bytes(int(payload[i + 8 * j:i + 8 * j + 8], 2) for j in range(ln))
            i += 8 * ln
            out.append(raw.decode("utf8"))
            continue
        if sym.startswith("SW:"):
            mode = sym[3:]
        elif sym == "LOCK":
            lock = 1 - lock
        elif sym == "CAP":
            cap = 1
        elif sym.startswith("L"):
            ch = sc.inv[mode][int(sym[2:])] if sym[1] == "#" else sym[2:]
            out.append(ch.upper() if (lock or cap) else ch)
            cap = 0
        elif sym.startswith("U"):
            ch = sc.inv[mode][int(sym[2:])] if sym[1] == "#" else sym[2:]
            out.append(ch.upper())
        elif sym.startswith("S:"):
            out.append(sym[2:])
    return "".join(out)
