from __future__ import annotations

from packbin._frame_types import Freshness

_MAX_COUNTER = (1 << 64) - 1


def _check_u64(value: int, name: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{name} must be an int, got {type(value).__name__}")
    if not 0 <= value <= _MAX_COUNTER:
        raise ValueError(f"{name} must be 0 to {_MAX_COUNTER}, got {value}")


class ReplayWindow:
    """The replay window of frame mode: the highest counter a sender's frames reached (`top`) and which of the 64
    counters up to it were committed (`bits`: bit i set means counter `top - i` was committed; 0 is an empty window).

    The caller owns one per sender and passes it, with the message's counter, to `FrameSession.open`. Not thread safe.

    The counter must come from bytes the tag covers (for example the `msg_id` or the associated data), never from an
    unauthenticated field of the wire: it is an argument of open and not part of the tag.

    `ReplayWindow(top, bits)` restores a stored window. `bits` 0 is empty whatever `top` is: a caller validates stored state
    (bit 0 set when the bits are not 0). A counter, `top` or `bits` outside 0 to 2**64 - 1 is a `ValueError`.
    """

    SIZE = 64
    __slots__ = ("_top", "_bits")

    def __init__(self, top: int = 0, bits: int = 0) -> None:
        _check_u64(top, "top")
        _check_u64(bits, "bits")
        self._top = top
        self._bits = bits

    @property
    def top(self) -> int:
        return self._top

    @property
    def bits(self) -> int:
        return self._bits

    def check(self, counter: int) -> Freshness:
        """What the window says about `counter`. Never changes the state."""
        _check_u64(counter, "counter")
        if self._bits == 0 or counter > self._top:
            return Freshness.FRESH
        behind = self._top - counter
        if behind >= self.SIZE:
            return Freshness.TOO_OLD
        return Freshness.DUPLICATE if (self._bits >> behind) & 1 else Freshness.FRESH

    def commit(self, counter: int) -> None:
        """Records `counter`. Open calls this only after a frame opened; a counter 64 or more behind the highest is ignored."""
        _check_u64(counter, "counter")
        if self._bits == 0:
            self._top = counter
            self._bits = 1
        elif counter > self._top:
            shift = counter - self._top
            self._bits = ((self._bits << shift) & _MAX_COUNTER if shift < self.SIZE else 0) | 1
            self._top = counter
        else:
            behind = self._top - counter
            if behind < self.SIZE:
                self._bits |= 1 << behind

    def __repr__(self) -> str:
        return f"ReplayWindow(top={self._top}, bits={self._bits:#x})"
