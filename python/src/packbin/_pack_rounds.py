from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from packbin._nodes import _Bytes, _Dict, _List, _Node, _Repeat, _Sized
from packbin._pack_limits import _name

_builtin_bytes = bytes
_builtin_list = list
_builtin_dict = dict


def _borrowed(label: str, count: Any, bias: int, ref: int | None = None) -> int:
    if count is None and ref is not None:
        raise ValueError(f"{label}: count {ref} was not written")
    if isinstance(count, bool) or not isinstance(count, int):
        raise ValueError(f"{label}: count missing")
    item_count = count + bias
    if item_count < 0:
        raise ValueError(f"{label}: item count {item_count}")
    return item_count


def _member_label(node: Any) -> str:
    if isinstance(node, _List):
        return "list"
    if isinstance(node, _Dict):
        return "dict"
    return str(node.field_id)


def _refuse_lone_collection(leaf: Any, value: Any) -> None:
    """A dict or a byte buffer for a `dict`, `bytes` or `sized` name in a round is one value of the round, so the
    name holds a list with one per round; a lone one would be read as one round's value or shared by every round."""
    if isinstance(leaf, _Dict) and isinstance(value, _builtin_dict):
        what, one = "dict", "dict"
    elif isinstance(leaf, (_Bytes, _Sized)) and isinstance(value, (_builtin_bytes, bytearray, memoryview)):
        what, one = "byte buffer", "buffer"
    else:
        return
    access = getattr(leaf.get, "access", None)
    name = access[1] if access is not None else _member_label(leaf)
    raise TypeError(
        f"member {name}: a {what} in a repeat or times round must be a list with one {one} per round, "
        f"got a single {one}"
    )


def _check_round_lists(leaves: Sequence[Any], row: Any, count: int) -> None:
    """A list a `times` body holds may not be longer than the count: the entries past it would be dropped."""
    for node in leaves:
        value = node.get(row)
        if isinstance(value, _builtin_list) and len(value) > count:
            raise ValueError(f"{_member_label(node)}: {len(value)} items, times count is {count}")


def _round_length(value: Any) -> int:
    if value is None:
        return 0
    return len(value) if isinstance(value, _builtin_list) else 1


class _RoundValues:
    """The value of a leaf in round `index`: entry `index` of its list, or the lone value every round shares.
    A leaf in `optional` (the ids of those a `times` body holds under `flags` or a flag bit) has no entry
    past the end of its list: it is absent in that round, as a `None` entry is. `count` is given for a `times`:
    it writes every round it counts, so a list that ends early names the leaf. A required leaf of a `repeat`
    whose list is empty beside a longer one is missing in every round and is named so."""

    def __init__(self, row: Any, index: int, optional: set[int] | None, count: int | None) -> None:
        self._row = row
        self._index = index
        self._optional = optional
        self._count = count

    def __call__(self, leaf: _Node) -> Any:
        value = leaf.get(self._row)  # type: ignore[attr-defined]
        if not isinstance(value, _builtin_list):
            return value
        index = self._index
        if self._optional and index >= len(value) and id(leaf) in self._optional:
            return None
        if self._count is not None and index >= len(value):
            raise ValueError(f"{_member_label(leaf)}: {len(value)} items, times count is {self._count}")
        if index >= len(value):
            raise KeyError(f"missing field {_name(leaf)}")
        return value[index]

    def unwritten_count(self, leaf: _Node) -> Any:
        """A count no field of this round wrote (its `when` is clear), as the U11 check reads it: a list with no
        entry for this round leaves the count absent, as a `None` entry does; the round never needed it."""
        value = leaf.get(self._row)  # type: ignore[attr-defined]
        if not isinstance(value, _builtin_list):
            return value
        return value[self._index] if self._index < len(value) else None


def _at_round(
    row: Any, index: int, optional: set[int] | None = None, count: int | None = None
) -> _RoundValues:
    return _RoundValues(row, index, optional, count)


def _refuse_repeat_over_limit(node: _Repeat, values: Sequence[Any], max_rounds: int) -> None:
    """A `repeat` writes a round per entry of its longest list, so the first list past `max_rounds` is refused
    before any round, named by its own member."""
    for leaf, value in zip(node.leaves, values):
        if isinstance(value, _builtin_list) and len(value) > max_rounds:
            raise ValueError(f"{_name(leaf)}: the repeat count is {len(value)}, above the limit of {max_rounds} rounds")


def _refuse_short_optional(node: _Repeat, values: Sequence[Any], rounds: int) -> None:
    """A non-empty list shorter than the rounds under a member a flag bit can leave absent does not say which
    rounds it belongs to, so it is refused, named by its member (the first one in declaration order). An empty
    list or none leaves the member absent in every round, a lone value goes to every round, and a required member
    is reported by the length check that follows."""
    for leaf, value in zip(node.leaves, values):
        if id(leaf) in node.optional and isinstance(value, _builtin_list) and 0 < len(value) < rounds:
            raise ValueError(
                f"{_name(leaf)}: {len(value)} items, repeat count {rounds}; "
                "give one entry per round, None where the member is absent"
            )
