"""The compact text format (contract `compact-text` 1.0.0): symbol layout, canonical codes, decoding tables.

The constants come from `_text_tables.py`, which is generated from `fixtures/text/tables.json` and never edited.
Mode numbers: 0 Ukrainian, 1 Russian, 2 English, 3 number, 4 raw UTF-8.
"""

from __future__ import annotations

from packbin import _text_tables as T

MAX_TEXT_BYTES = 65535
RAW_PREFIX = 0x10
MAX_CODE_LEN = 16
INF = 1 << 30

KIND_CHAR = 0
KIND_SWITCH = 1
KIND_CAP = 2
KIND_LOCK = 3
KIND_ESC = 4

LETTERS: tuple[tuple[str, ...], ...] = tuple(tuple(map(chr, t)) for t in (T.UA, T.RU, T.EN))
UPPERS: tuple[tuple[str | None, ...], ...] = tuple(
    tuple(chr(c) if c else None for c in t) for t in (T.UA_UPPER, T.RU_UPPER, T.EN_UPPER)
)
SHARED: tuple[str, ...] = tuple(map(chr, T.SHARED))
NUMSET: tuple[str, ...] = tuple(map(chr, T.NUMSET))
LENGTHS: tuple[tuple[int, ...], ...] = (T.LENGTHS_UA, T.LENGTHS_RU, T.LENGTHS_EN, T.LENGTHS_NUM)
CAPITALS: frozenset[str] = frozenset(c for row in UPPERS for c in row if c is not None)


def _layout(mode: int) -> tuple[int, int, int, int, dict[int, int]]:
    """(first shared index, cap index, lock index, esc index, {target mode: switch index}) of a mode's table."""
    if mode == 3:
        return 0, -1, -1, len(NUMSET) + 3, {t: len(NUMSET) + t for t in range(3)}
    base = len(LETTERS[mode]) + len(SHARED)
    switches = {t: base + k for k, t in enumerate(t for t in range(4) if t != mode)}
    return len(LETTERS[mode]), base + 3, base + 4, base + 5, switches


SHARED_AT = tuple(_layout(m)[0] for m in range(4))
CAP_AT = tuple(_layout(m)[1] for m in range(4))
LOCK_AT = tuple(_layout(m)[2] for m in range(4))
ESC_AT = tuple(_layout(m)[3] for m in range(4))
SWITCH_AT = tuple(_layout(m)[4] for m in range(4))


def canonical_codes(lengths: tuple[int, ...]) -> tuple[tuple[int, int], ...]:
    """(code, length) per symbol index: sorted by (length, index), the first code all zero, then plus 1 shifted."""
    if max(lengths) > MAX_CODE_LEN or sum(1 << (MAX_CODE_LEN - n) for n in lengths) != 1 << MAX_CODE_LEN:
        raise ValueError("a code table is not a complete code of length 16 or less")
    codes: list[tuple[int, int]] = [(0, 0)] * len(lengths)
    code = 0
    prev = 0
    for index in sorted(range(len(lengths)), key=lambda i: (lengths[i], i)):
        code <<= lengths[index] - prev
        codes[index] = (code, lengths[index])
        code += 1
        prev = lengths[index]
    return tuple(codes)


for _mode in range(4):
    if len(LENGTHS[_mode]) != ESC_AT[_mode] + 1:
        raise ValueError(f"table {_mode} has {len(LENGTHS[_mode])} lengths, the layout needs {ESC_AT[_mode] + 1}")

CODES: tuple[tuple[tuple[int, int], ...], ...] = tuple(canonical_codes(n) for n in LENGTHS)


class DecodeMode:
    """What the decoder needs of one mode: a 16-bit window table and one row per symbol index.

    `window[bits]` is `index * 32 + length` for the code that starts the 16 bits `bits`; the code is complete, so
    every pattern has one. `kind[index]`: 0 a character (`low`, its capital `up` or None, its UTF-8 size `size`),
    1 a switch to mode `arg`, 2 CAP, 3 LOCK, 4 ESC."""

    __slots__ = ("window", "kind", "low", "up", "size", "arg")

    def __init__(self, mode: int) -> None:
        count = len(CODES[mode])
        self.kind = [KIND_CHAR] * count
        self.low: list[str] = [""] * count
        self.up: list[str | None] = [None] * count
        self.size = [0] * count
        self.arg = [0] * count
        if mode == 3:
            for i, ch in enumerate(NUMSET):
                self.low[i] = ch
        else:
            for i, ch in enumerate(LETTERS[mode]):
                self.low[i] = ch
                self.up[i] = UPPERS[mode][i]
            for i, ch in enumerate(SHARED):
                self.low[SHARED_AT[mode] + i] = ch
            self.kind[CAP_AT[mode]] = KIND_CAP
            self.kind[LOCK_AT[mode]] = KIND_LOCK
        for target, index in SWITCH_AT[mode].items():
            self.kind[index] = KIND_SWITCH
            self.arg[index] = target
        self.kind[ESC_AT[mode]] = KIND_ESC
        for i, ch in enumerate(self.low):
            self.size[i] = len(ch.encode("utf-8"))
        window = [0] * (1 << MAX_CODE_LEN)
        for index, (code, length) in enumerate(CODES[mode]):
            first = code << (MAX_CODE_LEN - length)
            span = 1 << (MAX_CODE_LEN - length)
            window[first : first + span] = [index * 32 + length] * span
        self.window = window


_DECODE: list[DecodeMode | None] = [None, None, None, None]


def decode_mode(mode: int) -> DecodeMode:
    """The decoding tables of a mode, built on first use."""
    got = _DECODE[mode]
    if got is None:
        got = _DECODE[mode] = DecodeMode(mode)
    return got
