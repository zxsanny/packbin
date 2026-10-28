"""The frame commands of handoff.py (AZ-3338; contract pack-session 3.0.0, frame mode).

  frame-batch <file>   one line per line of the file: seal, open, mac, verify
"""
from __future__ import annotations

import sys

from packbin import (
    BadValue,
    BufferFull,
    FrameConfig,
    FrameDirections,
    FrameOpened,
    FrameSession,
    MacKey,
    MsgContext,
    ShortPacket,
    TagMismatch,
    TooLong,
)


def _bytes(token: str) -> bytes:
    return b"" if token == "-" else bytes.fromhex(token)


def _hex(data: bytes | bytearray) -> str:
    return bytes(data).hex() if len(data) else "-"


KINDS = {BadValue: "BadValue", TooLong: "TooLong", BufferFull: "BufferFull",
         ShortPacket: "ShortPacket", TagMismatch: "TagMismatch"}


def _directions(words: list[str]) -> tuple[FrameDirections, int]:
    """The optional trailing fields of a seal or open line: the directions loaded and the output buffer size."""
    digits, size = (words[9], int(words[10])) if len(words) > 10 else ("123", 300)
    if not digits or set(digits) - set("123"):
        raise ValueError("bad dirs: %s" % digits)
    return FrameDirections(sum(1 << (int(digit) - 1) for digit in digits)), size


def _kind(result: object) -> str:
    return KINDS.get(type(result), "error")


def _seal(words: list[str]) -> str:
    key, epoch, d, tag_len = _bytes(words[0]), int(words[1]), int(words[2]), int(words[3])
    msg_id, kind, ad, clear, plain = _bytes(words[4]), int(words[5]), _bytes(words[6]), _bytes(words[7]), _bytes(words[8])
    directions, size = _directions(words)
    session = FrameSession.load(key, epoch, FrameConfig(tag_len, directions))
    if isinstance(session, BadValue):
        return "BadValue"
    buf = bytearray(size)
    result = session.seal(d, MsgContext(msg_id, kind), ad, clear, plain, buf)
    if not isinstance(result, int):
        return _kind(result)
    return _hex(buf[:result])


def _open(words: list[str]) -> str:
    key, epoch, d, tag_len = _bytes(words[0]), int(words[1]), int(words[2]), int(words[3])
    msg_id, kind, ad, clear_len, body = _bytes(words[4]), int(words[5]), _bytes(words[6]), int(words[7]), _bytes(words[8])
    directions, size = _directions(words)
    session = FrameSession.load(key, epoch, FrameConfig(tag_len, directions))
    if isinstance(session, BadValue):
        return "BadValue"
    buf = bytearray(size)
    result = session.open(d, MsgContext(msg_id, kind), ad, body, clear_len, buf)
    if isinstance(result, FrameOpened):
        return _hex(buf[:result.plain_length])
    return _kind(result)


def _mac(words: list[str]) -> str:
    key, epoch, label, n, message = _bytes(words[0]), int(words[1]), _bytes(words[2]), int(words[3]), _bytes(words[4])
    mac = MacKey.derive(key, epoch, label)
    if isinstance(mac, BadValue):
        return "BadValue"
    tag = mac.tag([message], n)
    return _kind(tag) if isinstance(tag, BadValue) else _hex(tag)


def _verify(words: list[str]) -> str:
    key, epoch, label, n, message, tag = _bytes(words[0]), int(words[1]), _bytes(words[2]), int(words[3]), _bytes(words[4]), _bytes(words[5])
    mac = MacKey.derive(key, epoch, label)
    if isinstance(mac, BadValue):
        return "BadValue"
    return "valid" if mac.verify([message], tag) else "invalid"


def _line(words: list[str]) -> str:
    if words[0] == "seal":
        return _seal(words[1:])
    if words[0] == "open":
        return _open(words[1:])
    if words[0] == "mac":
        return _mac(words[1:])
    if words[0] == "verify":
        return _verify(words[1:])
    if words[0] in ("open-skip", "verify-skip"):
        return "skip"
    raise ValueError("unknown word %s" % words[0])


def run_frame(cmd: str, argv: list[str]) -> int:
    if cmd == "frame-batch" and len(argv) == 2:
        with open(argv[1], encoding="utf-8") as lines:
            for number, line in enumerate(lines, 1):
                if line.strip():
                    try:
                        print(_line(line.split()))
                    except (ValueError, IndexError) as x:
                        print("frame line %d: %s" % (number, x), file=sys.stderr)
                        return 1
        return 0
    return 2
