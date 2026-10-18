from __future__ import annotations

# Message error correction (contract message-ecc 1.0.0): a Reed-Solomon code over GF(256), field polynomial 0x11D,
# alpha = 2, generator roots alpha^0 .. alpha^(n-1). The code covers one byte that is not sent, the clear length.

MAX_BLOCK = 254
MAX_PARITY = 32

_EXP = [0] * 512
_LOG = [0] * 256
_value = 1
for _power in range(255):
    _EXP[_power] = _value
    _LOG[_value] = _power
    _value <<= 1
    if _value & 0x100:
        _value ^= 0x11D
for _power in range(255, 512):
    _EXP[_power] = _EXP[_power - 255]

_encode_tables: dict[int, list[int]] = {}
_syndrome_rows: dict[int, tuple[int, ...]] = {}


def _mul(a: int, b: int) -> int:
    return 0 if a == 0 or b == 0 else _EXP[_LOG[a] + _LOG[b]]


def _inv(a: int) -> int:
    return _EXP[255 - _LOG[a]]


def _generator(n: int) -> list[int]:
    """Monic generator, highest degree first."""
    g = [1]
    for i in range(n):
        out = [0] * (len(g) + 1)
        for j, c in enumerate(g):
            out[j] ^= c
            out[j + 1] ^= _mul(c, _EXP[i])
        g = out
    return g


def _encode_table(n: int) -> list[int]:
    """For each feedback byte c, the n bytes `g[1..n] * c` as one big-endian integer."""
    table = _encode_tables.get(n)
    if table is None:
        g = _generator(n)
        table = [int.from_bytes(bytes(_mul(g[j], c) for j in range(1, n + 1)), "big") for c in range(256)]
        _encode_tables[n] = table
    return table


def _syndrome_row(i: int) -> tuple[int, ...]:
    row = _syndrome_rows.get(i)
    if row is None:
        row = tuple(_mul(a, _EXP[i]) for a in range(256))
        _syndrome_rows[i] = row
    return row


def parity(clear: bytes | bytearray, n: int) -> bytes:
    """The n parity bytes of a clear message of at most `MAX_BLOCK - n` bytes, n from 1 to `MAX_PARITY`."""
    table = _encode_table(n)
    top = 8 * (n - 1)
    mask = (1 << (8 * n)) - 1
    register = table[len(clear)]
    for b in clear:
        register = ((register << 8) & mask) ^ table[b ^ (register >> top)]
    return register.to_bytes(n, "big")


def _syndromes(word: bytes, n: int) -> list[int]:
    out = []
    for i in range(n):
        row = _syndrome_row(i)
        s = len(word) - n
        for b in word:
            s = row[s] ^ b
        out.append(s)
    return out


def _poly_eval(p: list[int], x: int) -> int:
    """`p` lowest degree first."""
    y = 0
    for c in reversed(p):
        y = _mul(y, x) ^ c
    return y


def _locator(synd: list[int], n: int) -> list[int]:
    """Berlekamp-Massey: the error locator, lowest degree first, trimmed."""
    lam, prev = [1], [1]
    length, gap, last = 0, 1, 1
    for r in range(n):
        d = synd[r]
        for i in range(1, length + 1):
            if i < len(lam):
                d ^= _mul(lam[i], synd[r - i])
        if d == 0:
            gap += 1
            continue
        before = lam[:]
        coef = _mul(d, _inv(last))
        need = len(prev) + gap
        if len(lam) < need:
            lam += [0] * (need - len(lam))
        for i, c in enumerate(prev):
            lam[i + gap] ^= _mul(coef, c)
        if 2 * length <= r:
            length, prev, last, gap = r + 1 - length, before, d, 1
        else:
            gap += 1
    while len(lam) > 1 and lam[-1] == 0:
        lam.pop()
    return lam


def repair(received: bytes, n: int, limit: int) -> tuple[bytes, int] | None:
    """The clear bytes and the number of repaired bytes, or `None` when more than `limit` bytes are wrong.
    `received` is `n` to `MAX_BLOCK` bytes, `n` from 1 to `MAX_PARITY`, `limit` from 0 to `n // 2`."""
    size = len(received)
    head = received[: size - n]
    if parity(head, n) == received[size - n :]:
        return bytes(head), 0
    if limit == 0:
        return None
    synd = _syndromes(received, n)
    lam = _locator(synd, n)
    degree = len(lam) - 1
    if degree == 0 or degree > limit:
        return None
    # position p (0 = first byte sent) has locator X = alpha^(size - 1 - p); the unsent length byte sits one place before it
    roots = [p for p in range(size) if _poly_eval(lam, _EXP[(255 - (size - 1 - p)) % 255]) == 0]
    if len(roots) != degree:
        return None
    omega = [0] * n
    for i in range(n):
        for j in range(len(lam)):
            if i + j < n:
                omega[i + j] ^= _mul(synd[i], lam[j])
    derivative = [lam[i] if i % 2 == 1 else 0 for i in range(1, len(lam))]
    word = bytearray(received)
    for p in roots:
        x = _EXP[(size - 1 - p) % 255]
        x_inv = _inv(x)
        den = _poly_eval(derivative, x_inv)
        if den == 0:
            return None
        word[p] ^= _mul(x, _mul(_poly_eval(omega, x_inv), _inv(den)))
    fixed = bytes(word)
    if parity(fixed[: size - n], n) != fixed[size - n :]:
        return None
    return fixed[: size - n], degree
