from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    flag_byte,
    flags,
    group,
    repeat,
    times,
    u8,
    u16,
)


def _k(name: str):
    return lambda row, name=name: row[name]


def _u8(field_id: int, name: str):
    return u8(field_id, _k(name))


def _u16(field_id: int, name: str):
    return u16(field_id, _k(name))


def _ta() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), flags(1, times(1, 0, _u8(1, "pt")), _u16(2, "heading")))


def _ts() -> Scheme:
    m = flag_byte()
    return Scheme(1, dict, _u8(0, "n"), m, m.bit(times(1, 0, _u8(1, "pt"))), m.bit(_u16(2, "heading")))


def _tg() -> Scheme:
    return Scheme(
        1, dict, _u8(0, "n"), flags(1, group(1, times(1, 0, _u8(1, "pt"))), _u16(2, "heading"))
    )


def _t2() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "n"),
        flags(1, times(1, 0, _u8(1, "pt"), _u8(2, "pu")), _u16(3, "heading")),
    )


def _ra() -> Scheme:
    return Scheme(1, dict, _u8(0, "mode"), flags(1, _u16(1, "heading"), repeat(2, _u8(2, "pt"))))


def _r2() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "mode"),
        flags(1, _u16(1, "heading"), repeat(2, _u8(2, "pt"), _u8(3, "pu"))),
    )


SCHEMES = {"TA": _ta, "TS": _ts, "TG": _tg, "T2": _t2, "RA": _ra, "R2": _r2}

T0 = {"n": 0, "heading": 90}
T1 = {"n": 1, "pt": [5], "heading": 90}
T2R = {"n": 2, "pt": [5, 6], "heading": 90}
TIMES_ROWS = [
    ("0-rounds", T0, "0100025a00"),
    ("1-round", T1, "010103055a00"),
    ("2-rounds", T2R, "01020305065a00"),
    ("only-times", {"n": 2, "pt": [5, 6]}, "0102010506"),
    ("only-n", {"n": 0}, "010000"),
]
TIMES_ERRORS = [
    ("list-too-short", {"n": 2, "pt": [5], "heading": 90}, ValueError, "1: 1 items, times count is 2"),
    ("values-missing", {"n": 1, "heading": 90}, TypeError, "1: expected int, got NoneType"),
    ("count-0-values-given", {"n": 0, "pt": [5], "heading": 90}, ValueError, "1: 1 items, times count is 0"),
    ("list-too-long", {"n": 1, "pt": [5, 6], "heading": 90}, ValueError, "1: 2 items, times count is 1"),
]
ONE_VALUE_SCHEMES = ["TA", "TS", "TG"]

REPEAT_ROWS = [
    ("R-0-rounds", "RA", {"mode": 1, "heading": 90}, "0101015a00"),
    ("R-1-round", "RA", {"mode": 1, "pt": [5], "heading": 90}, "0101035a0005"),
    ("R-2-rounds", "RA", {"mode": 1, "pt": [5, 6], "heading": 90}, "0101035a000506"),
    ("R-only-repeat", "RA", {"mode": 1, "pt": [5, 6]}, "0101020506"),
    ("R-only-mode", "RA", {"mode": 1}, "010100"),
    ("R-two-values-1", "R2", {"mode": 1, "pt": [5], "pu": [6], "heading": 90}, "0101035a000506"),
    (
        "R-two-values-2",
        "R2",
        {"mode": 1, "pt": [5, 6], "pu": [7, 8], "heading": 90},
        "0101035a0005070608",
    ),
]


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def _times_cases():
    return [
        pytest.param(name, case, row, packet, id=f"{name}-{case}")
        for name in ONE_VALUE_SCHEMES
        for case, row, packet in TIMES_ROWS
    ]


@pytest.mark.parametrize("name,case,row,packet", _times_cases())
def test_ac4_a_times_under_flags_packs_the_pinned_bytes_and_round_trips(name, case, row, packet):
    scheme = SCHEMES[name]()

    result = _unpack(scheme, packet)

    assert BinaryPacker.pack(scheme, dict(row)).hex() == packet
    assert result.ok, result.error
    assert result.value == row


@pytest.mark.parametrize("name", ONE_VALUE_SCHEMES)
@pytest.mark.parametrize("case,row,kind,text", TIMES_ERRORS, ids=[c[0] for c in TIMES_ERRORS])
def test_ac4_a_set_times_member_that_cannot_be_written_in_full_fails_pack_naming_the_value(
    name, case, row, kind, text
):
    with pytest.raises(kind) as raised:
        BinaryPacker.pack(SCHEMES[name](), dict(row))

    assert str(raised.value) == text


@pytest.mark.parametrize("name", ONE_VALUE_SCHEMES)
def test_ac5_old_and_new_times_under_flags_packets_unpack(name):
    scheme = SCHEMES[name]()

    old = _unpack(scheme, "0100025a00")
    new = _unpack(scheme, "01020305065a00")

    assert old.ok and old.value == T0
    assert new.ok and new.value == T2R


def test_ac4_two_values_per_round_pack_in_round_order():
    scheme = _t2()
    one = {"n": 1, "pt": [5], "pu": [6], "heading": 90}
    two = {"n": 2, "pt": [5, 6], "pu": [7, 8], "heading": 90}

    assert BinaryPacker.pack(scheme, dict(one)).hex() == "01010305065a00"
    assert BinaryPacker.pack(scheme, dict(two)).hex() == "010203050706085a00"
    assert _unpack(scheme, "01010305065a00").value == one
    assert _unpack(scheme, "010203050706085a00").value == two


def test_ac4_a_times_round_missing_its_second_value_fails_pack_naming_it():
    with pytest.raises(TypeError) as raised:
        BinaryPacker.pack(_t2(), {"n": 1, "pt": [5], "heading": 90})

    assert str(raised.value) == "2: expected int, got NoneType"


def test_ac4_a_times_round_value_outside_its_range_fails_pack_naming_the_field():
    with pytest.raises(OverflowError, match=r"^1: 300 does not fit in u8$"):
        BinaryPacker.pack(_ta(), {"n": 1, "pt": [300], "heading": 90})


def test_ac4_a_times_count_above_zero_sets_the_bit_only_through_the_count_written_so_far():
    scheme = Scheme(1, dict, flags(0, _u8(0, "n"), times(1, 0, _u8(1, "pt"))))

    assert BinaryPacker.pack(scheme, {"n": 2, "pt": [5, 6]}).hex() == "0103020506"
    assert BinaryPacker.pack(scheme, {"n": 0}).hex() == "010100"
    assert BinaryPacker.pack(scheme, {}).hex() == "0100"
    with pytest.raises(ValueError, match=r"^times 1: body values are given, but count field 0 has no value"):
        BinaryPacker.pack(scheme, {"pt": [5, 6]})


@pytest.mark.parametrize("case,name,row,packet", REPEAT_ROWS, ids=[c[0] for c in REPEAT_ROWS])
def test_ac4_a_repeat_under_flags_packs_the_pinned_bytes_and_round_trips(case, name, row, packet):
    scheme = SCHEMES[name]()

    result = _unpack(scheme, packet)

    assert BinaryPacker.pack(scheme, dict(row)).hex() == packet
    assert result.ok, result.error
    assert result.value == row


def test_ac5_old_and_new_repeat_under_flags_packets_unpack():
    old = _unpack(_ra(), "0101015a00")
    new = _unpack(_ra(), "0101035a000506")

    assert old.ok and old.value == {"mode": 1, "heading": 90}
    assert new.ok and new.value == {"mode": 1, "pt": [5, 6], "heading": 90}


def test_ac5_a_repeat_with_two_values_unpacks_into_two_rounds():
    result = _unpack(_r2(), "0101035a0005060708")

    assert result.ok, result.error
    assert result.value == {"mode": 1, "pt": [5, 7], "pu": [6, 8], "heading": 90}


def test_ac4_a_repeat_round_missing_its_second_value_fails_pack_naming_it():
    with pytest.raises(TypeError) as raised:
        BinaryPacker.pack(_r2(), {"mode": 1, "pt": [5], "heading": 90})

    assert str(raised.value) == "3: expected int, got NoneType"


class _Row:
    n = None
    pt = None
    heading = None


def test_ac4_a_typed_row_packs_the_same_times_bytes_as_a_dict_row():
    scheme = Scheme(
        1,
        _Row,
        u8(0, lambda row: row.n),
        flags(1, times(1, 0, u8(1, lambda row: row.pt)), u16(2, lambda row: row.heading)),
    )
    row = _Row()
    row.n, row.pt, row.heading = 2, [5, 6], 90

    packed = BinaryPacker.pack(scheme, row)
    result = _unpack(scheme, packed.hex())

    assert packed.hex() == "01020305065a00"
    assert (result.value.n, result.value.pt, result.value.heading) == (2, [5, 6], 90)
