from __future__ import annotations

import random

import pytest

from packbin import BinaryPacker, ShortPacket, TooLong, Uncorrectable

import ecc_support as support
import percent_support as ps

# AZ-3500 AC-1 to AC-7: the parity percentage of a scheme (contract `message-ecc.md` 1.1.0), through the public
# scheme, pack and unpack. The row words of the shared file are read in `test_ecc_percent_vectors.py`.

PERCENTS = [0, 10, 25, 50, 100]
LENGTHS = [0, 1, 3, 10, 40, 100, 222]
# AC-2: `results_report.md`, the count of each (percentage, clear length).
COUNTS = {
    0: [0, 0, 0, 0, 0, 0, 0],
    10: [0, 1, 1, 1, 4, 10, 23],
    25: [0, 1, 1, 3, 10, 25, 32],
    50: [0, 1, 2, 5, 20, 32, 32],
    100: [0, 1, 3, 10, 32, 32, 32],
}


def _pack(percent: int, length: int) -> bytes:
    return BinaryPacker.pack(ps.percent_scheme(percent), {"b": [7] * (length - 1)})


def test_ac1_a_scheme_reports_the_percentage_and_a_new_scheme_has_none():
    # Arrange
    base = support.raw_scheme(0x40)

    # Act
    limited = base.with_limits(parity_percent=25)

    # Assert
    assert (base.parity_percent, limited.parity_percent, limited.parity) == (0, 25, 0)


@pytest.mark.parametrize("bad", [101, -1, 1000])
def test_ac1_a_percentage_outside_0_to_100_is_not_built_naming_it_and_100(bad: int):
    # Arrange
    scheme = support.raw_scheme(0x40)

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity_percent=bad)

    # Assert
    assert (str(bad) in str(refused.value), "100" in str(refused.value)) == (True, True)


def test_ac1_a_percentage_with_a_count_in_one_call_is_not_built_naming_the_percentage_and_100():
    # Arrange
    scheme = support.raw_scheme(0x40)

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity=4, parity_percent=25)

    # Assert
    assert ("25" in str(refused.value), "100" in str(refused.value)) == (True, True)


def test_ac1_the_last_setter_wins_between_a_count_and_a_percentage():
    # Arrange
    counted = support.raw_scheme(0x40, 4)

    # Act
    percent_after_count = counted.with_limits(parity_percent=25)
    count_after_percent = percent_after_count.with_limits(parity=2)

    # Assert
    assert (percent_after_count.parity, percent_after_count.parity_percent) == (0, 25)
    assert (count_after_percent.parity, count_after_percent.parity_percent) == (2, 0)
    assert BinaryPacker.pack(count_after_percent, {"b": [7] * 39}) == BinaryPacker.pack(
        support.raw_scheme(0x40, 2), {"b": [7] * 39}
    )


def test_ac1_the_other_limit_setters_keep_the_percentage_and_the_count():
    # Arrange
    percent = support.raw_scheme(0x40).with_limits(parity_percent=25)
    counted = support.raw_scheme(0x40, 4)

    # Act
    kept_percent = percent.with_limits(max_rounds=3)
    kept_count = counted.with_limits(max_rounds=3)

    # Assert
    assert (kept_percent.parity_percent, kept_percent.parity) == (25, 0)
    assert (kept_count.parity_percent, kept_count.parity) == (0, 4)


@pytest.mark.parametrize("percent", PERCENTS)
@pytest.mark.parametrize("length", LENGTHS)
def test_ac2_the_count_is_the_percentage_of_the_length_rounded_up_and_the_bytes_are_the_fixed_count_bytes(
    percent: int, length: int
):
    # Arrange
    expected = COUNTS[percent][LENGTHS.index(length)]
    if length == 0:
        assert ps.count_of(percent, 0) == expected
        return

    # Act
    packet = _pack(percent, length)

    # Assert
    fixed = BinaryPacker.pack(support.raw_scheme(0x40, expected), {"b": [7] * (length - 1)})
    assert (len(packet) - length, packet) == (expected, fixed)


@pytest.mark.parametrize("percent", [1, 10, 25, 50, 100])
def test_ac3_a_clear_message_one_byte_above_the_largest_is_refused_and_writes_nothing(percent: int):
    # Arrange
    scheme = ps.long_percent_scheme(percent)
    largest = ps.LARGEST_CLEAR[percent]
    row = ps.long_row(largest + 1)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.pack(scheme, row)
    packet = BinaryPacker.pack(scheme, ps.long_row(largest))

    # Assert
    assert (str(largest + 1) in str(refused.value), str(largest) in str(refused.value)) == (True, True)
    assert len(packet) <= 254


def test_ac3_the_independent_largest_length_matches_the_contract_figures():
    # Arrange
    figures = ps.LARGEST_CLEAR

    # Act
    found = {p: ps.largest_of(p) for p in figures}

    # Assert
    assert found == figures


def test_ac4_every_pair_of_percentage_and_clear_length_round_trips_with_zero_repaired():
    # Arrange
    pairs = 0
    failures: list[tuple[int, int]] = []

    # Act
    for percent in range(101):
        top = 254 if percent == 0 else ps.largest_of(percent)
        scheme = ps.percent_scheme(percent)
        for length in range(top + 1):
            pairs += 1
            if length == 0:
                result = support.read(b"", scheme)
                ok = isinstance(result.error, ShortPacket) and ps.count_of(percent, 0) == 0
                if not ok:
                    failures.append((percent, 0))
                continue
            row = {"b": [length & 0xFF] * (length - 1)}
            packet = BinaryPacker.pack(scheme, row)
            result = support.read(packet, scheme)
            if len(packet) != length + ps.count_of(percent, length) or not (
                result.ok and result.value.get("b", []) == row["b"] and result.repaired == 0
            ):
                failures.append((percent, length))

    # Assert
    assert (pairs, failures) == (22_752, [])


@pytest.mark.parametrize("percent", [1, 10, 25, 50, 100])
def test_ac4_a_length_no_clear_message_gives_is_uncorrectable_with_no_value_and_no_field(percent: int):
    # Arrange
    seen: list = []
    scheme = ps.percent_scheme(percent)
    gaps = [n for n in range(255) if all(length + ps.count_of(percent, length) != n for length in range(n + 1))]

    # Act
    results = [BinaryPacker.unpack(bytes(n), scheme.on(seen.append)) for n in gaps]

    # Assert
    assert len(gaps) == {1: 3, 10: 24, 25: 32, 50: 32, 100: 32}[percent]
    assert all((r.ok, r.value, r.error) == (False, None, Uncorrectable()) for r in results) and seen == []


def test_ac4_a_buffer_above_254_bytes_is_too_long_under_a_percentage():
    # Arrange
    scheme = ps.percent_scheme(25)

    # Act
    result = support.read(bytes(255), scheme)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, TooLong(length=255, limit=254))


@pytest.mark.parametrize("percent,corrupted,limit,parity", [(50, 10, 10, 20), (25, 5, 5, 10)])
def test_ac5_a_40_byte_clear_message_is_repaired_with_the_count_of_that_message(
    percent: int, corrupted: int, limit: int, parity: int
):
    # Arrange
    scheme = ps.percent_scheme(percent)
    row = {"b": list(range(39))}
    packet = BinaryPacker.pack(scheme, row)
    damaged, _ = support.corrupt(random.Random(5), packet, corrupted)

    # Act
    result = support.read(damaged, scheme, limit=limit)

    # Assert
    assert (len(packet) - 40, result.ok, result.value, result.repaired) == (parity, True, row, corrupted)


def test_ac6_a_limit_below_0_or_above_16_is_bad_limit_before_any_byte_is_read():
    # Arrange
    seen: list = []
    scheme = ps.percent_scheme(25)

    # Act
    refused = []
    for limit in (-1, 17):
        with pytest.raises(ValueError) as error:
            BinaryPacker.unpack(b"", scheme.on(seen.append), limit=limit)
        refused.append(str(limit) in str(error.value))

    # Assert
    assert (refused, seen) == ([True, True], [])


def test_ac6_a_limit_of_16_on_the_40_byte_message_at_25_percent_behaves_as_limit_5():
    # Arrange
    scheme = ps.percent_scheme(25)
    row = {"b": list(range(39))}
    packet = BinaryPacker.pack(scheme, row)
    rng = random.Random(6)
    cases = [support.corrupt(rng, packet, k)[0] for k in (3, 5, 6, 7, 9)]

    # Act
    high = [support.read(c, scheme, limit=16) for c in cases]
    five = [support.read(c, scheme, limit=5) for c in cases]

    # Assert
    assert [(r.ok, r.value, r.error, r.repaired) for r in high] == [(r.ok, r.value, r.error, r.repaired) for r in five]
    assert [r.repaired for r in high[:2]] == [3, 5]


def test_ac6_a_fixed_count_keeps_its_exact_rule_for_a_limit_above_half_the_count():
    # Arrange
    scheme = support.raw_scheme(0x40, 10)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40", scheme.on(lambda _row: None), limit=6)

    # Assert
    assert "6" in str(refused.value)


def _two_handlers(first: ps.Scheme, second: ps.Scheme):
    seen: list = []
    return seen, first.on(lambda row: seen.append(("a", row))), second.on(lambda row: seen.append(("b", row)))


def test_ac7_handlers_with_the_same_percentage_dispatch_after_the_repair():
    # Arrange
    first, second = ps.percent_scheme(25, 0x40), ps.percent_scheme(25, 0x41)
    seen, on_first, on_second = _two_handlers(first, second)
    packet = BinaryPacker.pack(second, {"b": list(range(20))})
    damaged, _ = support.corrupt(random.Random(7), packet, 2)

    # Act
    result = BinaryPacker.unpack(damaged, on_first, on_second, limit=2)

    # Assert
    assert (result.ok, result.repaired, seen) == (True, 2, [("b", {"b": list(range(20))})])


@pytest.mark.parametrize(
    "mixed",
    [
        lambda: (ps.percent_scheme(25, 0x40), ps.percent_scheme(50, 0x41)),
        lambda: (ps.percent_scheme(25, 0x40), support.raw_scheme(0x41, 4)),
        lambda: (support.raw_scheme(0x40, 4), ps.percent_scheme(25, 0x41)),
    ],
    ids=["two percentages", "percentage then count", "count then percentage"],
)
def test_ac7_a_mix_of_settings_is_refused_when_the_call_is_built_before_any_byte_is_read(mixed):
    # Arrange
    first, second = mixed()
    seen, on_first, on_second = _two_handlers(first, second)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40\x00", on_first, on_second, limit=1)

    # Assert
    assert ("one parity count" in str(refused.value), seen) == (True, [])


def test_percentage_0_is_a_scheme_without_parity_with_the_limit_rule_of_count_0():
    # Arrange
    zero_percent = support.raw_scheme(0x40).with_limits(parity_percent=0)
    seen: list = []

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40", zero_percent.on(seen.append), limit=1)
    result = BinaryPacker.unpack(b"\x40", zero_percent.on(seen.append), support.raw_scheme(0x41).on(seen.append))

    # Assert
    assert ("1" in str(refused.value), result.ok, (zero_percent.parity, zero_percent.parity_percent)) == (
        True,
        True,
        (0, 0),
    )
