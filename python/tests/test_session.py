from __future__ import annotations

import pytest

from packbin import BinaryPacker, PackSession, Scheme, flags, i16, i32, u8, u16

CIPHERTEXT_HEX = "b55d0a29c56c203712b241232e"
POSITION_HEX = "4001000065cd1d00a3e1110100"
NONCE = bytes.fromhex("01000000000000000000000000000000")

POSITION = Scheme(
    0x40,
    dict,
    u16(0, lambda row: row["sid"]),
    i32(1, lambda row: row["lat"]),
    i32(2, lambda row: row["lon"]),
    u8(3, lambda row: row["profile"]),
    flags(
        4,
        u16(4, lambda row: row["heading"]),
        u8(5, lambda row: row["speed"]),
        i16(6, lambda row: row["altitude"]),
    ),
)

POSITION_VALUES = {
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
}


def _seed() -> bytes:
    return bytes(range(1, 33))


def _mismatched_bytes(actual: bytes, expected_hex: str) -> int:
    expected = bytes.fromhex(expected_hex)
    return sum(1 for a, b in zip(actual, expected, strict=False) if a != b) + abs(
        len(actual) - len(expected)
    )


def _field_mismatches(row) -> int:
    n = 0
    if row.get("sid") != 1:
        n += 1
    if row.get("lat") != 500_000_000:
        n += 1
    if row.get("lon") != 300_000_000:
        n += 1
    if row.get("profile") != 1:
        n += 1
    for name in ("heading", "speed", "altitude"):
        if name in row and row[name] is not None:
            n += 1
    return n


def test_ac1_ciphertext_matches_csharp():
    opener = PackSession.load(_seed())
    assert opener is not None
    nonce = opener.start(NONCE)
    assert nonce == NONCE
    payload = opener.pack(POSITION, POSITION_VALUES)
    assert payload is not None
    assert len(payload) == 13
    assert payload.hex() == CIPHERTEXT_HEX
    assert _mismatched_bytes(payload, CIPHERTEXT_HEX) == 0


def test_ac2_waiter_recovers_row():
    opener = PackSession.load(_seed())
    waiter = PackSession.load(_seed())
    assert opener is not None
    assert waiter is not None
    assert opener.start(NONCE) == NONCE
    assert waiter.join(NONCE) is True
    payload = opener.pack(POSITION, POSITION_VALUES)
    assert payload is not None
    got = waiter.unpack(payload, POSITION.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert _field_mismatches(got.value) == 0


def test_ac3_clear_pack_unchanged():
    raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert raw.hex() == POSITION_HEX
    assert _mismatched_bytes(raw, POSITION_HEX) == 0


def test_ac4_bad_lengths_create_nothing():
    created = 0
    if PackSession.load(bytes(31)) is not None:
        created += 1
    if PackSession.load(bytes(33)) is not None:
        created += 1
    loaded = PackSession.load(_seed())
    assert loaded is not None
    if loaded.join(bytes(15)):
        created += 1
    if loaded.join(bytes(17)):
        created += 1
    if loaded.start(bytes(15)) is not None:
        created += 1
    assert created == 0
    assert loaded.pack(POSITION, POSITION_VALUES) is None


WRONG_SEED_SIZES = [0, 3, 31, 33]


@pytest.mark.parametrize("size", WRONG_SEED_SIZES)
def test_constructor_rejects_wrong_seed_length(size: int):
    with pytest.raises(ValueError, match="32 bytes"):
        PackSession(bytes(size))


@pytest.mark.parametrize("size", WRONG_SEED_SIZES)
def test_load_returns_none_for_a_wrong_seed_length(size: int):
    assert PackSession.load(bytes(size)) is None


def test_load_and_constructor_open_the_same_session_for_a_32_byte_seed():
    loaded = PackSession.load(_seed())
    built = PackSession(_seed())

    assert loaded is not None
    assert loaded.start(NONCE) == built.start(NONCE) == NONCE
    assert loaded.pack(POSITION, POSITION_VALUES) == built.pack(POSITION, POSITION_VALUES)
