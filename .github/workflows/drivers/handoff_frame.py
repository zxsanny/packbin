"""The frame commands of handoff.py (AZ-3338; contract pack-session 3.0.0, frame mode).

  frame-batch <file>   one line per line of the file: seal, open, mac, verify
"""
from __future__ import annotations

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


def _kind(result: object) -> str:
    return KINDS.get(type(result), "error")


def _seal(words: list[str]) -> str:
    key, epoch, d, tag_len = _bytes(words[0]), int(words[1]), int(words[2]), int(words[3])
    msg_id, kind, ad, clear, plain = _bytes(words[4]), int(words[5]), _bytes(words[6]), _bytes(words[7]), _bytes(words[8])
    session = FrameSession.load(key, epoch, FrameConfig(tag_len, FrameDirections(1 << (d - 1))))
    if isinstance(session, BadValue):
        return "BadValue"
    buf = bytearray(300)
    result = session.seal(d, MsgContext(msg_id, kind), ad, clear, plain, buf)
    if not isinstance(result, int):
        return _kind(result)
    return _hex(buf[:result])


def _open(words: list[str]) -> str:
    key, epoch, d, tag_len = _bytes(words[0]), int(words[1]), int(words[2]), int(words[3])
    msg_id, kind, ad, clear_len, body = _bytes(words[4]), int(words[5]), _bytes(words[6]), int(words[7]), _bytes(words[8])
    session = FrameSession.load(key, epoch, FrameConfig(tag_len, FrameDirections(1 << (d - 1))))
    if isinstance(session, BadValue):
        return "BadValue"
    buf = bytearray(300)
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
    raise ValueError("frame line: %s" % words[0])


def run_frame(cmd: str, argv: list[str]) -> int:
    if cmd == "frame-batch" and len(argv) == 2:
        with open(argv[1], encoding="utf-8") as lines:
            for line in lines:
                if line.strip():
                    print(_line(line.split()))
        return 0
    return 2
