"""AZ-4213, contract `repeat-last.md` 1.0.2: a repeat is the last thing a packet reads. A scheme that breaks the rule
is refused when it is built; a repeat that is last builds and packs the bytes it packed before.

Every scheme is built in the two forms Python has: dict rows read with key accessors and class rows read with
attribute accessors. The row of a list or dict element is always a dict, so an element's fields take key accessors.
The cases R1 to R9 and K1 to K4 of the contract are the hostile cases and sit in `repeat_last_support.py` with the
refusal texts, which the hostile loader reads too."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    bool as flag_bool,
    bytes as raw_bytes,
    dict as map_field,
    eq,
    f32,
    flag_byte,
    flags,
    group,
    list as list_field,
    packed,
    repeat,
    sized,
    times,
    u2,
    u8,
    utf8,
    when,
)
from repeat_last_support import KEPT as HOSTILE_KEPT
from repeat_last_support import REFUSED, Acc, Fields, followed, in_element, in_round, key, rounds


class Row:
    """A class row: its members are attributes."""


def _attr(name: str) -> Callable[[Any], Any]:
    return lambda row: getattr(row, name)


# form -> (row type, accessor of a member of the row)
FORMS: dict[str, tuple[type, Acc]] = {"dict_rows": (dict, key), "class_rows": (Row, _attr)}


def _refusal(fields: Fields, form: str) -> str:
    row_type, acc = FORMS[form]
    with pytest.raises(ValueError) as caught:
        Scheme(1, row_type, *fields(acc))
    return str(caught.value)


# What the refusal names: the first field after the repeat that can write a byte, the nearest place first.
FOLLOWERS: dict[str, tuple[Fields, str]] = {
    "a_later_field_of_the_when_that_holds_the_repeat_before_the_field_after_the_when": (
        lambda acc: [u8(0, acc("k")), when(1, eq(0, 1), rounds(1, acc), u8(2, acc("y"))), u8(3, acc("x"))],
        followed(1, "field 2"),
    ),
    "a_field_two_places_out_after_the_when_that_holds_the_flags_that_holds_the_repeat": (
        lambda acc: [u8(0, acc("k")), when(1, eq(0, 1), flags(1, rounds(1, acc))), u8(2, acc("x"))],
        followed(1, "field 2"),
    ),
    "a_later_member_of_the_flags_that_holds_the_repeat": (
        lambda acc: [flags(0, rounds(0, acc), u8(1, acc("x")))],
        followed(0, "field 1"),
    ),
    "a_later_member_of_the_flags_around_the_flags_that_holds_the_repeat": (
        lambda acc: [flags(0, flags(0, rounds(0, acc)), u8(1, acc("x")))],
        followed(0, "field 1"),
    ),
    "a_later_split_flag_bit": (
        lambda acc: [(byte := flag_byte()), byte.bit(rounds(0, acc)), byte.bit(u8(1, acc("x")))],
        followed(0, "field 1"),
    ),
    "a_field_under_a_group_is_named_not_the_group": (
        lambda acc: [rounds(0, acc), group(1, u8(1, acc("x")))],
        followed(0, "field 1"),
    ),
    "a_field_under_a_later_when_is_named_not_the_when": (
        lambda acc: [u8(0, acc("k")), rounds(1, acc), when(2, eq(0, 1), raw_bytes(2, acc("z"), 0), u8(3, acc("x")))],
        followed(1, "field 3"),
    ),
    "a_times_is_named_by_its_anchor": (
        lambda acc: [u8(0, acc("n")), rounds(1, acc), times(2, 0, u8(2, acc("w")))],
        followed(1, "times 2"),
    ),
    "a_flags_is_named_by_its_anchor": (
        lambda acc: [rounds(0, acc), flags(1, u8(1, acc("x")))],
        followed(0, "flags 1"),
    ),
    "a_flag_byte": (
        lambda acc: [rounds(0, acc), (byte := flag_byte()), byte.bit(u8(1, acc("x")))],
        followed(0, "a flag byte"),
    ),
    "a_list": (
        lambda acc: [rounds(0, acc), list_field(acc("items"), u8(0, lambda value: value))],
        followed(0, "a list"),
    ),
    "a_dict": (
        lambda acc: [rounds(0, acc), map_field(acc("d"), u8(0, lambda value: value))],
        followed(0, "a dict"),
    ),
    "a_u2_is_named_by_its_first_slot": (
        lambda acc: [rounds(0, acc), u2((1, acc("a")), (2, acc("b")))],
        followed(0, "field 1"),
    ),
    "a_float": (lambda acc: [rounds(0, acc), f32(1, acc("x"))], followed(0, "field 1")),
    "a_utf8": (lambda acc: [rounds(0, acc), utf8(1, acc("s"))], followed(0, "field 1")),
    "a_sized": (lambda acc: [u8(0, acc("n")), rounds(1, acc), sized(2, acc("p"), 0)], followed(1, "field 2")),
    "a_bits": (lambda acc: [u8(0, acc("n")), rounds(1, acc), bits(2, acc("b"), 0)], followed(1, "field 2")),
    "a_packed": (lambda acc: [u8(0, acc("n")), rounds(1, acc), packed(1, 2, acc("p"), 0)], followed(1, "field 2")),
    "a_zero_width_bytes_is_passed_over_for_the_field_after_it": (
        lambda acc: [rounds(0, acc), raw_bytes(1, acc("z"), 0), raw_bytes(2, acc("x"), 1)],
        followed(0, "field 2"),
    ),
    "the_first_repeat_is_named_when_a_field_follows_two": (
        lambda acc: [rounds(0, acc), repeat(1, raw_bytes(1, acc("z"), 0)), u8(2, acc("x"))],
        followed(0, "field 2"),
    ),
}

# A repeat inside an element is refused wherever it sits there, and whatever stands after it.
IN_ELEMENT: dict[str, tuple[Fields, str]] = {
    "under_a_when_of_the_element": (
        lambda acc: [
            list_field(acc("items"), group(0, u8(0, key("mode")), when(1, eq(0, 1), rounds(1, key)))),
        ],
        in_element(1),
    ),
    "under_a_flags_of_the_element": (
        lambda acc: [map_field(acc("d"), group(0, flags(0, rounds(0, key))))],
        in_element(0),
    ),
    "in_a_flags_element": (lambda acc: [list_field(acc("items"), flags(0, rounds(0, key)))], in_element(0)),
    "under_a_group_of_the_element": (
        lambda acc: [list_field(acc("items"), group(0, group(0, rounds(0, key))))],
        in_element(0),
    ),
    "under_a_split_flag_bit_of_the_element": (
        lambda acc: [list_field(acc("items"), group(0, (byte := flag_byte()), byte.bit(rounds(0, key))))],
        in_element(0),
    ),
    "in_the_element_of_a_list_inside_a_list_element": (
        lambda acc: [list_field(acc("outer"), list_field(key("inner"), group(0, rounds(0, key))))],
        in_element(0),
    ),
    "in_the_element_of_a_list_inside_a_repeat_round": (
        lambda acc: [repeat(0, u8(0, acc("k")), list_field(acc("rows"), group(0, rounds(0, key))))],
        in_element(0),
    ),
    "in_the_element_of_a_list_inside_a_times_round": (
        lambda acc: [u8(0, acc("n")), times(1, 0, list_field(acc("rows"), group(0, rounds(0, key))))],
        in_element(0),
    ),
    "with_a_field_after_it_in_the_element_the_element_text_not_the_follower_text": (
        lambda acc: [list_field(acc("items"), group(0, rounds(0, key), u8(1, key("x"))))],
        in_element(0),
    ),
    "in_the_body_of_a_repeat_that_a_field_follows_the_element_text_not_the_follower_text": (
        lambda acc: [repeat(0, u8(0, acc("k")), list_field(acc("rows"), group(0, rounds(0, key)))), u8(1, acc("x"))],
        in_element(0),
    ),
}

# The nesting, empty-body, duplicate-name and element-accessor rules run before the repeat-last rule and keep their
# texts, so a scheme that breaks two rules is answered by the earlier one.
EARLIER_RULES: dict[str, tuple[Fields, str]] = {
    "an_empty_repeat_body_before_a_field": (
        lambda acc: [repeat(0), u8(0, acc("x"))],
        "repeat 0: the body holds no member; a round of it would charge no slot and write nothing",
    ),
    "a_repeat_in_a_repeat_round_before_a_field": (
        lambda acc: [repeat(0, u8(0, acc("k")), rounds(1, acc)), u8(2, acc("x"))],
        in_round(1),
    ),
    "a_name_declared_twice_with_a_field_after_the_repeat": (
        lambda acc: [rounds(0, acc), u8(1, acc("v"))],
        "member v: declared twice in one scope; a row holds one value per name, so one would be lost",
    ),
    "an_attribute_accessor_in_an_element_with_a_repeat_in_it": (
        lambda acc: [list_field(acc("items"), group(0, u8(0, _attr("v")), rounds(1, key)))],
        "list element: field 0 uses the attribute accessor 'v'; "
        "an element row is a dict, so use a key accessor, row['v']",
    ),
}


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(REFUSED))
def test_ac1_a_refused_case_of_the_contract_is_refused_when_the_scheme_is_built(case: str, form: str):
    # Arrange: AZ-4213 AC-1, the cases R1 to R9, with dict rows and with class rows
    fields, text = REFUSED[case]

    # Act
    message = _refusal(fields, form)

    # Assert
    assert message == text


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(FOLLOWERS))
def test_ac1_the_refusal_names_the_first_field_after_the_repeat_that_can_write_a_byte(case: str, form: str):
    # Arrange: AZ-4213 AC-1, "after" is the repeat's own place and every place around it
    fields, text = FOLLOWERS[case]

    # Act
    message = _refusal(fields, form)

    # Assert
    assert message == text


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(IN_ELEMENT))
def test_ac1_a_repeat_inside_a_list_or_dict_element_is_refused(case: str, form: str):
    # Arrange: AZ-4213 AC-1, rule 2 of the contract
    fields, text = IN_ELEMENT[case]

    # Act
    message = _refusal(fields, form)

    # Assert
    assert message == text


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(EARLIER_RULES))
def test_ac1_a_scheme_that_also_breaks_an_earlier_rule_keeps_that_rules_text(case: str, form: str):
    # Arrange: AZ-4213 AC-1, the nesting, empty-body, duplicate-name and element-accessor rules run before the check
    fields, text = EARLIER_RULES[case]

    # Act
    message = _refusal(fields, form)

    # Assert
    assert message == text


@pytest.mark.parametrize(
    "build,text",
    [(list_field, "repeat is not a list element"), (map_field, "repeat is not a dictionary element")],
    ids=["list", "dict"],
)
def test_ac1_a_repeat_that_is_itself_the_element_keeps_the_refusal_of_the_builder(build: Any, text: str):
    # Arrange: AZ-4213 AC-1, the builder of a list or dict refuses a bare repeat element, before any scheme is built
    element = rounds(0, key)

    # Act
    with pytest.raises(ValueError) as caught:
        build(key("items"), element)

    # Assert
    assert str(caught.value) == text


# name -> (fields, the row's values, the packet)
Kept = dict[str, tuple[Fields, dict[str, Any], str]]

# The cases K1 to K5 of the contract; K1 to K4 are the hostile cases.
KEPT: Kept = {
    **HOSTILE_KEPT,
    "k5_a_bool_bit_of_an_earlier_flag_byte_after_the_repeat": (
        lambda acc: [
            (byte := flag_byte()),
            byte.bit(u8(0, acc("x"))),
            rounds(1, acc),
            byte.bit(flag_bool(2, acc("on"))),
        ],
        {"x": 9, "v": [5, 6], "on": True},
        "0103090506",
    ),
}

# A field after the repeat that cannot write a byte does not count.
NO_BYTE_AFTER: Kept = {
    "a_bool_member_of_the_flags_after_the_repeat": (
        lambda acc: [flags(0, u8(0, acc("x")), rounds(1, acc), flag_bool(2, acc("on")))],
        {"x": 9, "v": [5, 6], "on": True},
        "0107090506",
    ),
    "a_zero_width_bytes": (
        lambda acc: [rounds(0, acc), raw_bytes(1, acc("z"), 0)],
        {"v": [5, 6], "z": b""},
        "010506",
    ),
    "a_when_that_holds_only_a_zero_width_bytes": (
        lambda acc: [u8(0, acc("k")), rounds(1, acc), when(2, eq(0, 1), raw_bytes(2, acc("z"), 0))],
        {"k": 1, "v": [5, 6], "z": b""},
        "01010506",
    ),
    "a_group_that_holds_only_a_zero_width_bytes": (
        lambda acc: [rounds(0, acc), group(1, raw_bytes(1, acc("z"), 0))],
        {"v": [5, 6], "z": b""},
        "010506",
    ),
    "a_times_whose_body_holds_only_a_zero_width_bytes_with_no_round": (
        lambda acc: [u8(0, acc("n")), rounds(1, acc), times(2, 0, raw_bytes(2, acc("z"), 0))],
        {"n": 0, "v": [5, 6]},
        "01000506",
    ),
    "a_repeat_whose_body_holds_only_a_zero_width_bytes_with_no_round": (
        lambda acc: [rounds(0, acc), repeat(1, raw_bytes(1, acc("z"), 0))],
        {"v": [5, 6]},
        "010506",
    ),
}


def _round_trip(fields: Fields, values: dict[str, Any], form: str) -> tuple[str, dict[str, Any] | None]:
    """The packet of the values, in hex, and the values its unpack gives (None when it is refused)."""
    row_type, acc = FORMS[form]
    scheme = Scheme(1, row_type, *fields(acc))
    row: Any = dict(values)
    if row_type is Row:
        row = Row()
        vars(row).update(values)
    wire = BinaryPacker.pack(scheme, row)
    result = BinaryPacker.unpack(wire, scheme.on(lambda _row: None))
    if not result.ok:
        return wire.hex(), None
    return wire.hex(), result.value if row_type is dict else vars(result.value)


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(KEPT))
def test_ac2_a_repeat_that_is_the_last_thing_read_builds_and_packs_the_same_bytes(case: str, form: str):
    # Arrange: AZ-4213 AC-2, the cases K1 to K5 with the contract's values
    fields, values, packet = KEPT[case]

    # Act
    wire, back = _round_trip(fields, values, form)

    # Assert
    assert (wire, back) == (packet, values)


@pytest.mark.parametrize("form", sorted(FORMS))
@pytest.mark.parametrize("case", sorted(NO_BYTE_AFTER))
def test_ac1_a_field_after_the_repeat_that_cannot_write_a_byte_does_not_refuse_the_scheme(case: str, form: str):
    # Arrange: AZ-4213 AC-1, unit row 2
    fields, values, packet = NO_BYTE_AFTER[case]

    # Act
    wire, back = _round_trip(fields, values, form)

    # Assert
    assert (wire, back) == (packet, values)
