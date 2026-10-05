use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, group, i16, i32, insert, to_hex, u16, u8, when, MapScheme, PackError,
    Value, Values,
};

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

/// Packs `vals`, checks the hex, unpacks it again and returns what came back.
fn round_trip(scheme: &MapScheme, vals: &Values, expected_hex: &str) -> Values {
    let raw = pack(scheme, vals).expect("pack");
    assert_eq!(to_hex(&raw), expected_hex);
    unpack(scheme, &raw).expect("unpack")
}

// F1: a flag bit below a top-level group or a flags member.

#[test]
fn flag_bit_inside_a_top_level_group_is_set() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![f.byte(), group(1, "g", vec![f.bit(u8("1")), u8("2")])],
    );
    let vals = values(&[("1", Value::U8(5)), ("2", Value::U8(6))]);
    let got = round_trip(&scheme, &vals, "01010506");
    assert_eq!(got.get("1"), Some(&Some(Value::U8(5))));
}

#[test]
fn flag_bit_as_a_flags_member_is_set() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(1, vec![f.byte(), flags(1, "fl", vec![f.bit(u8("1"))])]);
    let got = round_trip(&scheme, &values(&[("1", Value::U8(5))]), "01010105");
    assert_eq!(got.get("1"), Some(&Some(Value::U8(5))));
}

// F2: the split-form motion example of _docs/01_solution/schema.md.

fn motion_scheme() -> MapScheme {
    let motion = flag_byte("motion");
    MapScheme::new(
        0x40,
        vec![
            u16("sid"),
            i32("lat"),
            i32("lon"),
            u8("profile"),
            motion.byte(),
            when(
                5,
                eq("profile", Value::U8(0)),
                vec![
                    u8("shape"),
                    flags(6, "identity", vec![u16("name"), u16("group"), u16("label")]),
                ],
            ),
            motion.bit(u16("heading")),
            motion.bit(u8("speed")),
            motion.bit(i16("altitude")),
            motion.bit(u8("frequency")),
        ],
    )
}

fn motion_values(profile: u8) -> Values {
    values(&[
        ("sid", Value::U16(1)),
        ("lat", Value::I32(500_000_000)),
        ("lon", Value::I32(300_000_000)),
        ("profile", Value::U8(profile)),
        ("heading", Value::U16(90)),
        ("frequency", Value::U8(5)),
    ])
}

#[test]
fn motion_example_bits_follow_field_order() {
    let scheme = motion_scheme();
    let got = round_trip(
        &scheme,
        &motion_values(1),
        "4001000065cd1d00a3e11101095a0005",
    );
    assert_eq!(got.get("heading"), Some(&Some(Value::U16(90))));
    assert_eq!(got.get("frequency"), Some(&Some(Value::U8(5))));
    assert_eq!(got.get("speed"), None);
    assert_eq!(got.get("altitude"), None);
}

#[test]
fn motion_example_with_identity_before_the_bits() {
    let scheme = motion_scheme();
    let mut vals = motion_values(0);
    insert(&mut vals, "shape", Some(Value::U8(2)));
    insert(&mut vals, "group", Some(Value::U16(7)));
    let got = round_trip(&scheme, &vals, "4001000065cd1d00a3e1110009020207005a0005");
    assert_eq!(got.get("group"), Some(&Some(Value::U16(7))));
    assert_eq!(got.get("frequency"), Some(&Some(Value::U8(5))));
}

// F3: what turns a flag bit or a group under flags on.

#[test]
fn non_empty_group_under_a_flag_bit_is_on_when_a_child_is_present() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![f.byte(), f.bit(group(1, "g", vec![u8("1"), u8("2")]))],
    );
    let vals = values(&[("1", Value::U8(5)), ("2", Value::U8(6))]);
    let got = round_trip(&scheme, &vals, "01010506");
    assert_eq!(got.get("2"), Some(&Some(Value::U8(6))));
}

#[test]
fn flag_bit_inside_a_group_under_flags_turns_the_group_on() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            f.byte(),
            flags(1, "fl", vec![group(1, "g", vec![f.bit(u8("1"))])]),
        ],
    );
    let got = round_trip(&scheme, &values(&[("1", Value::U8(5))]), "01010105");
    assert_eq!(got.get("1"), Some(&Some(Value::U8(5))));
}

// F4: a bool value is 0 or 1.

#[test]
fn map_bool_other_than_0_or_1_is_a_type_error() {
    let short = MapScheme::new(1, vec![flags(0, "f", vec![group(0, "0", vec![])])]);
    assert_eq!(
        pack(&short, &values(&[("0", Value::U8(2))])),
        Err(PackError::Type("0".to_string()))
    );
    let f = flag_byte("f");
    let split = MapScheme::new(1, vec![f.byte(), f.bit(group(1, "1", vec![]))]);
    assert_eq!(
        pack(&split, &values(&[("1", Value::Str("yes".into()))])),
        Err(PackError::Type("1".to_string()))
    );
}

// F5: a bit belongs to the latest instance of its flag byte that it can see.

#[test]
fn two_when_branches_each_number_their_own_flag_byte() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", Value::U8(1)), vec![f.byte(), f.bit(u8("2"))]),
            when(3, eq("0", Value::U8(2)), vec![f.byte(), f.bit(u8("4"))]),
        ],
    );
    let vals = values(&[("0", Value::U8(2)), ("4", Value::U8(9))]);
    let got = round_trip(&scheme, &vals, "01020109");
    assert_eq!(got.get("4"), Some(&Some(Value::U8(9))));
    // A value left over for the branch not taken does not set a bit in the taken one.
    let stale = values(&[("0", Value::U8(1)), ("4", Value::U8(9))]);
    assert_eq!(to_hex(&pack(&scheme, &stale).expect("pack")), "010100");
}

#[test]
fn second_instance_of_a_flag_byte_starts_its_own_bits() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(1, vec![f.byte(), f.bit(u8("a")), f.byte(), f.bit(u8("b"))]);
    let got = round_trip(&scheme, &values(&[("b", Value::U8(9))]), "01000109");
    assert_eq!(got.get("b"), Some(&Some(Value::U8(9))));
    assert_eq!(got.get("a"), None);
}

#[test]
fn flag_byte_read_inside_a_when_is_not_seen_after_it() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            f.byte(),
            when(2, eq("0", Value::U8(1)), vec![f.byte(), f.bit(u8("3"))]),
            f.bit(u8("4")),
        ],
    );
    let vals = values(&[
        ("0", Value::U8(1)),
        ("3", Value::U8(5)),
        ("4", Value::U8(6)),
    ]);
    let got = round_trip(&scheme, &vals, "010101010506");
    assert_eq!(got.get("4"), Some(&Some(Value::U8(6))));
}

// AZ-2133 / U4: a split bit inside a `when` that is not taken keeps its bit (`bitwhen` vector).

fn bitwhen_scheme() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("k"),
            m.byte(),
            when(2, eq("k", Value::U8(1)), vec![m.bit(u8("v"))]),
        ],
    )
}

#[test]
fn bitwhen_untaken_when_keeps_the_bit_and_skips_the_value() {
    let vals = values(&[("k", Value::U8(0)), ("v", Value::U8(5))]);
    let got = round_trip(&bitwhen_scheme(), &vals, "010001");
    assert_eq!(got.get("k"), Some(&Some(Value::U8(0))));
    assert_eq!(got.get("m"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("v"), None);
}

#[test]
fn bitwhen_taken_when_round_trips() {
    let vals = values(&[("k", Value::U8(1)), ("v", Value::U8(5))]);
    let got = round_trip(&bitwhen_scheme(), &vals, "01010105");
    assert_eq!(got.get("k"), Some(&Some(Value::U8(1))));
    assert_eq!(got.get("v"), Some(&Some(Value::U8(5))));
}
