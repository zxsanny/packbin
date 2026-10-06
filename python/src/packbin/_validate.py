from __future__ import annotations

from collections.abc import Sequence

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
