"""Reference message ECC codec (AZ-2679; contract _docs/02_document/contracts/library/message-ecc.md).

A protected message is the clear message followed by n parity bytes. The code is a Reed-Solomon code over GF(256)
with the field polynomial 0x11D, alpha = 2 and generator roots alpha^0 .. alpha^(n-1). The code covers one byte that is
not sent: the clear length, placed before the clear message. That makes a lost or added byte at either end change the
check (a plain systematic code accepts a clear message with one trailing zero byte more or less). Python 3.9+, standard
library only.
"""
from math import comb
from fractions import Fraction

POLY = 0x11D
MAX_BLOCK = 254   # sent bytes: the code word is 255, one byte of it (the clear length) is not sent
MAX_PARITY = 32

# Refusal kinds, the names the contract gives every package.
BAD_PARITY = "bad_parity"          # n above 32 (or negative)
BAD_LIMIT = "bad_limit"            # t above n // 2 (or negative)
TOO_LONG = "too_long"              # clear message above 255 - n, or a received buffer above 255
SHORT = "short"                    # received buffer shorter than n
UNCORRECTABLE = "uncorrectable"    # more wrong bytes than the limit allows


class EccError(Exception):
    def __init__(self, kind, detail=""):
        super().__init__(kind + (": " + detail if detail else ""))
        self.kind = kind


EXP = [0] * 512
LOG = [0] * 256
_x = 1
for _i in range(255):
    EXP[_i] = _x
    LOG[_x] = _i
    _x <<= 1
    if _x & 0x100:
        _x ^= POLY
for _i in range(255, 512):
    EXP[_i] = EXP[_i - 255]


def mul(a, b):
    return 0 if a == 0 or b == 0 else EXP[LOG[a] + LOG[b]]


def inv(a):
    return EXP[255 - LOG[a]]


def generator(n):
    """Monic generator, highest degree first."""
    g = [1]
    for i in range(n):
        out = [0] * (len(g) + 1)
        for j, c in enumerate(g):
            out[j] ^= c
            out[j + 1] ^= mul(c, EXP[i])
        g = out
    return g


def check_parity(n):
    if not isinstance(n, int) or n < 0 or n > MAX_PARITY:
        raise EccError(BAD_PARITY, "n=%r, limit %d" % (n, MAX_PARITY))


def parity(clear, n):
    check_parity(n)
    if n == 0:
        return b""
    if len(clear) > MAX_BLOCK - n:
        raise EccError(TOO_LONG, "clear %d, limit %d" % (len(clear), MAX_BLOCK - n))
    g = generator(n)
    rem = [len(clear)] + list(clear) + [0] * n
    for i in range(len(clear) + 1):
        c = rem[i]
        if c:
            for j in range(1, n + 1):
                rem[i + j] ^= mul(g[j], c)
    return bytes(rem[len(clear) + 1:])


def protect(clear, n):
    return bytes(clear) + parity(clear, n)


def syndromes(word, n):
    """Syndromes of the code word: the clear length (word length minus n), then the word."""
    out = []
    for i in range(n):
        s = len(word) - n
        for b in word:
            s = mul(s, EXP[i]) ^ b
        out.append(s)
    return out


def _poly_eval(p, x):
    """p lowest degree first."""
    y = 0
    for c in reversed(p):
        y = mul(y, x) ^ c
    return y


def _locator(synd, n):
    """Berlekamp-Massey. Returns the error locator, lowest degree first, trimmed."""
    lam, prev = [1], [1]
    l, m, b = 0, 1, 1
    for r in range(n):
        d = synd[r]
        for i in range(1, l + 1):
            if i < len(lam):
                d ^= mul(lam[i], synd[r - i])
        if d == 0:
            m += 1
            continue
        t = lam[:]
        coef = mul(d, inv(b))
        need = len(prev) + m
        if len(lam) < need:
            lam += [0] * (need - len(lam))
        for i, c in enumerate(prev):
            lam[i + m] ^= mul(coef, c)
        if 2 * l <= r:
            l, prev, b, m = r + 1 - l, t, d, 1
        else:
            m += 1
    while len(lam) > 1 and lam[-1] == 0:
        lam.pop()
    return lam


def decode(received, n, t):
    """Returns (clear, repaired). Raises EccError."""
    check_parity(n)
    if not isinstance(t, int) or t < 0 or t > n // 2:
        raise EccError(BAD_LIMIT, "t=%r, n=%d" % (t, n))
    word = bytearray(received)
    if n == 0:
        return bytes(word), 0
    if len(word) > MAX_BLOCK:
        raise EccError(TOO_LONG, "buffer %d, limit %d" % (len(word), MAX_BLOCK))
    if len(word) < n:
        raise EccError(SHORT, "needed %d, present %d" % (n, len(word)))
    synd = syndromes(word, n)
    if not any(synd):
        return bytes(word[:len(word) - n]), 0
    if t == 0:
        raise EccError(UNCORRECTABLE, "syndromes nonzero")
    lam = _locator(synd, n)
    deg = len(lam) - 1
    size = len(word)
    if deg == 0 or deg > t:
        raise EccError(UNCORRECTABLE, "locator degree %d, limit %d" % (deg, t))
    # position p (0 = first byte sent) has locator X = alpha^(size-1-p); the unsent length byte is one place before it
    roots = [p for p in range(size) if _poly_eval(lam, EXP[(255 - (size - 1 - p)) % 255]) == 0]
    if len(roots) != deg:
        raise EccError(UNCORRECTABLE, "locator roots %d, degree %d" % (len(roots), deg))
    # error evaluator omega = (synd(x) * lam(x)) mod x^n, lowest degree first
    omega = [0] * n
    for i in range(n):
        for j in range(len(lam)):
            if i + j < n:
                omega[i + j] ^= mul(synd[i], lam[j])
    dlam = [lam[i] if i % 2 == 1 else 0 for i in range(1, len(lam))]  # derivative in char 2, lowest degree first
    for p in roots:
        x = EXP[(size - 1 - p) % 255]
        xi = inv(x)
        den = _poly_eval(dlam, xi)
        if den == 0:
            raise EccError(UNCORRECTABLE, "zero derivative")
        word[p] ^= mul(x, mul(_poly_eval(omega, xi), inv(den)))
    if any(syndromes(word, n)):
        raise EccError(UNCORRECTABLE, "repair does not verify")
    return bytes(word[:size - n]), deg


def accept_fraction(clear_len, n, t):
    """Exact chance that a uniformly random buffer of clear_len + n bytes is accepted (returns a row) with limit t."""
    size = clear_len + n
    balls = sum(comb(size, i) * 255 ** i for i in range(t + 1))
    return Fraction(balls, 256 ** n)
