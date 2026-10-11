from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from packbin._nodes import _FlagBit, _Flags, _Group, _Node, _Repeat, _Times, _U2, _When
from packbin._unpack import DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS

DEFAULT_MAX_BYTES = 16_777_216


def _name(node: Any) -> str:
    """The member a message names: the key or attribute the accessor reads, else the field id."""
    access = getattr(getattr(node, "get", None), "access", None)
    if access is not None:
        return str(access[1])
    field_id = getattr(node, "field_id", None)
    return str(field_id) if field_id is not None else type(node).__name__


def _first_name(nodes: Sequence[_Node]) -> str | None:
    """The first name `nodes` declare, depth-first through `when`, `repeat`, `times`, groups, flags and flag bits."""
    for node in nodes:
        if isinstance(node, _U2):
            return _name(node.slots[0]) if node.slots else None
        if isinstance(node, (_Flags, _When, _Group, _Repeat, _Times)):
            inner = _first_name(node.fields)
        elif isinstance(node, _FlagBit):
            inner = _first_name([node.field])
        elif hasattr(node, "get"):
            inner = _name(node)
        else:
            inner = None
        if inner is not None:
            return inner
    return None


def round_member(node: _Repeat | _Times) -> str:
    """The member that names a round: the first value its body holds, else the `repeat` or `times` itself."""
    if node.leaves:
        return _name(node.leaves[0])
    return f"{'repeat' if isinstance(node, _Repeat) else 'times'} {node.anchor}"


def flags_member(node: _Flags) -> str:
    return _first_name(node.fields) or f"flags {node.anchor}"


class _PackBudget:
    """What one pack call may spend: `max_rounds` on a `repeat` or `times`, `max_slots` on the slots every round
    started so far has charged (the width unpack charges, shared by every round at any depth), and `max_bytes`
    on the packet, type byte included. A check refuses before the round or the append it guards."""

    __slots__ = ("max_rounds", "max_slots", "max_bytes", "slots")

    def __init__(
        self,
        max_rounds: int = DEFAULT_MAX_ROUNDS,
        max_slots: int = DEFAULT_MAX_SLOTS,
        max_bytes: int = DEFAULT_MAX_BYTES,
    ) -> None:
        self.max_rounds = max_rounds
        self.max_slots = max_slots
        self.max_bytes = max_bytes
        self.slots = 0

    def room(self, buf: bytearray, size: int, member: str) -> None:
        """Called before `size` bytes are appended to `buf`."""
        total = len(buf) + size
        if total > self.max_bytes:
            raise ValueError(f"{member}: the packet would be {total} bytes, above the limit of {self.max_bytes} bytes")

    def start_round(self, node: _Repeat | _Times) -> None:
        """Called as a round starts, before any byte of it is written."""
        total = self.slots + len(node.leaves)
        if total > self.max_slots:
            raise ValueError(
                f"{round_member(node)}: the rounds would hold {total} slots, above the limit of {self.max_slots} slots"
            )
        self.slots = total
