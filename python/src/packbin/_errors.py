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
