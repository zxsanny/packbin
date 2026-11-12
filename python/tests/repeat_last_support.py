"""The rule "a repeat is the last thing a packet reads" (contract `repeat-last.md`): what the test modules that pin it
share. The refusal texts, a repeat whose body is one byte, and the fifteen cases of `fixtures/hostile/cases.txt` that
the rule added (R1 to R9 and the two of AZ-4232 refused, K1 to K4 kept), each as a scheme that takes the accessor of
its fields, so `test_repeat_last.py` builds it with dict rows and with class rows and the hostile loader with dict rows.

Python has only an anchored group, which shares the ids of the row around it: `x` of the group case is id 1, and the
element row of the list and dict cases is `group(0, ...)`. The row of a list or dict element is always a dict, so an
element's fields take key accessors whatever the accessor of the outer scheme is."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from packbin import (
    BinaryPacker,
    Scheme,
    dict as map_field,
    eq,
    flags,
    group,
    list as list_field,
    repeat,
    times,
    u8,
    when,
)

Acc = Callable[[str], Callable[[Any], Any]]
Fields = Callable[[Acc], list[Any]]


def key(name: str) -> Callable[[Any], Any]:
    return lambda row: row[name]


def followed(anchor: int, field: str) -> str:
    """The refusal of a repeat that a field follows; `field` names it the way Python's other scheme errors do:
    `field <id>`, a round or flags by its kind and anchor, and what has no id by its kind."""
    return (
        f"repeat {anchor}: {field} follows it; "
        "a repeat reads to the end of the packet, so nothing can follow it; use times"
    )


def in_element(anchor: int) -> str:
    """The refusal of a repeat inside a list or dict element."""
    return (
        f"repeat {anchor} is inside a list or dict element; "
        "a repeat reads to the end of the packet, so another element cannot follow it; use times"
    )


def in_round(anchor: int) -> str:
    """The refusal of a repeat inside a repeat or times round, which the nesting rule of the other rounds keeps."""
    return f"repeat {anchor} is inside a repeat or times round; a round cannot hold another repeat or times"


def rounds(field_id: int, acc: Acc = key, name: str = "v") -> Any:
    """repeat { u8 v }, with the id its place gives it."""
    return repeat(field_id, u8(field_id, acc(name)))


def _element() -> Any:
    """The element row of the list and dict cases: u8 mode; repeat { u8 v }."""
    return group(0, u8(0, key("mode")), rounds(1))


# hostile case id -> (the fields, the text of the refusal)
REFUSED: dict[str, tuple[Fields, str]] = {
    "construct_repeat_then_field": (lambda acc: [rounds(0, acc), u8(1, acc("x"))], followed(0, "field 1")),
    "construct_repeat_in_when_then_field": (
        lambda acc: [u8(0, acc("k")), when(1, eq(0, 1), rounds(1, acc)), u8(2, acc("x"))],
        followed(1, "field 2"),
    ),
    "construct_repeat_in_flags_then_field": (
        lambda acc: [flags(0, rounds(0, acc)), u8(1, acc("x"))],
        followed(0, "field 1"),
    ),
    "construct_repeat_in_group_then_field": (
        lambda acc: [group(0, rounds(0, acc)), u8(1, acc("x"))],
        followed(0, "field 1"),
    ),
    "construct_repeat_then_repeat": (lambda acc: [rounds(0, acc), rounds(1, acc, "w")], followed(0, "repeat 1")),
    "construct_repeat_then_exclusive_when": (
        lambda acc: [u8(0, acc("k")), when(1, eq(0, 1), rounds(1, acc)), when(2, eq(0, 2), u8(2, acc("x")))],
        followed(1, "field 2"),
    ),
    "construct_repeat_in_list_element": (lambda acc: [list_field(acc("items"), _element())], in_element(1)),
    "construct_repeat_in_dict_element": (lambda acc: [map_field(acc("d"), _element())], in_element(1)),
    "construct_repeat_in_times_round": (
        lambda acc: [u8(0, acc("k")), times(1, 0, rounds(1, acc))],
        in_round(1),
    ),
    # AZ-4232: the same, one container deeper. The anchored group shares the ids of the row around it, so the
    # inner repeat is id 0 under the repeat and id 1 under the times; the nesting rule looks into the group.
    "construct_repeat_in_group_in_repeat_round": (
        lambda acc: [repeat(0, group(0, rounds(0, acc)))],
        in_round(0),
    ),
    "construct_repeat_in_group_in_times_round": (
        lambda acc: [u8(0, acc("k")), times(1, 0, group(1, rounds(1, acc)))],
        in_round(1),
    ),
}

# hostile case id -> (the fields, the row's values, the packet); each is a `bytes` case of the hostile loader
KEPT: dict[str, tuple[Fields, dict[str, Any], str]] = {
    "pack_repeat_last": (lambda acc: [u8(0, acc("x")), rounds(1, acc)], {"x": 9, "v": [5, 6]}, "01090506"),
    "pack_repeat_last_in_when": (
        lambda acc: [u8(0, acc("k")), when(1, eq(0, 1), rounds(1, acc))],
        {"k": 1, "v": [5, 6]},
        "01010506",
    ),
    "pack_repeat_last_in_flags": (
        lambda acc: [flags(0, u8(0, acc("x")), rounds(1, acc))],
        {"x": 9, "v": [5, 6]},
        "0103090506",
    ),
    "pack_times_then_field": (
        lambda acc: [u8(0, acc("k")), times(1, 0, u8(1, acc("v"))), u8(2, acc("x"))],
        {"k": 2, "v": [5, 6], "x": 9},
        "0102050609",
    ),
}

# The hostile loader's own tables: dict rows, so the fields take key accessors.
LOOP113_CONSTRUCT_CASES = {
    case_id: (lambda fields=fields: Scheme(1, dict, *fields(key))) for case_id, (fields, _text) in REFUSED.items()
}
LOOP113_CONSTRUCT_REFUSAL = {case_id: text for case_id, (_fields, text) in REFUSED.items()}
# case id -> (pack call, None: each is a `bytes` case)
LOOP113_PACK_CASES = {
    case_id: (lambda fields=fields, values=values: BinaryPacker.pack(Scheme(1, dict, *fields(key)), dict(values)), None)
    for case_id, (fields, values, _packet) in KEPT.items()
}
