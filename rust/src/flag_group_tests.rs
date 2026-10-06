use crate::walk::{pack, unpack};
use crate::{
    bits, flag_byte, flags, group, insert, packed, sized, to_hex, u2, u8, BinaryPacker, BoundField,
    MapScheme, PackError, Scheme, SchemeItem, Value, Values,
};

// AZ-2128: a group under `flags` is on when any value inside it, at any depth and of any kind, is
// present; the group is then written in full.

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

/// Packs `vals`, checks the hex, unpacks it, packs what came back and checks that it is the same
/// packet; returns what came back.
fn round_trip(scheme: &MapScheme, vals: &Values, expected_hex: &str) -> Values {
    let raw = pack(scheme, vals).expect("pack");
    assert_eq!(to_hex(&raw), expected_hex);
    let got = unpack(scheme, &raw).expect("unpack");
    let again = pack(scheme, &got).expect("repack");
    assert_eq!(to_hex(&again), expected_hex);
    got
}

fn bit_list(items: &[u8]) -> Value {
    Value::List(items.iter().map(|b| Value::U8(*b)).collect())
}

#[test]
fn ac1_u2_only_group_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![group(0, "g", vec![u2(&["p", "q"])])])],
    );
    let vals = values(&[("p", Value::U8(1)), ("q", Value::U8(2))]);
    let got = round_trip(&scheme, &vals, "010109");
    assert_eq!(got.get("p"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("q"), Some(&Some(Value::U8(2))));
}

#[test]
fn ac1_u2_only_group_is_on_when_only_the_second_name_is_present() {
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![group(0, "g", vec![u2(&["p", "q"])])])],
    );
    let vals = values(&[("p", Value::U8(0)), ("q", Value::U8(3))]);
    round_trip(&scheme, &vals, "01010c");
}

#[test]
fn ac1_sized_only_group_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![group(1, "g", vec![sized("d", "n")])]),
        ],
    );
    let vals = values(&[("n", Value::U8(2)), ("d", Value::Bytes(vec![7, 8]))]);
    let got = round_trip(&scheme, &vals, "0102010708");
    assert_eq!(got.get("d"), Some(&Some(Value::Bytes(vec![7, 8]))));
}

#[test]
fn ac1_bits_only_group_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![group(1, "g", vec![bits("b", "n")])]),
        ],
    );
    let vals = values(&[
        ("n", Value::U8(8)),
        ("b", bit_list(&[1, 0, 1, 0, 0, 0, 0, 0])),
    ]);
    let got = round_trip(&scheme, &vals, "01080105");
    assert_eq!(
        got.get("b"),
        Some(&Some(bit_list(&[1, 0, 1, 0, 0, 0, 0, 0])))
    );
}

#[test]
fn ac1_packed_only_group_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![group(1, "g", vec![packed(1, "p", "n", 0)])]),
        ],
    );
    let vals = values(&[("n", Value::U8(4)), ("p", bit_list(&[1, 0, 1, 1]))]);
    let got = round_trip(&scheme, &vals, "0104010d");
    assert_eq!(got.get("p"), Some(&Some(bit_list(&[1, 0, 1, 1]))));
}

#[test]
fn ac1_nested_group_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![group(0, "h", vec![u8("v")])])],
        )],
    );
    let got = round_trip(&scheme, &values(&[("v", Value::U8(5))]), "010105");
    assert_eq!(got.get("v"), Some(&Some(Value::U8(5))));
}

#[test]
fn ac1_nested_flags_sets_the_bit() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![flags(0, "h", vec![u8("b")])])],
        )],
    );
    let got = round_trip(&scheme, &values(&[("b", Value::U8(5))]), "01010105");
    assert_eq!(got.get("b"), Some(&Some(Value::U8(5))));
}

#[test]
fn ac1_value_three_groups_down_sets_every_bit_above() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(
                0,
                "g",
                vec![group(0, "h", vec![group(0, "i", vec![u2(&["p", "q"])])])],
            )],
        )],
    );
    let vals = values(&[("p", Value::U8(2)), ("q", Value::U8(1))]);
    round_trip(&scheme, &vals, "010106");
}

#[test]
fn ac1_group_with_no_value_present_stays_off() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(
                0,
                "g",
                vec![
                    u2(&["p", "q"]),
                    group(2, "h", vec![flags(2, "k", vec![u8("b")])]),
                ],
            )],
        )],
    );
    assert_eq!(
        to_hex(&pack(&scheme, &Values::new()).expect("pack")),
        "0100"
    );
}

#[test]
fn ac2_nested_group_value_with_a_null_sibling_names_the_sibling() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![u8("a"), group(1, "h", vec![u8("b")])])],
        )],
    );
    let vals = values(&[("b", Value::U8(5))]);
    assert_eq!(
        pack(&scheme, &vals),
        Err(PackError::Missing("a".to_string()))
    );
}

#[test]
fn ac2_nested_flags_value_with_a_null_sibling_names_the_sibling() {
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![u8("a"), flags(1, "h", vec![u8("b")])])],
        )],
    );
    let vals = values(&[("b", Value::U8(5))]);
    assert_eq!(
        pack(&scheme, &vals),
        Err(PackError::Missing("a".to_string()))
    );
}

#[test]
fn ac2_u2_with_one_name_null_names_that_value() {
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![group(0, "g", vec![u2(&["p", "q"])])])],
    );
    let vals = values(&[("p", Value::U8(1))]);
    assert_eq!(
        pack(&scheme, &vals),
        Err(PackError::Missing("q".to_string()))
    );
}

#[test]
fn ac1_group_under_a_flag_bit_is_on_for_a_u2_value() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![f.byte(), f.bit(group(1, "g", vec![u2(&["p", "q"])]))],
    );
    let vals = values(&[("p", Value::U8(1)), ("q", Value::U8(2))]);
    round_trip(&scheme, &vals, "010109");
}

#[test]
fn ac1_flags_member_u2_is_on_for_any_of_its_names() {
    let scheme = MapScheme::new(1, vec![flags(0, "f", vec![u2(&["p", "q"])])]);
    let vals = values(&[("p", Value::U8(1)), ("q", Value::U8(2))]);
    round_trip(&scheme, &vals, "010109");
    // Only the second name is present: the bit is set and the first name is missing.
    let only_q = values(&[("q", Value::U8(2))]);
    assert_eq!(
        pack(&scheme, &only_q),
        Err(PackError::Missing("p".to_string()))
    );
}

#[test]
fn ac1_flags_member_flags_is_on_for_a_value_inside_it() {
    let scheme = MapScheme::new(1, vec![flags(0, "f", vec![flags(0, "h", vec![u8("b")])])]);
    let got = round_trip(&scheme, &values(&[("b", Value::U8(5))]), "01010105");
    assert_eq!(got.get("b"), Some(&Some(Value::U8(5))));
}

#[test]
fn ac1_nested_flags_byte_read_as_zero_repacks_unchanged() {
    let scheme = MapScheme::new(1, vec![flags(0, "f", vec![flags(0, "h", vec![u8("b")])])]);
    let got = unpack(&scheme, &[1, 1, 0]).expect("unpack");
    assert_eq!(got.get("h"), Some(&Some(Value::U8(0))));
    assert_eq!(to_hex(&pack(&scheme, &got).expect("repack")), "010100");
}

#[test]
fn ac1_flag_byte_inside_a_group_under_flags_does_not_turn_the_group_on() {
    let fb = flag_byte("fb");
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![fb.byte(), fb.bit(u8("1"))])],
        )],
    );

    let got = unpack(&scheme, &[1, 1, 0]).expect("unpack");

    assert_eq!(got.get("f"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("fb"), Some(&Some(Value::U8(0))));
    // The packet does not repack as it came: the flag byte's value is its bits, not a value
    // that turns the group on. The same asymmetry exists at HEAD of loop 16 batch 1.
    assert_eq!(to_hex(&pack(&scheme, &got).expect("repack")), "0100");
}

#[derive(Default, Debug, PartialEq)]
struct Row {
    b: Option<u8>,
}

#[test]
fn ac1_typed_flags_nested_in_flags_is_on_for_a_value_inside_it() {
    let scheme = Scheme::<Row>::new(
        1,
        [SchemeItem::flags(
            0,
            [SchemeItem::flags(
                0,
                [BoundField::opt_u8(0, |r: &Row| r.b, |r: &mut Row, v| r.b = v).into()],
            )],
        )],
    );

    let wire = BinaryPacker::pack(&scheme, &Row { b: Some(5) }).expect("pack");

    assert_eq!(to_hex(&wire), "01010105");
    let mut got = None;
    let mut on_row = scheme.on(|row| got = Some(row));
    BinaryPacker::unpack_with(&wire, &mut [&mut on_row]).expect("unpack");
    assert_eq!(got, Some(Row { b: Some(5) }));
}
