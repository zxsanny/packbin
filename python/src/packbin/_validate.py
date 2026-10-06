from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from packbin._nodes import (
    _U2,
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
    _Packed,
    _Repeat,
    _Scalar,
    _Sized,
    _Times,
    _U2Slot,
    _Utf8,
    _When,
)

_COUNTED = {_Sized: "sized", _Bits: "bits", _Packed: "packed"}


def _require_visible(label: str, what: str, field_id: int, visible: set[int]) -> None:
    if field_id not in visible:
        raise ValueError(
            f"{label}: {what} field id {field_id} is allowed only if declared earlier in the same scope"
        )


def _validate_order(
    nodes: Sequence[_Node],
    next_id: int = 0,
    flag_bits: bool = False,
    visible: set[int] | None = None,
) -> int:
    """`flag_bits`: the nodes are the direct children of `flags` or of a flag-byte bit, the only
    places a bool may stand (its value is the bit itself).
    `visible`: the ids a `when` or a count may name here, the ones declared earlier in this scope.
    The top level, a `repeat` or `times` body and a list or dict element are separate scopes.
    A flag byte takes no id: each of its bits takes one where the bit stands."""
    if visible is None:
        visible = set()
    for node in nodes:
        if isinstance(node, _Bool) and not flag_bits:
            raise ValueError(
                f"field id {node.field_id}: bool is allowed only as a direct child of flags or a flag-byte bit"
            )
        if isinstance(node, _Group) and not node.fields:
            raise ValueError(f"group {node.anchor} has no fields, so it can never carry a value")
        if isinstance(node, (_Scalar, _Bytes, _Bool, _Utf8, _Sized, _Bits, _Packed)):
            if isinstance(node, (_Sized, _Bits, _Packed)):
                _require_visible(f"{_COUNTED[type(node)]} {node.field_id}", "count", node.count, visible)
            if node.field_id != next_id:
                raise ValueError(f"field id {node.field_id} is not the next order {next_id}")
            visible.add(node.field_id)
            next_id += 1
        elif isinstance(node, _U2Slot):
            if node.field_id != next_id:
                raise ValueError(f"field id {node.field_id} is not the next order {next_id}")
            visible.add(node.field_id)
            next_id += 1
        elif isinstance(node, _U2):
            next_id = _validate_order(node.slots, next_id, visible=visible)
        elif isinstance(node, (_Flags, _When, _Repeat, _Times, _Group)):
            if node.anchor != next_id:
                raise ValueError(f"anchor {node.anchor} is not the next order {next_id}")
            if isinstance(node, _When):
                _require_visible(f"when {node.anchor}", "eq names", node.condition.field_id, visible)
            if isinstance(node, _Times):
                _require_visible(f"times {node.anchor}", "count", node.count, visible)
            body = set() if isinstance(node, (_Repeat, _Times)) else visible
            next_id = _validate_order(node.fields, next_id, isinstance(node, _Flags), body)
        elif isinstance(node, _FlagByte):
            pass
        elif isinstance(node, _FlagBit):
            next_id = _validate_order([node.field], next_id, True, visible)
        elif isinstance(node, (_List, _Dict)):
            _validate_order([node.element], 0)
        else:
            raise TypeError(f"unknown field node: {type(node)!r}")
    return next_id


def _validate_round_nesting(nodes: Sequence[_Node], in_round: bool = False) -> None:
    """A round keeps one list entry per round for every name its body holds, so a `repeat` or `times` inside
    one has no place to put its own rounds. Refused wherever it sits in the body (directly, or under `when`,
    `flags`, a flag bit or a group). A list or dict element is a row of its own and starts outside any round."""
    for node in nodes:
        if isinstance(node, (_Repeat, _Times)):
            if in_round:
                kind = "repeat" if isinstance(node, _Repeat) else "times"
                raise ValueError(
                    f"{kind} {node.anchor} is inside a repeat or times round; a round cannot hold another repeat or times"
                )
            _validate_round_nesting(node.fields, True)
        elif isinstance(node, (_When, _Flags, _Group)):
            _validate_round_nesting(node.fields, in_round)
        elif isinstance(node, _FlagBit):
            _validate_round_nesting([node.field], in_round)
        elif isinstance(node, (_List, _Dict)):
            _validate_round_nesting([node.element])


def _declare_name(node: _Node, seen: list[tuple[str, Any]], under_when: bool) -> None:
    access = getattr(node.get, "access", None)  # type: ignore[attr-defined]
    if access is None or under_when:
        return
    if access in seen:
        raise ValueError(
            f"member {access[1]}: declared twice in one scope; a row holds one value per name, so one would be lost"
        )
    seen.append(access)


def _validate_names(
    nodes: Sequence[_Node], seen: list[tuple[str, Any]] | None = None, under_when: bool = False
) -> None:
    """A row holds one value per accessor name (`row["x"]` and `row.x` are different accessors; the identity has
    none), so a name declared twice in one scope loses a value. A scope is the top level or one list or dict
    element; `repeat`, `times`, `flags`, `when`, `group` and a flag bit share the scope around them, and a
    flag byte holds no name. A declaration under a `when` is not counted: the branches of a chain may share a
    member. `seen` holds the names declared outside any `when` in this scope."""
    if seen is None:
        seen = []
    for node in nodes:
        if isinstance(node, _U2):
            for slot in node.slots:
                _declare_name(slot, seen, under_when)
        elif isinstance(node, (_Flags, _Group, _Repeat, _Times)):
            _validate_names(node.fields, seen, under_when)
        elif isinstance(node, _When):
            _validate_names(node.fields, seen, True)
        elif isinstance(node, _FlagBit):
            _validate_names([node.field], seen, under_when)
        elif isinstance(node, (_List, _Dict)):
            _declare_name(node, seen, under_when)
            _validate_names([node.element])
        elif not isinstance(node, _FlagByte):
            _declare_name(node, seen, under_when)


_VALUE_LEAVES = (_Scalar, _Bytes, _Bool, _Utf8, _Sized, _Bits, _Packed)


def _container(node: _List | _Dict) -> str:
    return "list" if isinstance(node, _List) else "dict"


def _require_key_accessor(node: Any, holder: str, what: str) -> None:
    access = getattr(node.set, "access", None)
    if access is not None and access[0] == "attr":
        key = access[1]
        raise ValueError(
            f"{holder} element: {what} uses the attribute accessor '{key}'; "
            f"an element row is a dict, so use a key accessor, row['{key}']"
        )


def _validate_element_accessors(nodes: Sequence[_Node], holder: str | None = None) -> None:
    """Each `list` or `dict` element that is not a leaf is unpacked into a plain `dict`, so an accessor of its
    scope that reads and writes an attribute (`row.x`) could pack objects but never unpack a value. `holder`
    is `list` or `dict`, the container whose element scope the nodes are in, and `None` outside any element.
    A leaf element and an element that is itself a `list` or `dict` are read and written by value: their own
    accessor is never called, and the inner container is checked as the holder of its own element."""
    for node in nodes:
        if isinstance(node, (_List, _Dict)):
            if holder is not None:
                _require_key_accessor(node, holder, f"a nested {_container(node)}")
            _validate_element(node.element, _container(node))
        elif isinstance(node, _U2):
            if holder is not None:
                for slot in node.slots:
                    _require_key_accessor(slot, holder, f"field {slot.field_id}")
        elif isinstance(node, (_Flags, _Group, _When, _Repeat, _Times)):
            _validate_element_accessors(node.fields, holder)
        elif isinstance(node, _FlagBit):
            _validate_element_accessors([node.field], holder)
        elif holder is not None and isinstance(node, _VALUE_LEAVES):
            _require_key_accessor(node, holder, f"field {node.field_id}")


def _validate_element(element: _Node, holder: str) -> None:
    if isinstance(element, (_List, _Dict)):
        _validate_element(element.element, _container(element))
    elif not isinstance(element, _VALUE_LEAVES):
        _validate_element_accessors([element], holder)
