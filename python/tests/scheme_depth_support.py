from __future__ import annotations

from collections.abc import Callable
from typing import Any

from packbin import BinaryPacker, Scheme, bool as bool_, dict as dict_, eq, flags, group, list as list_, repeat, times, u8, when

# AZ-4297 (contract scheme-depth.md): every chain below is written by a loop, innermost first, so the tests
# never recurse. A builder takes the number of containers on the path to the innermost field and returns the
# fields of the scheme, a row and the packet that row packs to (the bytes the package packed before the limit).
# The row type is a dict: the accessors are key accessors.

Built = tuple[list[Any], dict[str, Any], str]


def _key(name: str) -> Callable[[Any], Any]:
    return lambda row: row[name]


def when_chain(depth: int) -> Built:
    inner: list[Any] = [u8(1, _key("b"))]
    for _ in range(depth):
        inner = [when(1, eq(0, 1), *inner)]
    return [u8(0, _key("a")), *inner], {"a": 1, "b": 7}, "010107"


def group_chain(depth: int) -> Built:
    inner: list[Any] = [u8(0, _key("b"))]
    for _ in range(depth):
        inner = [group(0, *inner)]
    return inner, {"b": 7}, "0107"


def flags_chain(depth: int) -> Built:
    inner: list[Any] = [bool_(0, _key("b"))]
    for _ in range(depth):
        inner = [flags(0, *inner)]
    return inner, {"b": True}, "01" * (depth + 1)


def list_chain(depth: int) -> Built:
    element: Any = u8(0, _key("b"))
    value: Any = 7
    for _ in range(depth):
        element = list_(_key("l"), element)
        value = [value]
    return [element], {"l": value}, "01" + "0100" * depth + "07"


def dict_chain(depth: int) -> Built:
    element: Any = u8(0, _key("b"))
    value: Any = 7
    for _ in range(depth):
        element = dict_(_key("l"), element)
        value = {"k": value}
    return [element], {"l": value}, "01" + "010002106b" * depth + "07"


def repeat_when_chain(depth: int) -> Built:
    """`depth` counts the round itself: a `repeat` holding `depth - 1` nested `when`s."""
    inner: list[Any] = [u8(1, _key("b"))]
    for _ in range(depth - 1):
        inner = [when(1, eq(0, 1), *inner)]
    return [repeat(0, u8(0, _key("k")), *inner)], {"k": [1, 1], "b": [7, 8]}, "0101070108"


def times_when_chain(depth: int) -> Built:
    """`depth` counts the round itself: a `times` holding `depth - 1` nested `when`s."""
    inner: list[Any] = [u8(2, _key("b"))]
    for _ in range(depth - 1):
        inner = [when(2, eq(1, 1), *inner)]
    return [u8(0, _key("n")), times(1, 0, u8(1, _key("k")), *inner)], {"n": 2, "k": [1, 1], "b": [7, 8]}, "010201070108"


def repeat_group_chain(depth: int) -> Built:
    """`depth` counts the round itself: a `repeat` holding `depth - 1` nested groups."""
    inner: list[Any] = [u8(1, _key("b"))]
    for _ in range(depth - 1):
        inner = [group(1, *inner)]
    return [repeat(0, u8(0, _key("k")), *inner)], {"k": [1, 1], "b": [7, 8]}, "0101070108"


def list_group_chain(depth: int) -> Built:
    """Groups and list element rows in turn, the innermost a group: the most frames per level the package has."""
    node: Any = u8(0, _key("b"))
    value: dict[str, Any] = {"b": 7}
    lists = 0
    for step in range(depth):
        if step % 2 == 0:
            node = group(0, node)
        else:
            node = list_(_key("l"), node)
            value = {"l": [value]}
            lists += 1
    return [node], value, "01" + "0100" * lists + "07"


# kind -> builder: every container kind the package can nest, the ones the contract names.
KINDS: dict[str, Callable[[int], Built]] = {
    "when": when_chain,
    "group": group_chain,
    "flags": flags_chain,
    "list": list_chain,
    "dict": dict_chain,
    "repeat": repeat_when_chain,
    "times": times_when_chain,
    "repeat_group": repeat_group_chain,
    "list_group": list_group_chain,
}

DEPTH_REFUSAL = "scheme nested too deep: more than 256 levels; the limit is 256"


# The hostile loader's own tables (fixtures/hostile/cases.txt, the four loop 126 cases): the chains are the
# probe's (scripts/probes/scheme-depth/python/probe.py), with dict rows.
def _built(chain: Callable[[int], Built], depth: int) -> Scheme[Any]:
    fields, _row, _packet = chain(depth)
    return Scheme(1, dict, *fields)


def _packed(chain: Callable[[int], Built], depth: int) -> bytes:
    fields, row, _packet = chain(depth)
    return BinaryPacker.pack(Scheme(1, dict, *fields), row)


LOOP126_CONSTRUCT_CASES: dict[str, Callable[[], Any]] = {
    "construct_depth_when_257": lambda: _built(when_chain, 257),
    "construct_depth_group_257": lambda: _built(group_chain, 257),
}
LOOP126_CONSTRUCT_REFUSAL: dict[str, str] = {case_id: DEPTH_REFUSAL for case_id in LOOP126_CONSTRUCT_CASES}
# case id -> (pack call, None: each is a `bytes` case)
LOOP126_PACK_CASES: dict[str, tuple[Callable[[], bytes], None]] = {
    "pack_depth_when_256": (lambda: _packed(when_chain, 256), None),
    "pack_depth_group_256": (lambda: _packed(group_chain, 256), None),
}
