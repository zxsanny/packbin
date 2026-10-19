"""Decoder of the compact text format (contract `compact-text`). Work and memory are bounded by the payload."""

from __future__ import annotations

from packbin._text_model import (
    KIND_CAP,
    KIND_CHAR,
    KIND_LOCK,
    KIND_SWITCH,
    MAX_TEXT_BYTES,
    RAW_PREFIX,
    decode_mode,
)


# Length of a UTF-8 sequence by the top five bits of its lead byte; 0 for a continuation byte or 0xF8 and up.
_UTF8_LENGTH = (1,) * 16 + (0,) * 8 + (2,) * 4 + (3,) * 2 + (4, 0)


class TextRefusal(Exception):
    """A refused field. `kind` is the contract's name (`short`, `varint`, `mode`, `pad`, `code`, `cap`, `esc`,
    `utf8`, `raw`, `length`); for `short`, `needed` bytes were wanted and `left` were there."""

    def __init__(self, kind: str, needed: int = 0, left: int = 0) -> None:
        super().__init__(kind)
        self.kind = kind
        self.needed = needed
        self.left = left


def decode_text(data: bytes | bytearray | memoryview, offset: int) -> tuple[str, int]:
    """The string whose count starts at `offset`, and the offset after it; raises `TextRefusal`."""
    view = memoryview(data)
    size = len(view)
    count = 0
    for k in range(3):
        if offset + k >= size:
            raise TextRefusal("short", 1, 0)
        byte = view[offset + k]
        count |= (byte & 0x7F) << (7 * k)
        if not byte & 0x80:
            if k and not byte:
                raise TextRefusal("varint")
            break
    else:
        raise TextRefusal("varint")
    start = offset + k + 1
    if count == 0:
        return "", start
    if start + count > size:
        raise TextRefusal("short", count, size - start)
    end = start + count
    first = view[start]
    mode = (first >> 2) & 7
    if mode == 4:
        return _raw(first, view[start + 1 : end]), end
    payload = bytes(view[start:end])
    if mode > 4:
        raise TextRefusal("mode")
    pad = first >> 5
    left = 8 * count - pad - 6
    if left < 0:
        raise TextRefusal("pad")
    if payload[-1] & ((1 << pad) - 1):
        raise TextRefusal("pad")
    return _symbols(payload, mode, left), end


def _raw(first: int, body: memoryview) -> str:
    # The limit is checked before the copy and the decode, so a long count costs no memory.
    if first != RAW_PREFIX:
        raise TextRefusal("raw")
    if len(body) > MAX_TEXT_BYTES:
        raise TextRefusal("length")
    try:
        return bytes(body).decode("utf-8")
    except UnicodeDecodeError:
        raise TextRefusal("utf8") from None


def _symbols(payload: bytes, mode: int, left: int) -> str:
    """Read symbols until `left` bits are used. The accumulator holds `held` unread bits; the payload is padded
    with zero bytes so that a 16-bit window never runs past it (a code that needs more than `left` is refused)."""
    padded = payload + b"\0\0\0\0"
    at = 1
    acc = payload[0] & 3
    held = 2
    tab = decode_mode(mode)
    window, kind, low, up, sizes, arg = tab.window, tab.kind, tab.low, tab.up, tab.size, tab.arg
    lock = False
    cap = False
    total = 0
    out: list[str] = []
    while left > 0:
        while held < 16:
            acc = (acc << 8) | padded[at]
            at += 1
            held += 8
        entry = window[(acc >> (held - 16)) & 0xFFFF]
        length = entry & 31
        if length > left:
            raise TextRefusal("code")
        index = entry >> 5
        held -= length
        acc &= (1 << held) - 1
        left -= length
        k = kind[index]
        if k == KIND_CHAR:
            capital = up[index]
            if cap:
                if capital is None:
                    raise TextRefusal("cap")
                char = capital
                cap = False
            elif lock and capital is not None:
                char = capital
            else:
                char = low[index]
            total += sizes[index]
        elif k == KIND_SWITCH:
            if cap:
                raise TextRefusal("cap")
            mode = arg[index]
            tab = decode_mode(mode)
            window, kind, low, up, sizes, arg = tab.window, tab.kind, tab.low, tab.up, tab.size, tab.arg
            continue
        elif k == KIND_CAP:
            if lock or cap:
                raise TextRefusal("cap")
            cap = True
            continue
        elif k == KIND_LOCK:
            if cap:
                raise TextRefusal("cap")
            lock = not lock
            continue
        else:
            if cap:
                raise TextRefusal("cap")
            raw = bytearray()
            want = 1
            while len(raw) < want:
                if left < 8:
                    raise TextRefusal("esc")
                while held < 8:
                    acc = (acc << 8) | padded[at]
                    at += 1
                    held += 8
                raw.append((acc >> (held - 8)) & 0xFF)
                held -= 8
                acc &= (1 << held) - 1
                left -= 8
                if want == 1 and len(raw) == 1:
                    lead = raw[0]
                    want = _UTF8_LENGTH[lead >> 3]
                    if want == 0:
                        raise TextRefusal("utf8")
            try:
                char = raw.decode("utf-8")
            except UnicodeDecodeError:
                raise TextRefusal("utf8") from None
            total += len(raw)
        if total > MAX_TEXT_BYTES:
            raise TextRefusal("length")
        out.append(char)
    if cap:
        raise TextRefusal("cap")
    return "".join(out)
