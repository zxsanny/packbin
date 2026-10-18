"""Encoder of the compact text format (contract `compact-text`): the optimal parse with the contract's tie-break.

A parse is a path through states (mode, capital lock). `f[i][state]` is the fewest bits that finish the text from
character `i`; the walk then takes, at every step, the edge with the smallest first-symbol index whose cost plus
the cost of the rest equals `f`. Costs are integers.
"""

from __future__ import annotations

from operator import add

from packbin._text_model import (
    CAP_AT,
    CAPITALS,
    CODES,
    ESC_AT,
    INF,
    LETTERS,
    LOCK_AT,
    MAX_TEXT_BYTES,
    NUMSET,
    RAW_PREFIX,
    SHARED,
    SHARED_AT,
    SWITCH_AT,
    UPPERS,
)

Pair = tuple[int, int]
# first symbol index, bits, target state (-1: the edge consumes the character), (code, length) pairs written
Edge = tuple[int, int, int, tuple[Pair, ...]]


def _utf8_size(char: str) -> int:
    point = ord(char)
    return 1 if point < 0x80 else 2 if point < 0x800 else 3 if point < 0x10000 else 4


class _Plan:
    """The states of one parse: with the capital lock (8 states) or without it (4 states, lock off). A text with
    no capital letter never gains from the lock: it adds a LOCK symbol and opens no edge, so the optimum, and
    the tie-break among optima, are the same without it."""

    def __init__(self, with_lock: bool) -> None:
        self.states = [(m, k) for m in range(4) for k in ((0, 1) if with_lock else (0,))]
        self.index = {state: i for i, state in enumerate(self.states)}
        self.count = len(self.states)
        self.controls: list[list[Edge]] = []
        for mode, lock in self.states:
            edges = [
                (at, CODES[mode][at][1], self.index[(target, lock)], (CODES[mode][at],))
                for target, at in SWITCH_AT[mode].items()
            ]
            if with_lock and mode != 3:
                at = LOCK_AT[mode]
                edges.append((at, CODES[mode][at][1], self.index[(mode, 1 - lock)], (CODES[mode][at],)))
            edges.sort()
            self.controls.append(edges)
        self.dist = self._distances()
        self._known: dict[str, tuple[tuple[int, ...], list[list[Edge]]]] = {}
        self._unknown: dict[int, tuple[int, ...]] = {}

    def _distances(self) -> tuple[tuple[int, ...], ...]:
        """Cheapest cost of the control edges from one state to another (Floyd-Warshall; 0 to itself)."""
        n = self.count
        dist = [[0 if a == b else INF for b in range(n)] for a in range(n)]
        for a, edges in enumerate(self.controls):
            for _, bits, target, _pairs in edges:
                dist[a][target] = min(dist[a][target], bits)
        for via in range(n):
            for a in range(n):
                for b in range(n):
                    if dist[a][via] + dist[via][b] < dist[a][b]:
                        dist[a][b] = dist[a][via] + dist[via][b]
        return tuple(tuple(row) for row in dist)

    def _emission_edges(self, mode: int, lock: int, char: str) -> list[Edge]:
        """The edges that consume `char` in a state, ESC included, sorted by first symbol."""
        codes = CODES[mode]
        edges: list[Edge] = []
        if mode != 3:
            letters = LETTERS[mode]
            if char in letters:
                i = letters.index(char)
                if UPPERS[mode][i] is None or lock == 0:
                    edges.append((i, codes[i][1], -1, (codes[i],)))
            for i, capital in enumerate(UPPERS[mode]):
                if capital == char:
                    if lock:
                        edges.append((i, codes[i][1], -1, (codes[i],)))
                    else:
                        cap = CAP_AT[mode]
                        edges.append((cap, codes[cap][1] + codes[i][1], -1, (codes[cap], codes[i])))
            if char in SHARED:
                at = SHARED_AT[mode] + SHARED.index(char)
                edges.append((at, codes[at][1], -1, (codes[at],)))
        elif char in NUMSET:
            at = NUMSET.index(char)
            edges.append((at, codes[at][1], -1, (codes[at],)))
        esc = ESC_AT[mode]
        raw = char.encode("utf-8")
        edges.append((esc, codes[esc][1] + 8 * len(raw), -1, (codes[esc], *((b, 8) for b in raw))))
        edges.sort()
        return edges

    def known(self, char: str) -> tuple[tuple[int, ...], list[list[Edge]]]:
        """(cost per state, edges per state) for a character of the alphabets; cached (a bounded set)."""
        got = self._known.get(char)
        if got is None:
            per_state = [self._emission_edges(mode, lock, char) for mode, lock in self.states]
            cost = tuple(min(edge[1] for edge in edges) for edges in per_state)
            walk = [sorted(self.controls[s] + per_state[s]) for s in range(self.count)]
            got = self._known[char] = (cost, walk)
        return got

    def unknown_cost(self, size: int) -> tuple[int, ...]:
        """Cost per state of a character with no symbol: ESC and `size` raw bytes."""
        got = self._unknown.get(size)
        if got is None:
            got = self._unknown[size] = tuple(CODES[mode][ESC_AT[mode]][1] + 8 * size for mode, _ in self.states)
        return got

    def walk_edges(self, state: int, char: str) -> list[Edge]:
        """The edges to try from `state` at `char`, smallest first symbol first (ESC is the largest index)."""
        if char in self._known:
            return self._known[char][1][state]
        mode = self.states[state][0]
        esc = ESC_AT[mode]
        raw = char.encode("utf-8")
        edge = (esc, CODES[mode][esc][1] + 8 * len(raw), -1, (CODES[mode][esc], *((b, 8) for b in raw)))
        return [*self.controls[state], edge]


_PLANS = (_Plan(False), _Plan(True))
_KNOWN_CHARS = frozenset(
    [c for row in LETTERS for c in row] + [c for row in UPPERS for c in row if c] + list(SHARED) + list(NUMSET)
)


def _parse(text: str) -> tuple[int, int, list[Pair]]:
    """(bits of the symbols, start mode, the (code, length) pairs written) of the optimal parse of a text."""
    plan = _PLANS[0 if CAPITALS.isdisjoint(text) else 1]
    dist = plan.dist
    known = plan.known
    unknown_cost = plan.unknown_cost
    size = len(text)
    f: list[tuple[int, ...]] = [()] * (size + 1)
    nxt = f[size] = (0,) * plan.count
    for i in range(size - 1, -1, -1):
        char = text[i]
        if char in _KNOWN_CHARS:
            cost = known(char)[0]
        else:
            cost = unknown_cost(_utf8_size(char))
        here = list(map(add, cost, nxt))
        nxt = f[i] = tuple([min(map(add, row, here)) for row in dist])
    index = plan.index
    start = min(range(4), key=lambda m: (f[0][index[(m, 0)]], m))
    state = index[(start, 0)]
    total = f[0][state]
    pairs: list[Pair] = []
    i = 0
    while i < size:
        want = f[i][state]
        here = f[i]
        after = f[i + 1]
        for _first, bits, target, written in plan.walk_edges(state, text[i]):
            if target >= 0:
                if bits + here[target] == want:
                    pairs.extend(written)
                    state = target
                    break
            elif bits + after[state] == want:
                pairs.extend(written)
                i += 1
                break
        else:
            raise AssertionError("the parse has no optimal edge")
    return total, start, pairs


def _varint(n: int) -> bytes:
    if n < 0x80:
        return bytes((n,))
    if n < 0x4000:
        return bytes((n & 0x7F | 0x80, n >> 7))
    return bytes((n & 0x7F | 0x80, (n >> 7) & 0x7F | 0x80, n >> 14))


# The last string encoded and its field: a `times` or `repeat` round, a list or a dictionary often writes one
# value again and again, and the parse costs a few microseconds per character.
_last: tuple[str, bytes] = ("", b"\0")


def encode_text(text: str, raw: bytes) -> bytes:
    """The field of a string: count then payload. `raw` is its UTF-8 bytes, at most 65,535 of them."""
    global _last
    if not raw:
        return b"\0"
    if len(raw) > MAX_TEXT_BYTES:
        raise ValueError(f"text longer than {MAX_TEXT_BYTES} UTF-8 bytes")
    last = _last
    if last[0] == text:
        return last[1]
    field = _field(text, raw)
    _last = (text, field)
    return field


def _field(text: str, raw: bytes) -> bytes:
    bits, start, pairs = _parse(text)
    size = (6 + bits + 7) >> 3
    if size >= len(raw) + 1:
        return _varint(len(raw) + 1) + bytes((RAW_PREFIX,)) + raw
    pad = 8 * size - 6 - bits
    out = bytearray(_varint(size))
    acc = (pad << 3) | start
    held = 6
    for code, length in pairs:
        acc = (acc << length) | code
        held += length
        if held >= 64:
            whole = held & ~7
            out += (acc >> (held - whole)).to_bytes(whole >> 3, "big")
            held -= whole
            acc &= (1 << held) - 1
    acc <<= pad
    held += pad
    out += acc.to_bytes(held >> 3, "big")
    return bytes(out)
