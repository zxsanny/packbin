from __future__ import annotations

import struct
from collections.abc import Callable, Mapping, Sequence
from typing import Any

from packbin._errors import ShortPacket, TypeMismatch
from packbin._nodes import (
    _Bits,
    _Bytes,
    _Dict,
    _FlagBit,
    _FlagByte,
    _Flags,
    _Group,
    _List,
    _Node,
    _Repeat,
    _Scalar,
    _Sized,
    _U2,
    _Utf8,
    _When,
)

_builtin_bytes = bytes
_builtin_list = list
_builtin_dict = dict


def _utf8_payload(name: str, value: Any) -> bytes:
    if not isinstance(value, str):
        raise TypeError(f"{name}: expected str")
    raw = value.encode("utf-8")
    if len(raw) > 65535:
        raise ValueError(f"{name}: utf-8 length {len(raw)}")
    return raw


def _group_on(values: dict[str, Any], node: _Group) -> bool:
    if _present(values, node.name):
        return True
    for child in node.fields:
        if isinstance(child, (_Scalar, _Bytes, _Utf8, _List, _Dict)) and _present(values, child.name):
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
    if not isinstance(raw, _builtin_list) or len(raw) != count:
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


def _present(values: Mapping[str, Any], name: str) -> bool:
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
    if isinstance(node, (_Scalar, _Bytes, _Utf8, _List, _Dict)):
        return node.name
    if isinstance(node, _FlagBit):
        return _field_name(node.field)
    raise TypeError(f"node has no field name: {type(node)!r}")


def pack_nodes(
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
                    pack_nodes(buf, fields, values, get_value)
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
                pack_nodes(buf, [node.field], values, get_value)
        elif isinstance(node, _When):
            current = values.get(node.condition.field)
            if current == node.condition.value:
                pack_nodes(buf, node.fields, values, get_value)
        elif isinstance(node, _Repeat):
            names = [_field_name(child) for child in node.fields]
            lengths = []
            for name in names:
                val = values.get(name)
                if val is None:
                    lengths.append(0)
                elif isinstance(val, _builtin_list):
                    lengths.append(len(val))
                else:
                    lengths.append(1)
            count = max(lengths) if lengths else 0
            if any(n not in (0, count) for n in lengths):
                raise ValueError("repeat fields must have equal lengths")
            for i in range(count):

                def at(name: str, index: int = i) -> Any:
                    val = values[name]
                    if isinstance(val, _builtin_list):
                        return val[index]
                    return val

                pack_nodes(buf, node.fields, values, at)
        elif isinstance(node, _Utf8):
            raw = _utf8_payload(node.name, take(node.name))
            buf.append(len(raw) & 0xFF)
            buf.append((len(raw) >> 8) & 0xFF)
            buf.extend(raw)
        elif isinstance(node, _List):
            items = take(node.name)
            if not isinstance(items, _builtin_list):
                raise TypeError(f"{node.name}: expected list")
            if len(items) > 65535:
                raise ValueError(f"{node.name}: length {len(items)}")
            buf.append(len(items) & 0xFF)
            buf.append((len(items) >> 8) & 0xFF)
            child_name = _field_name(node.element)
            for item in items:
                pack_nodes(buf, [node.element], {child_name: item})
        elif isinstance(node, _Dict):
            mapping = take(node.name)
            if not isinstance(mapping, _builtin_dict):
                raise TypeError(f"{node.name}: expected dict")
            if len(mapping) > 65535:
                raise ValueError(f"{node.name}: length {len(mapping)}")
            pairs = sorted(mapping.items(), key=lambda kv: kv[0].encode("utf-8"))
            buf.append(len(pairs) & 0xFF)
            buf.append((len(pairs) >> 8) & 0xFF)
            child_name = _field_name(node.element)
            for key, value in pairs:
                raw = _utf8_payload(node.name, key)
                buf.append(len(raw) & 0xFF)
                buf.append((len(raw) >> 8) & 0xFF)
                buf.extend(raw)
                pack_nodes(buf, [node.element], {child_name: value})
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")


def _append_value(out: dict[str, Any], name: str, value: Any, as_list: bool) -> None:
    if as_list:
        out.setdefault(name, []).append(value)
    else:
        out[name] = value


def unpack_nodes(
    data: memoryview,
    offset: int,
    nodes: Sequence[_Node],
    out: dict[str, Any],
    *,
    as_list: bool = False,
    flag_state: dict[int, int] | None = None,
) -> tuple[int, ShortPacket | TypeMismatch | None]:
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
                    offset, err = unpack_nodes(data, offset, fields, out, as_list=as_list, flag_state=flag_state)
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
                offset, err = unpack_nodes(data, offset, [node.field], out, as_list=as_list, flag_state=flag_state)
                if err is not None:
                    return offset, err
        elif isinstance(node, _When):
            if out.get(node.condition.field) == node.condition.value:
                offset, err = unpack_nodes(data, offset, node.fields, out, as_list=as_list, flag_state=flag_state)
                if err is not None:
                    return offset, err
        elif isinstance(node, _Repeat):
            while offset < len(data):
                offset, err = unpack_nodes(
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
        elif isinstance(node, _Utf8):
            left = len(data) - offset
            if left < 2:
                return offset, ShortPacket(field=node.name, needed=2, left=left)
            count = struct.unpack_from("<H", data, offset)[0]
            offset += 2
            left = len(data) - offset
            if left < count:
                return offset, ShortPacket(field=node.name, needed=count, left=left)
            raw = _builtin_bytes(data[offset : offset + count])
            offset += count
            _append_value(out, node.name, raw.decode("utf-8"), as_list)
        elif isinstance(node, _List):
            left = len(data) - offset
            if left < 2:
                return offset, ShortPacket(field=node.name, needed=2, left=left)
            count = struct.unpack_from("<H", data, offset)[0]
            offset += 2
            child_name = _field_name(node.element)
            items: list[Any] = []
            for _ in range(count):
                one: dict[str, Any] = {}
                offset, err = unpack_nodes(data, offset, [node.element], one)
                if err is not None:
                    return offset, err
                items.append(one.get(child_name))
            _append_value(out, node.name, items, as_list)
        elif isinstance(node, _Dict):
            left = len(data) - offset
            if left < 2:
                return offset, ShortPacket(field=node.name, needed=2, left=left)
            count = struct.unpack_from("<H", data, offset)[0]
            offset += 2
            child_name = _field_name(node.element)
            mapping: dict[str, Any] = {}
            for _ in range(count):
                left = len(data) - offset
                if left < 2:
                    return offset, ShortPacket(field=node.name, needed=2, left=left)
                key_len = struct.unpack_from("<H", data, offset)[0]
                offset += 2
                left = len(data) - offset
                if left < key_len:
                    return offset, ShortPacket(field=node.name, needed=key_len, left=left)
                key = _builtin_bytes(data[offset : offset + key_len]).decode("utf-8")
                offset += key_len
                one: dict[str, Any] = {}
                offset, err = unpack_nodes(data, offset, [node.element], one)
                if err is not None:
                    return offset, err
                if key in mapping:
                    return offset, ShortPacket(field=node.name, needed=0, left=0)
                mapping[key] = one.get(child_name)
            _append_value(out, node.name, mapping, as_list)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return offset, None


def bind_names(nodes: Sequence[_Node]) -> list[str]:
    names: list[str] = []
    for node in nodes:
        if isinstance(node, (_Scalar, _Bytes, _Utf8, _List, _Dict, _Sized, _Bits)):
            names.append(node.name)
        elif isinstance(node, _U2):
            names.extend(node.names)
        elif isinstance(node, _Flags):
            for child in node.fields:
                if isinstance(child, _Group):
                    if child.fields:
                        names.extend(bind_names(child.fields))
                    else:
                        names.append(child.name)
                else:
                    names.extend(bind_names([child]))
        elif isinstance(node, (_When, _Repeat, _Group)):
            names.extend(bind_names(node.fields))
        elif isinstance(node, _FlagByte):
            for child in node.bits:
                names.extend(bind_names([child]))
        elif isinstance(node, _FlagBit):
            names.extend(bind_names([node.field]))
    return names
