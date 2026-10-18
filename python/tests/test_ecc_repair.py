from __future__ import annotations

import random

import pytest

from packbin import BinaryPacker, TrailingBytes, Uncorrectable

import ecc_support as support
from ecc_support import POSITION_HEX, POSITION_VALUES

# AZ-2680 AC-3, AC-4: repair of up to t wrong bytes and refusal beyond it, on the position fixture (EC-5 to EC-8,
# EC-14, EC-6 row 17). Every case is seeded; a case that returns a wrong row counts as a failure by name.


def _protected(parity: int) -> bytes:
    return BinaryPacker.pack(support.position_scheme(parity), POSITION_VALUES)


def _clean_row() -> dict:
    return support.read(bytes.fromhex(POSITION_HEX), support.position_scheme(0)).value


def _outcomes(parity: int, limit: int, cases: list[bytes]) -> dict[str, int]:
    """How many of the corrupted messages came back repaired to the position row, refused, or as another row."""
    scheme = support.position_scheme(parity)
    expected = _clean_row()
    counts = {"repaired": 0, "refused": 0, "wrong": 0}
    for received in cases:
        result = support.read(received, scheme, limit=limit)
        if not result.ok:
            counts["refused"] += 1
        elif result.value == expected:
            counts["repaired"] += 1
        else:
            counts["wrong"] += 1
    return counts


def test_ec5_n2_all_15_positions_and_255_values_recover_the_position_row_with_one_repaired():
    # Arrange
    scheme = support.position_scheme(2)
    clean = _protected(2)
    expected = _clean_row()
    wrong = 0

    # Act
    for place in range(len(clean)):
        for delta in range(1, 256):
            word = bytearray(clean)
            word[place] ^= delta
            result = support.read(bytes(word), scheme, limit=1)
            if not (result.ok and result.value == expected and result.repaired == 1):
                wrong += 1

    # Assert
    assert (len(clean), wrong) == (15, 0)


@pytest.mark.parametrize("parity", [4, 8, 16])
def test_ec5_1000_seeded_cases_of_1_to_t_wrong_bytes_recover_the_position_row_and_count_them(parity: int):
    # Arrange
    rng = random.Random(0xEC5 + parity)
    scheme = support.position_scheme(parity)
    clean = _protected(parity)
    expected = _clean_row()
    limit = parity // 2
    failures = []

    # Act
    for case in range(1000):
        count = rng.randint(1, limit)
        word, _places = support.corrupt(rng, clean, count)
        result = support.read(word, scheme, limit=limit)
        if not (result.ok and result.value == expected and result.repaired == count):
            failures.append(case)

    # Assert
    assert failures == []


@pytest.mark.parametrize("parity", [4, 8, 16])
def test_ec5_a_repair_changes_neither_the_other_rows_nor_the_next_unpack(parity: int):
    # Arrange
    scheme = support.position_scheme(parity)
    clean = _protected(parity)
    damaged, _ = support.corrupt(random.Random(parity), clean, parity // 2)

    # Act
    support.read(damaged, scheme, limit=parity // 2)
    again = support.read(clean, scheme, limit=parity // 2)

    # Assert
    assert (again.ok, again.repaired, again.value) == (True, 0, _clean_row())


def test_ec5_all_eight_bits_of_a_byte_flipped_is_one_wrong_byte():
    # Arrange
    scheme = support.position_scheme(2)
    word = bytearray(_protected(2))
    word[7] ^= 0xFF

    # Act
    result = support.read(bytes(word), scheme, limit=1)

    # Assert
    assert (result.ok, result.value, result.repaired) == (True, _clean_row(), 1)


def test_ec6_n4_t1_10000_seeded_cases_of_2_or_3_wrong_bytes_are_all_refused_and_none_is_a_wrong_row():
    # Arrange
    rng = random.Random(0xEC6)
    clean = _protected(4)
    cases = [support.corrupt(rng, clean, rng.randint(2, 3))[0] for _ in range(10_000)]

    # Act
    counts = _outcomes(4, 1, cases)

    # Assert
    assert counts == {"repaired": 0, "refused": 10_000, "wrong": 0}


def test_ec6_n4_t0_10000_seeded_cases_of_1_to_4_wrong_bytes_are_all_refused_and_none_is_a_wrong_row():
    # Arrange
    rng = random.Random(0xEC60)
    clean = _protected(4)
    cases = [support.corrupt(rng, clean, rng.randint(1, 4))[0] for _ in range(10_000)]

    # Act
    counts = _outcomes(4, 0, cases)

    # Assert
    assert counts == {"repaired": 0, "refused": 10_000, "wrong": 0}


def test_ec6_row_17_20000_seeded_corruptions_of_1_to_4_bytes_of_row_4_are_all_refused_when_t_is_0():
    # Arrange
    rng = random.Random(0xEC17)
    clean = _protected(4)
    cases = [support.corrupt(rng, clean, rng.randint(1, 4))[0] for _ in range(20_000)]

    # Act
    counts = _outcomes(4, 0, cases)

    # Assert
    assert counts == {"repaired": 0, "refused": 20_000, "wrong": 0}


@pytest.mark.parametrize("parity", [8, 16])
def test_ec6_t_wrong_plus_one_up_to_n_minus_t_wrong_bytes_are_refused_for_every_t(parity: int):
    # Arrange
    rng = random.Random(0xEC61 + parity)
    clean = _protected(parity)
    totals = {"repaired": 0, "refused": 0, "wrong": 0}

    # Act
    limits = range((parity - 1) // 2 + 1)
    for limit in limits:
        cases = [
            support.corrupt(rng, clean, rng.randint(limit + 1, parity - limit))[0] for _ in range(300)
        ]
        for name, count in _outcomes(parity, limit, cases).items():
            totals[name] += count

    # Assert
    assert totals == {"repaired": 0, "refused": 300 * len(limits), "wrong": 0}


def test_ec7_200000_seeded_random_buffers_of_the_fixture_length_with_n2_t0_are_accepted_at_most_12_times():
    # Arrange
    rng = random.Random(0xEC7)
    scheme = support.position_scheme(2)
    accepted = 0

    # Act
    for _ in range(200_000):
        if support.read(rng.randbytes(15), scheme).ok:
            accepted += 1

    # Assert
    assert accepted <= 12


def test_ec8_an_intact_protected_message_returns_the_row_and_zero_repaired_for_every_limit():
    # Arrange
    scheme = support.position_scheme(8)
    clean = _protected(8)

    # Act
    results = [support.read(clean, scheme, limit=limit) for limit in range(5)]

    # Assert
    assert [(r.ok, r.value, r.repaired) for r in results] == [(True, _clean_row(), 0)] * 5


@pytest.mark.parametrize("parity", [1, 2, 4, 8, 16, 32])
def test_ec8_a_buffer_shorter_than_n_names_the_parity_n_needed_and_the_bytes_present(parity: int):
    # Arrange
    scheme = support.position_scheme(parity)

    # Act
    results = [support.read(bytes(size), scheme) for size in range(parity)]

    # Assert
    assert [(r.value, r.field, r.needed, r.left) for r in results] == [
        (None, "parity", parity, size) for size in range(parity)
    ]


def test_ec8_a_buffer_of_exactly_n_bytes_is_read_with_the_unprotected_rules():
    # Arrange
    scheme = support.position_scheme(4)

    # Act
    result = support.read(bytes(4), scheme)

    # Assert: the parity of the empty clear message is 4 zero bytes, so the check passes and the row is empty
    assert (result.ok, result.field, result.needed, result.left) == (False, "", 1, 0)


def test_ec14_n4_t0_10000_seeded_cases_of_1_to_3_bytes_removed_or_added_are_refused_with_no_value():
    # Arrange
    rng = random.Random(0xEC14)
    clean = _protected(4)
    cases = []
    for _ in range(10_000):
        count = rng.randint(1, 3)
        if rng.random() < 0.5:
            cases.append(clean[:-count])
        else:
            cases.append(clean + rng.randbytes(count))

    # Act
    counts = _outcomes(4, 0, cases)

    # Assert
    assert counts == {"repaired": 0, "refused": 10_000, "wrong": 0}


def _clear_with_last_parity_byte_zero() -> bytes:
    scheme = support.position_scheme(4)
    for sid in range(1, 65_536):
        packet = BinaryPacker.pack(scheme, {**POSITION_VALUES, "sid": sid})
        if packet[-1] == 0:
            return packet
    raise AssertionError("no sid gives a last parity byte of 00")


def test_ec14_a_shift_by_one_byte_is_refused_also_when_the_last_parity_byte_is_00():
    # Arrange
    scheme = support.position_scheme(4)
    ordinary = _protected(4)
    zero_ended = _clear_with_last_parity_byte_zero()
    shifted = [ordinary + b"\x00", ordinary[:-1], zero_ended + b"\x00", zero_ended[:-1]]

    # Act
    results = [support.read(word, scheme) for word in shifted]

    # Assert
    assert [(r.ok, r.value, r.error) for r in results] == [(False, None, Uncorrectable())] * 4


def test_ec14_the_unprotected_13_bytes_read_by_an_n4_scheme_are_refused_with_no_value():
    # Arrange
    scheme = support.position_scheme(4)

    # Act
    result = support.read(bytes.fromhex(POSITION_HEX), scheme)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, Uncorrectable())


def test_ec14_a_scheme_with_zero_parity_bytes_given_a_protected_message_returns_trailing_bytes():
    # Arrange
    scheme = support.position_scheme(0)

    # Act
    result = support.read(_protected(4), scheme)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, TrailingBytes(left=4))


def _agrees_with_the_reference(clear_size: int, parity: int, rng: random.Random) -> tuple[bool, bool]:
    """Whether pack gives the reference bytes and unpack gives the reference answer for one seeded message."""
    clear = rng.randbytes(clear_size)
    protected = support.reference.protect(clear, parity)
    word = bytearray(protected)
    for place in rng.sample(range(len(word)), min(rng.randint(0, parity + 1), len(word))):
        word[place] ^= rng.randrange(1, 256)
    limit = rng.randint(0, parity // 2)
    try:
        expected = support.reference.decode(bytes(word), parity, limit)
    except support.reference.EccError:
        expected = None
    packed = True
    if clear:
        packed = BinaryPacker.pack(support.raw_scheme(clear[0], parity), {"b": list(clear[1:])}) == protected
    if expected is None:
        return packed, support.kind_of(support.read(bytes(word), support.raw_scheme(0, parity), limit)) == "uncorrectable"
    fixed, count = expected
    if not fixed:
        result = support.read(bytes(word), support.raw_scheme(0, parity), limit)
        return packed, (not result.ok and result.field == "")
    result = support.read(bytes(word), support.raw_scheme(fixed[0], parity), limit)
    return packed, (result.ok and bytes([fixed[0]]) + bytes(result.value.get("b", [])) == fixed and result.repaired == count)


@pytest.mark.parametrize("parity", [1, 2, 4, 8, 16, 32])
def test_the_package_pack_and_unpack_match_the_reference_codec_on_seeded_messages(parity: int):
    # Arrange
    rng = random.Random(parity)
    sizes = [0, 1, 2, 13, 254 - parity] + [rng.randint(0, 254 - parity) for _ in range(115)]

    # Act
    verdicts = [_agrees_with_the_reference(size, parity, rng) for size in sizes]

    # Assert
    assert [i for i, (packed, unpacked) in enumerate(verdicts) if not (packed and unpacked)] == []
