#!/usr/bin/env python3
"""Compact-string benchmark for packbin loop 35. Corpus: Tatoeba (ukr, rus, eng).
Schemes: UTF8+2 (today), Unishox2, Huffman A/B/C (per-mode trees), overlay B (one tree),
fixed 6-bit (+9 bigram slots), predictive order-1 bigram (bound, not error-safe).
All-in size = 1 header byte (payload < 128 B) + ceil((5 prefix bits + code bits) / 8).
The 5 prefix bits are 3 pad bits and 2 initial-mode bits.

Files: bench_common.py (setup, corpus), bench_scheme.py (Huffman schemes, tokenizer, decoder),
bench_train.py (training, 6-bit, bigram bound), this file (the run and the report).
The alphabets and canonical codes come from scripts/text/textfmt.py."""
import difflib, json, math, os, random, subprocess

from bench_common import (ALLOWED, EN, EXTRA_B, G, LET, MB, MODES, PRINTABLE, RU, S, SHARED_A, UA,
                          header, load, log, lower_dom, pmap)
from bench_scheme import (Scheme, Tree, canon_codes, classify_upper, decode, huff_lengths, pack_bytes,
                          to_bits, tokenize, tokenize_full)
from bench_train import Six, _tok, _tok_A, bigram_bits, sizes_for, train


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


def run_unishox(tests):
    """Unishox2 sizes (+1 header byte) and damaged decodes, through usx.js."""
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
    return uni, allf


def train_and_measure(tm, tests, results):
    """Train the four Huffman schemes, add their sizes to `results`, check the round trip on a sample."""
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
    return trained


def damage_rows(trained, tests, allf):
    """Flip one random bit per message and compare the decoded text with the original."""
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
    return dmg_rows


def run():
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

    log("unishox2 ...")
    uni, allf = run_unishox(tests)
    results["Unishox2 (+1B)"] = uni

    trained = train_and_measure(tm, tests, results)

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

    print()
    log("damage simulation")
    dmg_rows = damage_rows(trained, tests, allf)
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


if __name__ == "__main__":
    run()
