"""Training and size measurement of the loop 35 benchmark: Huffman training passes, fixed 6-bit, order-1 bigram bound."""
import collections

from bench_common import G, LET, MB, MODES, SHARED_A, header, log, pmap
from bench_scheme import huff_lengths, tokenize_full


def _tok(text):
    return tokenize_full(text, G["sc"])


def _tok_A(text):
    return tokenize_full(text, G["A"])


def train(sc, msgs, passes=3):
    sc.init_lengths()
    # slot ranks for overlay
    for m in MODES:
        sc.rank[m] = {c: i for i, c in enumerate(LET[m])}
    sc.inv = {m: {i: c for c, i in sc.rank[m].items()} for m in MODES}
    for p in range(passes):
        G["sc"] = sc
        res = pmap(_tok, msgs)
        cnt = collections.defaultdict(collections.Counter)
        for bits, flat, m0 in res:
            for (m, s) in flat:
                if isinstance(s, tuple):
                    continue
                cnt[sc.treekey(m)][s] += 1
        if sc.overlay and p == 0:
            # order slots per mode by frequency of this pass, then retrain
            lc = {m: collections.Counter() for m in MODES}
            for bits, flat, m0 in res:
                for (m, s) in flat:
                    if isinstance(s, str) and s.startswith("L#"):
                        lc[m][int(s[2:])] += 1
            # map: new rank by frequency within mode letters (using text frequencies)
            for m in MODES:
                freq = collections.Counter()
                for t in msgs:
                    for ch in t.lower():
                        if ch in LET[m]:
                            freq[ch] += 1
                order = [c for c, _ in freq.most_common()] + [c for c in LET[m] if c not in freq]
                sc.rank[m] = {c: i for i, c in enumerate(order)}
                sc.inv[m] = {i: c for c, i in sc.rank[m].items()}
            res = pmap(_tok, msgs)
            cnt = collections.defaultdict(collections.Counter)
            for bits, flat, m0 in res:
                for (m, s) in flat:
                    if isinstance(s, tuple):
                        continue
                    cnt[sc.treekey(m)][s] += 1
        newlens = {}
        for m in MODES:
            k = sc.treekey(m)
            if k in newlens:
                continue
            counts = {s: cnt[k].get(s, 0) + 0.5 for s in sc.symbols(m)}
            newlens[k] = huff_lengths(counts)
        sc.lens = newlens
        sc.build()
        tot = sum(b for b, f, m0 in res)
        log(f"  train {sc.name} pass {p+1}: bits/msg {tot/len(msgs):.1f}")
    return sc


def sizes_for(sc, texts):
    G["sc"] = sc
    res = pmap(_tok, texts)
    out = []
    flats = []
    for t, (bits, flat, m0) in zip(texts, res):
        n = -(-(3 + MB + bits) // 8)
        out.append(header(n) + n)
        flats.append(flat)
    return out, res


# ---------------------------------------------------------------- 6-bit fixed (+ bigram slots)

class Six:
    def __init__(self, name, nbig):
        self.name, self.nbig = name, nbig
        self.big = {m: [] for m in MODES}

    def fit(self, texts_by_mode):
        for m in MODES:
            cnt = collections.Counter()
            al = set(LET[m]) | {" "}
            for t in texts_by_mode[m]:
                for a, b in zip(t, t[1:]):
                    if a in al and b in al:
                        cnt[a + b] += 1
            self.big[m] = [p for p, _ in cnt.most_common(self.nbig)]
        self.bigset = {m: set(self.big[m]) for m in MODES}

    def tokens(self, text):
        """Viterbi over mode; cost 6 per token (single char, bigram slot, switch); ESC adds 8 per raw byte."""
        INF = 10 ** 9
        L = len(text)
        best = [{m: INF for m in MODES} for _ in range(L + 1)]
        for m in MODES:
            best[0][m] = 0
        for i in range(L + 1):
            b = best[i]
            best[i] = {m2: min(b[m2], min(b[m] + 6 for m in MODES if m != m2)) for m2 in MODES}
            if i == L:
                break
            ch = text[i]
            for m in MODES:
                c = best[i][m]
                al = set(LET[m]) | set(SHARED_A)
                c1 = c + 6 + (0 if ch in al else 8 * len(ch.encode("utf8")))
                if c1 < best[i + 1][m]:
                    best[i + 1][m] = c1
                if i + 1 < L and text[i:i + 2] in self.bigset[m]:
                    if c + 6 < best[i + 2][m]:
                        best[i + 2][m] = c + 6
        return min(best[L].values())


# ---------------------------------------------------------------- bigram predictive (order-1, bound)

def bigram_bits(flat_list_train, flat_list_test, alpha=0.1):
    """context = (mode, previous symbol). tree per context. returns mean bits per test msg and table size."""
    def ctxs(flat):
        prev = "^"
        out = []
        mode = flat[0][0] if flat else "ua"
        for (m, s) in flat:
            if isinstance(s, tuple):
                out.append(((m, prev), s))
                continue
            out.append(((m, prev), s))
            prev = "^" if s.startswith("SW") else s
        return out
    cnt = collections.defaultdict(collections.Counter)
    syms_by_mode = collections.defaultdict(set)
    for flat in flat_list_train:
        for c, s in ctxs(flat):
            if isinstance(s, tuple):
                continue
            cnt[c][s] += 1
            syms_by_mode[c[0]].add(s)
    base = {m: collections.Counter() for m in MODES}
    for c, cn in cnt.items():
        base[c[0]].update(cn)
    trees = {}
    for c, cn in cnt.items():
        allsyms = syms_by_mode[c[0]]
        counts = {s: cn.get(s, 0) + alpha * (1 + base[c[0]][s] / max(1, sum(base[c[0]].values())) * len(allsyms)) for s in allsyms}
        trees[c] = huff_lengths(counts)
    fb = {m: huff_lengths({s: base[m][s] + 1 for s in syms_by_mode[m]}) for m in MODES}
    tot = 0
    sizes = []
    for flat in flat_list_test:
        b = 0
        for c, s in ctxs(flat):
            if isinstance(s, tuple):
                b += 8
            else:
                t = trees.get(c) or fb[c[0]]
                b += t.get(s) or fb[c[0]].get(s, 12)
        sizes.append(b)
    nsym = sum(len(v) for v in trees.values())
    return sizes, len(trees), nsym
