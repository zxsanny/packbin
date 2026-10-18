"""Shared setup of the loop 35 compact-string benchmark: paths, seed, log, corpus loading, worker pool.
The alphabets and the canonical code construction come from scripts/text/textfmt.py, the one reference."""
import importlib.util, multiprocessing as mp, os, pathlib, random, time

REPO = pathlib.Path(__file__).resolve().parents[4]
_spec = importlib.util.spec_from_file_location("textfmt", REPO / "scripts" / "text" / "textfmt.py")
textfmt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(textfmt)

S = os.environ.get('PACKBIN_BENCH_DIR', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
random.seed(35)
T0 = time.time()


def log(*a):
    print(f"[{time.time()-T0:6.0f}s]", *a, flush=True)


UA, RU, EN = textfmt.UA, textfmt.RU, textfmt.EN
LET = {"ua": UA, "ru": RU, "en": EN}
MODES = ["ua", "ru", "en"]
MB = 2  # bits of the initial-mode field (3 when a number mode is added)
SHARED_A = " 0123456789,.-:!?"
EXTRA_B = ';()"%/@+=*#&_$\n'
PRINTABLE = "".join(chr(c) for c in range(32, 127))
ALLOWED = set(UA) | set(RU) | set(EN) | set(SHARED_A)

G = {}  # the scheme the pool workers tokenize with; set before the pool forks


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


def header(n):
    return 1 if n < 128 else 2


def pmap(fn, items, chunk=64):
    with mp.get_context("fork").Pool(min(8, os.cpu_count() or 4)) as p:
        return p.map(fn, items, chunksize=chunk)
