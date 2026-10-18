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

tm = base + numtrain
random.shuffle(tm)
b.MODES.append("num"); b.LET["num"] = ""; b.MB = 3
sc = b.Scheme("B+num", caps="shift", shared=b.SHARED_A+b.EXTRA_B); sc.numset = set("0123456789.,-: ")
b.train(sc, tm)
NUM = sc.numset
TEXT = ("ua", "ru", "en")

def home(ch):
    lo = ch.lower()
    return [m for m in TEXT if lo in b.LET[m]]

def numrun(text, i):
    j = i
    while j < len(text) and text[j] in NUM: j += 1
    return text[i:j]

def greedy(text, sc):
    n = len(text); flat = []; bits = 0
    def emit(m, s):
        nonlocal bits
        flat.append((m, s))
        if isinstance(s, tuple): bits += 8
        else: bits += sc.cost(m, s)
    mode = "ua"
    first = numrun(text, 0)
    if sum(c.isdigit() for c in first) >= 3: mode = "num"
    else:
        for ch in text:
            h = home(ch)
            if h: mode = h[0]; break
    m0 = mode; last_text = mode if mode != "num" else "ua"; lock = False; i = 0
    shared = set(sc.shared)
    while i < n:
        ch = text[i]
        if mode != "num" and ch in NUM and sum(c.isdigit() for c in numrun(text, i)) >= 3 and ch.isdigit():
            emit(mode, "SW:num"); last_text = mode; mode = "num"; continue
        if mode == "num":
            if ch in NUM: emit("num", "S:" + ch); i += 1; continue
            h = home(ch); tgt = h[0] if h else last_text
            emit("num", "SW:" + tgt); mode = tgt; continue
        up = b.classify_upper(ch, mode); low = ch in b.LET[mode]
        if low or up:
            s = sc.lsym(mode, ch.lower())
            if up:
                if lock: emit(mode, s)
                else:
                    nxt = text[i+1] if i + 1 < n else ""
                    if b.classify_upper(nxt, mode) if nxt else False:
                        emit(mode, "LOCK"); lock = True; emit(mode, s)
                    else:
                        emit(mode, "CAP"); emit(mode, s)
            else:
                if lock: emit(mode, "LOCK"); lock = False
                emit(mode, s)
            i += 1; continue
        if ch in shared: emit(mode, "S:" + ch); i += 1; continue
        h = [m for m in TEXT if m != mode and (ch.lower() in b.LET[m])]
        if h:
            emit(mode, "SW:" + h[0]); last_text = h[0]; mode = h[0]; continue
        raw = ch.encode("utf8"); emit(mode, "ESC")
        for x in raw: emit(mode, ("RAW", x))
        i += 1
    return bits, flat, m0

mixed = [t[:40] + random.choice([", ", " "]) + nn for t, nn in zip(lowte["ua"][:800], nums(800, lowte["ua"]))]
sets = {"lower-ua": lowte["ua"][:1000], "lower-ru": lowte["ru"][:1000], "lower-en": lowte["en"][:1000], "numbers": numtest, "text+coords": mixed,
        "raw-ua": te["ua"][:1000], "raw-en": te["en"][:1000]}
print(f"{'set':12s}{'DP bits/char':>14s}{'greedy bits/char':>18s}{'greedy loss':>13s}")
bad = 0
for k, v in sets.items():
    chars = sum(len(t) for t in v); dp = gr = 0
    for t in v:
        bdp, fdp, m = b.tokenize_full(t, sc); dp += -(-(3 + b.MB + bdp) // 8) + 1
        bg, fg, mg = greedy(t, sc); gr += -(-(3 + b.MB + bg) // 8) + 1
        data = b.pack_bytes(b.to_bits(fg, sc, mg), mg)
        try: ok = b.decode(data, sc) == t
        except Exception: ok = False
        bad += not ok
    print(f"{k:12s}{8*dp/chars:14.2f}{8*gr/chars:18.2f}{100*(gr-dp)/dp:12.1f}%")
print("greedy round-trip failures:", bad)
