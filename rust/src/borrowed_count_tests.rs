use crate::walk::{pack, unpack};
use crate::{
    eq, flags, group, i32, insert, packed, times, to_hex, u16, u8, when, MapScheme, PackError,
    ShortPacket, UnpackError, Value, Values,
};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

const ROUTE_HEX: &str = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101";

fn route_scheme() -> MapScheme {
    MapScheme::new(
        0x34,
        vec![
            u16("sid"),
            u16("name"),
            flags(
                "opts",
                vec![
                    u16("unit"),
                    group("straight", vec![]),
                    u16("route_id"),
                ],
            ),
            u8("count"),
            packed(2, "kinds", "count", 0),
            times("count", vec![i32("lat"), i32("lon")]),
            when(
                eq("straight", Value::U8(1)),
                vec![packed(1, "mask", "count", -1)],
            ),
        ],
    )
}

#[test]
fn width2_four_values_are_one_byte() {
    let scheme = MapScheme::new(1, vec![u8("n"), packed(2, "kinds", "n", 0)]);
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U8(4)));
    insert(
        &mut vals,
        "kinds",
        Some(Value::List(vec![
            Value::U8(0),
            Value::U8(1),
            Value::U8(2),
            Value::U8(3),
        ])),
    );
    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw[2..]), "e4");
    let got = unpack(&scheme, &raw).unwrap();
    assert_eq!(
        got.get("kinds"),
        Some(&Some(Value::List(vec![
            Value::U8(0),
            Value::U8(1),
            Value::U8(2),
            Value::U8(3),
        ])))
    );
}

#[test]
fn width1_bias_minus_one_writes_eight_bits_or_none() {
    let scheme = MapScheme::new(1, vec![u8("n"), packed(1, "kinds", "n", -1)]);
    let mut eight = Values::new();
    insert(&mut eight, "n", Some(Value::U8(9)));
    insert(
        &mut eight,
        "kinds",
        Some(Value::List(vec![Value::U8(1); 8])),
    );
    let eight_raw = pack(&scheme, &eight).unwrap();
    assert_eq!(to_hex(&eight_raw[2..]), "ff");

    let mut none = Values::new();
    insert(&mut none, "n", Some(Value::U8(1)));
    insert(&mut none, "kinds", Some(Value::List(vec![])));
    let none_raw = pack(&scheme, &none).unwrap();
    assert_eq!(none_raw.len() - 2, 0);
    let got = unpack(&scheme, &none_raw).unwrap();
    assert_eq!(got.get("kinds"), Some(&Some(Value::List(vec![]))));
}

#[test]
fn length_mismatch_names_the_field() {
    let scheme = MapScheme::new(1, vec![u8("n"), packed(2, "kinds", "n", 0)]);
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U8(2)));
    insert(&mut vals, "kinds", Some(Value::List(vec![Value::U8(1)])));
    match pack(&scheme, &vals) {
        Err(PackError::Type(name)) => assert_eq!(name, "kinds"),
        other => panic!("expected PackError::Type(kinds), got {:?}", other),
    }
}

#[test]
fn times_stops_so_the_next_field_is_read() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            times("n", vec![i32("lat"), i32("lon")]),
            u8("tail"),
        ],
    );
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U8(2)));
    insert(
        &mut vals,
        "lat",
        Some(Value::List(vec![Value::I32(10), Value::I32(30)])),
    );
    insert(
        &mut vals,
        "lon",
        Some(Value::List(vec![Value::I32(20), Value::I32(40)])),
    );
    insert(&mut vals, "tail", Some(Value::U8(7)));
    let raw = pack(&scheme, &vals).unwrap();
    assert_eq!(to_hex(&raw[1..]), "020a000000140000001e0000002800000007");
    let got = unpack(&scheme, &raw).unwrap();
    assert_eq!(got.get("tail"), Some(&Some(Value::U8(7))));
    assert_eq!(
        got.get("lat"),
        Some(&Some(Value::List(vec![Value::I32(10), Value::I32(30)])))
    );
}

#[test]
fn route_matches_fixture_and_rejects_a_short_tail() {
    let scheme = route_scheme();
    let raw = parse_hex(ROUTE_HEX);
    let got = unpack(&scheme, &raw).unwrap();
    assert_eq!(got.get("sid"), Some(&Some(Value::U16(16))));
    assert_eq!(got.get("name"), Some(&Some(Value::U16(21))));
    assert!(!got.contains_key("unit") || matches!(got.get("unit"), Some(None) | None));
    assert_eq!(got.get("straight"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("route_id"), Some(&Some(Value::U16(45))));
    assert_eq!(got.get("count"), Some(&Some(Value::U8(2))));
    assert_eq!(
        got.get("kinds"),
        Some(&Some(Value::List(vec![Value::U8(1), Value::U8(3)])))
    );
    assert_eq!(
        got.get("lat"),
        Some(&Some(Value::List(vec![
            Value::I32(500_000_000),
            Value::I32(500_010_000),
        ])))
    );
    assert_eq!(
        got.get("lon"),
        Some(&Some(Value::List(vec![
            Value::I32(300_000_000),
            Value::I32(300_010_000),
        ])))
    );
    assert_eq!(
        got.get("mask"),
        Some(&Some(Value::List(vec![Value::U8(1)])))
    );

    let again = pack(&scheme, &got).unwrap();
    assert_eq!(to_hex(&again), ROUTE_HEX);

    let err = unpack(&scheme, &raw[..24]).expect_err("short");
    match err {
        UnpackError::Short(ShortPacket {
            field,
            needed,
            left,
        }) => {
            assert_eq!(field, "lon");
            assert_eq!(needed, 4);
            assert_eq!(left, 2);
        }
        other => panic!("expected ShortPacket, got {:?}", other),
    }
}
