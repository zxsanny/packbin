use packbin::{eq, mismatched_bytes, to_hex, BinaryPacker, BoundField, Scheme, SchemeItem, Value};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

const MARKER_AC1_HEX: &str = "2001000065cd1d00a3e111010000000000";

#[derive(Default, Debug, PartialEq)]
struct MarkerRow {
    sid: u16,
    lat: i32,
    lon: i32,
    kind: u8,
    kind_id: Option<u16>,
    title: u16,
    hidden: Option<bool>,
    delta: Option<bool>,
}

fn marker_scheme() -> Scheme<MarkerRow> {
    marker_scheme_when(Value::U8(1))
}

fn marker_scheme_when(expect: Value) -> Scheme<MarkerRow> {
    Scheme::new(
        0x20,
        [
            BoundField::u16(0, |r: &MarkerRow| r.sid, |r: &mut MarkerRow, v| r.sid = v).into(),
            BoundField::i32(1, |r: &MarkerRow| r.lat, |r: &mut MarkerRow, v| r.lat = v).into(),
            BoundField::i32(2, |r: &MarkerRow| r.lon, |r: &mut MarkerRow, v| r.lon = v).into(),
            BoundField::u8(3, |r: &MarkerRow| r.kind, |r: &mut MarkerRow, v| r.kind = v).into(),
            SchemeItem::when(
                4,
                eq(3, expect),
                [BoundField::opt_u16(
                    4,
                    |r: &MarkerRow| r.kind_id,
                    |r: &mut MarkerRow, v| r.kind_id = v,
                )
                .into()],
            ),
            BoundField::u16(
                5,
                |r: &MarkerRow| r.title,
                |r: &mut MarkerRow, v| r.title = v,
            )
            .into(),
            SchemeItem::flags(6, [
                BoundField::bool_flag(
                    6,
                    |r: &MarkerRow| r.hidden,
                    |r: &mut MarkerRow, v| r.hidden = v,
                )
                .into(),
                BoundField::bool_flag(
                    7,
                    |r: &MarkerRow| r.delta,
                    |r: &mut MarkerRow, v| r.delta = v,
                )
                .into(),
            ]),
        ],
    )
}

#[test]
fn field_id_ac1_member_names_not_wire_names() {
    let row = MarkerRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        kind: 1,
        kind_id: Some(0),
        title: 0,
        hidden: None,
        delta: None,
    };
    let scheme = marker_scheme();
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    assert_eq!(to_hex(&bytes), MARKER_AC1_HEX);
    let mut back = MarkerRow::default();
    BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|found| back = found)]).expect("unpack");
    assert_eq!(back.lat, 500_000_000);
    assert_eq!(back.sid, 1);
    assert_eq!(back.lon, 300_000_000);
    assert_eq!(back.kind, 1);
    let source = include_str!("field_id_tests.rs");
    let start = source.find("struct MarkerRow").expect("MarkerRow");
    let brace = source[start..].find('{').expect("{") + start;
    let mut depth = 0;
    let mut end = brace;
    for (i, ch) in source[brace..].char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    end = brace + i;
                    break;
                }
            }
            _ => {}
        }
    }
    let body = &source[start..=end];
    assert!(body.contains("lat"));
    assert!(!body.contains("\"lat\""));
}

#[test]
fn field_id_ac2_when_uses_order() {
    let with_id = MarkerRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        kind: 1,
        kind_id: Some(9),
        title: 0,
        hidden: None,
        delta: None,
    };
    let scheme = marker_scheme();
    let bytes = BinaryPacker::pack(&scheme, &with_id).expect("pack");
    let mut back = MarkerRow::default();
    BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|found| back = found)]).expect("unpack");
    assert_eq!(back.kind_id, Some(9));

    let without = MarkerRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        kind: 0,
        kind_id: None,
        title: 0,
        hidden: None,
        delta: None,
    };
    let bytes0 = BinaryPacker::pack(&scheme, &without).expect("pack");
    let mut back0 = MarkerRow::default();
    BinaryPacker::unpack_with(&bytes0, &mut [&mut scheme.on(|found| back0 = found)])
        .expect("unpack");
    assert_eq!(back0.kind_id, None);
    assert!(bytes0.len() < bytes.len());
}

#[test]
fn field_id_ac3_flags_child_accessors() {
    let row = MarkerRow {
        sid: 1,
        lat: 0,
        lon: 0,
        kind: 0,
        kind_id: None,
        title: 0,
        hidden: Some(true),
        delta: None,
    };
    let scheme = marker_scheme();
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    assert_eq!(*bytes.last().unwrap(), 0x01);
    let mut back = MarkerRow::default();
    BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|found| back = found)]).expect("unpack");
    assert_eq!(back.hidden, Some(true));
    assert_eq!(back.delta, None);
}

#[derive(Default)]
struct ParentRow {
    tag: u16,
    items: Vec<u16>,
}

#[test]
fn field_id_ac4_nested_row_ids() {
    let scheme = Scheme::new(
        1,
        [
            BoundField::u16(0, |r: &ParentRow| r.tag, |r: &mut ParentRow, v| r.tag = v).into(),
            BoundField::list_u16(
                |r: &ParentRow| r.items.clone(),
                |r: &mut ParentRow, v| r.items = v,
                0,
            )
            .into(),
        ],
    );
    let row = ParentRow {
        tag: 7,
        items: vec![1, 2],
    };
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let mut back = ParentRow::default();
    BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|found| back = found)]).expect("unpack");
    assert_eq!(back.tag, 7);
    assert_eq!(back.items, vec![1, 2]);
}

#[derive(Default)]
struct SidRow {
    sid: u8,
}

#[test]
fn field_id_ac5_order_must_match() {
    assert!(std::panic::catch_unwind(|| {
        let _ = Scheme::<SidRow>::new(
            1,
            [BoundField::u8(2, |r: &SidRow| r.sid, |r: &mut SidRow, v| r.sid = v).into()],
        );
    })
    .is_err());
}

#[test]
fn field_id_ac6_ac1_bytes() {
    let row = MarkerRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        kind: 1,
        kind_id: Some(0),
        title: 0,
        hidden: None,
        delta: None,
    };
    let bytes = BinaryPacker::pack(&marker_scheme(), &row).expect("pack");
    assert_eq!(to_hex(&bytes), MARKER_AC1_HEX);
    assert_eq!(mismatched_bytes(&bytes, &parse_hex(MARKER_AC1_HEX)), 0);
}

fn marker_with_kind_id() -> MarkerRow {
    MarkerRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        kind: 1,
        kind_id: Some(7),
        title: 0,
        hidden: None,
        delta: None,
    }
}

#[test]
fn field_id_when_matches_a_wider_eq_value_by_number() {
    for expect in [Value::U16(1), Value::I64(1)] {
        // Arrange
        let scheme = marker_scheme_when(expect.clone());
        let reference = BinaryPacker::pack(&marker_scheme(), &marker_with_kind_id()).expect("pack");

        // Act
        let bytes = BinaryPacker::pack(&scheme, &marker_with_kind_id()).expect("pack");
        let mut back = MarkerRow::default();
        BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|found| back = found)])
            .expect("unpack");

        // Assert
        assert_eq!(bytes, reference, "{expect:?}");
        assert_eq!(back.kind_id, Some(7), "{expect:?}");
    }
}

#[derive(Default)]
struct FloatTested {
    ratio: f32,
    tail: u8,
}

fn float_tested_scheme(expect: Value) {
    let _ = Scheme::<FloatTested>::new(
        1,
        [
            BoundField::f32(
                0,
                |r: &FloatTested| r.ratio,
                |r: &mut FloatTested, v| r.ratio = v,
            )
            .into(),
            SchemeItem::when(
                1,
                eq(0, expect),
                [BoundField::u8(
                    1,
                    |r: &FloatTested| r.tail,
                    |r: &mut FloatTested, v| r.tail = v,
                )
                .into()],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn field_id_when_on_a_float_field_is_refused() {
    float_tested_scheme(Value::U8(1));
}

#[derive(Default)]
struct KindRow {
    kind: u8,
    tail: u8,
}

#[test]
#[should_panic(expected = "compares field \"0\" with a value that is not an integer")]
fn field_id_when_with_a_float_eq_value_is_refused() {
    let _ = Scheme::<KindRow>::new(
        1,
        [
            BoundField::u8(0, |r: &KindRow| r.kind, |r: &mut KindRow, v| r.kind = v).into(),
            SchemeItem::when(
                1,
                eq(0, Value::F32(1.0)),
                [BoundField::u8(1, |r: &KindRow| r.tail, |r: &mut KindRow, v| r.tail = v).into()],
            ),
        ],
    );
}
