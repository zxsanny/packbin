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

DEFAULT_MAX_ROUNDS = 65_535
DEFAULT_MAX_SLOTS = 4_194_304


class _Budget:
    """What one unpack call may still spend on `repeat` and `times` rounds. `slots` counts the entries every
    round of the call has made so far, shared by every field and by list and dict elements, like `seen`.
    A round makes one entry per name its body holds, and the first round of a run also pays eight more per
    name for the list that holds the run's entries, so a short run in each of many elements costs what it takes."""

    __slots__ = ("max_rounds", "max_slots", "slots")

    LIST_SLOTS = 8

    def __init__(self, max_rounds: int = DEFAULT_MAX_ROUNDS, max_slots: int = DEFAULT_MAX_SLOTS) -> None:
        self.max_rounds = max_rounds
        self.max_slots = max_slots
        self.slots = 0

    def refuses(self, started: int, width: int) -> bool:
        """Called as a round starts: `started` is the rounds this field has begun, `width` the names of the body."""
        cost = width * (1 + self.LIST_SLOTS) if started == 0 else width
        if started >= self.max_rounds or self.slots + cost > self.max_slots:
            return True
        self.slots += cost
        return False


def _bad_value(data: memoryview, offset: int, label: str) -> ShortPacket:
    return ShortPacket(field=label, needed=0, left=len(data) - offset)


def _read_utf8(data: memoryview, offset: int, label: str) -> tuple[str, int] | ShortPacket:
    left = len(data) - offset
    if left < 2:
        return ShortPacket(field=label, needed=2, left=left)
    count = struct.unpack_from("<H", data, offset)[0]
    body = offset + 2
    left = len(data) - body
    if left < count:
        return ShortPacket(field=label, needed=count, left=left)
    try:
        text = _builtin_bytes(data[body : body + count]).decode("utf-8")
    except UnicodeDecodeError:
        return _bad_value(data, offset, label)
    return text, body + count


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
    if count < 0:
        return _bad_value(data, offset, label)
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


def _append(row: Any, node: Any, value: Any, lists: dict[int, list[Any]] | None) -> None:
    """Outside a round the value goes on the row; inside one it joins the node's list for the run."""
    if lists is None:
        node.set(row, value)
    else:
        lists[id(node)].append(value)


def _align_lists(leaves: Sequence[Any], lists: dict[int, list[Any]], rounds: int) -> None:
    """After each round, a name the round did not read gets `None`: entry `i` of every list is round `i`."""
    for leaf in leaves:
        values = lists[id(leaf)]
        if len(values) < rounds:
            values.append(None)


def _store_lists(row: Any, leaves: Sequence[Any], lists: dict[int, list[Any]]) -> None:
    """Gives each name its list once the run ends, so a default the row type carries (a number, or a list the
    class shares) is never part of it. Two nodes that bind one member (the arms of two `when`s) share one list:
    the entries of the second fill the places the first left `None`."""
    stored: dict[int, list[Any]] = {}
    for leaf in leaves:
        values = lists[id(leaf)]
        shared = stored.get(id(leaf.get(row)))
        if shared is None:
            leaf.set(row, values)
            stored[id(values)] = values
            continue
        for i, value in enumerate(values):
            if value is not None:
                shared[i] = value


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
        got = _read_utf8(data, offset, str(node.field_id))
        if isinstance(got, ShortPacket):
            return None, offset, got
        value, offset = got
        seen[node.field_id] = value
        return value, offset, None
    if isinstance(node, _Bool):
        return True, offset, None
    raise TypeError(f"not a leaf: {type(node)!r}")


def _unpack_element(
    data: memoryview, offset: int, element: _Node, budget: _Budget
) -> tuple[Any, int, ShortPacket | TypeMismatch | None]:
    if isinstance(element, _List):
        return _unpack_list_items(data, offset, element.element, budget)
    if isinstance(element, _Dict):
        return _unpack_dict_items(data, offset, element.element, budget)
    if _is_leaf(element):
        return _unpack_leaf(data, offset, element, {})
    child_row: dict[str, Any] = {}
    offset, err = unpack_nodes(data, offset, [element], child_row, budget=budget)
    if err is not None:
        return None, offset, err
    return child_row, offset, None


def _unpack_list_items(
    data: memoryview, offset: int, element: _Node, budget: _Budget
) -> tuple[list[Any], int, ShortPacket | TypeMismatch | None]:
    left = len(data) - offset
    if left < 2:
        return [], offset, ShortPacket(field="", needed=2, left=left)
    count = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    items: list[Any] = []
    for _ in range(count):
        before = offset
        value, offset, err = _unpack_element(data, offset, element, budget)
        if err is not None:
            return items, offset, err
        if offset == before:
            return items, offset, _bad_value(data, before, "")
        items.append(value)
    return items, offset, None


def _unpack_dict_items(
    data: memoryview, offset: int, element: _Node, budget: _Budget
) -> tuple[dict[str, Any], int, ShortPacket | TypeMismatch | None]:
    left = len(data) - offset
    if left < 2:
        return {}, offset, ShortPacket(field="", needed=2, left=left)
    count = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    mapping: dict[str, Any] = {}
    for _ in range(count):
        got = _read_utf8(data, offset, "")
        if isinstance(got, ShortPacket):
            return mapping, offset, got
        key, offset = got
        before = offset
        value, offset, err = _unpack_element(data, offset, element, budget)
        if err is not None:
            return mapping, offset, err
        if offset == before:
            return mapping, offset, _bad_value(data, before, "")
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
    lists: dict[int, list[Any]] | None = None,
    flag_state: dict[int, int] | None = None,
    budget: _Budget | None = None,
) -> tuple[int, ShortPacket | TypeMismatch | None]:
    """`lists`: inside a `repeat` or `times` round, the list each node of the body fills for the run."""
    if seen is None:
        seen = {}
    if flag_state is None:
        flag_state = {}
    if budget is None:
        budget = _Budget()

    for node in nodes:
        if isinstance(node, _Scalar):
            got = _read_scalar(data, offset, node)
            if isinstance(got, ShortPacket):
                return offset, got
            value, offset = got
            seen[node.field_id] = value
            _append(row, node, value, lists)
        elif isinstance(node, _Bytes):
            left = len(data) - offset
            if left < node.size:
                return offset, ShortPacket(field=str(node.field_id), needed=node.size, left=left)
            raw = _builtin_bytes(data[offset : offset + node.size])
            offset += node.size
            seen[node.field_id] = raw
            _append(row, node, raw, lists)
        elif isinstance(node, _Bool):  # only a set flag bit reaches a bool
            seen[node.field_id] = True
            _append(row, node, True, lists)
        elif isinstance(node, _Flags):
            left = len(data) - offset
            if left < 1:
                return offset, ShortPacket(field="", needed=1, left=left)
            flag = data[offset]
            offset += 1
            for i, child in enumerate(node.fields):
                if flag & (1 << i):
                    offset, err = unpack_nodes(
                        data, offset, [child], row, seen, lists=lists, flag_state=flag_state, budget=budget
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
                    data, offset, [node.field], row, seen, lists=lists, flag_state=flag_state, budget=budget
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _When):
            if seen.get(node.condition.field_id) == node.condition.value:
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, lists=lists, flag_state=flag_state, budget=budget
                )
                if err is not None:
                    return offset, err
        elif isinstance(node, _Repeat):
            leaves = node.leaves
            round_lists: dict[int, list[Any]] = {id(leaf): [] for leaf in leaves}
            started = 0
            while offset < len(data):
                if budget.refuses(started, len(leaves)):
                    return offset, _bad_value(data, offset, str(node.anchor))
                started += 1
                before = offset
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, lists=round_lists, flag_state=flag_state, budget=budget
                )
                if err is not None:
                    return offset, err
                if offset == before:
                    break
                _align_lists(leaves, round_lists, started)
            if started:
                _store_lists(row, leaves, round_lists)
        elif isinstance(node, _Sized):
            count = seen.get(node.count)
            if not isinstance(count, int) or count < 0:
                return offset, _bad_value(data, offset, str(node.field_id))
            left = len(data) - offset
            if left < count:
                return offset, ShortPacket(field=str(node.field_id), needed=count, left=left)
            raw = _builtin_bytes(data[offset : offset + count])
            offset += count
            seen[node.field_id] = raw
            _append(row, node, raw, lists)
        elif isinstance(node, _U2):
            label = str(node.slots[0].field_id) if node.slots else "0"
            got = _read_u2(data, offset, len(node.slots), label)
            if isinstance(got, ShortPacket):
                return offset, got
            values_u2, offset = got
            for slot, value in zip(node.slots, values_u2, strict=True):
                seen[slot.field_id] = value
                _append(row, slot, value, lists)
        elif isinstance(node, _Bits):
            count = seen.get(node.count)
            if not isinstance(count, int):
                return offset, _bad_value(data, offset, str(node.field_id))
            got_bits = _read_bits(data, offset, str(node.field_id), count)
            if isinstance(got_bits, ShortPacket):
                return offset, got_bits
            bits_value, offset = got_bits
            seen[node.field_id] = bits_value
            _append(row, node, bits_value, lists)
        elif isinstance(node, _Packed):
            label = str(node.field_id)
            raw_count = seen.get(node.count)
            if isinstance(raw_count, bool) or not isinstance(raw_count, int):
                return offset, _bad_value(data, offset, label)
            item_count = raw_count + node.bias
            got_packed = _read_packed(data, offset, label, node.width, item_count)
            if isinstance(got_packed, ShortPacket):
                return offset, got_packed
            packed_value, offset = got_packed
            seen[node.field_id] = packed_value
            _append(row, node, packed_value, lists)
        elif isinstance(node, _Times):
            raw_count = seen.get(node.count)
            if isinstance(raw_count, bool) or not isinstance(raw_count, int) or raw_count < 0:
                return offset, _bad_value(data, offset, str(node.anchor))
            leaves = node.leaves
            round_lists = {id(leaf): [] for leaf in leaves}
            for started in range(raw_count):
                if budget.refuses(started, len(leaves)):
                    return offset, _bad_value(data, offset, str(node.anchor))
                before = offset
                offset, err = unpack_nodes(
                    data, offset, node.fields, row, seen, lists=round_lists, flag_state=flag_state, budget=budget
                )
                if err is not None:
                    return offset, err
                if offset == before:
                    return offset, _bad_value(data, before, str(node.anchor))
                _align_lists(leaves, round_lists, started + 1)
            if raw_count:
                _store_lists(row, leaves, round_lists)
        elif isinstance(node, _Utf8):
            got_text = _read_utf8(data, offset, str(node.field_id))
            if isinstance(got_text, ShortPacket):
                return offset, got_text
            value, offset = got_text
            seen[node.field_id] = value
            _append(row, node, value, lists)
        elif isinstance(node, _List):
            items, offset, err = _unpack_list_items(data, offset, node.element, budget)
            if err is not None:
                return offset, err
            _append(row, node, items, lists)
        elif isinstance(node, _Dict):
            mapping, offset, err = _unpack_dict_items(data, offset, node.element, budget)
            if err is not None:
                return offset, err
            _append(row, node, mapping, lists)
        elif isinstance(node, _Group):
            offset, err = unpack_nodes(
                data, offset, node.fields, row, seen, lists=lists, flag_state=flag_state, budget=budget
            )
            if err is not None:
                return offset, err
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return offset, None
