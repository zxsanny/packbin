use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, group, insert, to_hex, u16, u8, when, MapScheme, PackError, Value, Values,
};

// AZ-2120 AC-3 / AZ-2128 flagged concern: a `when` that is a member of a `flags` container, or in
// a group or flag-bit field under it, is written like any other value. Its bit is on exactly
// when its condition holds on the values written so far and its body holds a value. Hex strings
// come from the C# reference table (wave 3a): `_docs` loop 18, AZ-2120.

fn bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

fn get<'a>(row: &'a Values, name: &str) -> Option<&'a Value> {
    row.get(name).and_then(|v| v.as_ref())
}

/// Packs `vals`, checks the hex, unpacks it, packs what came back and checks it is the same
/// packet; returns what came back.
fn round_trip(scheme: &MapScheme, vals: &Values, expected_hex: &str) -> Values {
    let raw = pack(scheme, vals).expect("pack");
    assert_eq!(to_hex(&raw), expected_hex);
    let got = unpack(scheme, &raw).expect("unpack");
    let again = pack(scheme, &got).expect("repack");
    assert_eq!(to_hex(&again), expected_hex);
    got
}

fn assert_row(row: &Values, expected: &[(&str, u64)], absent: &[&str]) {
    for (name, want) in expected {
        let got = match get(row, name) {
            Some(Value::U8(n)) => u64::from(*n),
            Some(Value::U16(n)) => u64::from(*n),
            other => panic!("{name}: {other:?}"),
        };
        assert_eq!(got, *want, "{name}");
    }
    for name in absent {
        assert_eq!(get(row, name), None, "{name} must be absent");
    }
}

fn mode_is_1() -> crate::Eq {
    eq("mode", Value::U8(1))
}

/// WA: `u8 mode; flags { when(mode == 1) { u8 speed }, u16 heading }`
fn wa() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![when(1, mode_is_1(), vec![u8("speed")]), u16("heading")],
            ),
        ],
    )
}

/// WS: the split form of WA.
fn ws() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            m.byte(),
            m.bit(when(2, mode_is_1(), vec![u8("speed")])),
            m.bit(u16("heading")),
        ],
    )
}

/// WG: WA with the `when` inside a group.
fn wg() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![
                    group(1, "g", vec![when(1, mode_is_1(), vec![u8("speed")])]),
                    u16("heading"),
                ],
            ),
        ],
    )
}

/// W2: a `when` with two body values.
fn w2() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![
                    when(1, mode_is_1(), vec![u8("speed"), u8("extra")]),
                    u16("heading"),
                ],
            ),
        ],
    )
}

/// GS: a group holding a sibling value and a `when`.
fn gs() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![
                    group(
                        1,
                        "g",
                        vec![u8("extra"), when(2, mode_is_1(), vec![u8("speed")])],
                    ),
                    u16("heading"),
                ],
            ),
        ],
    )
}

/// WE: the `when` names an earlier member of the same `flags`.
fn we() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![u8("mode"), when(1, mode_is_1(), vec![u8("speed")])],
        )],
    )
}

fn row(mode: Option<u8>, speed: Option<u8>, extra: Option<u8>, heading: Option<u16>) -> Values {
    let mut vals = Values::new();
    let put = |vals: &mut Values, name: &str, value: Option<Value>| {
        if value.is_some() {
            insert(vals, name, value);
        }
    };
    put(&mut vals, "mode", mode.map(Value::U8));
    put(&mut vals, "speed", speed.map(Value::U8));
    put(&mut vals, "extra", extra.map(Value::U8));
    put(&mut vals, "heading", heading.map(Value::U16));
    vals
}

fn missing(err: PackError, name: &str) {
    assert_eq!(err, PackError::Missing(name.to_string()));
}

// AC-3: W-true, W-false, W-true-no-body, W-false-body-given, W-only-when, W-only-mode.

#[test]
fn ac3_when_member_true_writes_its_body_and_sets_its_bit() {
    let got = round_trip(
        &wa(),
        &row(Some(1), Some(7), None, Some(90)),
        "010103075a00",
    );
    assert_row(&got, &[("mode", 1), ("speed", 7), ("heading", 90)], &[]);
}

#[test]
fn ac3_when_member_false_leaves_its_bit_clear() {
    let got = round_trip(&wa(), &row(Some(0), None, None, Some(90)), "0100025a00");
    assert_row(&got, &[("mode", 0), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_when_member_true_with_no_body_value_leaves_its_bit_clear() {
    let got = round_trip(&wa(), &row(Some(1), None, None, Some(90)), "0101025a00");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_when_member_false_drops_a_body_value_given_without_error() {
    let vals = row(Some(0), Some(7), None, Some(90));
    let raw = pack(&wa(), &vals).expect("pack");
    assert_eq!(to_hex(&raw), "0100025a00");
    let got = unpack(&wa(), &raw).expect("unpack");
    assert_row(&got, &[("mode", 0), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_when_member_alone_with_its_body_sets_only_its_bit() {
    let got = round_trip(&wa(), &row(Some(1), Some(7), None, None), "01010107");
    assert_row(&got, &[("mode", 1), ("speed", 7)], &["heading"]);
}

#[test]
fn ac3_mode_alone_sets_no_bit() {
    let got = round_trip(&wa(), &row(Some(0), None, None, None), "010000");
    assert_row(&got, &[("mode", 0)], &["speed", "heading"]);
}

// AC-5: the old packet (bit clear) and the new packet both unpack.

#[test]
fn ac5_old_clear_bit_packet_still_unpacks() {
    let got = unpack(&wa(), &bytes("0101025a00")).expect("unpack");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["speed"]);
}

#[test]
fn ac5_new_packet_unpacks_the_body() {
    let got = unpack(&wa(), &bytes("010103075a00")).expect("unpack");
    assert_row(&got, &[("mode", 1), ("speed", 7), ("heading", 90)], &[]);
}

// W-split-*: the same rule for a `when` under a flag bit.

#[test]
fn ac3_split_form_when_true_sets_its_bit() {
    let got = round_trip(
        &ws(),
        &row(Some(1), Some(7), None, Some(90)),
        "010103075a00",
    );
    assert_row(&got, &[("mode", 1), ("speed", 7), ("heading", 90)], &[]);
}

#[test]
fn ac3_split_form_when_false_leaves_its_bit_clear() {
    let got = round_trip(&ws(), &row(Some(0), None, None, Some(90)), "0100025a00");
    assert_row(&got, &[("mode", 0), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_split_form_when_true_with_no_body_value_leaves_its_bit_clear() {
    let got = round_trip(&ws(), &row(Some(1), None, None, Some(90)), "0101025a00");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_split_form_when_false_with_a_body_value_given_drops_it_without_error() {
    // AZ-2331 AC-3 (decided 2026-10-11): a false condition drops the body silently, as in WA.
    let vals = row(Some(0), Some(7), None, Some(90));
    let raw = pack(&ws(), &vals).expect("pack");
    assert_eq!(to_hex(&raw), "0100025a00");
    let got = unpack(&ws(), &raw).expect("unpack");
    assert_row(&got, &[("mode", 0), ("heading", 90)], &["speed"]);
}

// W-group-*: the same rule for a `when` inside a group under `flags`.

#[test]
fn ac3_group_when_true_sets_the_group_bit() {
    let got = round_trip(
        &wg(),
        &row(Some(1), Some(7), None, Some(90)),
        "010103075a00",
    );
    assert_row(&got, &[("mode", 1), ("speed", 7), ("heading", 90)], &[]);
}

#[test]
fn ac3_group_when_false_leaves_the_group_bit_clear() {
    let got = round_trip(&wg(), &row(Some(0), None, None, Some(90)), "0100025a00");
    assert_row(&got, &[("mode", 0), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_group_when_true_with_no_body_value_leaves_the_group_bit_clear() {
    let got = round_trip(&wg(), &row(Some(1), None, None, Some(90)), "0101025a00");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["speed"]);
}

#[test]
fn ac3_group_when_false_drops_a_body_value_given_without_error() {
    let raw = pack(&wg(), &row(Some(0), Some(7), None, Some(90))).expect("pack");
    assert_eq!(to_hex(&raw), "0100025a00");
}

#[test]
fn ac3_group_with_only_its_when_body_sets_the_group_bit() {
    let got = round_trip(&wg(), &row(Some(1), Some(7), None, None), "01010107");
    assert_row(&got, &[("mode", 1), ("speed", 7)], &["heading"]);
}

#[test]
fn ac5_group_old_clear_bit_packet_still_unpacks() {
    let got = unpack(&wg(), &bytes("0101025a00")).expect("unpack");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["speed"]);
}

// W2, GS: two body values and a group with a sibling.

#[test]
fn ac3_when_with_two_values_writes_both() {
    let got = round_trip(
        &w2(),
        &row(Some(1), Some(7), Some(8), Some(90)),
        "01010307085a00",
    );
    assert_row(
        &got,
        &[("mode", 1), ("speed", 7), ("extra", 8), ("heading", 90)],
        &[],
    );
}

#[test]
fn ac3_when_set_bit_with_a_body_value_missing_fails_pack_naming_it() {
    let err = pack(&w2(), &row(Some(1), Some(7), None, Some(90))).expect_err("pack");
    missing(err, "extra");
}

#[test]
fn ac3_group_sibling_and_when_both_written() {
    let got = round_trip(
        &gs(),
        &row(Some(1), Some(7), Some(4), Some(90)),
        "01010304075a00",
    );
    assert_row(
        &got,
        &[("mode", 1), ("extra", 4), ("speed", 7), ("heading", 90)],
        &[],
    );
}

#[test]
fn ac3_group_sibling_written_when_the_when_is_false() {
    let got = round_trip(
        &gs(),
        &row(Some(0), None, Some(4), Some(90)),
        "010003045a00",
    );
    assert_row(
        &got,
        &[("mode", 0), ("extra", 4), ("heading", 90)],
        &["speed"],
    );
}

#[test]
fn ac3_group_when_body_missing_fails_pack_naming_it() {
    let err = pack(&gs(), &row(Some(1), None, Some(4), Some(90))).expect_err("pack");
    missing(err, "speed");
}

#[test]
fn ac3_group_on_through_its_when_body_fails_pack_naming_the_missing_sibling() {
    let err = pack(&gs(), &row(Some(1), Some(7), None, Some(90))).expect_err("pack");
    missing(err, "extra");
}

#[test]
fn ac3_group_with_nothing_given_leaves_its_bit_clear() {
    let got = round_trip(&gs(), &row(Some(1), None, None, Some(90)), "0101025a00");
    assert_row(&got, &[("mode", 1), ("heading", 90)], &["extra", "speed"]);
}

// WE: the `when` names an earlier member of the same `flags`.

#[test]
fn ac3_when_names_an_earlier_member_of_the_same_flags() {
    let got = round_trip(&we(), &row(Some(1), Some(7), None, None), "01030107");
    assert_row(&got, &[("mode", 1), ("speed", 7)], &[]);
}

#[test]
fn ac3_same_flags_when_false_drops_the_body_without_error() {
    let raw = pack(&we(), &row(Some(0), Some(7), None, None)).expect("pack");
    assert_eq!(to_hex(&raw), "010100");
    let got = unpack(&we(), &raw).expect("unpack");
    assert_row(&got, &[("mode", 0)], &["speed"]);
}

#[test]
fn ac3_same_flags_when_true_with_no_body_value_leaves_its_bit_clear() {
    let got = round_trip(&we(), &row(Some(1), None, None, None), "010101");
    assert_row(&got, &[("mode", 1)], &["speed"]);
}

#[test]
fn ac3_same_flags_without_mode_clears_both_bits() {
    let raw = pack(&we(), &row(None, Some(7), None, None)).expect("pack");
    assert_eq!(to_hex(&raw), "0100");
    let got = unpack(&we(), &raw).expect("unpack");
    assert_row(&got, &[], &["mode", "speed"]);
}

#[test]
fn ac5_same_flags_packet_unpacks() {
    let got = unpack(&we(), &bytes("01030107")).expect("unpack");
    assert_row(&got, &[("mode", 1), ("speed", 7)], &[]);
}

// Hostile: a body value outside the field's range fails pack with no bytes.

#[test]
fn ac3_hostile_body_value_outside_its_field_fails_pack() {
    let mut vals = row(Some(1), None, None, Some(90));
    insert(&mut vals, "speed", Some(Value::U16(300)));
    let err = pack(&wa(), &vals).expect_err("pack");
    assert!(matches!(err, PackError::Type(_)), "{err:?}");
}
