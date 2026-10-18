import sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench as b
random.seed(5)
tr = {}
for lang, key in (("ukr","ua"),("rus","ru"),("eng","en")):
    t, _ = b.load(lang, 6000, 10); tr[key] = t
low = {k:[b.lower_dom(x) for x in v] for k,v in tr.items()}
msgs = low["ua"][:2000]+low["ru"][:1500]+low["en"][:1500]+tr["ua"][:1000]+tr["ru"][:750]+tr["en"][:750]
sc = b.Scheme("HUF-B", caps="shift", shared=b.SHARED_A+b.EXTRA_B)
b.train(sc, msgs)
print("EXTRA symbols:", repr(b.EXTRA_B))
for t in ["привіт, світе!", "Привіт, Світе!", "ПРИВІТ", "привіт ok 48.46", "привіт 😀"]:
    bits, flat, m0 = b.tokenize_full(t, sc)
    data = b.pack_bytes(b.to_bits(flat, sc, m0), m0)
    print()
    print(repr(t), "chars", len(t), "UTF-8 today", 2+len(t.encode()), "B ->", len(data)+1, "B  (prefix: start mode", m0 + ")")
    row = []
    for (m, s) in flat:
        if isinstance(s, tuple):
            row.append("raw byte %02x (8 bits)" % s[1]); continue
        c, l = sc.trees[sc.treekey(m)].codes[s]
        row.append(f"{s}[{m}] {format(c,'0%db'%l)} ({l})")
    print("  " + "\n  ".join(row))
    print("  code bits total:", bits)
