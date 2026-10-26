from __future__ import annotations

import pytest

from packbin import BinaryPacker

import ecc_support as support

# AZ-2694 AC-1: a duplicate type number among the handlers is refused before any byte is read (contract message-ecc,
# Dispatch rows).


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


# AZ-2704 AC-3: the checks run in one order in every package (no handler, duplicate type, parity mix, limit); a
# duplicate later in the list than a mix of counts is still the duplicate refusal.
@pytest.mark.parametrize("parity", [0, 4])
def test_a_duplicate_type_number_is_refused_before_a_parity_mix_and_a_bad_limit(parity: int):
    # Arrange
    handler = support.position_scheme(parity).on(lambda row: None)
    mixed = support.position_scheme(4 if parity == 0 else 0, type_number=support.POSITION_TYPE + 1).on(lambda row: None)

    # Act and Assert
    with pytest.raises(ValueError, match="duplicate type number"):
        BinaryPacker.unpack(bytes(4), handler, mixed, handler)
    with pytest.raises(ValueError, match="duplicate type number"):
        BinaryPacker.unpack(bytes(4), handler, handler, limit=9)
