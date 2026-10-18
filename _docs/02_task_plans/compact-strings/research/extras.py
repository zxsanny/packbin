import sys, os, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench as b
random.seed(5)
tr = {}
for lang, key in (("ukr","ua"),("rus","ru"),("eng","en")):
    t, _ = b.load(lang, 6000, 10)
    tr[key] = t
low = {k:[b.lower_dom(x) for x in v] for k,v in tr.items()}
msgs = low["ua"][:2000]+low["ru"][:1500]+low["en"][:1500]+tr["ua"][:1000]+tr["ru"][:750]+tr["en"][:750]
cases = ["", "a", "привіт", "Привіт", "ПРИВІТ, СВІТЕ!", "привіт 😀", "hello, world", "привіт! координати: 48.46, 35.04 ok?",
         "ёжик съел яблоко", "zażółć gęślą jaźń", "x"*300, "привіт"*60, "\n\t", "ǅ", "ß", "İstanbul", "á", "м'яч"]
for sc in (b.Scheme("HUF-B", caps="shift", shared=b.SHARED_A+b.EXTRA_B),
           b.Scheme("OVL-B", caps="shift", shared=b.SHARED_A+b.EXTRA_B, overlay=True)):
    b.train(sc, msgs)
    bad = 0
    for t in cases:
        bits, flat, m0 = b.tokenize_full(t, sc)
        data = b.pack_bytes(b.to_bits(flat, sc, m0), m0)
        try: back = b.decode(data, sc)
        except Exception as e: back = "EXC %s" % e
        ok = back == t
        bad += not ok
        print(f"  {sc.name} {'OK ' if ok else 'BAD'} {t[:30]!r:34} chars={len(t):4d} utf8+2={2+len(t.encode()):4d} compact={len(data)+b.header(len(data)):4d}", "" if ok else repr(back[:40]))
    print(sc.name, "case failures:", bad)
    mins = {k: (min(v.values()), max(v.values()), len(v)) for k,v in sc.lens.items()}
    print(sc.name, "code length min/max/symbols per tree:", mins)
    # random unicode fuzz
    rnd = random.Random(9); fail = 0
    alphabet = [chr(c) for c in list(range(32,127))+list(range(0x400,0x4ff))+[0x2014,0x20ac,0x1f600,0x4e2d,0x00e9,0x0301]]
    for i in range(3000):
        t = "".join(rnd.choice(alphabet) for _ in range(rnd.randint(0,60)))
        bits, flat, m0 = b.tokenize_full(t, sc)
        data = b.pack_bytes(b.to_bits(flat, sc, m0), m0)
        try: ok = b.decode(data, sc) == t
        except Exception: ok = False
        fail += not ok
    print(sc.name, "random Unicode round-trip failures: %d / 3000" % fail)
    # top codes
    for m in ("ua","en"):
        k = sc.treekey(m); l = sc.lens[k]
        print("  ", sc.name, m, "shortest:", sorted(l.items(), key=lambda kv: kv[1])[:8], "SW/ESC/CAP/LOCK:", {s:l[s] for s in l if s in ("ESC","CAP","LOCK") or s.startswith("SW")})
