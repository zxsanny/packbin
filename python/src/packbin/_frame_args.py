"""Argument helpers shared by `FrameSession` and `MacKey`: a wrong Python type is a `TypeError`, a value out of range is
the contract's `BadValue` (the callers decide)."""

from __future__ import annotations

from packbin._frame_types import is_int

BytesLike = bytes | bytearray | memoryview


def snapshot(value: object, name: str) -> bytes:
    """A copy of a bytes-like argument, so one read decides the whole call (the caller's buffer may change or overlap the output)."""
    if not isinstance(value, (bytes, bytearray, memoryview)):
        raise TypeError(f"{name} must be bytes-like, got {type(value).__name__}")
    return bytes(value)


def require_int(value: object, name: str) -> int:
    if not is_int(value):
        raise TypeError(f"{name} must be an int, got {type(value).__name__}")
    return value  # type: ignore[return-value]


def writable(value: object, name: str) -> memoryview:
    """A writable byte view of the caller's output buffer (`bytearray` or a writable `memoryview`)."""
    if not isinstance(value, (bytearray, memoryview)):
        raise TypeError(f"{name} must be a bytearray or a writable memoryview, got {type(value).__name__}")
    view = memoryview(value)
    if view.readonly:
        raise TypeError(f"{name} must be writable")
    return view.cast("B") if view.format != "B" or view.ndim != 1 else view
