from __future__ import annotations

import struct
from collections.abc import Callable, Sequence
from typing import Any

from packbin._nodes import (
    _Bits,
    _Bool,
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


def _utf8_payload(label: str, value: Any) -> bytes:
    if not isinstance(value, str):
        raise TypeError(f"{label}: expected str")
    raw = value.encode("utf-8")
    if len(raw) > 65535:
        raise ValueError(f"{label}: utf-8 length {len(raw)}")
    return raw


def _present_value(value: Any) -> bool:
    return value is not None


def _bool_on(value: Any) -> bool:
    return value is True


def _group_on(row: Any, node: _Group) -> bool:
    for child in node.fields:
        if _child_on(row, child):
            return True
    return False


def _child_on(row: Any, child: _Node) -> bool:
    if isinstance(child, _Group):
        return _group_on(row, child)
    if isinstance(child, _Bool):
        return _bool_on(child.get(row))
    if isinstance(child, (_Scalar, _Bytes, _Utf8, _Sized, _Bits, _List, _Dict)):
        return _present_value(child.get(row))
    if isinstance(child, _FlagBit):
        return _child_on(row, child.field)
    return False


def _write_u2(buf: bytearray, slots: Sequence[Any], row: Any, seen: dict[int, Any]) -> None:
    nbytes = (len(slots) + 3) // 4
    raw = bytearray(nbytes)
    for i, slot in enumerate(slots):
        value = slot.get(row)
        seen[slot.field_id] = value
        if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 3:
            raise ValueError(f"{slot.field_id}: expected 2-bit int")
        raw[i // 4] |= value << ((i % 4) * 2)
    buf.extend(raw)


def _write_bits(buf: bytearray, label: str, count: int, raw: Any) -> None:
    if not isinstance(raw, _builtin_list) or len(raw) != count:
        raise ValueError(f"{label}: expected {count} bits")
    nbytes = (count + 7) // 8
    packed = bytearray(nbytes)
    for i, bit in enumerate(raw):
        if bit not in (0, 1):
            raise ValueError(f"{label}: expected 0 or 1")
        packed[i // 8] |= int(bit) << (i % 8)
    buf.extend(packed)


def _require_int(field: _Scalar, value: Any) -> int | float:
    if field.kind in ("f32", "f64"):
        return float(value)
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{field.field_id}: expected int, got {type(value).__name__}")
    if value < field.min_v or value > field.max_v:
        raise OverflowError(f"{field.field_id}: {value} does not fit in {field.kind}")
    return value


def _write_scalar(buf: bytearray, field: _Scalar, value: Any) -> None:
    packed = struct.pack(field.endian_fmt(), _require_int(field, value))
    buf.extend(packed)


def _is_leaf(node: _Node) -> bool:
    return isinstance(node, (_Scalar, _Bytes, _Utf8, _Bool, _Sized, _Bits))


def _pack_element(buf: bytearray, element: _Node, item: Any) -> None:
    if isinstance(element, _List):
        _pack_list_items(buf, element.element, item)
    elif isinstance(element, _Dict):
        _pack_dict_items(buf, element.element, item)
    elif _is_leaf(element):
        pack_nodes(buf, [element], item, {}, lambda _n: item)
    else:
        pack_nodes(buf, [element], item, {})


def _pack_list_items(buf: bytearray, element: _Node, items: Any) -> None:
    if not isinstance(items, _builtin_list):
        raise TypeError("list: expected list")
    if len(items) > 65535:
        raise ValueError(f"list: length {len(items)}")
    buf.append(len(items) & 0xFF)
    buf.append((len(items) >> 8) & 0xFF)
    for item in items:
        _pack_element(buf, element, item)


def _pack_dict_items(buf: bytearray, element: _Node, mapping: Any) -> None:
    if not isinstance(mapping, _builtin_dict):
        raise TypeError("dict: expected dict")
    if len(mapping) > 65535:
        raise ValueError(f"dict: length {len(mapping)}")
    pairs = sorted(mapping.items(), key=lambda kv: kv[0].encode("utf-8"))
    buf.append(len(pairs) & 0xFF)
    buf.append((len(pairs) >> 8) & 0xFF)
    for key, value in pairs:
        raw = _utf8_payload("dict", key)
        buf.append(len(raw) & 0xFF)
        buf.append((len(raw) >> 8) & 0xFF)
        buf.extend(raw)
        _pack_element(buf, element, value)


def pack_nodes(
    buf: bytearray,
    nodes: Sequence[_Node],
    row: Any,
    seen: dict[int, Any] | None = None,
    get_value: Callable[[_Node], Any] | None = None,
) -> None:
    if seen is None:
        seen = {}

    def take(node: _Node) -> Any:
        if get_value is not None:
            return get_value(node)
        return node.get(row)  # type: ignore[attr-defined]

    for node in nodes:
        if isinstance(node, _Scalar):
            value = take(node)
            if not _present_value(value) and get_value is None:
                raise KeyError(f"missing field {node.field_id}")
            seen[node.field_id] = value
            _write_scalar(buf, node, value)
        elif isinstance(node, _Bytes):
            raw = take(node)
            if not _present_value(raw) and get_value is None:
                raise KeyError(f"missing field {node.field_id}")
            seen[node.field_id] = raw
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.field_id}: expected bytes")
            if len(raw) != node.size:
                raise ValueError(f"{node.field_id}: expected {node.size} bytes, got {len(raw)}")
            buf.extend(raw)
        elif isinstance(node, _Bool):
            seen[node.field_id] = take(node)
        elif isinstance(node, _Flags):
            flag = 0
            for i, child in enumerate(node.fields):
                if _child_on(row, child):
                    flag |= 1 << i
            buf.append(flag)
            for i, child in enumerate(node.fields):
                if flag & (1 << i):
                    if isinstance(child, _Bool):
                        seen[child.field_id] = child.get(row)
                    elif isinstance(child, _Group):
                        pack_nodes(buf, child.fields, row, seen, get_value)
                    else:
                        pack_nodes(buf, [child], row, seen, get_value)
        elif isinstance(node, _Sized):
            count = seen.get(node.count)
            if count is None:
                raise RuntimeError(f"{node.field_id}: count {node.count} is missing")
            raw = take(node)
            seen[node.field_id] = raw
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.field_id}: expected bytes")
            if len(raw) != count:
                raise ValueError(f"{node.field_id}: expected {count} bytes, got {len(raw)}")
            buf.extend(raw)
        elif isinstance(node, _U2):
            _write_u2(buf, node.slots, row, seen)
        elif isinstance(node, _Bits):
            count = seen.get(node.count)
            if count is None:
                raise RuntimeError(f"{node.field_id}: count {node.count} is missing")
            value = take(node)
            seen[node.field_id] = value
            _write_bits(buf, str(node.field_id), int(count), value)
        elif isinstance(node, _FlagByte):
            flag = 0
            for i, child in enumerate(node.bits):
                if _child_on(row, child):
                    flag |= 1 << i
            buf.append(flag)
        elif isinstance(node, _FlagBit):
            if _child_on(row, node.field):
                pack_nodes(buf, [node.field], row, seen, get_value)
        elif isinstance(node, _When):
            if seen.get(node.condition.field_id) == node.condition.value:
                pack_nodes(buf, node.fields, row, seen, get_value)
        elif isinstance(node, _Repeat):
            lengths = []
            for child in node.fields:
                val = child.get(row)  # type: ignore[attr-defined]
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

                def at(child: _Node, index: int = i) -> Any:
                    val = child.get(row)  # type: ignore[attr-defined]
                    if isinstance(val, _builtin_list):
                        return val[index]
                    return val

                pack_nodes(buf, node.fields, row, seen, at)
        elif isinstance(node, _Utf8):
            value = take(node)
            seen[node.field_id] = value
            raw = _utf8_payload(str(node.field_id), value)
            buf.append(len(raw) & 0xFF)
            buf.append((len(raw) >> 8) & 0xFF)
            buf.extend(raw)
        elif isinstance(node, _List):
            _pack_list_items(buf, node.element, take(node))
        elif isinstance(node, _Dict):
            _pack_dict_items(buf, node.element, take(node))
        elif isinstance(node, _Group):
            pack_nodes(buf, node.fields, row, seen, get_value)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
