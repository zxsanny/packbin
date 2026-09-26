from __future__ import annotations

import struct
from collections.abc import Sequence
from typing import Any

from packbin._errors import ShortPacket, TypeMismatch
from packbin._nodes import (
    _Bits,
    _Packed,
    _Times,
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


def _read_u2(data: memoryview, offset: int, count: int, label: str) -> tuple[list[int], int] | ShortPacket:
    nbytes = (count + 3) // 4
    left = len(data) - offset
    if left < nbytes:
        return ShortPacket(field=label, needed=nbytes, left=left)
    out: list[int] = []
    for i in range(count):
        out.append((data[offset + i // 4] >> ((i % 4) * 2)) & 3)
    return out, offset + nbytes


def _read_bits(data: memoryview, offset: int, label: str, count: int) -> tuple[list[int], int] | ShortPacket:
    return _read_packed(data, offset, label, 1, count)


def _read_packed(
    data: memoryview, offset: int, label: str, width: int, count: int
) -> tuple[list[int], int] | ShortPacket:
    nbytes = (count * width + 7) // 8
    left = len(data) - offset
    if left < nbytes:
        return ShortPacket(field=label, needed=nbytes, left=left)
    per = 8 if width == 1 else 4
    shift = 1 if width == 1 else 2
    mask = 1 if width == 1 else 3
    out = [((data[offset + i // per] >> ((i % per) * shift)) & mask) for i in range(count)]
    return out, offset + nbytes


def _read_scalar(
    data: memoryview, offset: int, field: _Scalar
) -> tuple[Any, int] | ShortPacket:
    left = len(data) - offset
    if left < field.size:
        return ShortPacket(field=str(field.field_id), needed=field.size, left=left)
    value = struct.unpack_from(field.endian_fmt(), data, offset)[0]
    return value, offset + field.size


def _is_leaf(node: _Node) -> bool:
    return isinstance(node, (_Scalar, _Bytes, _Utf8, _Bool, _Sized, _Bits, _Packed))


def _append(row: Any, node: Any, value: Any, as_list: bool) -> None:
    if as_list:
        cur = node.get(row)
        if cur is None:
            node.set(row, [value])
        elif isinstance(cur, _builtin_list):
            cur.append(value)
        else:
            node.set(row, [cur, value])
    else:
        node.set(row, value)


def _unpack_leaf(
    data: memoryview, offset: int, node: _Node, seen: dict[int, Any]
) -> tuple[Any, int, ShortPacket | TypeMismatch | None]:
    if isinstance(node, _Scalar):
        got = _read_scalar(data, offset, node)
        if isinstance(got, ShortPacket):
            return None, offset, got
        value, offset = got
        seen[node.field_id] = value
        return value, offset, None
    if isinstance(node, _Bytes):
        left = len(data) - offset
        if left < node.size:
            return None, offset, ShortPacket(field=str(node.field_id), needed=node.size, left=left)
        raw = _builtin_bytes(data[offset : offset + node.size])
        offset += node.size
        seen[node.field_id] = raw
        return raw, offset, None
    if isinstance(node, _Utf8):
        left = len(data) - offset
        if left < 2:
            return None, offset, ShortPacket(field=str(node.field_id), needed=2, left=left)
        count = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        left = len(data) - offset
        if left < count:
            return None, offset, ShortPacket(field=str(node.field_id), needed=count, left=left)
        raw = _builtin_bytes(data[offset : offset + count])
        offset += count
        value = raw.decode("utf-8")
        seen[node.field_id] = value
        return value, offset, None
    if isinstance(node, _Bool):
        return True, offset, None
    raise TypeError(f"not a leaf: {type(node)!r}")


def _unpack_element(
    data: memoryview, offset: int, element: _Node
) -> tuple[Any, int, ShortPacket | TypeMismatch | None]:
    if isinstance(element, _List):
        return _unpack_list_items(data, offset, element.element)
    if isinstance(element, _Dict):
        return _unpack_dict_items(data, offset, element.element)
    if _is_leaf(element):
        return _unpack_leaf(data, offset, element, {})
    child_row: dict[str, Any] = {}
    offset, err = unpack_nodes(data, offset, [element], child_row)
    if err is not None:
        return None, offset, err
    return child_row, offset, None


def _unpack_list_items(
    data: memoryview, offset: int, element: _Node
) -> tuple[list[Any], int, ShortPacket | TypeMismatch | None]:
    left = len(data) - offset
    if left < 2:
        return [], offset, ShortPacket(field="", needed=2, left=left)
    count = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    items: list[Any] = []
    for _ in range(count):
        value, offset, err = _unpack_element(data, offset, element)
        if err is not None:
            return items, offset, err
        items.append(value)
    return items, offset, None


def _unpack_dict_items(
    data: memoryview, offset: int, element: _Node
) -> tuple[dict[str, Any], int, ShortPacket | TypeMismatch | None]:
    left = len(data) - offset
    if left < 2:
        return {}, offset, ShortPacket(field="", needed=2, left=left)
    count = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    mapping: dict[str, Any] = {}
    for _ in range(count):
        left = len(data) - offset
        if left < 2:
            return mapping, offset, ShortPacket(field="", needed=2, left=left)
        key_len = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        left = len(data) - offset
        if left < key_len:
            return mapping, offset, ShortPacket(field="", needed=key_len, left=left)
        key = _builtin_bytes(data[offset : offset + key_len]).decode("utf-8")
        offset += key_len
        value, offset, err = _unpack_element(data, offset, element)
        if err is not None:
            return mapping, offset, err
        if key in mapping:
            return mapping, offset, ShortPacket(field="", needed=0, left=0)
        mapping[key] = value
    return mapping, offset, None


def unpack_nodes(
    data: memoryview,
    offset: int,
    nodes: Sequence[_Node],
    row: Any,
    seen: dict[int, Any] | None = None,
    *,
    as_list: bool = False,
    flag_state: dict[int, int] | None = None,
) -> tuple[int, ShortPacket | TypeMismatch | None]:
    if seen is None:
        seen = {}
    if flag_state is None:
        flag_state = {}

    for node in nodes:
        if isinstance(node, _Scalar):
            got = _read_scalar(data, offset, node)
            if isinstance(got, ShortPacket):
                return offset, got
            value, offset = got
            seen[node.field_id] = value
            _append(row, node, value, as_list)
        elif isinstance(node, _Bytes):
            left = len(data) - offset
            if left < node.size:
                return offset, ShortPacket(field=str(node.field_id), needed=node.size, left=left)
            raw = _builtin_bytes(data[offset : offset + node.size])
            offset += node.size
            seen[node.field_id] = raw
            _append(row, node, raw, as_list)
        elif isinstance(node, _Bool):
            pass
        elif isinstance(node, _Flags):
            left = len(data) - offset
            if left < 1:
                return offset, ShortPacket(field="", needed=1, left=left)
            flag = data[offset]
            offset += 1
            for i, child in enumerate(node.fields):
                if flag & (1 << i):
                    if isinstance(child, _Bool):
                        seen[child.field_id] = True
                        _append(row, child, True, as_list)
                    elif isinstance(child, _Group):
                        offset, err = unpack_nodes(
                            data, offset, child.fields, row, seen, as_list=as_list, flag_state=flag_state
                        )
                        if err is not None:
                            return offset, err
                    else:
                        offset, err = unpack_nodes(
                            data, offset, [child], row, seen, as_list=as_list, flag_state=flag_state
                        )
                        if err is not None:
                            return offset, err
        elif isinstance(node, _FlagByte):
            left = len(data) - offset
            if left < 1:
                return offset, ShortPacket(field="", needed=1, left=left)
            flag = data[offset]
            offset += 1
            flag_state[id(node)] = flag
        elif isinstance(node, _FlagBit):
            flag = flag_state.get(id(node.owner))
            if flag is None:
                raise RuntimeError("flag bit before flag byte")
            if flag & (1 << node.index):
                offset, err = unpack_nodes(
                    data, offset, [node.field], row, seen, as_list=as_list, flag_state=flag_state
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _When):
            if seen.get(node.condition.field_id) == node.condition.value:
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, as_list=as_list, flag_state=flag_state
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _Repeat):
            while offset < len(data):
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, as_list=True, flag_state=flag_state
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _Sized):
            count = seen.get(node.count)
            if not isinstance(count, int):
                raise RuntimeError(f"{node.field_id}: count {node.count} is missing")
            left = len(data) - offset
            if left < count:
                return offset, ShortPacket(field=str(node.field_id), needed=count, left=left)
            raw = _builtin_bytes(data[offset : offset + count])
            offset += count
            seen[node.field_id] = raw
            _append(row, node, raw, as_list)
        elif isinstance(node, _U2):
            label = str(node.slots[0].field_id) if node.slots else "0"
            got = _read_u2(data, offset, len(node.slots), label)
            if isinstance(got, ShortPacket):
                return offset, got
            values_u2, offset = got
            for slot, value in zip(node.slots, values_u2, strict=True):
                seen[slot.field_id] = value
                _append(row, slot, value, as_list)
        elif isinstance(node, _Bits):
            count = seen.get(node.count)
            if not isinstance(count, int):
                raise RuntimeError(f"{node.field_id}: count {node.count} is missing")
            got_bits = _read_bits(data, offset, str(node.field_id), count)
            if isinstance(got_bits, ShortPacket):
                return offset, got_bits
            bits_value, offset = got_bits
            seen[node.field_id] = bits_value
            _append(row, node, bits_value, as_list)
        elif isinstance(node, _Packed):
            label = str(node.field_id)
            raw_count = seen.get(node.count)
            if isinstance(raw_count, bool) or not isinstance(raw_count, int):
                raise RuntimeError(f"{label}: count is missing")
            item_count = raw_count + node.bias
            got_packed = _read_packed(data, offset, label, node.width, item_count)
            if isinstance(got_packed, ShortPacket):
                return offset, got_packed
            packed_value, offset = got_packed
            seen[node.field_id] = packed_value
            _append(row, node, packed_value, as_list)
        elif isinstance(node, _Times):
            raw_count = seen.get(node.count)
            if isinstance(raw_count, bool) or not isinstance(raw_count, int):
                raise RuntimeError("times: count is missing")
            for _ in range(raw_count):
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, as_list=True, flag_state=flag_state
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _Utf8):
            left = len(data) - offset
            if left < 2:
                return offset, ShortPacket(field=str(node.field_id), needed=2, left=left)
            count = struct.unpack_from("<H", data, offset)[0]
            offset += 2
            left = len(data) - offset
            if left < count:
                return offset, ShortPacket(field=str(node.field_id), needed=count, left=left)
            raw = _builtin_bytes(data[offset : offset + count])
            offset += count
            value = raw.decode("utf-8")
            seen[node.field_id] = value
            _append(row, node, value, as_list)
        elif isinstance(node, _List):
            items, offset, err = _unpack_list_items(data, offset, node.element)
            if err is not None:
                return offset, err
            _append(row, node, items, as_list)
        elif isinstance(node, _Dict):
            mapping, offset, err = _unpack_dict_items(data, offset, node.element)
            if err is not None:
                return offset, err
            _append(row, node, mapping, as_list)
        elif isinstance(node, _Group):
            offset, err = unpack_nodes(
                data, offset, node.fields, row, seen, as_list=as_list, flag_state=flag_state
            )
            if err is not None:
                return offset, err
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return offset, None
