from __future__ import annotations

import pytest

from packbin import BinaryPacker, _ecc

import ecc_support as support
import percent_support as ps

# AZ-3500 AC-7: every row word of `fixtures/ecc/percent-vectors.txt` (pct, encp, inv, limp, fixp, badp, parp,
# lmtp) through the public pack and unpack. An empty clear message is no message of the package (every message
# holds its type byte), so those rows check the codec's rule and the unpack of an empty buffer.

PCT = ps.rows("pct")
ENCP = ps.rows("encp")
INV = ps.rows("inv")
LIMP = ps.rows("limp")
FIXP = ps.rows("fixp")
BADP = ps.rows("badp")
PARP = ps.rows("parp")
LMTP = ps.rows("lmtp")


def test_every_row_word_of_the_file_is_read_and_each_has_rows():
    # Arrange
    words = {"pct", "encp", "inv", "limp", "fixp", "badp", "parp", "lmtp"}

    # Act
    found = {row.kind for row in ps.ROWS}

    # Assert
    assert found == words


@pytest.mark.parametrize("row", PCT, ids=ps.ids(PCT))
def test_pct_row_the_count_of_the_percentage_and_the_length(row: ps.PRow):
    # Arrange
    length = len(row.clear)
    packable = length >= 1 and (row.p == 0 or length <= ps.largest_of(row.p))

    # Act
    count = _ecc.parity_count(row.p, length)
    sent = len(BinaryPacker.pack(ps.percent_scheme(row.p), {"b": [0] * (length - 1)})) - length if packable else count

    # Assert
    assert (count, sent) == (row.n, row.n)


@pytest.mark.parametrize("row", ENCP, ids=ps.ids(ENCP))
def test_encp_row_pack_gives_the_protected_bytes(row: ps.PRow):
    # Arrange
    scheme = ps.percent_scheme(row.p, row.clear[0] if row.clear else 0)

    # Act
    packet = BinaryPacker.pack(scheme, ps.body_of(row.clear)) if row.clear else b""

    # Assert
    assert packet == row.received


@pytest.mark.parametrize("row", INV, ids=ps.ids(INV))
def test_inv_row_the_clear_length_of_a_sent_length_or_none(row: ps.PRow):
    # Arrange
    sent = row.n
    scheme = ps.percent_scheme(row.p)

    # Act
    length = sent if row.p == 0 else _ecc.clear_length(row.p, sent)
    result = support.read(bytes(sent), scheme) if row.expect == "none" else None

    # Assert
    assert ("none" if length is None else str(length)) == row.expect
    assert result is None or (support.kind_of(result), result.value) == ("uncorrectable", None)


LIMP_OK = [r for r in LIMP if r.expect == "ok"]
LIMP_REFUSED = [r for r in LIMP if r.expect == "too_long"]


@pytest.mark.parametrize("row", LIMP_OK, ids=ps.ids(LIMP_OK))
def test_limp_row_pack_within_the_limit_gives_clear_plus_the_derived_parity(row: ps.PRow):
    # Arrange
    scheme = ps.long_percent_scheme(row.p)

    # Act
    packet = BinaryPacker.pack(scheme, ps.long_row(row.n))

    # Assert
    expected = row.n if row.p == 0 else row.n + ps.count_of(row.p, row.n)
    assert len(packet) == expected


@pytest.mark.parametrize("row", LIMP_REFUSED, ids=ps.ids(LIMP_REFUSED))
def test_limp_row_pack_above_the_limit_is_refused_naming_the_length_and_the_limit(row: ps.PRow):
    # Arrange
    scheme = ps.long_percent_scheme(row.p)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.pack(scheme, ps.long_row(row.n))

    # Assert
    assert (str(row.n) in str(refused.value), str(ps.LARGEST_CLEAR[row.p]) in str(refused.value)) == (True, True)


@pytest.mark.parametrize("row", FIXP, ids=ps.ids(FIXP))
def test_fixp_row_unpack_repairs_to_the_clear_message_and_counts_the_bytes(row: ps.PRow):
    # Arrange
    scheme = ps.percent_scheme(row.p, row.clear[0] if row.clear else 0)

    # Act
    result = support.read(row.received, scheme, limit=row.t)

    # Assert
    if row.clear:
        assert (result.ok, result.value.get("b", []), result.repaired) == (True, list(row.clear[1:]), row.n)
    else:
        assert (result.ok, result.field, result.needed, result.left) == (False, "", 1, 0)


@pytest.mark.parametrize("row", BADP, ids=ps.ids(BADP))
def test_badp_row_unpack_is_refused_with_the_stated_kind_and_no_value(row: ps.PRow):
    # Arrange
    seen: list = []
    scheme = ps.percent_scheme(row.p)

    # Act
    result = BinaryPacker.unpack(row.received, scheme.on(seen.append), limit=row.t)

    # Assert
    assert (support.kind_of(result), result.value, seen) == (row.expect, None, [])


@pytest.mark.parametrize("row", PARP, ids=ps.ids(PARP))
def test_parp_row_percentage_with_a_count_is_not_built_naming_the_percentage_and_100(row: ps.PRow):
    # Arrange
    scheme = support.raw_scheme(0x40)

    # Act
    with pytest.raises(ValueError) as refused:
        scheme.with_limits(parity=row.n, parity_percent=row.p)

    # Assert
    assert (str(row.p) in str(refused.value), "100" in str(refused.value)) == (True, True)


@pytest.mark.parametrize("row", LMTP, ids=ps.ids(LMTP))
def test_lmtp_row_limit_outside_0_to_16_is_refused_before_any_byte_is_read(row: ps.PRow):
    # Arrange
    seen: list = []
    scheme = ps.percent_scheme(25)

    # Act
    with pytest.raises(ValueError) as refused:
        BinaryPacker.unpack(b"\x40", scheme.on(seen.append), limit=row.t)

    # Assert
    assert (str(row.t) in str(refused.value), seen) == (True, [])
