from __future__ import annotations

from typing import Callable

import pytest

from packbin import BinaryPacker, Scheme, bits, eq, flag_byte, flags, group, packed, repeat, sized, times, u8, when

# AZ-2436 (G3 of assessment 22): the U11 no-value count refusal of `reference_loop22.md` section 1 (row 56), pinned
# away from the top level. Row 56 is `u8 mode; when(mode == 1) { u8 c }; <bit> { member counted by c }` with
# `{mode: 0, c: 3}` and no value: refused, member and count named. Python's error is a `ValueError` (TypeScript:
# `RangeError`), the text is the same. Every position below is spelled with the split bit and with combined `flags`,
# for `bits`, `packed` (width 1, bias 0) and `sized`.
#
# Positions (probed first; Python can spell all of them):
#   AC-1 group_member         the member inside a group under the bit: `<bit> { group { member } }`
#   AC-1 group_whole          the whole row 56 shape inside a group: `group { mode; when { c }; <bit> { member } }`
#   AC-2 nested_count         the count behind nested whens, outer holds, inner clear:
#                             `u8 mode; u8 o; when(o == 1) { when(mode == 1) { u8 c } }; <bit> { member }`
#   AC-2 shape_in_when        the whole shape behind an outer holding when, the count's (inner) when clear:
#                             `u8 o; when(o == 1) { u8 mode; when(mode == 1) { u8 c }; <bit> { member } }`
#   AC-2 member_holding_when  a bit holding a holding when around the member:
#                             `u8 o; u8 mode; when(mode == 1) { u8 c }; <bit> { when(o == 1) { member } }`
#   AC-3 times / repeat       the row 56 shape as a round body; count 3 with no value in one round
# Same shapes and hex as `typescript/tests/loop23-novalue-nested.test.ts` (TypeScript groups take a nested row,
# Python groups read the same row; nested_count is a Python-only extra). AC-2 as amended on 2026-10-13: a counted
# member inside the clear `when` itself (member_in_clear_when) is the existing silent skip, pinned as observed.
# AC-4 rows (count 0, count left out, holding inner `when` with and without a value) pin the hex packed at b8b2809.

MEMBERS = ["bits", "packed", "sized"]
POSITIONS = ["split", "flags"]
VALUES = {"bits": [1, 0, 1], "packed": [1, 0, 1], "sized": b"\x01\x02\x03"}


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _member(kind: str, field_id: int, count_id: int):
    get = lambda row: row["v"]  # noqa: E731
    if kind == "bits":
        return bits(field_id, get, count_id)
    if kind == "packed":
        return packed(1, field_id, get, count_id)
    return sized(field_id, get, count_id)


def _bit(position: str, anchor: int, node) -> list:
    if position == "split":
        byte = flag_byte()
        return [byte, byte.bit(node)]
    return [flags(anchor, node)]


def _head() -> list:
    return [_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c"))]


Builder = Callable[[str, str], Scheme]

SCHEMES: dict[str, Builder] = {
    "group_member": lambda kind, position: Scheme(
        1, dict, *_head(), *_bit(position, 2, group(2, _member(kind, 2, 1)))
    ),
    "group_whole": lambda kind, position: Scheme(
        1, dict, group(0, *_head(), *_bit(position, 2, _member(kind, 2, 1)))
    ),
    "nested_count": lambda kind, position: Scheme(
        1,
        dict,
        _u8(0, "mode"),
        _u8(1, "o"),
        when(2, eq(1, 1), when(2, eq(0, 1), _u8(2, "c"))),
        *_bit(position, 3, _member(kind, 3, 2)),
    ),
    "shape_in_when": lambda kind, position: Scheme(
        1,
        dict,
        _u8(0, "o"),
        when(1, eq(0, 1), _u8(1, "mode"), when(2, eq(1, 1), _u8(2, "c")), *_bit(position, 3, _member(kind, 3, 2))),
    ),
    "member_holding_when": lambda kind, position: Scheme(
        1,
        dict,
        _u8(0, "o"),
        _u8(1, "mode"),
        when(2, eq(1, 1), _u8(2, "c")),
        *_bit(position, 3, when(3, eq(0, 1), _member(kind, 3, 2))),
    ),
    # The spec's literal `when(holds) { when(clear) { counted member } }`: observed silent skip, not U11.
    "member_in_clear_when": lambda kind, position: Scheme(
        1,
        dict,
        _u8(0, "o"),
        when(1, eq(0, 1), _u8(1, "mode"), when(2, eq(1, 1), _u8(2, "c"), *_bit(position, 3, _member(kind, 3, 2)))),
    ),
    "times": lambda kind, position: Scheme(
        1,
        dict,
        _u8(0, "n"),
        times(1, 0, _u8(1, "mode"), when(2, eq(1, 1), _u8(2, "c")), *_bit(position, 3, _member(kind, 3, 2))),
    ),
    "repeat": lambda kind, position: Scheme(
        1, dict, repeat(0, *_head(), *_bit(position, 2, _member(kind, 2, 1)))
    ),
}

# (position, row with count 3 and no value, AC)
REFUSED = [
    ("group_member", {"mode": 0, "c": 3}, "AC-1"),
    ("group_whole", {"mode": 0, "c": 3}, "AC-1"),
    ("nested_count", {"mode": 0, "o": 1, "c": 3}, "AC-2"),
    ("shape_in_when", {"o": 1, "mode": 0, "c": 3}, "AC-2"),
    ("member_holding_when", {"o": 1, "mode": 0, "c": 3}, "AC-2"),
    ("times", {"n": 2, "mode": [1, 0], "c": [3, 3]}, "AC-3"),
    ("times", {"n": 2, "mode": [1, 0], "c": [0, 3]}, "AC-3"),
    ("times", {"n": 1, "mode": [0], "c": [3]}, "AC-3"),
    ("times", {"n": 2, "mode": [0, 1], "c": [3, 3]}, "AC-3"),
    ("times", {"n": 1, "mode": 0, "c": 3}, "AC-3"),
    ("repeat", {"mode": [1, 0], "c": [3, 3]}, "AC-3"),
    ("repeat", {"mode": [1, 0], "c": [0, 3]}, "AC-3"),
    ("repeat", {"mode": [0], "c": [3]}, "AC-3"),
    ("repeat", {"mode": [0, 1], "c": [3, 3]}, "AC-3"),
    ("repeat", {"mode": 0, "c": 3}, "AC-3"),
]

# (position, row, hex at b8b2809): count 0, count left out, holding inner `when` with no value (row 56c shape)
UNCHANGED = [
    ("group_member", {"mode": 0, "c": 0}, "010000"),
    ("group_member", {"mode": 0}, "010000"),
    ("group_member", {"mode": 1, "c": 3}, "01010300"),
    ("group_whole", {"mode": 0, "c": 0}, "010000"),
    ("group_whole", {"mode": 0}, "010000"),
    ("group_whole", {"mode": 1, "c": 3}, "01010300"),
    ("nested_count", {"mode": 0, "o": 1, "c": 0}, "01000100"),
    ("nested_count", {"mode": 0, "o": 1}, "01000100"),
    ("nested_count", {"mode": 1, "o": 1, "c": 3}, "0101010300"),
    ("shape_in_when", {"o": 1, "mode": 0, "c": 0}, "01010000"),
    ("shape_in_when", {"o": 1, "mode": 0}, "01010000"),
    ("shape_in_when", {"o": 1, "mode": 1, "c": 3}, "0101010300"),
    ("member_holding_when", {"o": 1, "mode": 0, "c": 0}, "01010000"),
    ("member_holding_when", {"o": 1, "mode": 0}, "01010000"),
    ("member_holding_when", {"o": 1, "mode": 1, "c": 3}, "0101010300"),
    ("times", {"n": 2, "mode": [1, 0], "c": [3, 0]}, "01020103000000"),
    ("times", {"n": 2, "mode": [0, 1], "c": [0, 3]}, "01020000010300"),
    ("times", {"n": 2, "mode": [0, 0]}, "010200000000"),
    ("times", {"n": 2, "mode": [1, 0], "c": [0, 0]}, "01020100000000"),
    ("times", {"n": 1, "mode": [0]}, "01010000"),
    ("times", {"n": 1, "mode": [1], "c": [3]}, "0101010300"),
    ("times", {"n": 2, "mode": [1, 0], "c": [3, None]}, "01020103000000"),
    ("times", {"n": 2, "mode": [1, 1], "c": [3, 3]}, "0102010300010300"),
    ("repeat", {"mode": [1, 0], "c": [3, 0]}, "010103000000"),
    ("repeat", {"mode": [0, 1], "c": [0, 3]}, "010000010300"),
    ("repeat", {"mode": [0, 0]}, "0100000000"),
    ("repeat", {"mode": [1, 0], "c": [0, 0]}, "010100000000"),
    ("repeat", {"mode": [0]}, "010000"),
    ("repeat", {"mode": [1], "c": [3]}, "01010300"),
    ("repeat", {"mode": [1, 0], "c": [3, None]}, "010103000000"),
    ("repeat", {"mode": [1, 1], "c": [3, 3]}, "01010300010300"),
]

# (position, row without the value, hex for bits / packed, hex for sized): holding inner `when` with a value
WITH_VALUE = [
    ("group_member", {"mode": 1, "c": 3}, "0101030105", "01010301010203"),
    ("group_whole", {"mode": 1, "c": 3}, "0101030105", "01010301010203"),
    ("nested_count", {"mode": 1, "o": 1, "c": 3}, "010101030105", "0101010301010203"),
    ("shape_in_when", {"o": 1, "mode": 1, "c": 3}, "010101030105", "0101010301010203"),
    ("member_holding_when", {"o": 1, "mode": 1, "c": 3}, "010101030105", "0101010301010203"),
    ("times", {"n": 1, "mode": [1], "c": [3]}, "010101030105", "0101010301010203"),
    ("repeat", {"mode": [1], "c": [3]}, "0101030105", "01010301010203"),
]


def _no_value(count: int) -> str:
    return (
        f"v: the count c is {count} in the row, but no field wrote it (the when that holds it is clear), "
        "so the member reads nothing; give the count 0, leave it out, or make the when hold"
    )


def _ids(cases: list) -> list[str]:
    return [f"{case[0]}-{index}" for index, case in enumerate(cases)]


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize("shape,row,ac", REFUSED, ids=_ids(REFUSED))
def test_az2436_ac1_to_ac3_a_no_value_count_above_zero_is_refused_in_nested_positions(
    shape: str, row: dict, ac: str, member: str, position: str
):
    # Arrange
    scheme = SCHEMES[shape](member, position)

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, row)

    # Assert
    assert str(caught.value.args[0]) == _no_value(3), ac


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize("shape,row,expected", UNCHANGED, ids=_ids(UNCHANGED))
def test_az2436_ac4_count_zero_left_out_and_a_holding_when_pack_as_at_head(
    shape: str, row: dict, expected: str, member: str, position: str
):
    # Arrange
    scheme = SCHEMES[shape](member, position)

    # Act
    packet = BinaryPacker.pack(scheme, row)

    # Assert
    assert packet.hex() == expected


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize("shape,row,counted_hex,sized_hex", WITH_VALUE, ids=_ids(WITH_VALUE))
def test_az2436_ac4_a_holding_when_with_a_value_packs_as_at_head(
    shape: str, row: dict, counted_hex: str, sized_hex: str, member: str, position: str
):
    # Arrange
    value = VALUES[member]
    full = {**row, "v": [value] if shape in ("times", "repeat") else value}

    # Act
    packet = BinaryPacker.pack(SCHEMES[shape](member, position), full)

    # Assert
    assert packet.hex() == (sized_hex if member == "sized" else counted_hex)


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
def test_az2436_a_member_under_a_clear_when_inside_the_bit_is_not_reached_and_packs(member: str, position: str):
    # Arrange: the when around the member under the bit is clear, so the rule does not look at the member
    scheme = SCHEMES["member_holding_when"](member, position)

    # Act / Assert
    assert BinaryPacker.pack(scheme, {"o": 0, "mode": 0, "c": 3}).hex() == "01000000"


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
def test_az2436_ac2_observed_a_member_inside_the_clear_inner_when_is_a_silent_skip(member: str, position: str):
    # Arrange: the count, the bit and the member all sit in the clear inner when; nothing of them is written
    scheme = SCHEMES["member_in_clear_when"](member, position)

    # Act / Assert: as TypeScript (`loop23-novalue-nested.test.ts`), only the outer bytes
    assert BinaryPacker.pack(scheme, {"o": 1, "mode": 0, "c": 3}).hex() == "010100"


# AZ-2437: the U11 check reads a round's count as absent when the count list has no entry for that round, so a
# short count list whose missing round has a clear `when` packs (as TypeScript); at HEAD (2a76f1e) the check read
# past the end of the list and refused it. A round whose `when` holds still needs its entry (refused as at HEAD).
SHORT_COUNT_LIST = [
    ("times", {"n": 2, "mode": [1, 0], "c": [3]}, "01020103000000"),
    ("times", {"n": 2, "mode": [1, 0], "c": [3, None]}, "01020103000000"),
    ("repeat", {"mode": [1, 0], "c": [3]}, "010103000000"),
    ("repeat", {"mode": [1, 0], "c": [3, None]}, "010103000000"),
]


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize("shape,row,expected", SHORT_COUNT_LIST, ids=_ids(SHORT_COUNT_LIST))
def test_az2437_ac1_a_short_count_list_whose_missing_round_is_clear_packs(
    shape: str, row: dict, expected: str, member: str, position: str
):
    # Arrange
    scheme = SCHEMES[shape](member, position)

    # Act
    packet = BinaryPacker.pack(scheme, row)

    # Assert
    assert packet.hex() == expected


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize(
    "shape,row,kind,text",
    [
        ("times", {"n": 2, "mode": [1, 1], "c": [3]}, ValueError, "2: 1 items, times count is 2"),
        ("repeat", {"mode": [1, 1], "c": [3]}, KeyError, "missing field c"),
    ],
    ids=["times", "repeat"],
)
def test_az2437_ac3_a_holding_round_with_no_count_entry_is_refused_as_at_head(
    shape: str, row: dict, kind: type, text: str, member: str, position: str
):
    # Arrange
    scheme = SCHEMES[shape](member, position)

    # Act
    with pytest.raises(kind) as caught:
        BinaryPacker.pack(scheme, row)

    # Assert
    assert str(caught.value.args[0]) == text
