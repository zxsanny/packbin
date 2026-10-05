from __future__ import annotations

import pytest

from packbin import PackSession, Scheme, ShortPacket, TrailingBytes, i8, u8, u32, u64

import hostile_support as hs
from hostile_support import assert_rejected, error_kind, unpack_guarded

NONCE = bytes.fromhex("01000000000000000000000000000000")


def _short(hex_bytes: str, scheme: Scheme, field: str, left: int):
    result, seen, elapsed = unpack_guarded(scheme, bytes.fromhex(hex_bytes))
    assert_rejected(result, seen, elapsed)
    assert isinstance(result.error, ShortPacket)
    assert result.error.field == field
    assert result.error.needed == 0
    assert result.error.left == left
    assert error_kind(result) == "bad_value"


def test_zero_progress_repeat_ends():
    result, seen, elapsed = unpack_guarded(hs.zero_progress_when(), bytes.fromhex("010005"))
    assert_rejected(result, seen, elapsed)
    assert result.error == TrailingBytes(left=1)


def test_negative_sized_count_is_error():
    layout = hs.sized_by(hs.counter(i8))
    _short("01fd616263", layout, "1", 3)


def test_negative_bits_packed_times_count_is_error():
    _short("01fd", hs.bits_by(hs.counter(i8)), "1", 0)
    _short("01fd", hs.packed_by(hs.counter(i8)), "1", 0)
    _short("01fd", hs.times_by(hs.counter(i8)), "1", 0)


def test_bias_below_zero_is_error():
    _short("0100", hs.packed_by(hs.counter(u8), bias=-1), "1", 0)


def test_invalid_utf8_string_is_error():
    _short("010100ff", hs.utf8_name(), "0", 3)


def test_invalid_utf8_dict_key_is_error():
    _short("0101000100ff05", hs.dict_of_u8(), "", 4)


@pytest.mark.parametrize("consumer", ["sized", "bits", "packed", "times"])
def test_count_behind_clear_flag_is_error(consumer: str):
    result, seen, elapsed = unpack_guarded(hs.count_behind_clear_flag(consumer), bytes.fromhex("0100"))
    assert_rejected(result, seen, elapsed)
    assert result.error == ShortPacket(field="1", needed=0, left=0)


@pytest.mark.parametrize(
    "kind,hex_bytes,left",
    [(u64, "01ffffffffffffffff", 0), (u32, "01ffffffff", 0), (u8, "0103", 0), (u8, "010300", 1)],
    ids=["u64-max", "u32-max", "small-count", "small-count-extra-byte"],
)
def test_times_zero_width_round_is_error(kind, hex_bytes: str, left: int):
    _short(hex_bytes, hs.times_zero_width(hs.counter(kind)), "1", left)


def test_oversize_counts_stay_short_packet():
    cases = [
        (hs.list_of_u8(), "01ffff0100"),
        (hs.utf8_name(), "01ffff61"),
        (hs.times_by(hs.counter(u8)), "01ff0102"),
        (hs.sized_by(hs.counter(u8)), "01ff0102"),
        (hs.dict_of_u8(), "01ffff"),
    ]
    for layout, hex_bytes in cases:
        result, seen, elapsed = unpack_guarded(layout, bytes.fromhex(hex_bytes))
        assert_rejected(result, seen, elapsed)
        assert error_kind(result) == "short_packet"


def test_session_unpack_hostile_payload():
    sender = PackSession(bytes(range(1, 33)))
    waiter = PackSession(bytes(range(1, 33)))
    assert sender.start(NONCE) == NONCE
    assert waiter.join(NONCE)
    wire = Scheme(1, dict, u8(0, lambda row: row["k"]), u8(1, lambda row: row["x"]))
    payload = sender.pack(wire, {"k": 0, "x": 5})
    assert payload is not None
    clear, _, _ = unpack_guarded(hs.zero_progress_when(), bytes.fromhex("010005"))

    result, seen, elapsed = unpack_guarded(hs.zero_progress_when(), payload, waiter.unpack)
    assert_rejected(result, seen, elapsed)
    assert result == clear
