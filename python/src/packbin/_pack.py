from __future__ import annotations

import struct
from collections.abc import Callable, Sequence
from typing import Any

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
from packbin._pack_limits import _PackBudget, _name, flags_member, round_member
from packbin._pack_rounds import (
    _RoundValues,
    _at_round,
    _borrowed,
    _check_round_lists,
    _refuse_lone_collection,
    _refuse_repeat_over_limit,
    _refuse_short_optional,
    _round_length,
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


def _child_on(
    child: _Node, take: Callable[[_Node], Any], seen: dict[int, Any], row: Any, deciding: bool = False
) -> bool:
    """`take` gives the value of a leaf for the row, or for the round being packed; `seen` holds the values written
    so far in this scope, which decide a `when` and a `times` member. `deciding`: a split flag byte is deciding its
    bits, so a `times` whose count is not written yet leaves its bit clear and is looked at again at the bit."""
    if isinstance(child, (_Group, _Flags)):
        return any(_child_on(inner, take, seen, row, deciding) for inner in child.fields)
    if isinstance(child, _U2):
        return any(_present_value(take(slot)) for slot in child.slots)
    if isinstance(child, _Bool):
        return _bool_on(take(child))
    if isinstance(child, (_Scalar, _Bytes, _Utf8, _Sized, _Bits, _Packed, _List, _Dict)):
        return _present_value(take(child))
    if isinstance(child, _FlagBit):
        return _child_on(child.field, take, seen, row, deciding)
    if isinstance(child, _When):
        held = seen.get(child.condition.field_id) == child.condition.value
        return held and any(_child_on(inner, take, seen, row, deciding) for inner in child.fields)
    if isinstance(child, _Times):
        return _times_on(child, seen, row, deciding)
    if isinstance(child, _Repeat):
        return any(_round_length(leaf.get(row)) > 0 for leaf in child.leaves)
    return False


def _times_on(node: _Times, seen: dict[int, Any], row: Any, deciding: bool = False) -> bool:
    """On when the count is above 0. A count that was skipped is no round (unpack would not read the field either),
    but values given for the body would be dropped, so they are refused; a count of 0 with a list or a lone dict
    given for a body value is refused, as outside `flags`."""
    count = seen.get(node.count)
    if count is None:
        if not deciding:
            held = _first_held(node, row)
            if held is not None:
                raise ValueError(
                    f"{held}: a value is given, but the count of its times is not written, so its bit is clear; "
                    "write the count before the times"
                )
        return False
    rounds = _borrowed("times", count, 0)
    if rounds == 0:
        _refuse_zero_rounds(node, row)
    return rounds > 0


def _refuse_zero_rounds(node: _Times, row: Any) -> None:
    _check_round_lists(node.leaves, row, 0)
    for leaf in node.leaves:
        _refuse_lone_collection(leaf, leaf.get(row))


def _first_held(node: _Times, row: Any) -> str | None:
    """The name of the first body value the row gives (a list with entries, or a lone value)."""
    for leaf in node.leaves:
        if _round_length(leaf.get(row)) > 0:
            return _name(leaf)
    return None


def _refuse_dropped_times(node: _Times) -> None:
    raise ValueError(
        f"times {node.anchor}: body values are given, but count field {node.count} has no value "
        "(it was skipped, or is written after the flag byte that decides this bit)"
    )


def _unwritten_sources(child: _Node, seen: dict[int, Any]) -> list[_When | _Times | _Sized | _Bits | _Packed]:
    """Every `when` under a flag bit whose condition field has no value yet, and every `times`, `sized`, `bits`
    and `packed` whose count has none: a split flag byte decides the bit without them, so the bit must be
    re-checked when the fields are written."""
    found: list[_When | _Times | _Sized | _Bits | _Packed] = []
    if isinstance(child, (_Times, _Sized, _Bits, _Packed)):
        if seen.get(child.count) is None:
            found.append(child)
    elif isinstance(child, (_Group, _Flags, _When)):
        if isinstance(child, _When) and seen.get(child.condition.field_id) is None:
            found.append(child)
        for inner in child.fields:
            found.extend(_unwritten_sources(inner, seen))
    elif isinstance(child, _FlagBit):
        found.extend(_unwritten_sources(child.field, seen))
    return found


def _refuse_late_times(child: _Node, seen: dict[int, Any], row: Any) -> None:
    """A `times` under a clear split bit whose count was not written when the flag byte was decided: with the count
    now written, a count of 0 follows the rules outside a split byte (a list of values is refused, a lone value
    packs zero rounds), and a count above 0 with body values would drop them."""
    if isinstance(child, _Times):
        count = seen.get(child.count)
        if count is not None and _borrowed("times", count, 0) == 0:
            _refuse_zero_rounds(child, row)
        elif _first_held(child, row) is not None:
            _refuse_dropped_times(child)
    elif isinstance(child, (_Group, _Flags)):
        for inner in child.fields:
            _refuse_late_times(inner, seen, row)
    elif isinstance(child, _FlagBit):
        _refuse_late_times(child.field, seen, row)
    elif isinstance(child, _When) and seen.get(child.condition.field_id) == child.condition.value:
        for inner in child.fields:
            _refuse_late_times(inner, seen, row)


def _refuse_unwritten_count(child: _Node, seen: dict[int, Any], count_of: Callable[[_Node], Any]) -> None:
    """A clear bit holds a `times`, `bits`, `packed` or `sized` whose count no field wrote, because the `when` that
    holds it is clear, while the row gives the count a value above 0 (after the `packed` bias). Unpack would read
    the count as absent and the member as nothing, so pack refuses the row instead of writing a packet that drops
    it. A count of 0 or none, and a count that a field wrote, are left alone. Looked at through `flags`, flag bits,
    groups and the `when`s that hold. `count_of` reads the count; in a round, a list with no entry for it is none."""
    if isinstance(child, (_Times, _Sized, _Bits, _Packed)):
        source = child.count_source
        if source is None or seen.get(child.count) is not None:
            return
        count = count_of(source)
        bias = child.bias if isinstance(child, _Packed) else 0
        if isinstance(count, int) and not isinstance(count, bool) and count + bias > 0:
            ending = "its times reads no round" if isinstance(child, _Times) else "the member reads nothing"
            member = round_member(child) if isinstance(child, _Times) else _name(child)
            raise ValueError(
                f"{member}: the count {_name(source)} is {count} in the row, but no field wrote it "
                f"(the when that holds it is clear), so {ending}; "
                "give the count 0, leave it out, or make the when hold"
            )
    elif isinstance(child, (_Group, _Flags)):
        for inner in child.fields:
            _refuse_unwritten_count(inner, seen, count_of)
    elif isinstance(child, _FlagBit):
        _refuse_unwritten_count(child.field, seen, count_of)
    elif isinstance(child, _When) and seen.get(child.condition.field_id) == child.condition.value:
        for inner in child.fields:
            _refuse_unwritten_count(inner, seen, count_of)


def _refuse_late_body(
    child: _Node,
    flag_state: dict[int, Any],
    take: Callable[[_Node], Any],
    seen: dict[int, Any],
    row: Any,
    count_of: Callable[[_Node], Any],
) -> None:
    """A clear split bit with `when` conditions written after the flag byte: a body that a written condition
    now asks for would be dropped, so pack fails instead of returning a packet the row did not ask for. A false
    condition leaves the body out on purpose, as outside a split byte."""
    late = flag_state.get(id(child))
    if not late:
        return
    _refuse_late_times(child, seen, row)
    _refuse_unwritten_count(child, seen, count_of)
    if not _child_on(child, take, seen, row):
        return
    for node in late:
        if not isinstance(node, _When):
            continue
        source = node.condition.field_id
        if seen.get(source) == node.condition.value:
            raise ValueError(
                f"when {node.anchor}: a body value is given, but condition field {source} is written after "
                "the flag byte that decides this bit"
            )


def _write_u2(
    buf: bytearray, slots: Sequence[Any], take: Callable[[_Node], Any], seen: dict[int, Any], budget: _PackBudget
) -> None:
    nbytes = (len(slots) + 3) // 4
    raw = bytearray(nbytes)
    for i, slot in enumerate(slots):
        value = take(slot)
        seen[slot.field_id] = value
        if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 3:
            raise ValueError(f"{slot.field_id}: expected 2-bit int")
        raw[i // 4] |= value << ((i % 4) * 2)
    budget.room(buf, nbytes, _name(slots[0]))
    buf.extend(raw)


def _write_bits(buf: bytearray, label: str, count: int, raw: Any, budget: _PackBudget, member: str) -> None:
    _write_packed(buf, label, 1, count, raw, budget, member)


def _write_packed(
    buf: bytearray, label: str, width: int, count: int, raw: Any, budget: _PackBudget, member: str
) -> None:
    if not isinstance(raw, _builtin_list) or len(raw) != count:
        raise ValueError(f"{label}: expected {count} items")
    budget.room(buf, (count * width + 7) // 8, member)
    per = 8 if width == 1 else 4
    shift = 1 if width == 1 else 2
    limit = 1 if width == 1 else 3
    packed = bytearray((count * width + 7) // 8)
    for i, item in enumerate(raw):
        if isinstance(item, bool) or not isinstance(item, int) or item < 0 or item > limit:
            raise ValueError(f"{label}: expected 0..{limit}")
        packed[i // per] |= item << ((i % per) * shift)
    buf.extend(packed)


def _require_int(field: _Scalar, value: Any) -> int | float:
    if field.kind in ("f32", "f64"):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise TypeError(f"{field.field_id}: expected number, got {type(value).__name__}")
        return float(value)
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{field.field_id}: expected int, got {type(value).__name__}")
    if value < field.min_v or value > field.max_v:
        raise OverflowError(f"{field.field_id}: {value} does not fit in {field.kind}")
    return value


def _write_scalar(buf: bytearray, field: _Scalar, value: Any, budget: _PackBudget) -> None:
    number = _require_int(field, value)
    try:
        packed = struct.pack(field.endian_fmt(), number)
    except OverflowError as exc:  # only a finite f32 value too large for the format reaches here
        raise OverflowError(f"{field.field_id}: {value} does not fit in {field.kind}") from exc
    budget.room(buf, len(packed), _name(field))
    buf.extend(packed)


def _is_leaf(node: _Node) -> bool:
    return isinstance(node, (_Scalar, _Bytes, _Utf8, _Bool, _Sized, _Bits, _Packed))


def _pack_element(buf: bytearray, element: _Node, item: Any, budget: _PackBudget) -> None:
    if isinstance(element, _List):
        _pack_list_items(buf, element, element.element, item, budget)
    elif isinstance(element, _Dict):
        _pack_dict_items(buf, element, element.element, item, budget)
    elif _is_leaf(element):
        pack_nodes(buf, [element], item, {}, lambda _n: item, budget=budget)
    else:
        pack_nodes(buf, [element], item, {}, budget=budget)


def _pack_list_items(buf: bytearray, owner: _Node, element: _Node, items: Any, budget: _PackBudget) -> None:
    if not isinstance(items, _builtin_list):
        raise TypeError("list: expected list")
    if len(items) > 65535:
        raise ValueError(f"list: length {len(items)}")
    budget.room(buf, 2, _name(owner))
    buf.append(len(items) & 0xFF)
    buf.append((len(items) >> 8) & 0xFF)
    for item in items:
        _pack_element(buf, element, item, budget)


def _pack_dict_items(buf: bytearray, owner: _Node, element: _Node, mapping: Any, budget: _PackBudget) -> None:
    if not isinstance(mapping, _builtin_dict):
        raise TypeError("dict: expected dict")
    if len(mapping) > 65535:
        raise ValueError(f"dict: length {len(mapping)}")
    pairs = sorted(mapping.items(), key=lambda kv: kv[0].encode("utf-8"))
    member = _name(owner)
    budget.room(buf, 2, member)
    buf.append(len(pairs) & 0xFF)
    buf.append((len(pairs) >> 8) & 0xFF)
    for key, value in pairs:
        raw = _utf8_payload("dict", key)
        budget.room(buf, 2 + len(raw), member)
        buf.append(len(raw) & 0xFF)
        buf.append((len(raw) >> 8) & 0xFF)
        buf.extend(raw)
        _pack_element(buf, element, value, budget)


def pack_nodes(
    buf: bytearray,
    nodes: Sequence[_Node],
    row: Any,
    seen: dict[int, Any] | None = None,
    get_value: Callable[[_Node], Any] | None = None,
    *,
    flag_state: dict[int, Any] | None = None,
    budget: _PackBudget | None = None,
) -> None:
    """`flag_state`: the byte each read of a split flag byte wrote, which its bits follow.
    `budget`: the scheme's limits for this call: the round limit (a `times` count or a `repeat` list above it is
    refused, as unpack refuses the round), the slots the rounds charge and the length of the packet."""
    if seen is None:
        seen = {}
    if flag_state is None:
        flag_state = {}
    if budget is None:
        budget = _PackBudget()

    def take(node: _Node) -> Any:
        if get_value is not None:
            return get_value(node)
        return node.get(row)  # type: ignore[attr-defined]

    def count_of(node: _Node) -> Any:
        return get_value.unwritten_count(node) if isinstance(get_value, _RoundValues) else take(node)

    def run(members: Sequence[_Node], scope: dict[int, Any], getter: Callable[[_Node], Any] | None) -> None:
        pack_nodes(buf, members, row, scope, getter, flag_state=flag_state, budget=budget)

    for node in nodes:
        if isinstance(node, _Scalar):
            value = take(node)
            if not _present_value(value) and get_value is None:
                raise KeyError(f"missing field {node.field_id}")
            seen[node.field_id] = value
            _write_scalar(buf, node, value, budget)
        elif isinstance(node, _Bytes):
            raw = take(node)
            if not _present_value(raw) and get_value is None:
                raise KeyError(f"missing field {node.field_id}")
            seen[node.field_id] = raw
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.field_id}: expected bytes")
            if len(raw) != node.size:
                raise ValueError(f"{node.field_id}: expected {node.size} bytes, got {len(raw)}")
            budget.room(buf, len(raw), _name(node))
            buf.extend(raw)
        elif isinstance(node, _Bool):
            seen[node.field_id] = take(node)
        elif isinstance(node, _Flags):
            budget.room(buf, 1, flags_member(node))
            at = len(buf)
            buf.append(0)
            flag = 0
            for i, child in enumerate(node.fields):
                if not _child_on(child, take, seen, row):
                    _refuse_unwritten_count(child, seen, count_of)
                    continue
                flag |= 1 << i
                if isinstance(child, _Bool):
                    seen[child.field_id] = take(child)
                elif isinstance(child, _Group):
                    run(child.fields, seen, get_value)
                else:
                    run([child], seen, get_value)
            buf[at] = flag
        elif isinstance(node, _Sized):
            count = seen.get(node.count)
            if count is None:
                raise ValueError(f"{node.field_id}: count {node.count} was not written")
            raw = take(node)
            seen[node.field_id] = raw
            if not isinstance(raw, (_builtin_bytes, bytearray, memoryview)):
                raise TypeError(f"{node.field_id}: expected bytes")
            if len(raw) != count:
                raise ValueError(f"{node.field_id}: expected {count} bytes, got {len(raw)}")
            budget.room(buf, len(raw), _name(node))
            buf.extend(raw)
        elif isinstance(node, _U2):
            _write_u2(buf, node.slots, take, seen, budget)
        elif isinstance(node, _Bits):
            count = seen.get(node.count)
            if count is None:
                raise ValueError(f"{node.field_id}: count {node.count} was not written")
            value = take(node)
            seen[node.field_id] = value
            _write_bits(buf, str(node.field_id), int(count), value, budget, _name(node))
        elif isinstance(node, _Packed):
            label = str(node.field_id)
            item_count = _borrowed(label, seen.get(node.count), node.bias, node.count)
            value = take(node)
            seen[node.field_id] = value
            _write_packed(buf, label, node.width, item_count, value, budget, _name(node))
        elif isinstance(node, _Times):
            item_count = _borrowed("times", seen.get(node.count), 0, node.count)
            if item_count > budget.max_rounds:
                raise ValueError(
                    f"{round_member(node)}: the times count is {item_count}, "
                    f"above the limit of {budget.max_rounds} rounds"
                )
            _check_round_lists(node.leaves, row, item_count)
            for leaf in node.leaves:
                _refuse_lone_collection(leaf, leaf.get(row))
            for i in range(item_count):
                budget.start_round(node)
                at_round = _at_round(row, i, node.optional, item_count)
                run(node.fields, {}, at_round)
        elif isinstance(node, _FlagByte):
            flag = 0
            for i, child in enumerate(node.bits):
                flag_state.pop(id(child), None)
                if _child_on(child, take, seen, row, True):
                    flag |= 1 << i
                else:
                    unwritten = _unwritten_sources(child, seen)
                    if unwritten:
                        flag_state[id(child)] = unwritten
            budget.room(buf, 1, "flag byte")
            buf.append(flag)
            flag_state[id(node)] = flag
        elif isinstance(node, _FlagBit):
            flag = flag_state.get(id(node.owner))
            if flag is None:
                raise RuntimeError("flag bit before flag byte")
            if not flag & (1 << node.index):
                _refuse_late_body(node.field, flag_state, take, seen, row, count_of)
            else:
                run([node.field], seen, get_value)
        elif isinstance(node, _When):
            if seen.get(node.condition.field_id) == node.condition.value:
                run(node.fields, seen, get_value)
        elif isinstance(node, _Repeat):
            values = [leaf.get(row) for leaf in node.leaves]
            _refuse_repeat_over_limit(node, values, budget.max_rounds)
            lengths = [_round_length(value) for value in values]
            count = max(lengths, default=0)
            _refuse_short_optional(node, values, count)
            for leaf, value in zip(node.leaves, values):
                _refuse_lone_collection(leaf, value)
            for i in range(count):
                budget.start_round(node)
                run(node.fields, {}, _at_round(row, i, node.optional))
        elif isinstance(node, _Utf8):
            value = take(node)
            seen[node.field_id] = value
            raw = _utf8_payload(str(node.field_id), value)
            budget.room(buf, 2 + len(raw), _name(node))
            buf.append(len(raw) & 0xFF)
            buf.append((len(raw) >> 8) & 0xFF)
            buf.extend(raw)
        elif isinstance(node, _List):
            _pack_list_items(buf, node, node.element, take(node), budget)
        elif isinstance(node, _Dict):
            _pack_dict_items(buf, node, node.element, take(node), budget)
        elif isinstance(node, _Group):
            run(node.fields, seen, get_value)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
