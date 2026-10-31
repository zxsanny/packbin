from __future__ import annotations

import random

import pytest

from packbin import BinaryPacker, Scheme, flags, u8, u16, u32, utf8

import ecc_support as support
import percent_support as ps

# AZ-3512: a parity percentage over a message whose length varies by an optional field (AC-17, S12b), over a string
# field read after the repair (AC-18, S12c), and the refusal of a dispatch mix naming the percentage (AC-19, D4).

OPTIONAL = Scheme(
    1,
    dict,
    u32(0, lambda row: row["a"]),
    u32(1, lambda row: row["b"]),
    flags(2, u16(2, lambda row: row["h"]), u8(3, lambda row: row["s"])),
).with_limits(parity_percent=25)
WITH_FIELD = {"a": 1, "b": 2, "h": 3, "s": 4}
WITHOUT_FIELD = {"a": 1, "b": 2}

TEXT = Scheme(1, dict, utf8(0, lambda row: row["s"]), u8(1, lambda row: row["n"])).with_limits(parity_percent=25)


@pytest.mark.parametrize("row,clear,parity", [(WITH_FIELD, 13, 4), (WITHOUT_FIELD, 10, 3)])
def test_ac1_a_message_with_and_one_without_the_optional_field_carry_their_own_count_and_round_trip(
    row: dict, clear: int, parity: int
):
    # Arrange
    packet = BinaryPacker.pack(OPTIONAL, row)
    damaged, _ = support.corrupt(random.Random(9), packet, parity // 2)

    # Act
    intact = support.read(packet, OPTIONAL)
    repaired = support.read(damaged, OPTIONAL, limit=parity // 2)

    # Assert
    assert len(packet) == clear + parity
    assert (intact.ok, intact.repaired, repaired.ok, repaired.repaired) == (True, 0, True, parity // 2)


def test_ac1_the_values_of_both_messages_come_back_intact():
    # Arrange
    seen: list = []

    # Act
    for row in (WITH_FIELD, WITHOUT_FIELD):
        BinaryPacker.unpack(BinaryPacker.pack(OPTIONAL, row), OPTIONAL.on(seen.append))

    # Assert
    assert [(r["a"], r["b"], r.get("h"), r.get("s")) for r in seen] == [(1, 2, 3, 4), (1, 2, None, None)]


@pytest.mark.parametrize("text", ["pack bin ecc 0123456789", "Олександр, диспетчер", "gps_fix 48.46"])
def test_ac2_one_wrong_byte_inside_the_string_is_repaired_and_the_string_is_the_original(text: str):
    # Arrange
    seen: list = []
    packet = BinaryPacker.pack(TEXT, {"s": text, "n": 200})
    failures = []

    # Act
    for place in range(len(packet)):
        word = bytearray(packet)
        word[place] ^= 0x5A
        result = BinaryPacker.unpack(bytes(word), TEXT.on(seen.append), limit=1)
        if not (result.ok and result.repaired == 1):
            failures.append(place)

    # Assert
    assert failures == []
    assert all(row == {"s": text, "n": 200} for row in seen) and len(seen) == len(packet)


def test_ac3_a_handler_of_25_percent_with_a_handler_of_count_25_is_refused_telling_the_percentage():
    # Arrange
    seen: list = []
    percent, count = ps.percent_scheme(25, 0x40), support.raw_scheme(0x41, 25)

    # Act
    with pytest.raises(ValueError) as percent_first:
        BinaryPacker.unpack(b"\x40\x00", percent.on(seen.append), count.on(seen.append))
    with pytest.raises(ValueError) as count_first:
        BinaryPacker.unpack(b"\x40\x00", count.on(seen.append), percent.on(seen.append))

    # Assert
    assert "25 percent and 25 (" in str(percent_first.value)
    assert "25 and 25 percent (" in str(count_first.value)
    assert seen == []
