from __future__ import annotations

import random
import time
from array import array

import pytest

from packbin import BinaryPacker, ShortPacket, TooLong, TrailingBytes, TypeMismatch, Uncorrectable, UnpackResult

import ecc_support as support
from ecc_support import POSITION_HEX, POSITION_VALUES

# AZ-2680 AC-1, AC-4, AC-7: the scheme setting, the correction limit of unpack, hostile bytes and the speed bound.


def test_ec1_a_scheme_has_zero_parity_bytes_until_it_is_set():
    # Arrange
    scheme = support.position_scheme()

    # Act
    parity = scheme.parity

    # Assert
    assert parity == 0


@pytest.mark.parametrize("parity", [0, 1, 16, 32])
def test_ec3_a_parity_count_of_0_to_32_builds_a_scheme_that_reports_it(parity: int):
    # Arrange
    scheme = support.position_scheme()

    # Act
    built = scheme.with_limits(parity=parity)

    # Assert
    assert (built.parity, scheme.parity) == (parity, 0)


@pytest.mark.parametrize("value", [33, -1, 255, True, False, "4", 4.0, [4]])
def test_ec3_a_parity_count_that_is_not_a_whole_number_of_0_to_32_is_not_built_and_names_the_limit_32(value):
    # Arrange
    scheme = support.position_scheme()

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity=value)

    # Assert
    assert "32" in str(refused.value)


def test_ec3_a_refused_parity_count_leaves_the_scheme_unchanged():
    # Arrange
    scheme = support.position_scheme(4)

    # Act
    with pytest.raises(ValueError):
        scheme.with_limits(parity=33)

    # Assert
    assert scheme.parity == 4


def test_ec3_with_limits_takes_the_parity_count_and_a_missing_one_keeps_it():
    # Arrange
    scheme = support.position_scheme(4).with_limits(max_slots=10, parity=2)

    # Act
    kept = scheme.with_limits(max_slots=20)
    cleared = scheme.with_limits(parity=0)

    # Assert
    assert (scheme.parity, scheme.max_slots, kept.parity, kept.max_slots, cleared.parity) == (2, 10, 2, 20, 0)


def test_ec1_unpack_of_an_unprotected_scheme_reports_zero_repaired_and_the_golden_row():
    # Arrange
    scheme = support.position_scheme(0)

    # Act
    result = support.read(bytes.fromhex(POSITION_HEX), scheme)

    # Assert
    assert (result.ok, result.repaired, result.value["sid"]) == (True, 0, POSITION_VALUES["sid"])


@pytest.mark.parametrize("limit", [1, -1, True, "0", 0.0, None])
def test_ec8_an_unprotected_scheme_takes_only_the_limit_0(limit):
    # Arrange
    seen: list = []
    scheme = support.position_scheme(0)

    # Act
    with pytest.raises(ValueError):
        BinaryPacker.unpack(bytes.fromhex(POSITION_HEX), scheme.on(seen.append), limit=limit)

    # Assert
    assert seen == []


@pytest.mark.parametrize("limit", [3, 17, -1, True, "1", 1.0, None])
def test_ec8_a_limit_that_is_not_a_whole_number_of_0_to_half_the_parity_raises_before_any_byte_is_read(limit):
    # Arrange
    seen: list = []
    scheme = support.position_scheme(4)

    # Act
    with pytest.raises(ValueError):
        BinaryPacker.unpack(b"", scheme.on(seen.append), limit=limit)

    # Assert
    assert seen == []


def test_ec1_unpack_without_handlers_is_still_a_type_error():
    # Arrange
    packet = bytes.fromhex(POSITION_HEX)

    # Act and assert
    with pytest.raises(TypeError, match="missing handlers"):
        BinaryPacker.unpack(packet)


@pytest.mark.parametrize("make", [bytes, bytearray, memoryview])
def test_ec5_a_protected_message_is_read_from_every_bytes_like_input(make):
    # Arrange
    scheme = support.position_scheme(4)
    damaged = bytearray(BinaryPacker.pack(scheme, POSITION_VALUES))
    damaged[3] ^= 0x77

    # Act
    result = support.read(make(bytes(damaged)), scheme, limit=2)

    # Assert
    assert (result.ok, result.repaired) == (True, 1)


def test_ec8_a_buffer_of_wider_items_is_counted_in_bytes_and_never_raises():
    # Arrange
    scheme = support.position_scheme(4)
    wide = array("I", [0x40010000, 7, 8])

    # Act
    result = support.read(wide, scheme, limit=2)

    # Assert
    assert result.ok is False and result.value is None


ERRORS = (Uncorrectable, TooLong, ShortPacket, TrailingBytes, TypeMismatch)


def _verdict_is_typed(result: UnpackResult, limit: int) -> bool:
    if result.ok:
        return result.value is not None and 0 <= result.repaired <= limit
    return result.value is None and isinstance(result.error, ERRORS)


@pytest.mark.parametrize("parity", [1, 2, 4, 8, 16, 32])
def test_hostile_random_buffers_of_0_to_300_bytes_never_raise_and_give_a_typed_result(parity: int):
    # Arrange
    rng = random.Random(0xB0B + parity)
    scheme = support.position_scheme(parity)
    bad = []

    # Act
    for case in range(1500):
        word = rng.randbytes(rng.randint(0, 300))
        limit = rng.randint(0, parity // 2)
        if not _verdict_is_typed(support.read(word, scheme, limit=limit), limit):
            bad.append(case)

    # Assert
    assert bad == []


@pytest.mark.parametrize("parity", [2, 8, 32])
def test_hostile_damaged_valid_messages_of_any_size_never_raise_and_never_repair_more_than_the_limit(parity: int):
    # Arrange
    rng = random.Random(0xBAD + parity)
    bad = []

    # Act
    for case in range(800):
        body = [rng.randrange(256) for _ in range(rng.randint(0, 254 - parity - 1))]
        scheme = support.raw_scheme(0x40, parity)
        word = bytearray(BinaryPacker.pack(scheme, {"b": body}))
        for place in rng.sample(range(len(word)), min(len(word), rng.randint(0, parity + 2))):
            word[place] = rng.randrange(256)
        limit = rng.randint(0, parity // 2)
        if not _verdict_is_typed(support.read(bytes(word), scheme, limit=limit), limit):
            bad.append(case)

    # Assert
    assert bad == []


def test_ec13_1000_corrections_of_a_254_byte_message_with_16_parity_bytes_and_8_wrong_bytes_take_at_most_5_s():
    # Arrange
    scheme = support.raw_scheme(0x40, 16)
    body = list(range(237))
    clean = BinaryPacker.pack(scheme, {"b": body})
    damaged, _ = support.corrupt(random.Random(0xEC13), clean, 8)
    handler = scheme.on(lambda _row: None)

    # Act
    started = time.perf_counter()
    for _ in range(1000):
        result = BinaryPacker.unpack(damaged, handler, limit=8)
    seconds = time.perf_counter() - started

    # Assert
    assert (len(clean), result.ok, result.value["b"], result.repaired) == (254, True, body, 8)
    assert seconds <= 5.0


def test_ec13_1000_packs_of_a_254_byte_message_with_16_parity_bytes_take_at_most_1_s():
    # Arrange
    scheme = support.raw_scheme(0x40, 16)
    row = {"b": list(range(237))}

    # Act
    started = time.perf_counter()
    for _ in range(1000):
        packet = BinaryPacker.pack(scheme, row)
    seconds = time.perf_counter() - started

    # Assert
    assert len(packet) == 254
    assert seconds <= 1.0
