from __future__ import annotations

from array import array

import pytest

from packbin import BinaryPacker, PackSession, Scheme, u8

SCHEME = Scheme(0x40, dict, u8(0, lambda row: row["a"]))
SEED = bytes(range(1, 33))
NONCE = bytes.fromhex("01000000000000000000000000000000")


def _pair() -> tuple[PackSession, PackSession]:
    sender, receiver = PackSession.load(SEED), PackSession.load(SEED)
    assert sender is not None and receiver is not None
    assert sender.start(NONCE) == NONCE and receiver.join(NONCE)
    return sender, receiver


@pytest.mark.parametrize("payload", ["abc", 10**9, 3, None, 1.5, [1, 2], object()], ids=["str", "huge_int", "int", "none", "float", "list", "object"])
def test_a_payload_that_is_not_bytes_like_raises_before_the_receive_index_moves(payload):
    sender, receiver = _pair()
    packet = sender.pack(SCHEME, {"a": 7})
    seen: list[dict] = []

    with pytest.raises(TypeError):
        receiver.unpack(payload, SCHEME.on(seen.append))
    got = receiver.unpack(packet, SCHEME.on(seen.append))

    assert got.ok is True
    assert seen == [{"a": 7}]


@pytest.mark.parametrize("make", [bytes, bytearray, memoryview, lambda b: array("B", b)], ids=["bytes", "bytearray", "memoryview", "array"])
def test_a_bytes_like_payload_still_unpacks(make):
    sender, receiver = _pair()
    seen: list[dict] = []

    got = receiver.unpack(make(sender.pack(SCHEME, {"a": 9})), SCHEME.on(seen.append))

    assert got.ok is True
    assert seen == [{"a": 9}]


def test_the_plain_unpack_refuses_a_wrong_type_payload_too():
    for payload in ("abc", 5, None):
        with pytest.raises(TypeError):
            BinaryPacker.unpack(payload, SCHEME.on(lambda row: None))
