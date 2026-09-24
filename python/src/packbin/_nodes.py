from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Sequence


_builtin_list = list


class _Node:
    pass


@dataclass(slots=True)
class _Scalar(_Node):
    name: str
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
    name: str
    size: int


@dataclass(slots=True)
class _FlagByte(_Node):
    name: str
    bits: list[_Node]

    def bit(self, field: _Node) -> _FlagBit:
        index = len(self.bits)
        if index >= 8:
            raise ValueError(f"flags {self.name!r} already has 8 bits")
        self.bits.append(field)
        return _FlagBit(self, field, index)


@dataclass(slots=True)
class _FlagBit(_Node):
    owner: _FlagByte
    field: _Node
    index: int


@dataclass(slots=True)
class _Flags(_Node):
    name: str
    fields: list[_Node]


@dataclass(slots=True)
class _Eq:
    field: str
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
    name: str
    fields: list[_Node]


@dataclass(slots=True)
class _Sized(_Node):
    name: str
    count: str


@dataclass(slots=True)
class _U2(_Node):
    names: list[str]


@dataclass(slots=True)
class _Bits(_Node):
    name: str
    count: str


@dataclass(slots=True)
class _Utf8(_Node):
    name: str


@dataclass(slots=True)
class _List(_Node):
    name: str
    element: _Node


@dataclass(slots=True)
class _Dict(_Node):
    name: str
    element: _Node


def _scalar(
    name: str,
    kind: str,
    size: int,
    fmt: str,
    signed: bool,
    min_v: int | float,
    max_v: int | float,
) -> _Scalar:
    return _Scalar(
        name=name,
        kind=kind,
        size=size,
        fmt_le="<" + fmt,
        fmt_be=">" + fmt,
        signed=signed,
        min_v=min_v,
        max_v=max_v,
    )


def u8(name: str) -> _Scalar:
    return _scalar(name, "u8", 1, "B", False, 0, 0xFF)


def u16(name: str) -> _Scalar:
    return _scalar(name, "u16", 2, "H", False, 0, 0xFFFF)


def u32(name: str) -> _Scalar:
    return _scalar(name, "u32", 4, "I", False, 0, 0xFFFFFFFF)


def u64(name: str) -> _Scalar:
    return _scalar(name, "u64", 8, "Q", False, 0, 0xFFFFFFFFFFFFFFFF)


def i8(name: str) -> _Scalar:
    return _scalar(name, "i8", 1, "b", True, -0x80, 0x7F)


def i16(name: str) -> _Scalar:
    return _scalar(name, "i16", 2, "h", True, -0x8000, 0x7FFF)


def i32(name: str) -> _Scalar:
    return _scalar(name, "i32", 4, "i", True, -0x80000000, 0x7FFFFFFF)


def i64(name: str) -> _Scalar:
    return _scalar(name, "i64", 8, "q", True, -0x8000000000000000, 0x7FFFFFFFFFFFFFFF)


def f32(name: str) -> _Scalar:
    return _scalar(name, "f32", 4, "f", True, float("-inf"), float("inf"))


def f64(name: str) -> _Scalar:
    return _scalar(name, "f64", 8, "d", True, float("-inf"), float("inf"))


def bytes(name: str, n: int) -> _Bytes:  # noqa: A001 — schema helper name
    if n < 0:
        raise ValueError("bytes length must be >= 0")
    return _Bytes(name=name, size=n)


def be(field: _Scalar) -> _Scalar:
    if not isinstance(field, _Scalar):
        raise TypeError("be() expects a numeric field")
    return _Scalar(
        name=field.name,
        kind=field.kind,
        size=field.size,
        fmt_le=field.fmt_le,
        fmt_be=field.fmt_be,
        signed=field.signed,
        min_v=field.min_v,
        max_v=field.max_v,
        big_endian=True,
    )


def flags(name: str, fields: Sequence[_Node]) -> _Flags:
    return _Flags(name=name, fields=_builtin_list(fields))


def flag_byte(name: str) -> _FlagByte:
    return _FlagByte(name=name, bits=[])


def eq(field: str, value: Any) -> _Eq:
    return _Eq(field=field, value=value)


def when(condition: _Eq, fields: Sequence[_Node]) -> _When:
    return _When(condition=condition, fields=_builtin_list(fields))


def repeat(fields: Sequence[_Node]) -> _Repeat:
    return _Repeat(fields=_builtin_list(fields))


def group(name: str, fields: Sequence[_Node]) -> _Group:
    return _Group(name=name, fields=_builtin_list(fields))


def sized(name: str, count: str) -> _Sized:
    return _Sized(name=name, count=count)


def u2(*names: str) -> _U2:
    if not names:
        raise ValueError("u2 needs at least one name")
    return _U2(names=_builtin_list(names))


def bits(name: str, count: str) -> _Bits:
    return _Bits(name=name, count=count)


def utf8(name: str) -> _Utf8:
    return _Utf8(name=name)


def list(name: str, element: _Node) -> _List:
    if isinstance(element, _Repeat):
        raise ValueError("repeat is not a list element")
    return _List(name=name, element=element)


def dict(name: str, element: _Node) -> _Dict:
    if isinstance(element, _Repeat):
        raise ValueError("repeat is not a dictionary element")
    return _Dict(name=name, element=element)
