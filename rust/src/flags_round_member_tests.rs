use crate::walk::{pack, unpack};
use crate::{
    flag_byte, flags, group, insert, repeat, times, to_hex, u16, u8, MapScheme, PackError, Value,
    Values,
};

// AZ-2120 AC-4 / AZ-2128 flagged concern: a `times` or `repeat` that is a member of a `flags`
// container, or in a group or flag-bit field under it, is written like any other value. A
// `times` bit is on exactly when its count is above 0, a `repeat` bit when a round holds a value.
// Hex strings come from the C# reference table (wave 3a).

fn bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

fn list(items: &[u8]) -> Value {
    Value::List(items.iter().map(|b| Value::U8(*b)).collect())
}

fn get<'a>(row: &'a Values, name: &str) -> Option<&'a Value> {
    row.get(name).and_then(|v| v.as_ref())
}

/// `n` rounds of `pt` (and `pu` when given) as one list per name, plus `heading`.
fn times_row(n: u8, pt: Option<&[u8]>, pu: Option<&[u8]>, heading: Option<u16>) -> Values {
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U8(n)));
    if let Some(items) = pt {
        insert(&mut vals, "pt", Some(list(items)));
    }
    if let Some(items) = pu {
        insert(&mut vals, "pu", Some(list(items)));
    }
    if let Some(h) = heading {
        insert(&mut vals, "heading", Some(Value::U16(h)));
    }
    vals
}

fn repeat_row(pt: &[u8], pu: Option<&[u8]>, heading: Option<u16>) -> Values {
    let mut vals = Values::new();
    insert(&mut vals, "mode", Some(Value::U8(1)));
    if let Some(h) = heading {
        insert(&mut vals, "heading", Some(Value::U16(h)));
    }
    let rounds = pt
        .iter()
        .enumerate()
        .map(|(i, p)| {
            let mut round = Values::new();
            insert(&mut round, "pt", Some(Value::U8(*p)));
            if let Some(items) = pu {
                insert(&mut round, "pu", Some(Value::U8(items[i])));
            }
            round
        })
        .collect::<Vec<_>>();
    if !rounds.is_empty() {
        insert(&mut vals, "__repeat__", Some(Value::Groups(rounds)));
    }
    vals
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

fn assert_n_and_lists(
    row: &Values,
    n: u8,
    pt: Option<&[u8]>,
    pu: Option<&[u8]>,
    heading: Option<u16>,
) {
    assert_eq!(get(row, "n"), Some(&Value::U8(n)));
    assert_eq!(get(row, "pt"), pt.map(list).as_ref());
    assert_eq!(get(row, "pu"), pu.map(list).as_ref());
    assert_eq!(get(row, "heading"), heading.map(Value::U16).as_ref());
}

fn rounds_of(row: &Values) -> Vec<(Option<Value>, Option<Value>)> {
    match get(row, "__repeat__") {
        Some(Value::Groups(rounds)) => rounds
            .iter()
            .map(|r| (get(r, "pt").cloned(), get(r, "pu").cloned()))
            .collect(),
        None => Vec::new(),
        other => panic!("__repeat__: {other:?}"),
    }
}

/// TA: `u8 n; flags { times(n) { u8 pt }, u16 heading }`
fn ta() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![times(1, "n", vec![u8("pt")]), u16("heading")]),
        ],
    )
}

/// TS: the split form of TA.
fn ts() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("n"),
            m.byte(),
            m.bit(times(2, "n", vec![u8("pt")])),
            m.bit(u16("heading")),
        ],
    )
}

/// TG: TA with the `times` inside a group.
fn tg() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(
                1,
                "f",
                vec![
                    group(1, "g", vec![times(1, "n", vec![u8("pt")])]),
                    u16("heading"),
                ],
            ),
        ],
    )
}

/// T2: a `times` with two values per round.
fn t2() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(
                1,
                "f",
                vec![times(1, "n", vec![u8("pt"), u8("pu")]), u16("heading")],
            ),
        ],
    )
}

/// RA: `u8 mode; flags { u16 heading, repeat { u8 pt } }`
fn ra() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(1, "f", vec![u16("heading"), repeat(2, vec![u8("pt")])]),
        ],
    )
}

/// R2: a `repeat` with two values per round.
fn r2() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![u16("heading"), repeat(2, vec![u8("pt"), u8("pu")])],
            ),
        ],
    )
}

fn pack_err(scheme: &MapScheme, vals: &Values) -> PackError {
    pack(scheme, vals).expect_err("pack must fail")
}

fn names_value(err: &PackError, name: &str) {
    match err {
        PackError::Missing(own) => assert_eq!(own, name),
        PackError::Type(text) => assert!(text.contains(&format!("'{name}'")), "{text}"),
    }
}

// AC-4 `times`: T-0-rounds, T-1-round, T-2-rounds, T-only-times, T-only-n.

#[test]
fn ac4_times_with_no_round_leaves_its_bit_clear() {
    let got = round_trip(&ta(), &times_row(0, None, None, Some(90)), "0100025a00");
    assert_n_and_lists(&got, 0, None, None, Some(90));
}

#[test]
fn ac4_times_with_one_round_sets_its_bit() {
    let got = round_trip(
        &ta(),
        &times_row(1, Some(&[5]), None, Some(90)),
        "010103055a00",
    );
    assert_n_and_lists(&got, 1, Some(&[5]), None, Some(90));
}

#[test]
fn ac4_times_with_two_rounds_writes_both() {
    let got = round_trip(
        &ta(),
        &times_row(2, Some(&[5, 6]), None, Some(90)),
        "01020305065a00",
    );
    assert_n_and_lists(&got, 2, Some(&[5, 6]), None, Some(90));
}

#[test]
fn ac4_times_alone_sets_only_its_bit() {
    let got = round_trip(
        &ta(),
        &times_row(2, Some(&[5, 6]), None, None),
        "0102010506",
    );
    assert_n_and_lists(&got, 2, Some(&[5, 6]), None, None);
}

#[test]
fn ac4_count_alone_sets_no_bit() {
    let got = round_trip(&ta(), &times_row(0, None, None, None), "010000");
    assert_n_and_lists(&got, 0, None, None, None);
}

#[test]
fn ac5_times_old_clear_bit_packet_still_unpacks() {
    let got = unpack(&ta(), &bytes("0100025a00")).expect("unpack");
    assert_n_and_lists(&got, 0, None, None, Some(90));
}

#[test]
fn ac5_times_new_packet_unpacks_the_rounds() {
    let got = unpack(&ta(), &bytes("01020305065a00")).expect("unpack");
    assert_n_and_lists(&got, 2, Some(&[5, 6]), None, Some(90));
}

// AC-4 `times` errors: a set bit that cannot be written in full, and values for count 0.

#[test]
fn ac4_times_list_shorter_than_the_count_fails_pack_naming_the_value() {
    names_value(
        &pack_err(&ta(), &times_row(2, Some(&[5]), None, Some(90))),
        "pt",
    );
}

#[test]
fn ac4_times_values_missing_fails_pack_naming_the_value() {
    names_value(&pack_err(&ta(), &times_row(1, None, None, Some(90))), "pt");
}

#[test]
fn ac4_times_count_zero_with_a_list_given_fails_pack_naming_the_value() {
    names_value(
        &pack_err(&ta(), &times_row(0, Some(&[5]), None, Some(90))),
        "pt",
    );
}

#[test]
fn ac4_times_list_longer_than_the_count_fails_pack_naming_the_value() {
    names_value(
        &pack_err(&ta(), &times_row(1, Some(&[5, 6]), None, Some(90))),
        "pt",
    );
}

#[test]
fn ac4_times_count_field_skipped_leaves_its_bit_clear() {
    let mut vals = Values::new();
    insert(&mut vals, "heading", Some(Value::U16(90)));
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![u8("n"), times(1, "n", vec![u8("pt")]), u16("heading")],
        )],
    );
    let raw = pack(&scheme, &vals).expect("pack");
    assert_eq!(to_hex(&raw), "01045a00");
}

// Split form and group.

#[test]
fn ac4_split_form_times_matches_the_combined_form() {
    for (vals, hex) in [
        (times_row(0, None, None, Some(90)), "0100025a00"),
        (times_row(1, Some(&[5]), None, Some(90)), "010103055a00"),
        (
            times_row(2, Some(&[5, 6]), None, Some(90)),
            "01020305065a00",
        ),
    ] {
        round_trip(&ts(), &vals, hex);
    }
}

#[test]
fn ac4_split_form_times_errors_name_the_value() {
    names_value(
        &pack_err(&ts(), &times_row(2, Some(&[5]), None, Some(90))),
        "pt",
    );
    names_value(&pack_err(&ts(), &times_row(1, None, None, Some(90))), "pt");
    names_value(
        &pack_err(&ts(), &times_row(0, Some(&[5]), None, Some(90))),
        "pt",
    );
    names_value(
        &pack_err(&ts(), &times_row(1, Some(&[5, 6]), None, Some(90))),
        "pt",
    );
}

#[test]
fn ac4_group_times_matches_the_combined_form() {
    for (vals, hex) in [
        (times_row(0, None, None, Some(90)), "0100025a00"),
        (times_row(1, Some(&[5]), None, Some(90)), "010103055a00"),
        (
            times_row(2, Some(&[5, 6]), None, Some(90)),
            "01020305065a00",
        ),
    ] {
        round_trip(&tg(), &vals, hex);
    }
}

#[test]
fn ac4_group_times_errors_name_the_value() {
    names_value(
        &pack_err(&tg(), &times_row(2, Some(&[5]), None, Some(90))),
        "pt",
    );
    names_value(&pack_err(&tg(), &times_row(1, None, None, Some(90))), "pt");
    names_value(
        &pack_err(&tg(), &times_row(0, Some(&[5]), None, Some(90))),
        "pt",
    );
    names_value(
        &pack_err(&tg(), &times_row(1, Some(&[5, 6]), None, Some(90))),
        "pt",
    );
}

// Two values per round.

#[test]
fn ac4_times_with_two_values_missing_one_fails_pack_naming_it() {
    names_value(
        &pack_err(&t2(), &times_row(1, Some(&[5]), None, Some(90))),
        "pu",
    );
}

#[test]
fn ac4_times_with_two_values_one_round() {
    let got = round_trip(
        &t2(),
        &times_row(1, Some(&[5]), Some(&[6]), Some(90)),
        "01010305065a00",
    );
    assert_n_and_lists(&got, 1, Some(&[5]), Some(&[6]), Some(90));
}

#[test]
fn ac4_times_with_two_values_two_rounds_interleave_them() {
    let got = round_trip(
        &t2(),
        &times_row(2, Some(&[5, 6]), Some(&[7, 8]), Some(90)),
        "010203050706085a00",
    );
    assert_n_and_lists(&got, 2, Some(&[5, 6]), Some(&[7, 8]), Some(90));
}

// AC-4 `repeat`: R-0-rounds .. R-two-values-unpack.

#[test]
fn ac4_repeat_with_no_round_leaves_its_bit_clear() {
    let got = round_trip(&ra(), &repeat_row(&[], None, Some(90)), "0101015a00");
    assert!(rounds_of(&got).is_empty());
}

#[test]
fn ac4_repeat_with_one_round_sets_its_bit() {
    let got = round_trip(&ra(), &repeat_row(&[5], None, Some(90)), "0101035a0005");
    assert_eq!(rounds_of(&got), vec![(Some(Value::U8(5)), None)]);
}

#[test]
fn ac4_repeat_with_two_rounds_writes_both() {
    let got = round_trip(
        &ra(),
        &repeat_row(&[5, 6], None, Some(90)),
        "0101035a000506",
    );
    assert_eq!(
        rounds_of(&got),
        vec![(Some(Value::U8(5)), None), (Some(Value::U8(6)), None)]
    );
}

#[test]
fn ac4_repeat_alone_sets_only_its_bit() {
    round_trip(&ra(), &repeat_row(&[5, 6], None, None), "0101020506");
}

#[test]
fn ac4_mode_alone_sets_no_repeat_bit() {
    let got = round_trip(&ra(), &repeat_row(&[], None, None), "010100");
    assert!(rounds_of(&got).is_empty());
}

#[test]
fn ac5_repeat_old_clear_bit_packet_still_unpacks() {
    let got = unpack(&ra(), &bytes("0101015a00")).expect("unpack");
    assert_eq!(get(&got, "heading"), Some(&Value::U16(90)));
    assert!(rounds_of(&got).is_empty());
}

#[test]
fn ac5_repeat_new_packet_unpacks_the_rounds() {
    let got = unpack(&ra(), &bytes("0101035a000506")).expect("unpack");
    assert_eq!(get(&got, "heading"), Some(&Value::U16(90)));
    assert_eq!(rounds_of(&got).len(), 2);
}

#[test]
fn ac4_repeat_round_missing_a_value_fails_pack_naming_it() {
    names_value(&pack_err(&r2(), &repeat_row_missing_pu()), "pu");
}

fn repeat_row_missing_pu() -> Values {
    repeat_row(&[5], None, Some(90))
}

#[test]
fn ac4_repeat_with_two_values_one_round() {
    let got = round_trip(
        &r2(),
        &repeat_row(&[5], Some(&[6]), Some(90)),
        "0101035a000506",
    );
    assert_eq!(
        rounds_of(&got),
        vec![(Some(Value::U8(5)), Some(Value::U8(6)))]
    );
}

#[test]
fn ac4_repeat_with_two_values_two_rounds() {
    round_trip(
        &r2(),
        &repeat_row(&[5, 6], Some(&[7, 8]), Some(90)),
        "0101035a0005070608",
    );
}

#[test]
fn ac5_repeat_with_two_values_unpacks_as_two_rounds() {
    let got = unpack(&r2(), &bytes("0101035a0005060708")).expect("unpack");
    assert_eq!(
        rounds_of(&got),
        vec![
            (Some(Value::U8(5)), Some(Value::U8(6))),
            (Some(Value::U8(7)), Some(Value::U8(8)))
        ]
    );
}

// Hostile: a round entry outside the field's range fails pack.

#[test]
fn ac4_hostile_round_entry_outside_its_field_fails_pack() {
    let mut vals = times_row(1, None, None, Some(90));
    insert(&mut vals, "pt", Some(Value::List(vec![Value::U16(300)])));
    let err = pack_err(&ta(), &vals);
    assert!(matches!(err, PackError::Type(_)), "{err:?}");
}
