from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from packbin._nodes import (
    _U2,
    _Dict,
    _FlagBit,
    _FlagByte,
    _Flags,
    _Group,
    _List,
    _Node,
    _Repeat,
    _optional_leaves,
    _round_leaves,
    _Times,
    _When,
)

FLAG_BITS = 8


def _bit_label(field: _Node) -> str:
    if isinstance(field, _U2):
        return str(field.slots[0].field_id)
    named: Any = getattr(field, "field_id", getattr(field, "anchor", None))
    return type(field).__name__.lstrip("_").lower() if named is None else str(named)


def _bind_flag_bits(nodes: Sequence[_Node]) -> list[_Node]:
    """A split flag bit reads the flag byte of its own scope, and only after that byte. `reads` holds the latest
    read of each flag byte so far in this scope: a `when` body and a `flags` or flag-bit member see the reads
    before them but leave theirs behind, and a `repeat` or `times` body or a list or dict element starts empty.

    Each read of a flag byte becomes a `_FlagByte` of its own, and its bits are numbered by their place in the
    scheme: bit 0 is the first bit that follows the read, as in the combined form, and a bit nested in another
    bit's field comes after the outer one. The handle and the bits the caller holds are not changed, so one
    handle can be read again and be a member of any number of schemes; the nodes returned here belong to this one."""
    return _bind_all(nodes, {})


def _bind_all(nodes: Sequence[_Node], reads: dict[int, _FlagByte]) -> list[_Node]:
    return [_bind(node, reads) for node in nodes]


def _bind(node: _Node, reads: dict[int, _FlagByte]) -> _Node:
    if isinstance(node, _FlagByte):
        read = _FlagByte(bits=[])
        reads[id(node)] = read
        return read
    if isinstance(node, _FlagBit):
        read = reads.get(id(node.owner))
        if read is None:
            raise ValueError(
                f"flag bit {_bit_label(node.field)}: its flag byte is not read earlier in the same scope"
            )
        index = len(read.bits)
        if index == FLAG_BITS:
            raise ValueError(f"flags already has {FLAG_BITS} bits")
        read.bits.append(node.field)  # keeps the number while the field below is bound
        field = _bind(node.field, dict(reads))
        read.bits[index] = field
        return _FlagBit(owner=read, field=field, index=index)
    if isinstance(node, _Flags):
        return _Flags(anchor=node.anchor, fields=[_bind(member, dict(reads)) for member in node.fields])
    if isinstance(node, _Group):
        return _Group(anchor=node.anchor, fields=_bind_all(node.fields, reads))
    if isinstance(node, _When):
        return _When(anchor=node.anchor, condition=node.condition, fields=_bind_all(node.fields, dict(reads)))
    if isinstance(node, _Repeat):
        repeated = _Repeat(anchor=node.anchor, fields=_bind_all(node.fields, {}))
        repeated.leaves = _round_leaves(repeated.fields)
        return repeated
    if isinstance(node, _Times):
        timed = _Times(anchor=node.anchor, count=node.count, fields=_bind_all(node.fields, {}))
        timed.leaves = _round_leaves(timed.fields)
        timed.optional = _optional_leaves(timed.fields)
        return timed
    if isinstance(node, _List):
        return _List(get=node.get, set=node.set, element=_bind(node.element, {}))
    if isinstance(node, _Dict):
        return _Dict(get=node.get, set=node.set, element=_bind(node.element, {}))
    return node
