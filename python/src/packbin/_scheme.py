from __future__ import annotations

import copy
from collections.abc import Callable, Mapping
from typing import Any, Generic, Optional, TypeVar

from packbin import _ecc
from packbin._errors import ShortPacket, TooLong, TrailingBytes, TypeMismatch, Uncorrectable, UnpackResult
from packbin._flag_scope import _bind_flag_bits
from packbin._nodes import _Node
from packbin._pack import pack_nodes
from packbin._pack_limits import DEFAULT_MAX_BYTES, _PackBudget
from packbin._unpack import DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS, _Budget, unpack_nodes
from packbin._validate import (
    _shown,
    _validate_element_accessors,
    _validate_names,
    _validate_order,
    _validate_round_bodies,
    _validate_round_nesting,
)

T = TypeVar("T")
_builtin_bytes = bytes
_builtin_dict = dict


def _checked_limit(name: str, value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError(f"{name} must be a whole number of at least 1, got {_shown(value)}")
    return value


def _checked_parity(value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > _ecc.MAX_PARITY:
        raise ValueError(
            f"parity must be a whole number of 0 to {_ecc.MAX_PARITY}, got n = {_shown(value)} (limit {_ecc.MAX_PARITY})"
        )
    return value


def _checked_correction(limit: Any, parity: int) -> int:
    if isinstance(limit, bool) or not isinstance(limit, int) or limit < 0 or limit > parity // 2:
        raise ValueError(
            f"limit must be a whole number of 0 to {parity // 2} for {parity} parity bytes, got {_shown(limit)}"
        )
    return limit


class Scheme(Generic[T]):
    """`max_rounds` is the most rounds one `repeat` or `times` field may start in one unpack, and `max_slots`
    the most entries all the rounds of one unpack may make together (one per name a round can hold), so the
    length of a packet does not set its memory cost. Pack keeps the same two limits and refuses a packet longer
    than `max_bytes`, type byte included. `parity` is the number of parity bytes (0 to 32) pack appends to the
    message, so unpack can detect a corrupted message and repair up to half that many wrong bytes."""

    __slots__ = ("_type_number", "_row_type", "_fields", "_max_rounds", "_max_slots", "_max_bytes", "_parity")

    DEFAULT_MAX_ROUNDS = DEFAULT_MAX_ROUNDS
    DEFAULT_MAX_SLOTS = DEFAULT_MAX_SLOTS
    DEFAULT_MAX_BYTES = DEFAULT_MAX_BYTES

    def __init__(self, type_number: int, row_type: type[T], *fields: _Node) -> None:
        if isinstance(type_number, bool) or not isinstance(type_number, int) or type_number < 0 or type_number > 255:
            raise ValueError(f"type number must be 0..255, got {_shown(type_number)}")
        _validate_order(fields)
        bound = _bind_flag_bits(fields)
        _validate_round_nesting(bound)
        _validate_round_bodies(bound)
        _validate_names(bound)
        _validate_element_accessors(bound)
        self._type_number = type_number
        self._row_type = row_type
        self._fields = bound
        self._max_rounds = DEFAULT_MAX_ROUNDS
        self._max_slots = DEFAULT_MAX_SLOTS
        self._max_bytes = DEFAULT_MAX_BYTES
        self._parity = 0

    @property
    def max_rounds(self) -> int:
        return self._max_rounds

    @property
    def max_slots(self) -> int:
        return self._max_slots

    @property
    def max_bytes(self) -> int:
        return self._max_bytes

    @property
    def parity(self) -> int:
        return self._parity

    def with_limits(
        self,
        max_rounds: int = DEFAULT_MAX_ROUNDS,
        max_slots: int = DEFAULT_MAX_SLOTS,
        max_bytes: int = DEFAULT_MAX_BYTES,
        parity: Optional[int] = None,
    ) -> Scheme[T]:
        """A scheme with these limits and the same fields; this one is unchanged. A limit left out is the
        default, not this scheme's current value; `parity` left out keeps this scheme's count, so setting a limit
        never drops protection."""
        limited = copy.copy(self)
        limited._max_rounds = _checked_limit("max_rounds", max_rounds)
        limited._max_slots = _checked_limit("max_slots", max_slots)
        limited._max_bytes = _checked_limit("max_bytes", max_bytes)
        limited._parity = self._parity if parity is None else _checked_parity(parity)
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
    def _pack_clear(scheme: Scheme[T], row: T | Mapping[str, Any]) -> bytes:
        buf = bytearray()
        buf.append(scheme._type_number)
        budget = _PackBudget(scheme._max_rounds, scheme._max_slots, scheme._max_bytes)
        pack_nodes(buf, scheme._fields, row, budget=budget)
        room = _ecc.MAX_BLOCK - scheme._parity
        if scheme._parity and len(buf) > room:
            raise ValueError(
                f"the clear message is {len(buf)} bytes, above the limit of {room} bytes "
                f"({_ecc.MAX_BLOCK} minus {scheme._parity} parity bytes)"
            )
        return _builtin_bytes(buf)

    @staticmethod
    def pack(scheme: Scheme[T], row: T | Mapping[str, Any]) -> bytes:
        clear = BinaryPacker._pack_clear(scheme, row)
        if scheme._parity == 0:
            return clear
        return clear + _ecc.parity(clear, scheme._parity)

    @staticmethod
    def unpack(
        data: bytes | bytearray | memoryview,
        *handlers: _Handler[Any],
        limit: int = 0,
    ) -> UnpackResult[Any]:
        """`limit` is how many wrong bytes of a protected message may be repaired (0 to half its parity bytes);
        0 only detects."""
        if not handlers:
            raise TypeError("unpack() missing handlers")
        by_type, parity = BinaryPacker._dispatch_table(handlers)
        _checked_correction(limit, parity)
        return BinaryPacker._receive(data, by_type, parity, limit)

    @staticmethod
    def _unpack_fields(scheme: Scheme[T], view: memoryview, offset: int, repaired: int = 0) -> UnpackResult[T]:
        row = _new_row(scheme._row_type)
        budget = _Budget(scheme._max_rounds, scheme._max_slots)
        offset, err = unpack_nodes(view, offset, scheme._fields, row, budget=budget)
        if err is not None:
            return UnpackResult(ok=False, value=None, error=err)
        left = len(view) - offset
        if left > 0:
            return UnpackResult(ok=False, value=None, error=TrailingBytes(left=left))
        return UnpackResult(ok=True, value=row, error=None, repaired=repaired)

    @staticmethod
    def _dispatch_table(handlers: tuple[_Handler[Any], ...]) -> tuple[dict[int, _Handler[Any]], int]:
        """The handlers by type number and their one parity count; a repeated number, then a mix of counts, is
        refused (the order of every package)."""
        by_type: dict[int, _Handler[Any]] = {}
        for handler in handlers:
            number = handler.scheme._type_number
            if number in by_type:
                raise ValueError(f"duplicate type number {number}")
            by_type[number] = handler
        first = handlers[0].scheme
        for handler in handlers:
            if handler.scheme._parity != first._parity:
                raise ValueError(
                    f"one unpack needs one parity count, got {first._parity} and {handler.scheme._parity} "
                    f"(type numbers {first._type_number} and {handler.scheme._type_number})"
                )
        return by_type, first._parity

    @staticmethod
    def _receive(
        data: bytes | bytearray | memoryview,
        by_type: dict[int, _Handler[Any]],
        parity: int,
        limit: int,
        unpad: Callable[[bytes], bytes] | None = None,
    ) -> UnpackResult[Any]:
        """Repair a protected message (`unpad` removes a session's pad from the repaired bytes), then dispatch."""
        view = memoryview(data)
        repaired = 0
        if parity:
            size = view.nbytes
            if size > _ecc.MAX_BLOCK:
                return UnpackResult(ok=False, value=None, error=TooLong(length=size, limit=_ecc.MAX_BLOCK))
            if size < parity:
                return UnpackResult(ok=False, value=None, error=ShortPacket(field="parity", needed=parity, left=size))
            fixed = _ecc.repair(view.tobytes(), parity, limit)
            if fixed is None:
                return UnpackResult(ok=False, value=None, error=Uncorrectable())
            clear, repaired = fixed
            view = memoryview(unpad(clear) if unpad else clear)
        elif unpad:
            view = memoryview(unpad(view.tobytes()))
        left = len(view)
        if left < 1:
            return UnpackResult(ok=False, value=None, error=ShortPacket(field="", needed=1, left=left))
        actual = int(view[0])
        matched = by_type.get(actual)
        if matched is None:
            return UnpackResult(ok=False, value=None, error=TypeMismatch(expected=-1, actual=actual))
        result = BinaryPacker._unpack_fields(matched.scheme, view, 1, repaired)
        if not result.ok or result.value is None:
            return result
        matched.handler(result.value)
        return result
