from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    bool as flag_bool,
    bytes as raw_bytes,
    eq,
    f32,
    f64,
    flag_byte,
    flags,
    i16,
    packed,
    sized,
    times,
    u2,
    u8,
    utf8,
    when,
)


def _row(name: str):
    return lambda row, name=name: row[name]


def _on(field_id: int = 0):
    return flag_bool(field_id, _row("on"))


def _bool_when(value) -> Scheme:
    return Scheme(1, dict, flags(0, _on()), when(1, eq(0, value), u8(1, _row("v"))))


def _unpack(scheme: Scheme, raw: bytes):
    result = BinaryPacker.unpack(raw, scheme.on(lambda _row: None))
    assert result.ok, result.error
    return result.value


def test_az_2126_ac2_eq_true_on_a_bool_round_trips():
    scheme = _bool_when(True)

    raw = BinaryPacker.pack(scheme, {"on": True, "v": 5})

    assert raw.hex() == "010105"
    assert _unpack(scheme, raw) == {"on": True, "v": 5}


def test_az_2126_ac2_eq_true_on_a_flag_byte_bit_round_trips():
    handle = flag_byte()
    scheme = Scheme(1, dict, handle, handle.bit(_on()), when(1, eq(0, True), u8(1, _row("v"))))

    raw = BinaryPacker.pack(scheme, {"on": True, "v": 5})

    assert _unpack(scheme, raw) == {"on": True, "v": 5}


@pytest.mark.parametrize("value", [False, 1, 0, "yes", None], ids=repr)
def test_az_2126_ac1_eq_on_a_bool_with_anything_but_true_is_a_scheme_error(value):
    with pytest.raises(ValueError, match=r"when 1: .*bool field 0 .*compared only with true"):
        _bool_when(value)


def test_az_2126_ac1_eq_on_a_flag_byte_bit_with_false_is_a_scheme_error():
    handle = flag_byte()

    with pytest.raises(ValueError, match=r"when 1: .*bool field 0"):
        Scheme(1, dict, handle, handle.bit(_on()), when(1, eq(0, False), u8(1, _row("v"))))


def test_az_2126_ac1_eq_on_a_bool_inside_a_round_with_false_is_a_scheme_error():
    with pytest.raises(ValueError, match=r"when 2: .*bool field 1"):
        Scheme(1, dict, u8(0, _row("n")), times(1, 0, flags(1, _on(1)), when(2, eq(1, False), u8(2, _row("v")))))


@pytest.mark.parametrize(
    "source,kind",
    [
        (lambda: f32(0, _row("k")), "f32"),
        (lambda: f64(0, _row("k")), "f64"),
        (lambda: utf8(0, _row("k")), "utf8"),
        (lambda: raw_bytes(0, _row("k"), 1), "bytes"),
    ],
    ids=["f32", "f64", "utf8", "bytes"],
)
def test_az_2126_when_naming_a_non_integer_non_bool_source_is_a_scheme_error(source, kind):
    with pytest.raises(ValueError, match=rf"when 1: .*field 0, which is a {kind}"):
        Scheme(1, dict, source(), when(1, eq(0, 1), u8(1, _row("v"))))


@pytest.mark.parametrize("make", [lambda: sized(1, _row("p"), 0), lambda: bits(1, _row("p"), 0),
                                  lambda: packed(1, 1, _row("p"), 0)], ids=["sized", "bits", "packed"])
def test_az_2126_when_naming_a_counted_field_is_a_scheme_error(make):
    with pytest.raises(ValueError, match=r"when 2: .*field 1"):
        Scheme(1, dict, u8(0, _row("n")), make(), when(2, eq(1, 1), u8(2, _row("v"))))


@pytest.mark.parametrize("kind", [u8, i16], ids=["u8", "i16"])
def test_az_2126_when_on_an_integer_keeps_working(kind):
    scheme = Scheme(1, dict, kind(0, _row("k")), when(1, eq(0, 1), u8(1, _row("v"))))

    raw = BinaryPacker.pack(scheme, {"k": 1, "v": 5})

    assert raw.hex() == ("010105" if kind is u8 else "01010005")
    assert _unpack(scheme, raw) == {"k": 1, "v": 5}


def test_az_2126_when_on_a_u2_slot_keeps_working():
    scheme = Scheme(1, dict, u2((0, _row("a")), (1, _row("b"))), when(2, eq(1, 1), u8(2, _row("v"))))

    raw = BinaryPacker.pack(scheme, {"a": 1, "b": 1, "v": 5})

    assert _unpack(scheme, raw) == {"a": 1, "b": 1, "v": 5}


def _counts(source):
    return {
        "sized": lambda: Scheme(1, dict, source(), sized(1, _row("p"), 0)),
        "bits": lambda: Scheme(1, dict, source(), bits(1, _row("p"), 0)),
        "packed": lambda: Scheme(1, dict, source(), packed(1, 1, _row("p"), 0)),
        "times": lambda: Scheme(1, dict, source(), times(1, 0, u8(1, _row("x")))),
    }


@pytest.mark.parametrize("consumer", ["sized", "bits", "packed", "times"])
@pytest.mark.parametrize(
    "source,kind",
    [
        (lambda: flags(0, _on()), "bool"),
        (lambda: f32(0, _row("n")), "f32"),
        (lambda: f64(0, _row("n")), "f64"),
        (lambda: utf8(0, _row("n")), "utf8"),
        (lambda: raw_bytes(0, _row("n"), 1), "bytes"),
    ],
    ids=["bool", "f32", "f64", "utf8", "bytes"],
)
def test_az_2126_a_count_naming_a_non_integer_field_is_a_scheme_error(consumer, source, kind):
    with pytest.raises(ValueError, match=rf"{consumer} 1: count names field 0, which is a {kind}; a count names an integer"):
        _counts(source)[consumer]()


def test_az_2126_a_count_naming_a_counted_field_is_a_scheme_error():
    with pytest.raises(ValueError, match=r"times 2: count names field 1, which is a sized"):
        Scheme(1, dict, u8(0, _row("m")), sized(1, _row("p"), 0), times(2, 1, u8(2, _row("x"))))


@pytest.mark.parametrize("consumer", ["sized", "bits", "packed", "times"])
def test_az_2126_a_count_naming_an_integer_keeps_working(consumer):
    scheme = _counts(lambda: u8(0, _row("n")))[consumer]()
    row = {
        "sized": {"n": 1, "p": b"a"},
        "bits": {"n": 1, "p": [1]},
        "packed": {"n": 1, "p": [1]},
        "times": {"n": 1, "x": [7]},
    }[consumer]

    raw = BinaryPacker.pack(scheme, row)

    assert _unpack(scheme, raw) == row


def test_az_2126_a_count_naming_a_u2_slot_keeps_working():
    scheme = Scheme(1, dict, u2((0, _row("a")), (1, _row("b"))), sized(2, _row("p"), 1))

    raw = BinaryPacker.pack(scheme, {"a": 0, "b": 1, "p": b"a"})

    assert raw.hex() == "010461"
    assert _unpack(scheme, raw) == {"a": 0, "b": 1, "p": b"a"}
