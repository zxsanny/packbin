from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any, Generic, TypeVar

from packbin._errors import ShortPacket, TrailingBytes, TypeMismatch, UnpackResult
from packbin._nodes import _Node, _validate_order
from packbin._pack import pack_nodes
from packbin._unpack import unpack_nodes

T = TypeVar("T")
_builtin_bytes = bytes
_builtin_dict = dict


class Scheme(Generic[T]):
    __slots__ = ("_type_number", "_row_type", "_fields")

    def __init__(self, type_number: int, row_type: type[T], *fields: _Node) -> None:
        if isinstance(type_number, bool) or not isinstance(type_number, int) or type_number < 0 or type_number > 255:
            raise ValueError(f"type number must be 0..255, got {type_number!r}")
        _validate_order(fields)
        self._type_number = type_number
        self._row_type = row_type
        self._fields = list(fields)

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
        first: Scheme[T] | bytes | bytearray | memoryview,
        second: bytes | bytearray | memoryview | _Handler[Any] | None = None,
        *rest: _Handler[Any],
    ) -> UnpackResult[Any]:
        if isinstance(first, Scheme):
            if second is None:
                raise TypeError("unpack() missing data")
            if isinstance(second, _Handler):
                raise TypeError("known unpack expects bytes")
            return BinaryPacker._unpack_known(first, second)
        if second is None and not rest:
            raise TypeError("unpack() missing handlers")
        handlers: list[_Handler[Any]] = []
        if second is not None:
            if not isinstance(second, _Handler):
                raise TypeError("unknown unpack expects handlers")
            handlers.append(second)
        handlers.extend(rest)
        return BinaryPacker._unpack_dispatch(first, tuple(handlers))

    @staticmethod
    def _unpack_fields(scheme: Scheme[T], view: memoryview, offset: int) -> UnpackResult[T]:
        row = _new_row(scheme._row_type)
        offset, err = unpack_nodes(view, offset, scheme._fields, row)
        if err is not None:
            return UnpackResult(ok=False, value=None, error=err)
        left = len(view) - offset
        if left > 0:
            return UnpackResult(ok=False, value=None, error=TrailingBytes(left=left))
        return UnpackResult(ok=True, value=row, error=None)

    @staticmethod
    def _unpack_known(scheme: Scheme[T], data: bytes | bytearray | memoryview) -> UnpackResult[T]:
        view = memoryview(data)
        left = len(view)
        if left < 1:
            return UnpackResult(ok=False, value=None, error=ShortPacket(field="", needed=1, left=left))
        actual = int(view[0])
        if actual != scheme._type_number:
            return UnpackResult(ok=False, value=None, error=TypeMismatch(expected=scheme._type_number, actual=actual))
        return BinaryPacker._unpack_fields(scheme, view, 1)

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
