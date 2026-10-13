from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    bits,
    eq,
    flag_byte,
    flags,
    group,
    packed,
    repeat,
    sized,
    times,
    u8,
    when,
)
from packbin import list as list_field

# Loop 22 rows of `_docs/03_implementation/reference_loop22.md` (TypeScript reference).
# AZ-2410 (U11, section 1): a `bits`, `packed` or `sized` count above 0 that no field wrote, behind a clear `when`,
# is refused with no value given. Python's error is a `ValueError` (TypeScript: `RangeError`), the text is the same.
# AZ-2413 (U14, section 3b): a lone value and a `when` list outside `flags` pack in a `repeat`; a short required
# list is refused, naming the member (`KeyError`, where TypeScript says `missing b`).
# AZ-2415 (U17, section 2): the default `max_slots` is 1 048 576.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _refusal(scheme: Scheme, row: dict, kind: type = ValueError) -> str:
    with pytest.raises(kind) as caught:
        BinaryPacker.pack(scheme, row)
    return str(caught.value.args[0])


def _unpacked(scheme: Scheme, hex_bytes: str):
    result = BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))
    assert result.ok
    return result.value


def _counted(member: str, position: str, bias: int = 0) -> Scheme:
    head = (_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")))
    node = {
        "bits": lambda: bits(2, lambda row: row["v"], 1),
        "packed": lambda: packed(1, 2, lambda row: row["v"], 1, bias),
        "sized": lambda: sized(2, lambda row: row["v"], 1),
    }[member]()
    if position == "plain":
        return Scheme(1, dict, *head, node)
    if position == "split":
        byte = flag_byte()
        return Scheme(1, dict, *head, byte, byte.bit(node))
    return Scheme(1, dict, *head, flags(2, node))


def _no_value(count: int) -> str:
    return (
        f"v: the count c is {count} in the row, but no field wrote it (the when that holds it is clear), "
        "so the member reads nothing; give the count 0, leave it out, or make the when hold"
    )


POSITIONS = ["split", "flags"]
MEMBERS = ["bits", "packed", "sized"]


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize("count", [3, 4, 1, 300])
def test_az2410_ac1_row56_a_count_above_zero_with_no_value_behind_a_clear_when_is_refused(
    member: str, position: str, count: int
):
    # Arrange
    row = {"mode": 0, "c": count}

    # Act / Assert
    assert _refusal(_counted(member, position), row) == _no_value(count)


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
@pytest.mark.parametrize(
    "row",
    [{"mode": 0, "c": 0}, {"mode": 0}, {"mode": 0, "c": -1}, {"mode": 0, "c": True}],
    ids=["count0_56a", "left_out_56b", "negative", "bool"],
)
def test_az2410_ac2_rows56a_and_56b_count_zero_and_a_left_out_count_pack_a_clear_bit(
    member: str, position: str, row: dict
):
    # Arrange / Act / Assert
    assert _pack(_counted(member, position), row) == "010000"


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("member", MEMBERS)
def test_az2410_row56c_a_holding_when_with_no_value_packs_a_count_and_no_items(member: str, position: str):
    # Arrange / Act / Assert
    assert _pack(_counted(member, position), {"mode": 1, "c": 3}) == "01010300"


@pytest.mark.parametrize("member", MEMBERS)
def test_az2410_ac3_row56_plain_position_is_unchanged(member: str):
    # Arrange / Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(_counted(member, "plain"), {"mode": 0, "c": 3})

    # Assert
    assert str(caught.value).startswith("2: count") and str(caught.value).endswith("was not written")


def test_az2410_row56d_packed_compares_the_count_after_the_bias():
    # Arrange
    scheme = _counted("packed", "split", bias=-1)

    # Act / Assert: count 1 minus 1 is 0; count 3 is refused with the count as the row gives it
    assert _pack(scheme, {"mode": 0, "c": 1}) == "010000"
    assert _refusal(scheme, {"mode": 0, "c": 3}) == _no_value(3)


def test_az2410_a_count_a_field_wrote_before_the_member_is_not_refused():
    # Arrange: the count field is written, so no `when` is clear
    byte = flag_byte()
    scheme = Scheme(1, dict, byte, _u8(0, "c"), byte.bit(bits(1, lambda row: row["v"], 0)))

    # Act / Assert
    assert _pack(scheme, {"c": 3}) == "0100" + "03"


def _repeat_k() -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "k")))


def _repeat_ab() -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "a"), _u8(1, "b")))


def _repeat_k_when_v() -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"))))


@pytest.mark.parametrize(
    "scheme,row,expected",
    [
        (_repeat_k, {"k": 7}, "0107"),
        (_repeat_k, {"k": [7]}, "0107"),
        (_repeat_k, {"k": [7, 8]}, "010708"),
        (_repeat_ab, {"a": [1, 2], "b": 7}, "0101070207"),
        (_repeat_ab, {"a": 1, "b": [5, 6]}, "0101050106"),
        (_repeat_ab, {"a": [1, 2], "b": [5, 6]}, "0101050206"),
        (_repeat_ab, {"a": 1, "b": 5}, "010105"),
        (_repeat_k_when_v, {"k": [1, 2], "v": [9]}, "01010902"),
        (_repeat_k_when_v, {"k": [1, 2], "v": [9, 8]}, "01010902"),
        (_repeat_k_when_v, {"k": [1, 1], "v": [9, 8]}, "0101090108"),
        (_repeat_k_when_v, {"k": [1, 1], "v": 9}, "0101090109"),
        (_repeat_k_when_v, {"k": [2, 2], "v": [9]}, "010202"),
    ],
    ids=["R1a", "R1b1", "R1b2", "R2a", "R2b", "R2c", "both_lone", "R3a", "R3b", "R3c", "R3e", "R3f"],
)
def test_az2413_ac2_rows_r1_to_r3_pack_to_the_bytes_of_the_other_packages(scheme, row: dict, expected: str):
    # Arrange / Act / Assert
    assert _pack(scheme(), row) == expected


@pytest.mark.parametrize(
    "row,member",
    [
        ({"a": [1, 2, 3], "b": [5]}, "b"),
        ({"a": [1], "b": [5, 6, 7]}, "a"),
        ({"a": [1, 2], "b": []}, "b"),
    ],
    ids=["R2d", "R2e", "R2f"],
)
def test_az2413_rows_r2d_to_r2f_a_short_required_list_is_refused_naming_the_member(row: dict, member: str):
    # Arrange / Act / Assert
    assert _refusal(_repeat_ab(), row, KeyError) == f"missing field {member}"


def test_az2413_row_r3d_a_held_when_with_too_few_entries_is_refused_naming_the_member():
    # Arrange / Act / Assert
    assert _refusal(_repeat_k_when_v(), {"k": [1, 1], "v": [9]}, KeyError) == "missing field v"


def test_az2413_ac2_the_packed_rows_unpack_to_one_entry_per_round():
    # Arrange / Act / Assert
    assert _unpacked(_repeat_ab(), "0101070207") == {"a": [1, 2], "b": [7, 7]}
    assert _unpacked(_repeat_k_when_v(), "01010902") == {"k": [1, 2], "v": [9, None]}


def _f10_scheme() -> Scheme:
    items = group(
        0,
        _u8(0, "n"),
        times(1, 0, *[u8(1 + i, lambda row, i=i: row[f"k{i}"]) for i in range(64)]),
    )
    return Scheme(1, dict, list_field(lambda row: row["items"], items))


def test_az2415_ac2_the_f10_packet_is_refused_by_the_slots_at_the_default_limit():
    # Arrange: 65 535 items of one round of 64 names; 4 194 240 slots in all, the old worst case for memory
    packet = b"\x01\xff\xff" + (b"\x01" * 65) * 65535
    seen: list = []

    # Act
    result = BinaryPacker.unpack(packet, _f10_scheme().on(seen.append))

    # Assert: refused at the 16 385th item, after 16 384 items charged 1 048 576 slots
    assert result.ok is False
    assert seen == []
    assert result.error == ShortPacket(field="1", needed=0, left=3_194_814)
