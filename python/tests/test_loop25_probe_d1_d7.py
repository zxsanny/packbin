from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, flag_byte, flags, group, u8, when

# Loop 25 probe rows D1 (AZ-2476) and D7 (AZ-2478), reference value taken from TypeScript.
#
# D1: TypeScript packs `flags(0, [group(0, x => x.mark, [])]), u8(0, x => x.n)` (an empty group whose
# anchor is the next id but which takes none) to 0101 / 0100 for a mark, 010303 split, 010103 with n = 3.
# A Python group has no name or accessor, so an empty group cannot carry a mark: Python refuses the scheme
# when it is built (README, "An empty group that could never set its bit"). The D1 rows are pinned as that
# refusal, and the tests are named for the difference.
#
# D7: a split flag bit inside a `when` whose condition is false packs as TypeScript, and so does the repack.

EMPTY_GROUP_REFUSAL = "group 0 has no fields, so it can never carry a value"


def _key(name: str):
    return lambda row, name=name: row[name]


def _unpack(scheme: Scheme, packet: str):
    seen: list = []
    result = BinaryPacker.unpack(bytes.fromhex(packet), scheme.on(seen.append))
    assert result.ok, packet
    assert len(seen) == 1
    return seen[0]


def _empty_group_in_flags() -> Scheme:
    return Scheme(1, dict, flags(0, group(0)))


def _empty_group_split_with_next_field() -> Scheme:
    m = flag_byte()
    return Scheme(1, dict, m, m.bit(group(0)), m.bit(u8(0, _key("n"))))


def _empty_group_then_u8_with_the_same_id() -> Scheme:
    return Scheme(1, dict, flags(0, group(0)), u8(0, _key("n")))


D1_SCHEMES = {
    "empty_group_mark": _empty_group_in_flags,
    "empty_group_mark_split": _empty_group_split_with_next_field,
    "empty_group_then_u8_with_the_same_id": _empty_group_then_u8_with_the_same_id,
}


@pytest.mark.parametrize("case", sorted(D1_SCHEMES))
def test_d1_empty_group_mark_is_refused_at_construction_differs_from_typescript(case: str):
    # Arrange
    build = D1_SCHEMES[case]

    # Act
    with pytest.raises(ValueError) as refusal:
        build()

    # Assert
    assert str(refusal.value) == EMPTY_GROUP_REFUSAL


def _split_bit_in_when() -> Scheme:
    m = flag_byte()
    return Scheme(
        1,
        dict,
        u8(0, _key("k")),
        m,
        when(1, eq(0, 1), m.bit(u8(1, _key("a")))),
        m.bit(u8(2, _key("b"))),
    )


def test_d7_split_bit_in_a_true_when_packs_the_body():
    # Arrange
    scheme = _split_bit_in_when()

    # Act
    packet = BinaryPacker.pack(scheme, {"k": 1, "a": 5, "b": 6})

    # Assert
    assert packet.hex() == "0101030506"


def test_d7_split_bit_in_a_false_when_with_the_member_given_sets_the_bit_and_writes_no_body():
    # Arrange
    scheme = _split_bit_in_when()

    # Act
    packet = BinaryPacker.pack(scheme, {"k": 0, "a": 5, "b": 6})

    # Assert: a's bit is set although the when does not match, and there is no `a` byte
    assert packet.hex() == "01000306"


def test_d7_unpack_of_the_false_when_packet_reads_no_member():
    # Arrange
    scheme = _split_bit_in_when()

    # Act
    row = _unpack(scheme, "01000306")

    # Assert
    assert row == {"k": 0, "b": 6}


def test_d7_unpack_of_the_true_when_packet_reads_the_body():
    # Arrange
    scheme = _split_bit_in_when()

    # Act
    row = _unpack(scheme, "0101030506")

    # Assert
    assert row == {"k": 1, "a": 5, "b": 6}


def test_d7_repack_of_the_unpacked_false_when_packet_clears_the_bit():
    # Arrange
    scheme = _split_bit_in_when()
    row = _unpack(scheme, "01000306")

    # Act
    repacked = BinaryPacker.pack(scheme, row)

    # Assert
    assert repacked.hex() == "01000206"
