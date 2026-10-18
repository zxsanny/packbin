#!/usr/bin/env python3
"""Train and freeze the code-length tables of the packbin compact text format (AZ-2646).

Usage:
  train_tables.py --corpus DIR [--out fixtures/text/tables.json] [--report fixtures/text/tables.report.md]
  train_tables.py --corpus DIR --check          # retrain and compare with the committed tables.json

DIR holds ukr_sentences.tsv, rus_sentences.tsv and eng_sentences.tsv, unpacked from
https://downloads.tatoeba.org/exports/per_language/<lang>/<lang>_sentences.tsv.bz2 (CC BY 2.0 FR).
Their sha256 are recorded below and checked. The run takes no randomness except the seeded
generator in this file, so the output is the same bytes on every machine.
"""
import argparse
import hashlib
import heapq
import json
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import textfmt as tf  # noqa: E402

CORPUS_SHA256 = {
    "ukr": "882a6b3976993fba09393926cb21a7e1cc97908cd73598dd9f736f949c853a7e",
    "rus": "db438e855b6b99874c4bef8770cdedbfae3e3ff1d48afa503852d3ec27bc2b92",
    "eng": "ac9f0d48a44c7ac4f3eab724567774487b9841dcfcb3b2bcac48e1cc5636cd96",
}
SEED = 35
PASSES = 4
TRAIN_PER_LANG = 12000
TEST_PER_LANG = 2000
MASK = (1 << 64) - 1
ALLOWED_LOWER = set(tf.UA) | set(tf.RU) | set(tf.EN) | set(" 0123456789,.-:!?")
OUT_DEFAULT = os.path.join(HERE, "..", "..", "fixtures", "text", "tables.json")
REPORT_DEFAULT = os.path.join(HERE, "..", "..", "fixtures", "text", "tables.report.md")


class Rng:
    """splitmix64: the same numbers on every platform and Python version."""

    def __init__(self, seed):
        self.s = seed & MASK

    def next(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & MASK
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return z ^ (z >> 31)

    def below(self, n):
        return self.next() % n

    def choice(self, a):
        return a[self.below(len(a))]

    def uniform_milli(self, lo, hi):
        """An integer number of thousandths in [lo*1000, hi*1000)."""
        return lo * 1000 + self.below((hi - lo) * 1000)


def sample_distinct(rng, n_items, k):
    """k distinct indexes of range(n_items), in draw order (partial Fisher-Yates)."""
    idx = list(range(n_items))
    for i in range(k):
        j = i + rng.below(n_items - i)
        idx[i], idx[j] = idx[j], idx[i]
    return idx[:k]


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def load_language(corpus, lang, rng):
    path = os.path.join(corpus, "%s_sentences.tsv" % lang)
    got = sha256_of(path)
    if got != CORPUS_SHA256[lang]:
        raise SystemExit("%s: sha256 %s differs from the recorded %s" % (path, got, CORPUS_SHA256[lang]))
    rows = []
    with open(path, encoding="utf8") as f:
        for line in f:
            text = line.rstrip("\n").split("\t", 2)[2]
            if 3 <= len(text) <= 100:
                rows.append(text)
    picks = sample_distinct(rng, len(rows), TRAIN_PER_LANG + TEST_PER_LANG)
    chosen = [rows[i] for i in picks]
    return chosen[:TRAIN_PER_LANG], chosen[TRAIN_PER_LANG:]


def lower_domain(text):
    kept = "".join(c for c in text.lower() if c in ALLOWED_LOWER)
    return " ".join(kept.split())


def lower_list(texts):
    return [t for t in (lower_domain(x) for x in texts) if len(t) >= 3]


def number_messages(rng, n, ua_lower):
    out = []
    for _ in range(n):
        r = rng.below(100)
        if r < 25:
            out.append("%.4f, %.4f" % (rng.uniform_milli(44, 52) / 1000, rng.uniform_milli(22, 40) / 1000))
        elif r < 45:
            out.append("id: %d" % (1000 + rng.below(99998999)))
        elif r < 60:
            out.append("%02d:%02d" % (rng.below(24), rng.below(60)))
        elif r < 80:
            out.append(rng.choice(ua_lower)[:25] + " %d" % (1 + rng.below(999)))
        else:
            out.append("%d.%d, %d.%d, %d" % tuple(rng.below(100) for _ in range(5)))
    return out


def mixed_messages(rng, n, ua, ru, en):
    short_en = [s for s in en if len(s.split()) <= 4] or en
    out = []
    for _ in range(n):
        r = rng.below(100)
        base = rng.choice(ua)
        if r < 30:
            out.append(base + ", %.2f, %.2f" % (rng.uniform_milli(44, 52) / 1000, rng.uniform_milli(22, 40) / 1000))
        elif r < 55:
            out.append(base + " " + rng.choice(["ok?", "ok", "gps", "ping!", "ua", "en"]))
        elif r < 80:
            out.append(rng.choice(ru) + " " + rng.choice(short_en))
        else:
            out.append("id: %d " % (1000 + rng.below(998999)) + base[:30])
    return out


def pick(rng, items, k):
    return [items[i] for i in sample_distinct(rng, len(items), k)]


# ---- length-limited Huffman, integer weights, deterministic ties
def huffman_lengths(weights, limit):
    n = len(weights)
    floor = 0
    while True:
        w = [max(x, floor) for x in weights]
        heap = [(w[i], i, (i,)) for i in range(n)]
        heapq.heapify(heap)
        depth = [0] * n
        seq = n
        while len(heap) > 1:
            w1, _, m1 = heapq.heappop(heap)
            w2, _, m2 = heapq.heappop(heap)
            for i in m1 + m2:
                depth[i] += 1
            heapq.heappush(heap, (w1 + w2, seq, m1 + m2))
            seq += 1
        if max(depth) <= limit:
            return depth
        floor = max(2, floor * 2)


_TABLES = None


def _parse_one(text):
    total, symbols, _ = tf.parse(text, _TABLES)
    return symbols


def parse_all(messages, tables, workers):
    global _TABLES
    _TABLES = tables
    with mp.get_context("fork").Pool(workers) as pool:
        return pool.map(_parse_one, messages, chunksize=32)


def train(messages, workers, log):
    lengths = [huffman_lengths([1] * len(tf.SYMBOLS[m]), tf.MAX_CODE_LEN) for m in range(4)]
    for p in range(PASSES):
        tables = tf.Tables(lengths)
        parsed = parse_all(messages, tables, workers)
        counts = [[0] * len(tf.SYMBOLS[m]) for m in range(4)]
        bits = 0
        for symbols in parsed:
            for mode, s in symbols:
                if isinstance(s, tuple):
                    bits += 8
                else:
                    counts[mode][s] += 1
                    bits += lengths[mode][s]
        lengths = [huffman_lengths([2 * c + 1 for c in counts[m]], tf.MAX_CODE_LEN) for m in range(4)]
        log("pass %d: %.1f bits per message" % (p + 1, bits / len(messages)))
    return lengths


# ---- report
def field_bytes(text, tables):
    return len(tf.encode(text, tables))


def report(tests, tables):
    rows = []
    bounds = {"lower-ua": 0.40, "lower-ru": 0.40, "lower-en": 0.62, "mixed": 0.48,
              "raw-ua": 0.40, "raw-ru": 0.40, "raw-en": 0.62, "numbers": 0.56, "text+coords": 0.45}
    ok = True
    for name, texts in tests.items():
        compact = sum(field_bytes(t, tables) for t in texts)
        today = sum(2 + len(t.encode("utf8")) for t in texts)
        chars = sum(len(t) for t in texts)
        ratio = compact / today
        bound = bounds.get(name)
        passed = bound is None or ratio <= bound
        ok = ok and passed
        rows.append((name, len(texts), chars, today, compact, ratio, 8 * compact / chars, bound, passed))
    lines = ["# Compact text tables: size report", "",
             "Held-out sentences (not used for training) and synthetic number messages; sizes are whole string fields.", "",
             "| set | messages | chars | today (bytes) | compact (bytes) | compact / today | bits per char | bound | |",
             "|-----|---------:|------:|--------------:|----------------:|----------------:|--------------:|------:|---|"]
    for (name, n, chars, today, compact, ratio, bpc, bound, passed) in rows:
        lines.append("| %s | %d | %d | %d | %d | %.1f %% | %.2f | %s | %s |" % (
            name, n, chars, today, compact, 100 * ratio, bpc,
            "-" if bound is None else "%.0f %%" % (100 * bound), "ok" if passed else "OVER"))
    return "\n".join(lines) + "\n", ok


def build(corpus, workers, log):
    rng = Rng(SEED)
    train_txt, test_txt = {}, {}
    for lang, key in (("ukr", "ua"), ("rus", "ru"), ("eng", "en")):
        train_txt[key], test_txt[key] = load_language(corpus, lang, rng)
        log("%s: %d train, %d test" % (lang, len(train_txt[key]), len(test_txt[key])))
    low_tr = {k: lower_list(v) for k, v in train_txt.items()}
    low_te = {k: lower_list(v) for k, v in test_txt.items()}
    messages = (pick(rng, low_tr["ua"], 2000) + pick(rng, low_tr["ru"], 1500) + pick(rng, low_tr["en"], 1500)
                + mixed_messages(rng, 1000, low_tr["ua"], low_tr["ru"], low_tr["en"])
                + pick(rng, train_txt["ua"], 1000) + pick(rng, train_txt["ru"], 750) + pick(rng, train_txt["en"], 750)
                + number_messages(rng, 1500, low_tr["ua"]))
    order = sample_distinct(rng, len(messages), len(messages))
    messages = [messages[i] for i in order]
    log("training messages: %d" % len(messages))
    lengths = train(messages, workers, log)
    tables = tf.Tables(lengths)
    tests = {
        "lower-ua": pick(rng, low_te["ua"], 1000), "lower-ru": pick(rng, low_te["ru"], 1000),
        "lower-en": pick(rng, low_te["en"], 1000),
        "mixed": mixed_messages(rng, 1000, low_te["ua"], low_te["ru"], low_te["en"]),
        "raw-ua": pick(rng, test_txt["ua"], 1000), "raw-ru": pick(rng, test_txt["ru"], 1000),
        "raw-en": pick(rng, test_txt["en"], 1000),
        "numbers": number_messages(rng, 1000, low_te["ua"]),
    }
    tests["text+coords"] = [t[:40] + rng.choice([", ", " "]) + n for t, n in
                            zip(pick(rng, low_te["ua"], 800), number_messages(rng, 800, low_te["ua"]))]
    text, ok = report(tests, tables)
    data = {
        "format": "packbin-compact-text", "version": 1,
        "alphabets": {"ua": tf.UA, "ru": tf.RU, "en": tf.EN},
        "upper": {n: [u or "" for u in tf.UPPER[i]] for i, n in enumerate(("ua", "ru", "en"))},
        "shared": tf.SHARED, "numset": tf.NUMSET,
        "modes": {tf.MODE_NAMES[m]: {"symbols": [tf.symbol_name(m, s) for s in tf.SYMBOLS[m]], "lengths": lengths[m]}
                  for m in range(4)},
        "training": {"seed": SEED, "passes": PASSES, "messages": len(messages), "max_code_length": tf.MAX_CODE_LEN,
                     "corpus_sha256": CORPUS_SHA256,
                     "recipe": "train/test = %d/%d sentences per language (3 to 100 chars) drawn with splitmix64(seed); "
                               "mix: 2000 ua + 1500 ru + 1500 en lowercase, 1000 mixed, 1000 ua + 750 ru + 750 en as written, "
                               "1500 synthetic number messages; %d Viterbi passes; weights 2*count+1" % (
                                   TRAIN_PER_LANG, TEST_PER_LANG, PASSES)},
    }
    return json.dumps(data, ensure_ascii=False, indent=1) + "\n", text, ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default=os.environ.get("PACKBIN_TEXT_CORPUS"))
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--report", default=REPORT_DEFAULT)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    if not args.corpus:
        raise SystemExit("--corpus DIR or PACKBIN_TEXT_CORPUS is required")

    def log(msg):
        print(msg, file=sys.stderr, flush=True)

    tables_json, report_md, ok = build(args.corpus, args.workers, log)
    if args.check:
        with open(args.out, encoding="utf8") as f:
            same = f.read() == tables_json
        print("tables.json reproduced byte for byte" if same else "tables.json DIFFERS from the committed file")
        return 0 if same else 1
    with open(args.out, "w", encoding="utf8") as f:
        f.write(tables_json)
    with open(args.report, "w", encoding="utf8") as f:
        f.write(report_md)
    print(report_md)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
