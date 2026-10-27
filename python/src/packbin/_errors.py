from __future__ import annotations

from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")


@dataclass(frozen=True, slots=True)
class ShortPacket:
    field: str
    needed: int
    left: int


@dataclass(frozen=True, slots=True)
class TrailingBytes:
    left: int


@dataclass(frozen=True, slots=True)
class TypeMismatch:
    expected: int
    actual: int


@dataclass(frozen=True, slots=True)
class Uncorrectable:
    """A protected message with more wrong bytes than the correction limit allows; it names no field."""


@dataclass(frozen=True, slots=True)
class TooLong:
    """A protected message of `length` bytes, above the `limit` of one message."""

    length: int
    limit: int


@dataclass(frozen=True, slots=True)
class BadValue:
    """A configuration or argument is out of range (epoch above 0xFFFFFF, a direction not loaded, a `kind` above 15, a
    label or tag length that is not allowed, a call on a closed session)."""

    reason: str


@dataclass(frozen=True, slots=True)
class BufferFull:
    """The caller's output buffer is shorter than the `needed` bytes the call writes."""

    needed: int


@dataclass(frozen=True, slots=True)
class TagMismatch:
    """The tag does not match with the current key, nor with the previous key when one is loaded. Nothing was decrypted."""


@dataclass(frozen=True, slots=True)
class Duplicate:
    """The replay window has already committed this counter. No tag was computed."""


@dataclass(frozen=True, slots=True)
class TooOld:
    """The counter is 64 or more behind the highest counter the replay window committed. No tag was computed."""


@dataclass(frozen=True, slots=True)
class UnpackResult(Generic[T]):
    """`repaired` is the number of wrong bytes a protected scheme repaired before it read the row."""

    ok: bool
    value: T | None = None
    error: ShortPacket | TrailingBytes | TypeMismatch | Uncorrectable | TooLong | None = None
    repaired: int = 0

    @property
    def field(self) -> str | None:
        if isinstance(self.error, ShortPacket):
            return self.error.field
        return None

    @property
    def needed(self) -> int | None:
        if isinstance(self.error, ShortPacket):
            return self.error.needed
        return None

    @property
    def left(self) -> int | None:
        if isinstance(self.error, (ShortPacket, TrailingBytes)):
            return self.error.left
        return None
