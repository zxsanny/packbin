from __future__ import annotations

import pytest

from packbin import BinaryPacker, PackSession

import ecc_support as support
from ecc_support import POSITION_VALUES

# AZ-2694 AC-1: a duplicate type number among the handlers is refused before any byte is read and before the receive
# index advances (contract message-ecc, Session and Dispatch rows).

SEED = bytes(range(1, 33))
NONCE = bytes.fromhex("01000000000000000000000000000000")


def _pair() -> tuple[PackSession, PackSession]:
    sender = PackSession.load(SEED)
    receiver = PackSession.load(SEED)
    assert sender is not None and receiver is not None
    assert sender.start(NONCE) == NONCE
    assert receiver.join(NONCE) is True
    return sender, receiver


@pytest.mark.parametrize("parity", [0, 4])
def test_a_duplicate_type_number_is_refused_and_the_receive_index_stays(parity: int):
    # Arrange
    scheme = support.position_scheme(parity)
    sender, receiver = _pair()
    first = sender.pack(scheme, POSITION_VALUES)
    second = sender.pack(scheme, POSITION_VALUES)
    assert first is not None and second is not None
    rows: list[dict] = []
    handler = scheme.on(rows.append)

    # Act
    with pytest.raises(ValueError, match="duplicate type number"):
        receiver.unpack(first, handler, handler)
    read_first = receiver.unpack(first, handler)
    read_second = receiver.unpack(second, handler)

    # Assert
    assert (read_first.ok, read_second.ok) == (True, True)
    assert rows == [read_first.value, read_second.value]
    assert len(rows) == 2


@pytest.mark.parametrize("parity", [0, 4])
def test_a_duplicate_type_number_is_refused_before_any_byte_is_read_by_the_static_unpack(parity: int):
    # Arrange
    scheme = support.position_scheme(parity)
    rows: list[dict] = []
    handler = scheme.on(rows.append)

    # Act
    with pytest.raises(ValueError, match="duplicate type number"):
        BinaryPacker.unpack(b"", handler, handler)

    # Assert
    assert rows == []
