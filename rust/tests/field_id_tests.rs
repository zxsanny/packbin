use packbin::{
    eq, mismatched_bytes, to_hex, BinaryPacker, BoundField, Scheme, SchemeItem, Value,
};

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
    Scheme::new(
        0x20,
        [
            BoundField::u16(
                0,
                |r: &MarkerRow| r.sid,
                |r: &mut MarkerRow, v| r.sid = v,
            )
            .into(),
            BoundField::i32(
                1,
                |r: &MarkerRow| r.lat,
                |r: &mut MarkerRow, v| r.lat = v,
            )
            .into(),
            BoundField::i32(
                2,
                |r: &MarkerRow| r.lon,
                |r: &mut MarkerRow, v| r.lon = v,
            )
            .into(),
            BoundField::u8(
                3,
                |r: &MarkerRow| r.kind,
                |r: &mut MarkerRow, v| r.kind = v,
            )
            .into(),
            SchemeItem::when(
                eq(3, Value::U8(1)),
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
            SchemeItem::flags([
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
    let bytes = BinaryPacker::pack(&marker_scheme(), &row).expect("pack");
    assert_eq!(to_hex(&bytes), MARKER_AC1_HEX);
    let back = BinaryPacker::unpack(&marker_scheme(), &bytes).expect("unpack");
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
    let bytes = BinaryPacker::pack(&marker_scheme(), &with_id).expect("pack");
    let back = BinaryPacker::unpack(&marker_scheme(), &bytes).expect("unpack");
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
    let bytes0 = BinaryPacker::pack(&marker_scheme(), &without).expect("pack");
    let back0 = BinaryPacker::unpack(&marker_scheme(), &bytes0).expect("unpack");
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
    let bytes = BinaryPacker::pack(&marker_scheme(), &row).expect("pack");
    assert_eq!(*bytes.last().unwrap(), 0x01);
    let back = BinaryPacker::unpack(&marker_scheme(), &bytes).expect("unpack");
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
            BoundField::u16(
                0,
                |r: &ParentRow| r.tag,
                |r: &mut ParentRow, v| r.tag = v,
            )
            .into(),
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
    let back = BinaryPacker::unpack(&scheme, &bytes).expect("unpack");
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
