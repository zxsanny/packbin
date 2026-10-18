import sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench as b
random.seed(11)
tr = {}; te = {}
for lang, key in (("ukr","ua"),("rus","ru"),("eng","en")):
    t, e = b.load(lang, 6000, 800); tr[key] = t; te[key] = e
low = {k:[b.lower_dom(x) for x in v] for k,v in tr.items()}
lowte = {k:[b.lower_dom(x) for x in v] for k,v in te.items()}
def nums(n, ua):
    out = []
    for i in range(n):
        r = random.random()
        if r < 0.25: out.append("%.4f, %.4f" % (random.uniform(44,52), random.uniform(22,40)))
        elif r < 0.45: out.append("id: %d" % random.randint(1000, 99999999))
        elif r < 0.6: out.append("%02d:%02d" % (random.randint(0,23), random.randint(0,59)))
        elif r < 0.8: out.append(random.choice(ua)[:25] + " %d" % random.randint(1, 999))
        else: out.append("%d.%d, %d.%d, %d" % tuple(random.randint(0,99) for _ in range(5)))
    return out
base = (low["ua"][:2000]+low["ru"][:1500]+low["en"][:1500]+tr["ua"][:1000]+tr["ru"][:750]+tr["en"][:750])
numtrain = nums(1500, low["ua"])
numtest = nums(1000, lowte["ua"])
txt = lowte["ua"][:1000]
def sz(sc, v):
    s, _ = b.sizes_for(sc, v); return 8*sum(s)/sum(len(t) for t in v), sum(s)/len(v)
def report(name, sc):
    d = sc.lens["ua"]
    print(name, "| digit code lengths:", sorted(set(d["S:%d"%i] for i in range(10))), "| symbols", sum(len(sc.symbols(m)) for m in b.MODES))
    for lab, v in (("numbers", numtest), ("lower-ua text", txt), ("mixed text+coords", mixed)):
        bpc, by = sz(sc, v)
        print(f"   {lab:18s} {bpc:6.2f} bits/char  {by:6.2f} bytes/msg  (today: {sum(2+len(t.encode()) for t in v)/len(v):.2f} B)")
    return sc
mixed = [t[:40] + random.choice([", ", " "]) + n for t, n in zip(lowte["ua"][:800], nums(800, lowte["ua"]))]
tm = base + numtrain
random.shuffle(tm)
sc1 = b.Scheme("B", caps="shift", shared=b.SHARED_A+b.EXTRA_B); b.train(sc1, tm)
report("B, digits in the ordinary tables (trained with numbers)", sc1)
b.MODES.append("num"); b.LET["num"] = ""; b.MB = 3
sc2 = b.Scheme("B+num", caps="shift", shared=b.SHARED_A+b.EXTRA_B); sc2.numset = set("0123456789.,-: ")
b.train(sc2, tm)
report("B + number mode (digits . , - : space)", sc2)
cases = ["48.4612, 35.0403", "привіт 48.46", "id: 123456 ok", "12:45", "ПРИВІТ 5", "", "привіт 😀 12"]
bad = 0
for t in cases:
    bits, flat, m0 = b.tokenize_full(t, sc2)
    data = b.pack_bytes(b.to_bits(flat, sc2, m0), m0)
    try: ok = b.decode(data, sc2) == t
    except Exception as e: ok = False
    bad += not ok
    print("   ", "OK " if ok else "BAD", repr(t), "->", len(data) + 1, "B", "(today", 2 + len(t.encode()), "B)")
print("number-mode round-trip failures:", bad)
