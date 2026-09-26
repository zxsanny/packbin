from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    bool as flag_bool,
    eq,
    flags,
    i32,
    packed,
    times,
    u8,
    u16,
    when,
)

ROUTE = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101"


def _route():
    return Scheme(
        0x34,
        dict,
        u16(0, lambda row: row["sid"]),
        u16(1, lambda row: row["name"]),
        flags(
            u16(2, lambda row: row["unit"]),
            flag_bool(3, lambda row: row["straight"]),
            u16(4, lambda row: row["route_id"]),
        ),
        u8(5, lambda row: row["count"]),
        packed(2, 6, lambda row: row["kinds"], 5),
        times(5, i32(7, lambda row: row["lat"]), i32(8, lambda row: row["lon"])),
        when(eq(3, True), packed(1, 9, lambda row: row["mask"], 5, -1)),
    )


def test_width2_four_values_are_one_byte():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["n"]),
        packed(2, 1, lambda row: row["kinds"], 0),
    )
    raw = BinaryPacker.pack(layout, {"n": 4, "kinds": [0, 1, 2, 3]})
    assert raw[1:].hex() == "04e4"
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["kinds"] == [0, 1, 2, 3]


def test_width1_bias_minus_one():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["n"]),
        packed(1, 1, lambda row: row["kinds"], 0, -1),
    )
    eight = BinaryPacker.pack(layout, {"n": 9, "kinds": [1] * 8})
    assert eight[1:].hex() == "09ff"
    none = BinaryPacker.pack(layout, {"n": 1, "kinds": []})
    assert none[1:].hex() == "01"
    got = BinaryPacker.unpack(none, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["kinds"] == []


def test_length_mismatch_names_the_field():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["n"]),
        packed(2, 1, lambda row: row["kinds"], 0),
    )
    try:
        BinaryPacker.pack(layout, {"n": 2, "kinds": [1]})
    except ValueError as ex:
        assert "1" in str(ex)
    else:
        raise AssertionError("expected ValueError")


def test_times_stops_so_the_next_field_is_read():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["n"]),
        times(0, i32(1, lambda row: row["lat"]), i32(2, lambda row: row["lon"])),
        u8(3, lambda row: row["tail"]),
    )
    raw = BinaryPacker.pack(layout, {"n": 2, "lat": [10, 30], "lon": [20, 40], "tail": 7})
    assert raw[1:].hex() == "020a000000140000001e0000002800000007"
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["tail"] == 7
    assert got.value["lat"] == [10, 30]
    assert got.value["lon"] == [20, 40]


def test_route_matches_fixture_and_rejects_a_short_tail():
    layout = _route()
    raw = bytes.fromhex(ROUTE)
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["sid"] == 16
    assert got.value["kinds"] == [1, 3]
    assert got.value["lat"] == [500_000_000, 500_010_000]
    assert got.value["mask"] == [1]
    assert BinaryPacker.pack(layout, got.value).hex() == ROUTE

    short = BinaryPacker.unpack(raw[:24], layout.on(lambda row: None))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "8"
    assert short.needed == 4
    assert short.left == 2
