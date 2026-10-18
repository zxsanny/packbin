from __future__ import annotations

import random

import pytest

from packbin import BinaryPacker, PackSession, Scheme, Uncorrectable, u8, u16, utf8

import ecc_support as support
import text_vectors
from ecc_support import POSITION_VALUES

# AZ-2680 AC-6: a protected message under an open session (EC-10), holding a compact-text field (EC-11), and read
# through a dispatch of several schemes (EC-16).

SEED = bytes(range(1, 33))
NONCE = bytes.fromhex("01000000000000000000000000000000")
CIPHERTEXT_HEX = "b55d0a29c56c203712b241232e"


def _pair() -> tuple[PackSession, PackSession]:
    sender = PackSession.load(SEED)
    receiver = PackSession.load(SEED)
    assert sender is not None and receiver is not None
    assert sender.start(NONCE) == NONCE
    assert receiver.join(NONCE) is True
    return sender, receiver


def _row_of(position: Scheme) -> dict:
    return support.read(BinaryPacker.pack(position, POSITION_VALUES), position).value


def test_ec10_a_session_scheme_with_zero_parity_bytes_keeps_the_payload_of_clear_pack():
    # Arrange
    sender, _receiver = _pair()

    # Act
    payload = sender.pack(support.position_scheme(0), POSITION_VALUES)

    # Assert
    assert payload is not None and payload.hex() == CIPHERTEXT_HEX


def test_ec10_the_parity_of_a_session_payload_covers_the_padded_bytes():
    # Arrange
    sender, _receiver = _pair()

    # Act
    payload = sender.pack(support.position_scheme(4), POSITION_VALUES)

    # Assert
    ciphertext = bytes.fromhex(CIPHERTEXT_HEX)
    assert payload == ciphertext + support.reference.parity(ciphertext, 4)


def test_ec10_n4_two_wrong_bytes_anywhere_recover_the_row_for_300_seeded_payloads():
    # Arrange
    rng = random.Random(0xEC10)
    scheme = support.position_scheme(4)
    expected = _row_of(scheme)
    sender, receiver = _pair()
    failures = []

    # Act
    for case in range(300):
        payload = sender.pack(scheme, POSITION_VALUES)
        assert payload is not None
        damaged, _ = support.corrupt(rng, payload, 2)
        result = receiver.unpack(damaged, scheme.on(lambda _row: None), limit=2)
        if not (result.ok and result.value == expected and result.repaired == 2):
            failures.append(case)

    # Assert
    assert failures == []


def test_ec10_n4_t2_three_wrong_bytes_are_uncorrectable_and_the_next_payload_is_still_read():
    # Arrange
    scheme = support.position_scheme(4)
    expected = _row_of(scheme)
    sender, receiver = _pair()
    first = sender.pack(scheme, POSITION_VALUES)
    second = sender.pack(scheme, POSITION_VALUES)
    assert first is not None and second is not None
    damaged = bytearray(first)
    for place in (1, 6, 15):
        damaged[place] ^= 0x5A

    # Act
    refused = receiver.unpack(bytes(damaged), scheme.on(lambda _row: None), limit=2)
    next_one = receiver.unpack(second, scheme.on(lambda _row: None), limit=2)

    # Assert
    assert (refused.ok, refused.value, refused.error) == (False, None, Uncorrectable())
    assert (next_one.ok, next_one.value, next_one.repaired) == (True, expected, 0)


def test_ec10_a_session_unpack_of_a_protected_payload_without_a_limit_only_detects():
    # Arrange
    scheme = support.position_scheme(4)
    sender, receiver = _pair()
    payload = sender.pack(scheme, POSITION_VALUES)
    assert payload is not None
    damaged = bytes([payload[0] ^ 1]) + payload[1:]

    # Act
    result = receiver.unpack(damaged, scheme.on(lambda _row: None))

    # Assert
    assert (result.ok, result.error) == (False, Uncorrectable())


def test_ec10_a_limit_above_half_the_parity_raises_before_a_byte_is_read_and_the_receive_index_stays():
    # Arrange
    scheme = support.position_scheme(4)
    sender, receiver = _pair()
    payload = sender.pack(scheme, POSITION_VALUES)
    assert payload is not None

    # Act
    with pytest.raises(ValueError):
        receiver.unpack(payload, scheme.on(lambda _row: None), limit=3)
    result = receiver.unpack(payload, scheme.on(lambda _row: None))

    # Assert
    assert (result.ok, result.repaired) == (True, 0)


def test_ec10_a_session_pack_above_the_clear_limit_raises_and_the_send_index_stays():
    # Arrange
    scheme = support.raw_scheme(0x40, 32)
    sender, receiver = _pair()

    # Act
    with pytest.raises(ValueError):
        sender.pack(scheme, {"b": [0] * 222})
    payload = sender.pack(scheme, {"b": [7] * 221})
    result = receiver.unpack(payload, scheme.on(lambda _row: None))

    # Assert
    assert (len(payload), result.ok, result.value) == (254, True, {"b": [7] * 221})


def test_ec10_a_session_dispatch_of_schemes_with_different_parity_counts_is_refused():
    # Arrange
    _sender, receiver = _pair()
    plain = support.position_scheme(0)
    protected = support.position_scheme(4, type_number=0x41)

    # Act
    with pytest.raises(ValueError) as refused:
        receiver.unpack(b"\x40", plain.on(lambda _row: None), protected.on(lambda _row: None))

    # Assert
    assert ("0" in str(refused.value), "4" in str(refused.value)) == (True, True)


# EC-11: a compact-text field in a protected message

TEXT = Scheme(1, dict, utf8(0, lambda row: row["s"]), u8(1, lambda row: row["n"])).with_limits(parity=4)
STRINGS = ["pack bin ecc 0123456789", "Олександр, диспетчер", "gps_fix 48.46", "", "a"]


@pytest.mark.parametrize("text", STRINGS)
def test_ec11_n4_any_two_wrong_bytes_return_the_original_row_and_the_original_string(text: str):
    # Arrange
    row = {"s": text, "n": 200}
    clean = BinaryPacker.pack(TEXT, row)
    rng = random.Random(0xEC11)
    differing = []

    # Act
    for first in range(len(clean)):
        for second in range(first + 1, len(clean)):
            word = bytearray(clean)
            word[first] ^= rng.randrange(1, 256)
            word[second] ^= rng.randrange(1, 256)
            result = support.read(bytes(word), TEXT, limit=2)
            if not (result.ok and result.value == row and result.repaired == 2):
                differing.append((first, second))

    # Assert
    assert differing == []


# a refused row longer than 250 bytes is no protected message (EC-4), so only the rows that fit are protected
TEXT_BAD = [r for r in text_vectors.rows("bad") if 1 + len(r.field) <= 250]
ONE = Scheme(1, dict, utf8(0, lambda row: row["s"]))


@pytest.mark.parametrize("limit", [0, 2])
@pytest.mark.parametrize("row", TEXT_BAD, ids=[r.id for r in TEXT_BAD])
def test_ec11_a_refused_compact_text_field_in_a_protected_message_is_refused_as_before(row, limit: int):
    # Arrange
    clear = b"\x01" + row.field
    protected = support.reference.protect(clear, 4)
    scheme = Scheme(1, dict, utf8(0, lambda r: r["s"])).with_limits(parity=4)
    expected = support.read(clear, ONE)

    # Act
    result = support.read(protected, scheme, limit=limit)

    # Assert
    assert (result.ok, result.value, result.error) == (expected.ok, expected.value, expected.error)


# EC-16: one dispatch over schemes of one parity count

def _other_scheme(parity: int) -> Scheme:
    scheme = Scheme(0x41, dict, u16(0, lambda row: row["a"]), u8(1, lambda row: row["b"]))
    return scheme.with_limits(parity=parity)


def test_ec16_1000_seeded_cases_with_the_type_byte_among_the_wrong_bytes_reach_the_right_handler():
    # Arrange
    rng = random.Random(0xEC16)
    position = support.position_scheme(4)
    other = _other_scheme(4)
    messages = [
        (BinaryPacker.pack(position, POSITION_VALUES), 0),
        (BinaryPacker.pack(other, {"a": 4660, "b": 9}), 1),
    ]
    calls: list[list] = [[], []]
    handlers = (position.on(calls[0].append), other.on(calls[1].append))
    wrong_handlers = 0
    failures = []

    # Act
    for case in range(1000):
        clean, index = messages[case % 2]
        count = rng.randint(1, 2)
        word = bytearray(clean)
        for place in [0] + rng.sample(range(1, len(word)), count - 1):
            word[place] ^= rng.randrange(1, 256)
        before = [len(c) for c in calls]
        result = BinaryPacker.unpack(bytes(word), *handlers, limit=2)
        ran = [len(c) - b for c, b in zip(calls, before)]
        wrong_handlers += sum(ran) - ran[index]
        if not (result.ok and ran[index] == 1 and result.repaired == count):
            failures.append(case)

    # Assert
    assert (failures, wrong_handlers) == ([], 0)


def test_ec16_a_dispatch_of_schemes_with_different_parity_counts_is_refused_naming_both_counts():
    # Arrange
    four = support.position_scheme(4)
    two = _other_scheme(2)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40", four.on(lambda _row: None), two.on(lambda _row: None))

    # Assert
    assert ("4" in str(refused.value), "2" in str(refused.value)) == (True, True)


def test_ec16_a_dispatch_of_a_protected_and_an_unprotected_scheme_is_refused_and_runs_no_handler():
    # Arrange
    seen: list = []
    four = support.position_scheme(4)
    zero = _other_scheme(0)

    # Act
    with pytest.raises(ValueError):
        BinaryPacker.unpack(BinaryPacker.pack(four, POSITION_VALUES), four.on(seen.append), zero.on(seen.append))

    # Assert
    assert seen == []


def test_ec16_a_dispatch_of_one_parity_count_without_a_wrong_byte_runs_only_the_matching_handler():
    # Arrange
    calls: list[list] = [[], []]
    position = support.position_scheme(8)
    other = _other_scheme(8)

    # Act
    result = BinaryPacker.unpack(
        BinaryPacker.pack(other, {"a": 1, "b": 2}), position.on(calls[0].append), other.on(calls[1].append)
    )

    # Assert
    assert (result.ok, result.repaired, calls) == (True, 0, [[], [{"a": 1, "b": 2}]])
