#!/usr/bin/env python3
"""Compact-string benchmark for packbin loop 35. Corpus: Tatoeba (ukr, rus, eng).
Schemes: UTF8+2 (today), Unishox2, Huffman A/B/C (per-mode trees), overlay B (one tree),
fixed 6-bit (+9 bigram slots), predictive order-1 bigram (bound, not error-safe).
All-in size = 1 header byte (payload < 128 B) + ceil((5 prefix bits + code bits) / 8).
The 5 prefix bits are 3 pad bits and 2 initial-mode bits."""
import collections, heapq, json, math, multiprocessing as mp, os, random, subprocess, sys, time, difflib

S = os.environ.get('PACKBIN_BENCH_DIR', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
random.seed(35)
T0 = time.time()


def log(*a):
    print(f"[{time.time()-T0:6.0f}s]", *a, flush=True)


UA = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"
RU = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
EN = "abcdefghijklmnopqrstuvwxyz'"
LET = {"ua": UA, "ru": RU, "en": EN}
MODES = ["ua", "ru", "en"]
MB = 2  # bits of the initial-mode field (3 when a number mode is added)
SHARED_A = " 0123456789,.-:!?"
EXTRA_B = ';()"%/@+=*#&_$\n'
PRINTABLE = "".join(chr(c) for c in range(32, 127))
ALLOWED = set(UA) | set(RU) | set(EN) | set(SHARED_A)


def load(lang, n_train, n_test):
    rows = []
    with open(f"{S}/corpus/{lang}_sentences.tsv", encoding="utf8") as f:
        for i, line in enumerate(f):
            t = line.rstrip("\n").split("\t", 2)[2]
            if 3 <= len(t) <= 100:
                rows.append(t)
    random.shuffle(rows)
    return rows[:n_train], rows[n_train:n_train + n_test]


def lower_dom(t):
    t = t.lower()
    t = "".join(c for c in t if c in ALLOWED)
    return " ".join(t.split())


# ---------------------------------------------------------------- Huffman

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
    """canonical codes: sort by (len, sym). returns sym->(code int, len)"""
    codes = {}
    code = 0
    prev = 0
    for s, l in sorted(lengths.items(), key=lambda kv: (kv[1], kv[0])):
        code <<= (l - prev)
        codes[s] = (code, l)
        code += 1
        prev = l
    return codes


class Tree:
    def __init__(self, lengths):
        self.len = lengths
        self.codes = canon_codes(lengths)
        self.dec = {(c, l): s for s, (c, l) in self.codes.items()}
        self.maxlen = max(lengths.values())


# ---------------------------------------------------------------- scheme model

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


def header(n):
    return 1 if n < 128 else 2


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


# ---------------------------------------------------------------- training
G = {}


def _tok(text):
    return tokenize_full(text, G["sc"])


def pmap(fn, items, chunk=64):
    with mp.get_context("fork").Pool(min(8, os.cpu_count() or 4)) as p:
        return p.map(fn, items, chunksize=chunk)


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


# ---------------------------------------------------------------- main
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


def run():
    sets = {}
    train_txt = {}
    test_raw = {}
    for lang, key in (("ukr", "ua"), ("rus", "ru"), ("eng", "en")):
        tr, te = load(lang, 12000, 2000)
        train_txt[key] = tr
        test_raw[key] = te
        log(f"loaded {lang}: train {len(tr)} test {len(te)}")
    low_train = {k: [lower_dom(t) for t in v] for k, v in train_txt.items()}
    low_train = {k: [t for t in v if len(t) >= 3] for k, v in low_train.items()}
    low_test = {k: [t for t in (lower_dom(x) for x in v) if len(t) >= 3] for k, v in test_raw.items()}

    def mix(sentences_ua, sentences_ru, sentences_en, n):
        out = []
        short_en = [s for s in sentences_en if len(s.split()) <= 4] or sentences_en
        for i in range(n):
            r = random.random()
            ua = random.choice(sentences_ua)
            if r < 0.3:
                out.append(ua + ", %.2f, %.2f" % (random.uniform(44, 52), random.uniform(22, 40)))
            elif r < 0.55:
                out.append(ua + " " + random.choice(["ok?", "ok", "gps", "ping!", "ua", "en"]))
            elif r < 0.8:
                en = random.choice(short_en)
                out.append(random.choice(sentences_ru) + " " + en)
            else:
                out.append("id: %d " % random.randint(1000, 999999) + ua[:30])
        return out

    # training mixture
    tm = (random.sample(low_train["ua"], 2000) + random.sample(low_train["ru"], 1500)
          + random.sample(low_train["en"], 1500)
          + mix(low_train["ua"], low_train["ru"], low_train["en"], 1000)
          + random.sample(train_txt["ua"], 1000) + random.sample(train_txt["ru"], 750)
          + random.sample(train_txt["en"], 750))
    random.shuffle(tm)
    log("training messages:", len(tm))

    tests = {
        "lower-ua": random.sample(low_test["ua"], 1500),
        "lower-ru": random.sample(low_test["ru"], 1500),
        "lower-en": random.sample(low_test["en"], 1500),
        "mixed": mix(low_test["ua"], low_test["ru"], low_test["en"], 1500),
        "raw-ua": random.sample(test_raw["ua"], 1500),
        "raw-ru": random.sample(test_raw["ru"], 1500),
        "raw-en": random.sample(test_raw["en"], 1500),
    }
    # extra: samples of tiny and short messages
    short = [t for t in low_test["ua"] if len(t) <= 20][:1500]
    tests["short-ua(<=20)"] = short

    results = {}
    total_chars = {k: sum(len(t) for t in v) for k, v in tests.items()}

    # baseline
    results["UTF8+2B (today)"] = {k: sum(2 + len(t.encode("utf8")) for t in v) for k, v in tests.items()}
    results["UTF8+1B"] = {k: sum(1 + len(t.encode("utf8")) for t in v) for k, v in tests.items()}

    # Unishox2
    log("unishox2 ...")
    uni = {}
    allf = {}
    for k, v in tests.items():
        fl = [random.random() for _ in v]
        json.dump({"texts": v, "flips": fl}, open(f"{S}/usx_in.json", "w"), ensure_ascii=False)
        subprocess.run(["node", f"{os.path.dirname(os.path.abspath(__file__))}/usx.js", f"{S}/unishox", f"{S}/usx_in.json", f"{S}/usx_out.json"],
                       stdout=subprocess.DEVNULL, stdin=subprocess.DEVNULL, check=True)
        o = json.load(open(f"{S}/usx_out.json"))
        uni[k] = sum(1 + math.ceil(x) for x in o["lens"])
        allf[k] = (v, o["damaged"])
        if o["bad"]:
            log(f"  unishox roundtrip failures in {k}: {o['bad']}")
    results["Unishox2 (+1B)"] = uni

    schemes = [
        Scheme("HUF-A lower+escape"),
        Scheme("HUF-B shift+15punct", caps="shift", shared=SHARED_A + EXTRA_B),
        Scheme("HUF-C table-all", caps="table", shared="".join(c for c in PRINTABLE if not c.isalpha())),
        Scheme("OVL-B overlay shift", caps="shift", shared=SHARED_A + EXTRA_B, overlay=True),
    ]
    trained = []
    for sc in schemes:
        log("training", sc.name)
        train(sc, tm)
        trained.append(sc)
        res = {}
        flats_by_test = {}
        for k, v in tests.items():
            sz, rr = sizes_for(sc, v)
            res[k] = sum(sz)
            flats_by_test[k] = rr
        results[sc.name] = res
        sc.flats = flats_by_test
        nsym = sum(len(sc.symbols(m)) for m in MODES) if not sc.overlay else len(sc.symbols("ua"))
        sc.nsym = nsym
        log(f"  {sc.name}: symbols in tables {nsym}")
        # round trip check
        bad = 0
        for k, v in tests.items():
            for t, (bits, flat, m0) in list(zip(v, flats_by_test[k]))[:150]:
                data = pack_bytes(to_bits(flat, sc, m0), m0)
                try:
                    if decode(data, sc) != t:
                        bad += 1
                except Exception as e:
                    bad += 1
        log(f"  {sc.name}: round-trip failures in sample: {bad}")

    # 6-bit
    for name, nb in (("SIX6 plain", 0), ("SIX6 +9 bigram slots", 9)):
        six = Six(name, nb)
        six.fit({m: low_train[m] for m in MODES})
        res = {}
        for k, v in tests.items():
            tot = 0
            for t in v:
                bits = six.tokens(t)
                n = -(-(5 + bits) // 8)
                tot += header(n) + n
            res[k] = tot
        results[name] = res
        log("done", name, six.big["ua"][:9])

    # predictive bigram (bound) on HUF-A tokenization
    A = trained[0]
    G["A"] = A
    flat_train = [f for (b, f, m0) in pmap(_tok_A, tm)]
    pred = {}
    for k, v in tests.items():
        sizes, nctx, nsym = bigram_bits(flat_train, [f for (b, f, m0) in A.flats[k]])
        pred[k] = sum(header(-(-(5 + b) // 8)) + -(-(5 + b) // 8) for b in sizes)
    results["BIGRAM-pred (order-1, not error-safe)"] = pred
    log(f"bigram tables: contexts {nctx}, entries {nsym}")

    # report
    ks = list(tests)
    print()
    print("ALL-IN bits per character (1 header byte + prefix + padding included); lower is better")
    print(f"{'scheme':42s}" + "".join(f"{k:>15s}" for k in ks))
    for name, r in results.items():
        print(f"{name:42s}" + "".join(f"{8*r[k]/total_chars[k]:15.2f}" for k in ks))
    print()
    print("mean bytes per message")
    print(f"{'scheme':42s}" + "".join(f"{k:>15s}" for k in ks))
    for name, r in results.items():
        print(f"{name:42s}" + "".join(f"{r[k]/len(tests[k]):15.2f}" for k in ks))
    print()
    print("chars per message:", {k: round(total_chars[k] / len(tests[k]), 1) for k in ks})
    for sc in trained:
        print(sc.name, "symbols in tables:", sc.nsym)

    # damage
    print()
    log("damage simulation")
    dmg_rows = []
    sample_k = ["lower-ua", "mixed", "lower-en"]
    for sc in trained[:2] + [trained[3]]:
        for k in sample_k:
            v = tests[k][:600]
            fl = sc.flats[k][:600]
            err = 0
            wrong = []
            for t, (bits, flat, m0) in zip(v, fl):
                data = bytearray(pack_bytes(to_bits(flat, sc, m0), m0))
                bit = random.randrange(len(data) * 8)
                data[bit >> 3] ^= 0x80 >> (bit & 7)
                try:
                    d = decode(bytes(data), sc)
                    r = difflib.SequenceMatcher(None, t, d, autojunk=False).ratio()
                    wrong.append((1 - r))
                except Exception:
                    err += 1
            ok = len(wrong)
            dmg_rows.append((sc.name, k, err / len(v), sum(wrong) / max(1, ok)))
    # utf8 and unishox
    for k in sample_k:
        v = tests[k][:600]
        wrong = []
        for t in v:
            data = bytearray(t.encode("utf8"))
            bit = random.randrange(len(data) * 8)
            data[bit >> 3] ^= 0x80 >> (bit & 7)
            d = bytes(data).decode("utf8", errors="replace")
            wrong.append(1 - difflib.SequenceMatcher(None, t, d, autojunk=False).ratio())
        dmg_rows.append(("UTF8", k, 0.0, sum(wrong) / len(wrong)))
        v0, dm = allf[k]
        wrong, err = [], 0
        for t, d in list(zip(v0, dm))[:600]:
            if d is None:
                err += 1
            else:
                wrong.append(1 - difflib.SequenceMatcher(None, t, d, autojunk=False).ratio())
        dmg_rows.append(("Unishox2", k, err / 600, sum(wrong) / max(1, len(wrong))))
    print(f"{'scheme':30s}{'test':12s}{'decode error':>14s}{'mean damage of decoded':>26s}")
    for r in dmg_rows:
        print(f"{r[0]:30s}{r[1]:12s}{r[2]*100:13.1f}%{r[3]*100:25.1f}%")
    json.dump({"results": results, "chars": total_chars, "n": {k: len(v) for k, v in tests.items()}},
              open(f"{S}/bench_results.json", "w"))
    # table dumps for the report
    for sc in trained:
        d = {k: {s: l for s, l in v.items()} for k, v in sc.lens.items()}
        json.dump(d, open(f"{S}/lens_{sc.name.split()[0]}.json", "w"), ensure_ascii=False)
    log("done")


def _tok_A(text):
    return tokenize_full(text, G["A"])


if __name__ == "__main__":
    run()
