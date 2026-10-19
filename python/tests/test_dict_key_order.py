from __future__ import annotations

import time

import pytest

from packbin import BinaryPacker, ShortPacket, Scheme, dict as map_field, u8

SCHEME = Scheme(1, dict, map_field(lambda row: row["d"], u8(0, lambda row: row["v"])))


def _key(text: str) -> bytes:
    """A compact-text key field in its raw form: count, start byte 0x10, then the UTF-8 bytes (short keys only)."""
    raw = text.encode("utf-8")
    assert len(raw) < 100
    return bytes([len(raw) + 1, 0x10]) + raw


def _packet(*keys: str) -> bytes:
    body = b"".join(_key(key) + b"\x00" for key in keys)
    return bytes([1]) + len(keys).to_bytes(2, "little") + body


def _unpack(packet: bytes):
    return BinaryPacker.unpack(packet, SCHEME.on(lambda row: None))


@pytest.mark.parametrize(
    "keys",
    [("a", "b"), ("a", "ab"), ("", "a"), ("z", "～", "\U00010000"), ("\U0000e000", "\U0000ff5e", "\U00010000")],
    ids=["ascending", "prefix_first", "empty_then_a", "fullwidth_tilde_then_supplementary", "bmp_private_then_supplementary"],
)
def test_ascending_keys_in_utf8_byte_order_are_accepted(keys: tuple[str, ...]):
    result = _unpack(_packet(*keys))

    assert result.ok is True
    assert list(result.value["d"]) == list(keys)


@pytest.mark.parametrize(
    "keys",
    [("b", "a"), ("a", "a"), ("ab", "a"), ("\U00010000", "～"), ("a", "b", "a")],
    ids=["descending", "repeated", "prefix_descends", "supplementary_then_fullwidth_tilde", "repeated_after_gap"],
)
def test_keys_that_do_not_ascend_are_refused_with_the_dict_key_error(keys: tuple[str, ...]):
    result = _unpack(_packet(*keys))

    assert result.ok is False
    assert result.value is None
    assert result.error == ShortPacket(field="", needed=0, left=0)


def test_a_repeated_key_in_two_byte_forms_is_refused():
    packet = bytes.fromhex("01020002106100" + "02c90000")

    result = _unpack(packet)

    assert result.ok is False
    assert result.error == ShortPacket(field="", needed=0, left=0)


def test_the_pack_side_writes_keys_in_utf8_byte_order():
    packet = BinaryPacker.pack(SCHEME, {"d": {"\U00010000": 3, "～": 2, "b": 1, "a": 0}})

    result = _unpack(packet)

    assert result.ok is True
    assert list(result.value["d"].items()) == [("a", 0), ("b", 1), ("～", 2), ("\U00010000", 3)]


def _reference_seconds() -> float:
    best = float("inf")
    for _ in range(3):
        start = time.perf_counter()
        sorted(f"key{n:05d}".encode() for n in range(65_535))
        best = min(best, time.perf_counter() - start)
    return best


def test_65535_ascending_keys_packed_by_the_package_unpack_within_a_second():
    # Arrange: the bound is 1 s on a quiet machine and grows with the load seen by a reference loop in this process.
    keys = {f"key{n:05d}": n & 0xFF for n in range(65_535)}
    packet = BinaryPacker.pack(SCHEME, {"d": keys})
    reference = _reference_seconds()
    start = time.perf_counter()

    # Act
    result = _unpack(packet)
    elapsed = time.perf_counter() - start

    # Assert
    assert result.ok is True
    assert len(result.value["d"]) == 65_535
    bound = 1.0 * max(1.0, reference / 0.03)
    assert elapsed <= bound, f"elapsed {elapsed:.3f}s, bound {bound:.3f}s (reference loop {reference:.3f}s)"
