from __future__ import annotations

import copy
from collections.abc import Callable, Mapping
from typing import Any, Generic, TypeVar

from packbin._errors import ShortPacket, TrailingBytes, TypeMismatch, UnpackResult
from packbin._flag_scope import _bind_flag_bits
from packbin._nodes import _Node
from packbin._pack import pack_nodes
from packbin._unpack import DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS, _Budget, unpack_nodes
from packbin._validate import _validate_order, _validate_round_nesting

T = TypeVar("T")
_builtin_bytes = bytes
_builtin_dict = dict


def _checked_limit(name: str, value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError(f"{name} must be a whole number of at least 1, got {value!r}")
    return value


class Scheme(Generic[T]):
    """`max_rounds` is the most rounds one `repeat` or `times` field may start in one unpack, and `max_slots`
    the most entries all the rounds of one unpack may make together (one per name a round can hold), so the
    length of a packet does not set its memory cost."""

    __slots__ = ("_type_number", "_row_type", "_fields", "_max_rounds", "_max_slots")

    DEFAULT_MAX_ROUNDS = DEFAULT_MAX_ROUNDS
    DEFAULT_MAX_SLOTS = DEFAULT_MAX_SLOTS

    def __init__(self, type_number: int, row_type: type[T], *fields: _Node) -> None:
        if isinstance(type_number, bool) or not isinstance(type_number, int) or type_number < 0 or type_number > 255:
            raise ValueError(f"type number must be 0..255, got {type_number!r}")
        _validate_order(fields)
        bound = _bind_flag_bits(fields)
        _validate_round_nesting(bound)
        self._type_number = type_number
        self._row_type = row_type
        self._fields = bound
        self._max_rounds = DEFAULT_MAX_ROUNDS
        self._max_slots = DEFAULT_MAX_SLOTS

    @property
    def max_rounds(self) -> int:
        return self._max_rounds

    @property
    def max_slots(self) -> int:
        return self._max_slots

    def with_limits(
        self, max_rounds: int = DEFAULT_MAX_ROUNDS, max_slots: int = DEFAULT_MAX_SLOTS
    ) -> Scheme[T]:
        """A scheme with these limits and the same fields; this one is unchanged. A limit left out is the
        default, not this scheme's current value."""
        limited = copy.copy(self)
        limited._max_rounds = _checked_limit("max_rounds", max_rounds)
        limited._max_slots = _checked_limit("max_slots", max_slots)
        return limited

    def on(self, handler: Callable[[T], None]) -> _Handler[T]:
        return _Handler(self, handler)


class _Handler(Generic[T]):
    __slots__ = ("scheme", "handler")

    def __init__(self, scheme: Scheme[T], handler: Callable[[T], None]) -> None:
        self.scheme = scheme
        self.handler = handler


def _new_row(row_type: type[T]) -> T:
    if row_type is _builtin_dict:
        return {}  # type: ignore[return-value]
    return row_type()


class BinaryPacker:
    @staticmethod
    def pack(scheme: Scheme[T], row: T | Mapping[str, Any]) -> bytes:
        buf = bytearray()
        buf.append(scheme._type_number)
        pack_nodes(buf, scheme._fields, row)
        return _builtin_bytes(buf)

    @staticmethod
    def unpack(
        data: bytes | bytearray | memoryview,
        *handlers: _Handler[Any],
    ) -> UnpackResult[Any]:
        if not handlers:
            raise TypeError("unpack() missing handlers")
        return BinaryPacker._unpack_dispatch(data, handlers)

    @staticmethod
    def _unpack_fields(scheme: Scheme[T], view: memoryview, offset: int) -> UnpackResult[T]:
        row = _new_row(scheme._row_type)
        budget = _Budget(scheme._max_rounds, scheme._max_slots)
        offset, err = unpack_nodes(view, offset, scheme._fields, row, budget=budget)
        if err is not None:
            return UnpackResult(ok=False, value=None, error=err)
        left = len(view) - offset
        if left > 0:
            return UnpackResult(ok=False, value=None, error=TrailingBytes(left=left))
        return UnpackResult(ok=True, value=row, error=None)

    @staticmethod
    def _unpack_dispatch(
        data: bytes | bytearray | memoryview,
        handlers: tuple[_Handler[Any], ...],
    ) -> UnpackResult[Any]:
        by_type: dict[int, _Handler[Any]] = {}
        for handler in handlers:
            number = handler.scheme._type_number
            if number in by_type:
                raise ValueError(f"duplicate type number {number}")
            by_type[number] = handler
        view = memoryview(data)
        left = len(view)
        if left < 1:
            return UnpackResult(ok=False, value=None, error=ShortPacket(field="", needed=1, left=left))
        actual = int(view[0])
        matched = by_type.get(actual)
        if matched is None:
            return UnpackResult(ok=False, value=None, error=TypeMismatch(expected=-1, actual=actual))
        result = BinaryPacker._unpack_fields(matched.scheme, view, 1)
        if not result.ok or result.value is None:
            return result
        matched.handler(result.value)
        return result
