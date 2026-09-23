from __future__ import annotations

import struct
from dataclasses import dataclass
from typing import Any, Callable, Sequence

_builtin_bytes = bytes
__all__ = [
    "ShortPacket",
    "TrailingBytes",
    "UnpackResult",
    "packet",
    "u8",
    "u16",
    "u32",
    "u64",
    "i8",
    "i16",
    "i32",
    "i64",
    "f32",
    "f64",
    "bytes",
    "be",
    "flags",
    "flag_byte",
    "eq",
    "when",
    "repeat",
    "group",
    "sized",
    "u2",
    "bits",
    "pack",
    "unpack",
]


@dataclass(frozen=True, slots=True)
class ShortPacket:
    field: str
    needed: int
    left: int


@dataclass(frozen=True, slots=True)
class TrailingBytes:
    left: int


@dataclass(frozen=True, slots=True)
class UnpackResult:
    ok: bool
    value: dict[str, Any] | None = None
    error: ShortPacket | TrailingBytes | None = None

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
        if self.error is None:
            return None
        return self.error.left


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
class Packet:
    fields: list[_Node]


def packet(fields: Sequence[_Node]) -> Packet:
    return Packet(list(fields))


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
    return _Flags(name=name, fields=list(fields))


def flag_byte(name: str) -> _FlagByte:
    return _FlagByte(name=name, bits=[])


def eq(field: str, value: Any) -> _Eq:
    return _Eq(field=field, value=value)


def when(condition: _Eq, fields: Sequence[_Node]) -> _When:
    return _When(condition=condition, fields=list(fields))


def repeat(fields: Sequence[_Node]) -> _Repeat:
    return _Repeat(fields=list(fields))


def group(name: str, fields: Sequence[_Node]) -> _Group:
    return _Group(name=name, fields=list(fields))


def sized(name: str, count: str) -> _Sized:
    return _Sized(name=name, count=count)


def u2(*names: str) -> _U2:
    if not names:
        raise ValueError("u2 needs at least one name")
    return _U2(names=list(names))


def bits(name: str, count: str) -> _Bits:
    return _Bits(name=name, count=count)


def _group_on(values: dict[str, Any], node: _Group) -> bool:
    if _present(values, node.name):
        return True
    for child in node.fields:
        if isinstance(child, (_Scalar, _Bytes)) and _present(values, child.name):
            return True
    return False


def _write_u2(buf: bytearray, names: Sequence[str], take: Callable[[str], Any]) -> None:
    nbytes = (len(names) + 3) // 4
    raw = bytearray(nbytes)
    for i, name in enumerate(names):
        value = take(name)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 3:
            raise ValueError(f"{name}: expected 2-bit int")
        raw[i // 4] |= value << ((i % 4) * 2)
    buf.extend(raw)


def _read_u2(data: memoryview, offset: int, names: Sequence[str]) -> tuple[list[int], int] | ShortPacket:
    nbytes = (len(names) + 3) // 4
    left = len(data) - offset
    if left < nbytes:
        return ShortPacket(field=names[0], needed=nbytes, left=left)
    out: list[int] = []
    for i in range(len(names)):
        out.append((data[offset + i // 4] >> ((i % 4) * 2)) & 3)
    return out, offset + nbytes


def _write_bits(buf: bytearray, name: str, count: int, raw: Any) -> None:
    if not isinstance(raw, list) or len(raw) != count:
        raise ValueError(f"{name}: expected {count} bits")
    nbytes = (count + 7) // 8
    packed = bytearray(nbytes)
    for i, bit in enumerate(raw):
        if bit not in (0, 1):
            raise ValueError(f"{name}: expected 0 or 1")
        packed[i // 8] |= int(bit) << (i % 8)
    buf.extend(packed)


def _read_bits(data: memoryview, offset: int, name: str, count: int) -> tuple[list[int], int] | ShortPacket:
    nbytes = (count + 7) // 8
    left = len(data) - offset
    if left < nbytes:
        return ShortPacket(field=name, needed=nbytes, left=left)
    out = [((data[offset + i // 8] >> (i % 8)) & 1) for i in range(count)]
    return out, offset + nbytes


def _present(values: dict[str, Any], name: str) -> bool:
    return name in values and values[name] is not None


def _require_int(field: _Scalar, value: Any) -> int | float:
    if field.kind in ("f32", "f64"):
        return float(value)
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{field.name}: expected int, got {type(value).__name__}")
    if value < field.min_v or value > field.max_v:
        raise OverflowError(f"{field.name}: {value} does not fit in {field.kind}")
    return value


def _write_scalar(buf: bytearray, field: _Scalar, value: Any) -> None:
    packed = struct.pack(field.endian_fmt(), _require_int(field, value))
    buf.extend(packed)


def _read_scalar(
    data: memoryview, offset: int, field: _Scalar
) -> tuple[Any, int] | ShortPacket:
    left = len(data) - offset
    if left < field.size:
        return ShortPacket(field=field.name, needed=field.size, left=left)
    value = struct.unpack_from(field.endian_fmt(), data, offset)[0]
    return value, offset + field.size


def _field_name(node: _Node) -> str:
    if isinstance(node, (_Scalar, _Bytes)):
        return node.name
    if isinstance(node, _FlagBit):
        return _field_name(node.field)
    raise TypeError(f"node has no field name: {type(node)!r}")


def _pack_nodes(
    buf: bytearray,
    nodes: Sequence[_Node],
    values: dict[str, Any],
    get_value: Callable[[str], Any] | None = None,
) -> None:
    def take(name: str) -> Any:
        if get_value is not None:
            return get_value(name)
        return values[name]

    for node in nodes:
        if isinstance(node, _Scalar):
            if not _present(values, node.name) and get_value is None:
                raise KeyError(f"missing field {node.name!r}")
            _write_scalar(buf, node, take(node.name))
        elif isinstance(node, _Bytes):
            raw = take(node.name) if get_value is not None or _present(values, node.name) else None
            if raw is None and get_value is None:
                raise KeyError(f"missing field {node.name!r}")
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.name}: expected bytes")
            if len(raw) != node.size:
                raise ValueError(f"{node.name}: expected {node.size} bytes, got {len(raw)}")
            buf.extend(raw)
        elif isinstance(node, _Flags):
            flag = 0
            for i, child in enumerate(node.fields):
                on = _group_on(values, child) if isinstance(child, _Group) else _present(values, _field_name(child))
                if on:
                    flag |= 1 << i
            buf.append(flag)
            for i, child in enumerate(node.fields):
                if flag & (1 << i):
                    fields = child.fields if isinstance(child, _Group) else [child]
                    _pack_nodes(buf, fields, values, get_value)
        elif isinstance(node, _Sized):
            count = take(node.count) if get_value is not None else values[node.count]
            raw = take(node.name)
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.name}: expected bytes")
            if len(raw) != count:
                raise ValueError(f"{node.name}: expected {count} bytes, got {len(raw)}")
            buf.extend(raw)
        elif isinstance(node, _U2):
            _write_u2(buf, node.names, take)
        elif isinstance(node, _Bits):
            count = take(node.count) if get_value is not None else values[node.count]
            _write_bits(buf, node.name, int(count), take(node.name))
        elif isinstance(node, _FlagByte):
            flag = 0
            for i, child in enumerate(node.bits):
                name = _field_name(child)
                if _present(values, name):
                    flag |= 1 << i
            buf.append(flag)
        elif isinstance(node, _FlagBit):
            name = _field_name(node.field)
            if _present(values, name):
                _pack_nodes(buf, [node.field], values, get_value)
        elif isinstance(node, _When):
            current = values.get(node.condition.field)
            if current == node.condition.value:
                _pack_nodes(buf, node.fields, values, get_value)
        elif isinstance(node, _Repeat):
            names = [_field_name(child) for child in node.fields]
            lengths = []
            for name in names:
                val = values.get(name)
                if val is None:
                    lengths.append(0)
                elif isinstance(val, list):
                    lengths.append(len(val))
                else:
                    lengths.append(1)
            count = max(lengths) if lengths else 0
            if any(n not in (0, count) for n in lengths):
                raise ValueError("repeat fields must have equal lengths")
            for i in range(count):

                def at(name: str, index: int = i) -> Any:
                    val = values[name]
                    if isinstance(val, list):
                        return val[index]
                    return val

                _pack_nodes(buf, node.fields, values, at)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")


def pack(target: Packet, values: dict[str, Any] | None = None) -> bytes:
    if values is None:
        values = {}
    buf = bytearray()
    _pack_nodes(buf, target.fields, values)
    return _builtin_bytes(buf)


def _append_value(out: dict[str, Any], name: str, value: Any, as_list: bool) -> None:
    if as_list:
        out.setdefault(name, []).append(value)
    else:
        out[name] = value


def _unpack_nodes(
    data: memoryview,
    offset: int,
    nodes: Sequence[_Node],
    out: dict[str, Any],
    *,
    as_list: bool = False,
    flag_state: dict[int, int] | None = None,
) -> tuple[int, ShortPacket | None]:
    if flag_state is None:
        flag_state = {}

    for node in nodes:
        if isinstance(node, _Scalar):
            got = _read_scalar(data, offset, node)
            if isinstance(got, ShortPacket):
                return offset, got
            value, offset = got
            _append_value(out, node.name, value, as_list)
        elif isinstance(node, _Bytes):
            left = len(data) - offset
            if left < node.size:
                return offset, ShortPacket(field=node.name, needed=node.size, left=left)
            raw = _builtin_bytes(data[offset : offset + node.size])
            offset += node.size
            _append_value(out, node.name, raw, as_list)
        elif isinstance(node, _Flags):
            left = len(data) - offset
            if left < 1:
                return offset, ShortPacket(field=node.name, needed=1, left=left)
            flag = data[offset]
            offset += 1
            out[node.name] = flag
            for i, child in enumerate(node.fields):
                if flag & (1 << i):
                    fields = child.fields if isinstance(child, _Group) else [child]
                    if isinstance(child, _Group) and not child.fields:
                        out[child.name] = True
                    offset, err = _unpack_nodes(data, offset, fields, out, as_list=as_list, flag_state=flag_state)
                    if err is not None:
                        return offset, err
        elif isinstance(node, _FlagByte):
            left = len(data) - offset
            if left < 1:
                return offset, ShortPacket(field=node.name, needed=1, left=left)
            flag = data[offset]
            offset += 1
            out[node.name] = flag
            flag_state[id(node)] = flag
        elif isinstance(node, _FlagBit):
            flag = flag_state.get(id(node.owner))
            if flag is None:
                raise RuntimeError(f"flag bit for {node.owner.name!r} before flag byte")
            if flag & (1 << node.index):
                offset, err = _unpack_nodes(data, offset, [node.field], out, as_list=as_list, flag_state=flag_state)
                if err is not None:
                    return offset, err
        elif isinstance(node, _When):
            if out.get(node.condition.field) == node.condition.value:
                offset, err = _unpack_nodes(data, offset, node.fields, out, as_list=as_list, flag_state=flag_state)
                if err is not None:
                    return offset, err
        elif isinstance(node, _Repeat):
            while offset < len(data):
                offset, err = _unpack_nodes(
                    data, offset, node.fields, out, as_list=True, flag_state=flag_state
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _Sized):
            count = out.get(node.count)
            if not isinstance(count, int):
                raise RuntimeError(f"{node.name}: count {node.count!r} is missing")
            left = len(data) - offset
            if left < count:
                return offset, ShortPacket(field=node.name, needed=count, left=left)
            raw = _builtin_bytes(data[offset : offset + count])
            offset += count
            _append_value(out, node.name, raw, as_list)
        elif isinstance(node, _U2):
            got = _read_u2(data, offset, node.names)
            if isinstance(got, ShortPacket):
                return offset, got
            values_u2, offset = got
            for name, value in zip(node.names, values_u2, strict=True):
                _append_value(out, name, value, as_list)
        elif isinstance(node, _Bits):
            count = out.get(node.count)
            if not isinstance(count, int):
                raise RuntimeError(f"{node.name}: count {node.count!r} is missing")
            got_bits = _read_bits(data, offset, node.name, count)
            if isinstance(got_bits, ShortPacket):
                return offset, got_bits
            bits_value, offset = got_bits
            _append_value(out, node.name, bits_value, as_list)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return offset, None


def unpack(target: Packet, data: bytes | bytearray | memoryview) -> UnpackResult:
    view = memoryview(data)
    out: dict[str, Any] = {}
    offset, err = _unpack_nodes(view, 0, target.fields, out)
    if err is not None:
        return UnpackResult(ok=False, value=None, error=err)
    left = len(view) - offset
    if left > 0:
        return UnpackResult(ok=False, value=None, error=TrailingBytes(left=left))
    return UnpackResult(ok=True, value=out, error=None)
