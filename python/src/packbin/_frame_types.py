"""The value types of frame mode (`_docs/02_document/contracts/library/pack-session.md` 3.0.0): directions, slots,
the configuration, the per-message inputs and the result of an open. The names are the same in every package."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, IntEnum, IntFlag


class FrameDirection(IntEnum):
    """The direction of a frame: the nonce and the keys depend on it."""

    UP = 1
    DOWN = 2
    GROUP = 3


class FrameDirections(IntFlag):
    """The directions a frame session loads keys for: `FrameDirections.UP | FrameDirections.DOWN`."""

    NONE = 0
    UP = 1
    DOWN = 2
    GROUP = 4
    ALL = 7


class FrameSlot(Enum):
    """Which loaded key opened a frame."""

    CURRENT = "current"
    PREVIOUS = "previous"


class Freshness(Enum):
    """What a replay window says about a counter."""

    FRESH = "Fresh"
    DUPLICATE = "Duplicate"
    TOO_OLD = "TooOld"


@dataclass(frozen=True, slots=True)
class FrameConfig:
    """What a frame session is loaded with besides the key. A `tag_len` other than 4, 8 or 16 makes load give `BadValue`."""

    tag_len: int
    directions: FrameDirections


@dataclass(frozen=True, slots=True)
class FrameOpened:
    """What `FrameSession.open` reports for a frame that opened."""

    slot: FrameSlot
    clear_length: int
    plain_length: int


def is_int(value: object) -> bool:
    """An int that is not a bool."""
    return isinstance(value, int) and not isinstance(value, bool)


@dataclass(frozen=True, slots=True)
class MsgContext:
    """What the caller supplies per message: the 8-byte `msg_id` and the 4-bit `kind` (0 to 15).

    **For one (key, epoch, direction), a `msg_id` is never sealed twice with different contents.** Reuse breaks the
    confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys and nonces. meshbell builds
    the id as source (2 bytes), id field (2 bytes) and creation wave (4 bytes), so it is unique by construction.

    `msg_id` is copied to `bytes` when the value is made. One that is not 8 bytes long, or a `kind` outside 0 to 15, is
    refused by seal and open as `BadValue`; a `msg_id` that is not bytes-like or a `kind` that is not an int is a `TypeError`.
    """

    msg_id: bytes
    kind: int

    def __post_init__(self) -> None:
        if not isinstance(self.msg_id, (bytes, bytearray, memoryview)):
            raise TypeError(f"msg_id must be bytes-like, got {type(self.msg_id).__name__}")
        if not is_int(self.kind):
            raise TypeError(f"kind must be an int, got {type(self.kind).__name__}")
        object.__setattr__(self, "msg_id", bytes(self.msg_id))
