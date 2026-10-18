from __future__ import annotations

import pytest

from packbin import BinaryPacker, TooLong, Uncorrectable, _ecc

import ecc_support as support
from ecc_support import POSITION_HEX, POSITION_VALUES, Row

# AZ-2680 AC-1, AC-2, AC-4, AC-5: the shared vector rows (`fixtures/ecc/vectors.txt`) and the position rows 1 to 14
# of the results report, read through the public pack and unpack. An empty clear message is no message of the
# package (every message holds its type byte), so the `enc` rows with an empty clear check the codec itself.

ENC = support.rows("enc")
FIX = support.rows("fix")
BAD = support.rows("bad")
LIM = support.rows("lim")
PAR = support.rows("par")
LMT = support.rows("lmt")

REPORT_BYTES = {
    1: "4001000065cd1d00a3e1110100ab",
    2: "4001000065cd1d00a3e111010016bd",
    4: "4001000065cd1d00a3e1110100ca856682",
    8: "4001000065cd1d00a3e11101006d4f38479f3f2472",
    16: "4001000065cd1d00a3e11101004ace66ecd5e4a28ffa28098279f5f19d",
}


def _body(clear: bytes) -> dict:
    return {"b": list(clear[1:])}


def _scheme_of(clear: bytes, parity: int):
    return support.raw_scheme(clear[0], parity)


@pytest.mark.parametrize("row", [r for r in ENC if r.clear], ids=support.ids([r for r in ENC if r.clear]))
def test_enc_row_pack_gives_the_protected_bytes(row: Row):
    # Arrange
    scheme = _scheme_of(row.clear, row.n)

    # Act
    packet = BinaryPacker.pack(scheme, _body(row.clear))

    # Assert
    assert packet == row.received


@pytest.mark.parametrize("row", [r for r in ENC if not r.clear], ids=support.ids([r for r in ENC if not r.clear]))
def test_enc_row_of_an_empty_clear_message_gives_the_parity_of_the_codec(row: Row):
    # Arrange
    expected = row.received

    # Act
    parity = _ecc.parity(b"", row.n) if row.n else b""

    # Assert
    assert parity == expected


@pytest.mark.parametrize("row", [r for r in ENC if r.clear], ids=support.ids([r for r in ENC if r.clear]))
def test_enc_row_unpacks_intact_with_zero_repaired(row: Row):
    # Arrange
    scheme = _scheme_of(row.clear, row.n)

    # Act
    result = support.read(row.received, scheme)

    # Assert
    assert (result.ok, result.value.get("b", []), result.repaired) == (True, list(row.clear[1:]), 0)


@pytest.mark.parametrize("row", FIX, ids=support.ids(FIX))
def test_fix_row_unpack_repairs_to_the_clear_message_and_counts_the_bytes(row: Row):
    # Arrange
    scheme = _scheme_of(row.clear, row.n)

    # Act
    result = support.read(row.received, scheme, limit=row.t)

    # Assert
    assert (result.ok, result.value.get("b", []), result.repaired) == (True, list(row.clear[1:]), int(row.expect))


@pytest.mark.parametrize("row", BAD, ids=support.ids(BAD))
def test_bad_row_unpack_is_refused_with_the_stated_kind_and_no_value(row: Row):
    # Arrange
    seen: list = []
    scheme = support.raw_scheme(0x40, row.n)

    # Act
    result = BinaryPacker.unpack(row.received, scheme.on(seen.append), limit=row.t)

    # Assert
    assert (support.kind_of(result), result.value, seen) == (row.expect, None, [])


LIM_OK = [r for r in LIM if r.expect == "ok"]
LIM_REFUSED = [r for r in LIM if r.expect == "too_long"]


@pytest.mark.parametrize("row", LIM_OK, ids=support.ids(LIM_OK))
def test_lim_row_pack_of_a_clear_message_within_the_limit_gives_clear_plus_parity_bytes(row: Row):
    # Arrange
    scheme = support.raw_scheme(0, row.n)

    # Act
    packet = BinaryPacker.pack(scheme, {"b": [0] * (len(row.clear) - 1)})

    # Assert
    assert len(packet) == len(row.clear) + row.n


@pytest.mark.parametrize("row", LIM_REFUSED, ids=support.ids(LIM_REFUSED))
def test_lim_row_pack_above_the_limit_is_refused_naming_the_clear_length_and_the_limit(row: Row):
    # Arrange
    scheme = support.raw_scheme(0, row.n)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.pack(scheme, {"b": [0] * (len(row.clear) - 1)})

    # Assert
    assert (str(len(row.clear)) in str(refused.value), str(254 - row.n) in str(refused.value)) == (True, True)


@pytest.mark.parametrize("row", PAR, ids=support.ids(PAR))
def test_par_row_scheme_with_that_many_parity_bytes_is_not_built_naming_n_and_32(row: Row):
    # Arrange
    scheme = support.raw_scheme(0x40)

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity=row.n)

    # Assert
    assert (str(row.n) in str(refused.value), "32" in str(refused.value)) == (True, True)


@pytest.mark.parametrize("row", LMT, ids=support.ids(LMT))
def test_lmt_row_limit_above_half_the_parity_is_refused_before_any_byte_is_read(row: Row):
    # Arrange
    seen: list = []
    scheme = support.raw_scheme(0x40, row.n)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40", scheme.on(seen.append), limit=row.t)

    # Assert
    assert (str(row.t) in str(refused.value), seen) == (True, [])


@pytest.mark.parametrize("parity", [1, 2, 4, 8, 16])
def test_ec2_position_fixture_packs_to_the_golden_protected_bytes(parity: int):
    # Arrange
    scheme = support.position_scheme(parity)

    # Act
    packet = BinaryPacker.pack(scheme, POSITION_VALUES)

    # Assert
    assert packet.hex() == REPORT_BYTES[parity]


def test_ec1_position_fixture_with_zero_parity_bytes_is_the_unchanged_golden_bytes():
    # Arrange
    scheme = support.position_scheme(0)

    # Act
    packet = BinaryPacker.pack(scheme, POSITION_VALUES)

    # Assert
    assert packet.hex() == POSITION_HEX


def test_ec3_position_scheme_with_33_parity_bytes_is_not_built_and_names_33_and_32():
    # Arrange
    scheme = support.position_scheme()

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity=33)

    # Assert
    assert ("33" in str(refused.value), "32" in str(refused.value)) == (True, True)


def test_ec5_report_row_7_one_changed_bit_is_repaired_to_the_position_row():
    # Arrange
    scheme = support.position_scheme(2)
    received = bytes.fromhex("4001000065cc1d00a3e111010016bd")
    expected = support.read(bytes.fromhex(REPORT_BYTES[2]), scheme).value

    # Act
    result = support.read(received, scheme, limit=1)

    # Assert
    assert (result.ok, result.value, result.repaired) == (True, expected, 1)


def test_ec5_report_row_8_two_changed_bytes_are_repaired_to_the_position_row():
    # Arrange
    scheme = support.position_scheme(4)
    received = bytes.fromhex("40015a0065cd1d00a322110100ca856682")
    expected = support.read(bytes.fromhex(REPORT_BYTES[4]), scheme).value

    # Act
    result = support.read(received, scheme, limit=2)

    # Assert
    assert (result.ok, result.value, result.repaired) == (True, expected, 2)


@pytest.mark.parametrize("limit", [0, 1])
def test_ec6_report_rows_9_and_10_two_changed_bytes_under_a_smaller_limit_are_uncorrectable(limit: int):
    # Arrange
    scheme = support.position_scheme(4)
    received = bytes.fromhex("40015a0065cd1d00a322110100ca856682")

    # Act
    result = support.read(received, scheme, limit=limit)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, Uncorrectable())


def test_ec8_report_row_11_an_intact_message_returns_the_row_with_zero_repaired():
    # Arrange
    scheme = support.position_scheme(4)
    expected = support.read(bytes.fromhex(POSITION_HEX), support.position_scheme(0)).value

    # Act
    result = support.read(bytes.fromhex(REPORT_BYTES[4]), scheme, limit=2)

    # Assert
    assert (result.ok, result.value, result.repaired) == (True, expected, 0)


def test_ec8_report_row_12_three_bytes_under_four_parity_bytes_name_the_parity_4_needed_3_present():
    # Arrange
    scheme = support.position_scheme(4)

    # Act
    result = support.read(bytes.fromhex("400100"), scheme, limit=2)

    # Assert
    assert (result.ok, result.value, result.field, result.needed, result.left) == (False, None, "parity", 4, 3)


def test_ec4_report_row_13_a_251_byte_clear_message_under_four_parity_bytes_names_251_and_250():
    # Arrange
    scheme = support.raw_scheme(0x40, 4)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.pack(scheme, {"b": [0] * 250})

    # Assert
    assert ("251" in str(refused.value), "250" in str(refused.value)) == (True, True)


def test_ec4_a_buffer_above_254_bytes_under_a_protected_scheme_is_too_long_with_no_value():
    # Arrange
    scheme = support.raw_scheme(0x40, 4)

    # Act
    result = support.read(bytes(255), scheme)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, TooLong(length=255, limit=254))


def test_ec4_a_failed_pack_of_a_clear_message_above_the_limit_writes_no_bytes_and_the_next_pack_works():
    # Arrange
    scheme = support.raw_scheme(0x40, 32)

    # Act
    with pytest.raises(ValueError):
        BinaryPacker.pack(scheme, {"b": [0] * 222})
    packet = BinaryPacker.pack(scheme, {"b": [0] * 221})

    # Assert
    assert len(packet) == 254
