from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, bits, eq, flag_byte, flags, packed, sized, times, u8, u16, when

# Loop 21 probes of `_docs/03_implementation/reference_loop21_slots.md` section 5.
# AZ-2384 (U4, rows 40 to 43): Python packs a clear bit already, no change.
# AZ-2386 (U6, rows 44 to 52): a count above 0 that no field wrote, behind a clear `when`, is refused.
# AZ-2387 (U7, rows 53 to 55): `bits`, `packed` and `sized` with a value behind a clear `when` are refused already;
# row 56 (no value) is refused since AZ-2410 (loop 22), see tests/test_loop22_parity.py.
# Python differences: the U6 text is the reference text with Python's names (`pt`, `c`); the rows that
# TypeScript refuses with its own texts (43, 49, 52, 53) are refused here with the Python texts pinned by loops 19,
# 20 and 25 (`times 1: body values are given ...`, `times: count 1 was not written`, `2: count 1 was not written`;
# AZ-2474 switched `RuntimeError("count N is missing")` to `ValueError("count N was not written")`).


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _heading(field_id: int):
    return u16(field_id, lambda row: row["heading"])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _refusal(scheme: Scheme, row: dict) -> tuple[type, str]:
    with pytest.raises(Exception) as caught:
        BinaryPacker.pack(scheme, row)
    return type(caught.value), str(caught.value)


def _split_times_after_byte() -> Scheme:
    byte = flag_byte()
    return Scheme(1, dict, byte, _u8(0, "n"), byte.bit(times(1, 0, _u8(1, "pt"))), byte.bit(_heading(2)))


@pytest.mark.parametrize(
    "row,expected",
    [
        ({"n": 2, "heading": 90}, "0102025a00"),
        ({"n": 2, "pt": [], "heading": 90}, "0102025a00"),
        ({"n": 0, "heading": 90}, "0102005a00"),
    ],
    ids=["row40", "row41", "row42"],
)
def test_az2384_ac1_rows40_to_42_a_count_after_the_byte_with_no_body_packs_a_clear_bit(row: dict, expected: str):
    # Arrange / Act / Assert
    assert _pack(_split_times_after_byte(), row) == expected


def test_az2384_ac2_row43_a_body_given_after_the_byte_is_refused():
    # Arrange
    row = {"n": 2, "pt": [5, 6], "heading": 90}

    # Act
    kind, message = _refusal(_split_times_after_byte(), row)

    # Assert
    assert kind is ValueError
    assert message.startswith("times 1: body values are given, but count field 0 has no value")


CLEAR_COUNT = (
    "pt: the count c is {n} in the row, but no field wrote it (the when that holds it is clear), so its times "
    "reads no round; give the count 0, leave it out, or make the when hold"
)


def _count_behind_when(position: str) -> Scheme:
    head = (_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")))
    body = times(2, 1, _u8(2, "pt"))
    if position == "split":
        byte = flag_byte()
        return Scheme(1, dict, *head, byte, byte.bit(body), byte.bit(_heading(3)))
    if position == "flags":
        return Scheme(1, dict, *head, flags(2, body, _heading(3)))
    return Scheme(1, dict, *head, body, _heading(3))


@pytest.mark.parametrize(
    "row,count",
    [
        ({"mode": 0, "c": 1, "heading": 90}, 1),
        ({"mode": 0, "c": 1, "pt": [], "heading": 90}, 1),
        ({"mode": 0, "c": 3, "heading": 90}, 3),
    ],
    ids=["row44", "row45", "row46"],
)
def test_az2386_ac1_rows44_to_46_a_split_bit_count_above_zero_behind_a_clear_when_is_refused(row: dict, count: int):
    # Arrange / Act
    kind, message = _refusal(_count_behind_when("split"), row)

    # Assert
    assert (kind, message) == (ValueError, CLEAR_COUNT.format(n=count))


@pytest.mark.parametrize(
    "row",
    [{"mode": 0, "c": 0, "heading": 90}, {"mode": 0, "heading": 90}],
    ids=["row47_count_zero", "row48_count_left_out"],
)
def test_az2386_ac2_rows47_and_48_count_zero_and_no_count_pack_a_clear_bit(row: dict):
    # Arrange / Act / Assert
    assert _pack(_count_behind_when("split"), row) == "0100025a00"


def test_az2386_row49_values_given_behind_the_clear_when_are_refused_by_the_earlier_rule():
    # Arrange
    row = {"mode": 0, "c": 2, "pt": [5, 6], "heading": 90}

    # Act
    kind, message = _refusal(_count_behind_when("split"), row)

    # Assert
    assert kind is ValueError
    assert message.startswith("times 2: body values are given, but count field 1 has no value")


def test_az2386_ac1_row50_a_combined_flags_count_above_zero_behind_a_clear_when_is_refused():
    # Arrange
    row = {"mode": 0, "c": 2, "heading": 90}

    # Act
    kind, message = _refusal(_count_behind_when("flags"), row)

    # Assert
    assert (kind, message) == (ValueError, CLEAR_COUNT.format(n=2))


def test_az2386_ac2_row50_a_combined_flags_count_zero_packs():
    # Arrange / Act / Assert
    assert _pack(_count_behind_when("flags"), {"mode": 0, "c": 0, "heading": 90}) == "0100025a00"


def test_az2386_row51_a_holding_when_packs_the_rounds():
    # Arrange
    row = {"mode": 1, "c": 1, "pt": [5], "heading": 90}

    # Act / Assert
    assert _pack(_count_behind_when("split"), row) == "01010103055a00"


@pytest.mark.parametrize("count", [1, 0])
def test_az2386_row52_a_plain_times_behind_a_clear_when_is_refused_for_any_count(count: int):
    # Arrange
    row = {"mode": 0, "c": count, "heading": 90}

    # Act
    kind, message = _refusal(_count_behind_when("plain"), row)

    # Assert
    assert (kind, message) == (ValueError, "times: count 1 was not written")


def test_az2386_a_count_a_field_wrote_after_the_byte_is_not_refused():
    # Arrange
    byte = flag_byte()
    scheme = Scheme(1, dict, byte, _u8(0, "n"), byte.bit(times(1, 0, _u8(1, "pt"))))

    # Act / Assert
    assert _pack(scheme, {"n": 2}) == "010002"


def _counted(member: str, position: str) -> Scheme:
    head = (_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")))
    node = {
        "bits": lambda: bits(2, lambda row: row["v"], 1),
        "packed": lambda: packed(1, 2, lambda row: row["v"], 1),
        "sized": lambda: sized(2, lambda row: row["v"], 1),
    }[member]()
    if position == "plain":
        return Scheme(1, dict, *head, node)
    if position == "split":
        byte = flag_byte()
        return Scheme(1, dict, *head, byte, byte.bit(node))
    return Scheme(1, dict, *head, flags(2, node))


def _value(member: str):
    return b"\x01\x02\x03" if member == "sized" else [1, 0, 1]


@pytest.mark.parametrize("position", ["plain", "split", "flags"])
@pytest.mark.parametrize("member", ["bits", "packed", "sized"])
def test_az2387_ac1_row53_a_counted_member_behind_a_clear_when_is_refused(member: str, position: str):
    # Arrange
    row = {"mode": 0, "c": 3, "v": _value(member)}

    # Act
    kind, message = _refusal(_counted(member, position), row)

    # Assert
    assert kind is ValueError
    assert message.endswith("was not written") and message.startswith("2: count")


@pytest.mark.parametrize(
    "member,position,expected",
    [
        ("bits", "plain", "01010305"),
        ("packed", "plain", "01010305"),
        ("bits", "split", "0101030105"),
        ("packed", "split", "0101030105"),
        ("sized", "plain", "010103010203"),
        ("sized", "split", "01010301010203"),
    ],
)
def test_az2387_ac2_rows54_and_55_a_holding_when_packs(member: str, position: str, expected: str):
    # Arrange
    row = {"mode": 1, "c": 3, "v": _value(member)}

    # Act / Assert
    assert _pack(_counted(member, position), row) == expected


@pytest.mark.parametrize("position", ["split", "flags"])
@pytest.mark.parametrize("member", ["bits", "packed", "sized"])
def test_az2387_row56_no_value_and_count_zero_behind_a_clear_when_pack_a_clear_bit(member: str, position: str):
    # Arrange: AZ-2410 (loop 22) refuses the same row with a count above 0 (tests/test_loop22_parity.py)
    row = {"mode": 0, "c": 0}

    # Act / Assert
    assert _pack(_counted(member, position), row) == "010000"
