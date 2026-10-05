use crate::hostile_tests::within_one_second;
use crate::walk::{pack, packed_layout, unpack};
use crate::{
    bytes, eq, flag_byte, packed, repeat, sized, times, u64, u8, when, BinaryPacker, BoundField,
    MapScheme, Scheme, SchemeItem, ShortPacket, UnpackError, Value, Values,
};

#[derive(Default)]
struct Row {
    a: u8,
}

fn row_a() -> SchemeItem<Row> {
    BoundField::u8(0, |r: &Row| r.a, |r: &mut Row, v| r.a = v).into()
}

#[test]
#[should_panic(expected = "field id 0 is not in the same scope")]
fn outer_when_inside_repeat_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![u8("1")])]),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 0 is not in the same scope")]
fn outer_when_inside_repeat_is_refused_in_the_typed_form() {
    let _ = Scheme::new(
        1,
        [
            row_a(),
            SchemeItem::Field(repeat(1, vec![when(1, eq(0, Value::U8(1)), vec![u8("1")])])),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 1 is not in the same scope")]
fn outer_count_inside_times_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            u8("1"),
            times(2, "0", vec![u8("2"), sized("3", "1")]),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 0 is not in the same scope")]
fn outer_flag_byte_inside_repeat_is_refused() {
    let flag = flag_byte("0");
    MapScheme::new(1, vec![flag.byte(), repeat(1, vec![flag.bit(u8("1"))])]);
}

#[test]
#[should_panic(expected = "field id 0 is not in the same scope")]
fn outer_count_inside_nested_times_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![u8("1"), times(2, "1", vec![sized("3", "0")])]),
        ],
    );
}

#[test]
fn same_scope_references_still_build() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(
                1,
                vec![u8("1"), when(2, eq("1", Value::U8(1)), vec![u8("2")])],
            ),
        ],
    );
    let got = unpack(&scheme, &[0x01, 0xaa, 0x01, 0x07, 0x03]).expect("unpack");
    let Some(Some(Value::Groups(groups))) = got.get("__repeat__") else {
        panic!("expected repeat groups");
    };
    assert_eq!(groups.len(), 2);
    assert_eq!(groups[0].get("2"), Some(&Some(Value::U8(7))));
    assert_eq!(groups[1].get("2"), None);
    let mut again = Values::new();
    again.insert("0".into(), Some(Value::U8(0xaa)));
    again.insert("__repeat__".into(), got.get("__repeat__").cloned().unwrap());
    assert_eq!(
        pack(&scheme, &again).expect("pack"),
        vec![0x01, 0xaa, 0x01, 0x07, 0x03]
    );
}

#[test]
fn times_count_reads_the_enclosing_scope() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(1, vec![u8("1"), times(2, "1", vec![u8("2")])]),
        ],
    );
    let got = unpack(&scheme, &[0x01, 0x00, 0x02, 0x0a, 0x0b]).expect("unpack");
    let Some(Some(Value::Groups(groups))) = got.get("__repeat__") else {
        panic!("expected repeat groups");
    };
    assert_eq!(groups.len(), 1);
    assert_eq!(groups[0].get("1"), Some(&Some(Value::U8(2))));
    assert_eq!(
        groups[0].get("2"),
        Some(&Some(Value::List(vec![Value::U8(0x0a), Value::U8(0x0b)])))
    );
}

#[test]
fn flag_byte_inside_repeat_builds() {
    let flag = flag_byte("1");
    MapScheme::new(
        1,
        vec![u8("0"), repeat(1, vec![flag.byte(), flag.bit(u8("2"))])],
    );
}

#[test]
fn zero_progress_repeat_ends_with_trailing() {
    let result = within_one_second("empty repeat", || {
        let scheme = MapScheme::new(1, vec![u8("0"), repeat(1, vec![])]);
        unpack(&scheme, &[0x01, 0x05, 0x09]).map(|_| ())
    });
    assert_eq!(result.unwrap_err(), UnpackError::Trailing { left: 1 });
}

#[test]
fn zero_progress_repeat_with_nothing_left_is_empty() {
    let result = within_one_second("empty repeat, no bytes", || {
        let scheme = MapScheme::new(1, vec![u8("0"), repeat(1, vec![])]);
        unpack(&scheme, &[0x01, 0x05]).map(|_| ())
    });
    assert!(result.is_ok());
}

#[test]
fn repeat_round_with_a_real_body_still_reports_short() {
    let scheme = MapScheme::new(1, vec![repeat(0, vec![crate::u16("0")])]);
    let err = unpack(&scheme, &[0x01, 0xaa]).unwrap_err();
    assert_eq!(
        err,
        UnpackError::Short(ShortPacket {
            field: "0".to_string(),
            needed: 2,
            left: 1,
        })
    );
}

#[test]
fn zero_width_times_round_is_short_even_with_a_huge_count() {
    let result = within_one_second("empty times", || {
        let scheme = MapScheme::new(1, vec![u64("0"), times(1, "0", vec![])]);
        let mut packet = vec![0x01];
        packet.extend_from_slice(&u64::MAX.to_le_bytes());
        unpack(&scheme, &packet).map(|_| ())
    });
    assert_eq!(result, Err(zero_width_times(0)));
}

#[test]
fn zero_width_times_round_is_short_with_a_small_count() {
    let result = within_one_second("zero-width times", || {
        let scheme = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![bytes("1", 0)])]);
        unpack(&scheme, &[0x01, 0x03]).map(|_| ())
    });
    assert_eq!(result, Err(zero_width_times(0)));
}

#[test]
fn zero_width_times_round_reports_the_bytes_left_at_its_start() {
    let result = within_one_second("zero-width times, bytes left", || {
        let scheme = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![bytes("1", 0)])]);
        unpack(&scheme, &[0x01, 0x03, 0xaa, 0xbb]).map(|_| ())
    });
    assert_eq!(result, Err(zero_width_times(2)));
}

fn zero_width_times(left: usize) -> UnpackError {
    UnpackError::Short(ShortPacket {
        field: "times".to_string(),
        needed: 0,
        left,
    })
}

#[test]
fn packed_count_at_the_edge_of_i64_is_short_not_a_panic() {
    let result = within_one_second("packed count 2^63", || {
        let scheme = MapScheme::new(1, vec![u64("0"), packed(1, "1", "0", -1)]);
        let mut packet = vec![0x01];
        packet.extend_from_slice(&(1u64 << 63).to_le_bytes());
        unpack(&scheme, &packet).map(|_| ())
    });
    assert!(matches!(result, Err(UnpackError::Short(_))));
}

#[test]
fn typed_scheme_with_same_scope_repeat_still_unpacks() {
    #[derive(Default)]
    struct Msg {
        a: u8,
    }
    let scheme = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Msg| r.a, |r: &mut Msg, v| r.a = v).into(),
            SchemeItem::Field(repeat(1, vec![u8("1")])),
        ],
    );
    let mut got = None;
    {
        let mut handler = scheme.on(|m: Msg| got = Some(m.a));
        BinaryPacker::unpack_with(&[0x01, 0x09, 0x01, 0x02], &mut [&mut handler]).expect("unpack");
    }
    assert_eq!(got, Some(9));
}

#[test]
fn packed_count_that_wraps_i64_is_short() {
    let result = within_one_second("packed count 2^64-1", || {
        // Built from the crate-private kind: the public `packed` only allows bias 0 or -1.
        let packed_field = crate::Field {
            kind: crate::field::FieldKind::Packed {
                name: crate::value::name_of("1"),
                count: crate::value::name_of("0"),
                width: 1,
                bias: 5,
            },
        };
        let scheme = MapScheme::new(1, vec![u64("0"), packed_field]);
        let mut packet = vec![0x01];
        packet.extend_from_slice(&u64::MAX.to_le_bytes());
        packet.push(0xff);
        unpack(&scheme, &packet).map(|_| ())
    });
    assert!(matches!(result, Err(UnpackError::Short(_))));
}

#[test]
fn packed_layout_rejects_overflow_and_negative_counts() {
    assert_eq!(packed_layout(4, 0, 2), Some((4, 1)));
    assert_eq!(packed_layout(5, -1, 1), Some((4, 1)));
    assert_eq!(packed_layout(0, -1, 1), None);
    assert_eq!(packed_layout(usize::MAX, 5, 1), None);
    // n * width overflows usize here (on 32-bit targets, the same shape with a count near 2^30).
    assert_eq!(packed_layout(usize::MAX / 4 + 1, 0, 4), None);
}
