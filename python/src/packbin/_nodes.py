from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass
from typing import Any


Get = Callable[[Any], Any]
Set = Callable[[Any, Any], None]
_builtin_list = list


class _Node:
    pass


@dataclass(slots=True)
class _Scalar(_Node):
    field_id: int
    get: Get
    set: Set
    kind: str
    size: int
    fmt_le: str
    fmt_be: str
    signed: bool
    min_v: int | float
    max_v: int | float
    big_endian: bool = False

    def endian_fmt(self) -> str:
        return self.fmt_be if self.big_endian else self.fmt_le


@dataclass(slots=True)
class _Bytes(_Node):
    field_id: int
    get: Get
    set: Set
    size: int


@dataclass(slots=True)
class _Bool(_Node):
    field_id: int
    get: Get
    set: Set


@dataclass(slots=True)
class _FlagByte(_Node):
    bits: list[_Node]

    def bit(self, field: _Node) -> _FlagBit:
        index = len(self.bits)
        if index >= 8:
            raise ValueError("flags already has 8 bits")
        self.bits.append(field)
        return _FlagBit(self, field, index)


@dataclass(slots=True)
class _FlagBit(_Node):
    owner: _FlagByte
    field: _Node
    index: int


@dataclass(slots=True)
class _Flags(_Node):
    fields: list[_Node]


@dataclass(slots=True)
class _Eq:
    field_id: int
    value: Any


@dataclass(slots=True)
class _When(_Node):
    condition: _Eq
    fields: list[_Node]


@dataclass(slots=True)
class _Repeat(_Node):
    fields: list[_Node]


@dataclass(slots=True)
class _Group(_Node):
    fields: list[_Node]


@dataclass(slots=True)
class _Sized(_Node):
    field_id: int
    get: Get
    set: Set
    count: int


@dataclass(slots=True)
class _U2Slot(_Node):
    field_id: int
    get: Get
    set: Set


@dataclass(slots=True)
class _U2(_Node):
    slots: list[_U2Slot]


@dataclass(slots=True)
class _Bits(_Node):
    field_id: int
    get: Get
    set: Set
    count: int


@dataclass(slots=True)
class _Utf8(_Node):
    field_id: int
    get: Get
    set: Set


@dataclass(slots=True)
class _List(_Node):
    get: Get
    set: Set
    element: _Node


@dataclass(slots=True)
class _Dict(_Node):
    get: Get
    set: Set
    element: _Node


def _scalar(
    field_id: int,
    get: Get,
    set: Set,
    kind: str,
    size: int,
    fmt: str,
    signed: bool,
    min_v: int | float,
    max_v: int | float,
) -> _Scalar:
    return _Scalar(
        field_id=field_id,
        get=get,
        set=set,
        kind=kind,
        size=size,
        fmt_le="<" + fmt,
        fmt_be=">" + fmt,
        signed=signed,
        min_v=min_v,
        max_v=max_v,
    )


def u8(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "u8", 1, "B", False, 0, 0xFF)


def u16(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "u16", 2, "H", False, 0, 0xFFFF)


def u32(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "u32", 4, "I", False, 0, 0xFFFFFFFF)


def u64(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "u64", 8, "Q", False, 0, 0xFFFFFFFFFFFFFFFF)


def i8(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "i8", 1, "b", True, -0x80, 0x7F)


def i16(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "i16", 2, "h", True, -0x8000, 0x7FFF)


def i32(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "i32", 4, "i", True, -0x80000000, 0x7FFFFFFF)


def i64(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "i64", 8, "q", True, -0x8000000000000000, 0x7FFFFFFFFFFFFFFF)


def f32(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "f32", 4, "f", True, float("-inf"), float("inf"))


def f64(field_id: int, get: Get, set: Set) -> _Scalar:
    return _scalar(field_id, get, set, "f64", 8, "d", True, float("-inf"), float("inf"))


def bool(field_id: int, get: Get, set: Set) -> _Bool:  # noqa: A001
    return _Bool(field_id=field_id, get=get, set=set)


def bytes(field_id: int, get: Get, set: Set, n: int) -> _Bytes:  # noqa: A001
    if n < 0:
        raise ValueError("bytes length must be >= 0")
    return _Bytes(field_id=field_id, get=get, set=set, size=n)


def be(field: _Scalar) -> _Scalar:
    if not isinstance(field, _Scalar):
        raise TypeError("be() expects a numeric field")
    return _Scalar(
        field_id=field.field_id,
        get=field.get,
        set=field.set,
        kind=field.kind,
        size=field.size,
        fmt_le=field.fmt_le,
        fmt_be=field.fmt_be,
        signed=field.signed,
        min_v=field.min_v,
        max_v=field.max_v,
        big_endian=True,
    )


def flags(*fields: _Node) -> _Flags:
    return _Flags(fields=_builtin_list(fields))


def flag_byte() -> _FlagByte:
    return _FlagByte(bits=[])


def eq(field_id: int, value: Any) -> _Eq:
    return _Eq(field_id=field_id, value=value)


def when(condition: _Eq, *fields: _Node) -> _When:
    return _When(condition=condition, fields=_builtin_list(fields))


def repeat(*fields: _Node) -> _Repeat:
    return _Repeat(fields=_builtin_list(fields))


def group(*fields: _Node) -> _Group:
    return _Group(fields=_builtin_list(fields))


def sized(field_id: int, get: Get, set: Set, count: int) -> _Sized:
    return _Sized(field_id=field_id, get=get, set=set, count=count)


def u2(*slots: _U2Slot | tuple[int, Get, Set]) -> _U2:
    if not slots:
        raise ValueError("u2 needs at least one slot")
    out: list[_U2Slot] = []
    for slot in slots:
        if isinstance(slot, _U2Slot):
            out.append(slot)
        else:
            field_id, get, set = slot
            out.append(_U2Slot(field_id=field_id, get=get, set=set))
    return _U2(slots=out)


def bits(field_id: int, get: Get, set: Set, count: int) -> _Bits:
    return _Bits(field_id=field_id, get=get, set=set, count=count)


def utf8(field_id: int, get: Get, set: Set) -> _Utf8:
    return _Utf8(field_id=field_id, get=get, set=set)


def list(get: Get, set: Set, element: _Node) -> _List:  # noqa: A001
    if isinstance(element, _Repeat):
        raise ValueError("repeat is not a list element")
    return _List(get=get, set=set, element=element)


def dict(get: Get, set: Set, element: _Node) -> _Dict:  # noqa: A001
    if isinstance(element, _Repeat):
        raise ValueError("repeat is not a dictionary element")
    return _Dict(get=get, set=set, element=element)


def _validate_order(nodes: Sequence[_Node], next_id: int = 0) -> int:
    for node in nodes:
        if isinstance(node, (_Scalar, _Bytes, _Bool, _Utf8, _Sized, _Bits)):
            if node.field_id != next_id:
                raise ValueError(f"field id {node.field_id} is not the next order {next_id}")
            next_id += 1
        elif isinstance(node, _U2Slot):
            if node.field_id != next_id:
                raise ValueError(f"field id {node.field_id} is not the next order {next_id}")
            next_id += 1
        elif isinstance(node, _U2):
            next_id = _validate_order(node.slots, next_id)
        elif isinstance(node, _Flags):
            next_id = _validate_order(node.fields, next_id)
        elif isinstance(node, (_When, _Repeat, _Group)):
            next_id = _validate_order(node.fields, next_id)
        elif isinstance(node, _FlagByte):
            next_id = _validate_order(node.bits, next_id)
        elif isinstance(node, _FlagBit):
            next_id = _validate_order([node.field], next_id)
        elif isinstance(node, (_List, _Dict)):
            _validate_order([node.element], 0)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return next_id
