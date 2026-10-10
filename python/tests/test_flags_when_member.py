from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    eq,
    flag_byte,
    flags,
    group,
    u8,
    u16,
    when,
)


def _k(name: str):
    return lambda row, name=name: row[name]


def _u8(field_id: int, name: str):
    return u8(field_id, _k(name))


def _u16(field_id: int, name: str):
    return u16(field_id, _k(name))


def _wa() -> Scheme:
    return Scheme(1, dict, _u8(0, "mode"), flags(1, when(1, eq(0, 1), _u8(1, "speed")), _u16(2, "heading")))


def _ws() -> Scheme:
    m = flag_byte()
    return Scheme(
        1, dict, _u8(0, "mode"), m, m.bit(when(1, eq(0, 1), _u8(1, "speed"))), m.bit(_u16(2, "heading"))
    )


def _wg() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "mode"),
        flags(1, group(1, when(1, eq(0, 1), _u8(1, "speed"))), _u16(2, "heading")),
    )


def _w2() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "mode"),
        flags(1, when(1, eq(0, 1), _u8(1, "speed"), _u8(2, "extra")), _u16(3, "heading")),
    )


def _gs() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "mode"),
        flags(1, group(1, _u8(1, "extra"), when(2, eq(0, 1), _u8(2, "speed"))), _u16(3, "heading")),
    )


def _we() -> Scheme:
    return Scheme(1, dict, flags(0, _u8(0, "mode"), when(1, eq(0, 1), _u8(1, "speed"))))


SCHEMES = {"WA": _wa, "WS": _ws, "WG": _wg, "W2": _w2, "GS": _gs, "WE": _we}

MODE1 = {"mode": 1, "heading": 90}
TRUE_ROW = {"mode": 1, "speed": 7, "heading": 90}
FALSE_ROW = {"mode": 0, "heading": 90}

# (case, scheme, row to pack, packet, row that packet unpacks to)
PACK_CASES = [
    ("W-true", "WA", TRUE_ROW, "010103075a00", TRUE_ROW),
    ("W-false", "WA", FALSE_ROW, "0100025a00", FALSE_ROW),
    ("W-true-no-body", "WA", MODE1, "0101025a00", MODE1),
    ("W-false-body-given", "WA", {**FALSE_ROW, "speed": 7}, "0100025a00", FALSE_ROW),
    ("W-only-when", "WA", {"mode": 1, "speed": 7}, "01010107", {"mode": 1, "speed": 7}),
    ("W-only-mode", "WA", {"mode": 0}, "010000", {"mode": 0}),
    ("W-split-true", "WS", TRUE_ROW, "010103075a00", TRUE_ROW),
    ("W-split-false", "WS", FALSE_ROW, "0100025a00", FALSE_ROW),
    ("W-split-no-body", "WS", MODE1, "0101025a00", MODE1),
    ("W-split-false-body-given", "WS", {**FALSE_ROW, "speed": 7}, "0100025a00", FALSE_ROW),
    ("W-group-true", "WG", TRUE_ROW, "010103075a00", TRUE_ROW),
    ("W-group-false", "WG", FALSE_ROW, "0100025a00", FALSE_ROW),
    ("W-group-no-body", "WG", MODE1, "0101025a00", MODE1),
    ("W-group-false-body-given", "WG", {**FALSE_ROW, "speed": 7}, "0100025a00", FALSE_ROW),
    ("W-group-only-when", "WG", {"mode": 1, "speed": 7}, "01010107", {"mode": 1, "speed": 7}),
    (
        "W-two-values",
        "W2",
        {"mode": 1, "speed": 7, "extra": 8, "heading": 90},
        "01010307085a00",
        {"mode": 1, "speed": 7, "extra": 8, "heading": 90},
    ),
    (
        "W-group-sibling-true",
        "GS",
        {"mode": 1, "extra": 4, "speed": 7, "heading": 90},
        "01010304075a00",
        {"mode": 1, "extra": 4, "speed": 7, "heading": 90},
    ),
    (
        "W-group-sibling-false",
        "GS",
        {"mode": 0, "extra": 4, "heading": 90},
        "010003045a00",
        {"mode": 0, "extra": 4, "heading": 90},
    ),
    ("W-group-nothing", "GS", MODE1, "0101025a00", MODE1),
    ("W-same-flags-true", "WE", {"mode": 1, "speed": 7}, "01030107", {"mode": 1, "speed": 7}),
    ("W-same-flags-false", "WE", {"mode": 0, "speed": 7}, "010100", {"mode": 0}),
    ("W-same-flags-no-body", "WE", {"mode": 1}, "010101", {"mode": 1}),
    ("W-same-flags-no-mode", "WE", {"speed": 7}, "0100", {}),
]

# (case, scheme, row, error type, text the error starts with: the id of the missing value)
ERROR_CASES = [
    ("W-missing-body-value", "W2", {"mode": 1, "speed": 7, "heading": 90}, KeyError, "'missing field 2'"),
    (
        "W-group-sibling-missing-when-body",
        "GS",
        {"mode": 1, "extra": 4, "heading": 90},
        KeyError,
        "'missing field 2'",
    ),
    (
        "W-group-sibling-missing-sibling",
        "GS",
        {"mode": 1, "speed": 7, "heading": 90},
        KeyError,
        "'missing field 1'",
    ),
]

# Packets of the shape written before loop 18 (bit clear), and the packet of a new row; unpack reads both.
UNPACK_CASES = [
    ("W-old-packet", "WA", "0101025a00", MODE1),
    ("W-new-packet", "WA", "010103075a00", TRUE_ROW),
    ("W-group-old-packet", "WG", "0101025a00", MODE1),
    ("W-split-old-packet", "WS", "0101025a00", MODE1),
    ("W-same-flags-unpack", "WE", "01030107", {"mode": 1, "speed": 7}),
]


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


@pytest.mark.parametrize("case,name,row,packet,_", PACK_CASES, ids=[c[0] for c in PACK_CASES])
def test_ac3_a_when_under_flags_packs_the_pinned_bytes(case, name, row, packet, _):
    assert BinaryPacker.pack(SCHEMES[name](), dict(row)).hex() == packet


@pytest.mark.parametrize("case,name,_,packet,unpacked", PACK_CASES, ids=[c[0] for c in PACK_CASES])
def test_ac5_a_when_under_flags_packet_unpacks_to_the_pinned_row(case, name, _, packet, unpacked):
    result = _unpack(SCHEMES[name](), packet)

    assert result.ok, result.error
    assert result.value == unpacked


@pytest.mark.parametrize("case,name,row,packet,unpacked", PACK_CASES, ids=[c[0] for c in PACK_CASES])
def test_ac3_the_unpacked_row_of_a_when_under_flags_repacks_to_the_same_bytes(case, name, row, packet, unpacked):
    scheme = SCHEMES[name]()

    assert BinaryPacker.pack(scheme, dict(unpacked)).hex() == packet


@pytest.mark.parametrize("case,name,packet,unpacked", UNPACK_CASES, ids=[c[0] for c in UNPACK_CASES])
def test_ac5_old_and_new_when_under_flags_packets_unpack(case, name, packet, unpacked):
    result = _unpack(SCHEMES[name](), packet)

    assert result.ok, result.error
    assert result.value == unpacked


@pytest.mark.parametrize("case,name,row,kind,text", ERROR_CASES, ids=[c[0] for c in ERROR_CASES])
def test_ac3_a_set_when_member_missing_a_value_fails_pack_naming_it(case, name, row, kind, text):
    with pytest.raises(kind) as raised:
        BinaryPacker.pack(SCHEMES[name](), dict(row))

    assert str(raised.value) == text


def test_ac3_a_when_body_value_outside_its_range_fails_pack_naming_the_field():
    with pytest.raises(OverflowError, match=r"^1: 300 does not fit in u8$"):
        BinaryPacker.pack(_wa(), {"mode": 1, "speed": 300, "heading": 90})


def test_ac3_a_when_body_value_outside_its_range_is_not_checked_while_the_condition_is_false():
    assert BinaryPacker.pack(_wa(), {"mode": 0, "speed": 300, "heading": 90}).hex() == "0100025a00"


class _Row:
    mode = None
    speed = None
    heading = None


def test_ac3_a_typed_row_packs_the_same_bytes_as_a_dict_row():
    scheme = Scheme(
        1,
        _Row,
        u8(0, lambda row: row.mode),
        flags(1, when(1, eq(0, 1), u8(1, lambda row: row.speed)), u16(2, lambda row: row.heading)),
    )
    row = _Row()
    row.mode, row.speed, row.heading = 1, 7, 90

    packed = BinaryPacker.pack(scheme, row)
    result = _unpack(scheme, packed.hex())

    assert packed.hex() == "010103075a00"
    assert (result.value.mode, result.value.speed, result.value.heading) == (1, 7, 90)
