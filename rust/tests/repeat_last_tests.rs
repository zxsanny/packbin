#![cfg(feature = "std")]
use packbin::{
    bytes, dict, eq, flag_byte, flags, group, insert, list, pack, repeat, sized, times, to_hex, u2,
    u8, unpack, utf8, when, BoundField, Field, MapScheme, Scheme, SchemeItem, Value, Values,
};
use std::panic::{catch_unwind, AssertUnwindSafe};

// AZ-4218: a `repeat` must be the last thing its packet reads, in the map form. The rule, the
// refused cases R1 to R9, the cases K1 to K5 that keep building and the refusal text are the
// contract `_docs/02_document/contracts/library/repeat-last.md`. A `repeat` has no count on the
// wire, so unpack reads rounds until the packet ends and would read a field after it as one more
// round. Rust refuses a scheme by panicking in `MapScheme::new` (see its doc); the heap-free API
// is in `nostd_repeat_last_tests.rs`.

/// The text of the panic `build` ends in, or `None` when it returns.
fn panic_of<T>(build: impl FnOnce() -> T) -> Option<String> {
    catch_unwind(AssertUnwindSafe(build))
        .err()
        .map(|panic| match panic.downcast_ref::<String>() {
            Some(text) => text.clone(),
            None => panic
                .downcast_ref::<&str>()
                .map_or_else(String::new, |s| (*s).to_string()),
        })
}

/// The refusal of the scheme `fields` builds, or `None` when it builds. The fields are built
/// inside, since `list` and `dict` refuse an element on their own.
fn refusal(fields: impl FnOnce() -> Vec<Field>) -> Option<String> {
    panic_of(|| MapScheme::new(1, fields()))
}

fn followed(anchor: u32, field: &str) -> Option<String> {
    Some(format!(
        "repeat {anchor}: field {field} follows it; a repeat reads to the end of the packet, so \
         nothing can follow it; use times"
    ))
}

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

/// One round row per item, each holding `v`.
fn rounds(items: &[u8]) -> Value {
    Value::Groups(items.iter().map(|x| v(&[("v", n(*x))])).collect())
}

/// The `v` of each round kept under `key`.
fn round_values(values: &Values, key: &str) -> Vec<Option<Value>> {
    let Some(Some(Value::Groups(rounds))) = values.get(key) else {
        panic!("no rounds under {key}");
    };
    rounds
        .iter()
        .map(|round| round.get("v").cloned().flatten())
        .collect()
}

fn value(values: &Values, name: &str) -> Option<Value> {
    values.get(name).cloned().flatten()
}

/// The packet of `row` as hex and the values its own unpack returns.
fn round_trip(scheme: &MapScheme, row: &Values) -> (String, Values) {
    let packet = pack(scheme, row).expect("pack");
    let back = unpack(scheme, &packet).expect("unpack");
    (to_hex(&packet), back)
}

fn when_k(anchor: u32, k: u8, fields: Vec<Field>) -> Field {
    when(anchor, eq("k", n(k)), fields)
}

// AC-1: the refused cases, each with the whole text

#[test]
fn ac1_r1_a_field_after_a_repeat_at_the_top_level_is_refused_naming_both() {
    // Arrange / Act (AC-1)
    let refused = refusal(|| vec![repeat(0, vec![u8("v")]), u8("x")]);

    // Assert
    assert_eq!(
        refused.as_deref(),
        Some(
            "repeat 0: field \"x\" follows it; a repeat reads to the end of the packet, so \
             nothing can follow it; use times"
        )
    );
}

#[test]
fn ac1_r2_a_field_after_the_when_that_holds_the_repeat_is_refused() {
    // Arrange / Act (AC-1)
    let refused = refusal(|| {
        vec![
            u8("k"),
            when_k(1, 1, vec![repeat(1, vec![u8("v")])]),
            u8("x"),
        ]
    });

    // Assert
    assert_eq!(refused, followed(1, "\"x\""));
}

#[test]
fn ac1_r3_a_field_after_the_flags_that_holds_the_repeat_is_refused() {
    // Arrange / Act (AC-1)
    let refused = refusal(|| vec![flags(0, "f", vec![repeat(0, vec![u8("v")])]), u8("x")]);

    // Assert
    assert_eq!(refused, followed(0, "\"x\""));
}

#[test]
fn ac1_r4_a_field_after_the_group_that_holds_the_repeat_is_refused() {
    // Arrange / Act (AC-1): Rust has only an anchored group, which shares the ids of its row
    let refused = refusal(|| vec![group(0, "m", vec![repeat(0, vec![u8("v")])]), u8("x")]);

    // Assert
    assert_eq!(refused, followed(0, "\"x\""));
}

#[test]
fn ac1_r5_a_second_repeat_is_refused_by_its_first_member() {
    // Arrange / Act (AC-1)
    let refused = refusal(|| vec![repeat(0, vec![u8("v")]), repeat(1, vec![u8("w")])]);

    // Assert
    assert_eq!(refused, followed(0, "\"w\""));
}

#[test]
fn ac1_r6_a_field_under_a_when_that_excludes_the_repeats_when_is_refused_all_the_same() {
    // Arrange / Act (AC-1): no row writes both the repeat and `x`; the conditions are not compared
    let refused = refusal(|| {
        vec![
            u8("k"),
            when_k(1, 1, vec![repeat(1, vec![u8("v")])]),
            when_k(2, 2, vec![u8("x")]),
        ]
    });

    // Assert
    assert_eq!(refused, followed(1, "\"x\""));
}

#[test]
fn ac1_r7_r8_have_no_spelling_a_list_or_dict_element_is_one_value_never_a_row() {
    // Arrange (AC-1): the nearest schemes, a group as the element and the repeat as the element
    let row = || group(0, "item", vec![u8("mode"), repeat(1, vec![u8("v")])]);
    let one_value =
        "an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name";

    // Act
    let list_of_rows = refusal(|| vec![list("items", row())]);
    let dict_of_rows = refusal(|| vec![dict("d", row())]);
    let list_of_repeat = refusal(|| vec![list("items", repeat(0, vec![u8("v")]))]);
    let dict_of_repeat = refusal(|| vec![dict("d", repeat(0, vec![u8("v")]))]);

    // Assert: the refusal is for the row (with or without a repeat), not for the repeat
    assert_eq!(
        list_of_rows,
        Some(format!(
            "list \"items\" cannot carry element \"item\": {one_value}"
        ))
    );
    assert_eq!(
        dict_of_rows,
        Some(format!(
            "dict \"d\" cannot carry element \"item\": {one_value}"
        ))
    );
    assert_eq!(
        list_of_repeat.as_deref(),
        Some("repeat is not a list element")
    );
    assert_eq!(
        dict_of_repeat.as_deref(),
        Some("repeat is not a dictionary element")
    );
}

#[test]
fn ac1_r9_a_repeat_inside_a_times_round_keeps_the_nesting_rule_and_its_text() {
    // Arrange / Act (AC-1)
    let refused = refusal(|| vec![u8("k"), times(1, "k", vec![repeat(1, vec![u8("v")])])]);

    // Assert
    assert_eq!(
        refused.as_deref(),
        Some(
            "repeat at id 1 is inside a repeat or times round; a round keeps no inner repeat \
             rounds"
        )
    );
}

/// (what, the scheme, the anchor of the repeat, the field that follows it)
type Case = (&'static str, Vec<Field>, u32, &'static str);

/// Every case refused with the whole text for its repeat and the field that follows it.
fn assert_each_refused(cases: Vec<Case>) {
    for (what, fields, anchor, field) in cases {
        // Act
        let refused = refusal(|| fields);

        // Assert
        assert_eq!(refused, followed(anchor, field), "{what}");
    }
}

#[test]
fn ac1_a_byte_writing_field_in_any_container_place_after_a_repeat_is_refused() {
    // Arrange (AC-1): the places a field can stand in: flags, flag bits, a when, behind a field
    let m = flag_byte("m");
    let cases: Vec<Case> = vec![
        (
            "a later member of the same flags",
            vec![flags(0, "f", vec![repeat(0, vec![u8("v")]), u8("x")])],
            0,
            "\"x\"",
        ),
        (
            "the field of a flag bit",
            vec![m.byte(), repeat(1, vec![u8("v")]), m.bit(u8("x"))],
            1,
            "\"x\"",
        ),
        (
            "a field after the flag bit that holds the repeat",
            vec![m.byte(), m.bit(repeat(1, vec![u8("v")])), u8("x")],
            1,
            "\"x\"",
        ),
        (
            "a field behind one that writes nothing",
            vec![repeat(0, vec![u8("v")]), bytes("z", 0), u8("x")],
            0,
            "\"x\"",
        ),
        (
            "a field in a group in a when",
            vec![
                u8("k"),
                repeat(1, vec![u8("v")]),
                when_k(2, 1, vec![group(2, "g", vec![u8("x")])]),
            ],
            1,
            "\"x\"",
        ),
    ];

    // Act / Assert
    assert_each_refused(cases);
}

#[test]
fn ac1_every_kind_of_field_that_writes_a_byte_after_a_repeat_is_refused() {
    // Arrange (AC-1): the kinds of field that write a byte, each right after the repeat
    let m = flag_byte("m");
    let after_v = || repeat(0, vec![u8("v")]);
    let cases: Vec<Case> = vec![
        (
            "a flags of one bool: its byte is written",
            vec![after_v(), flags(1, "f", vec![group(1, "on", vec![])])],
            0,
            "\"f\"",
        ),
        ("a flag byte", vec![after_v(), m.byte()], 0, "\"m\""),
        (
            "a list",
            vec![after_v(), list("items", u8("e"))],
            0,
            "\"items\"",
        ),
        ("a dict", vec![after_v(), dict("d", u8("e"))], 0, "\"d\""),
        ("a utf8", vec![after_v(), utf8("s")], 0, "\"s\""),
        ("a u2", vec![after_v(), u2(&["a", "b"])], 0, "\"a\""),
        (
            "a sized, whatever its count",
            vec![u8("k"), repeat(1, vec![u8("v")]), sized("s", "k")],
            1,
            "\"s\"",
        ),
        (
            "a times whose body can write a byte",
            vec![
                u8("k"),
                repeat(1, vec![u8("v")]),
                times(2, "k", vec![u8("w")]),
            ],
            1,
            "\"w\"",
        ),
    ];

    // Act / Assert
    assert_each_refused(cases);
}

#[derive(Default)]
struct Tail {
    x: u8,
}

#[test]
fn ac1_a_typed_scheme_that_holds_a_raw_repeat_before_a_bound_field_is_refused_the_same_way() {
    // Arrange (AC-1): the typed `Scheme` has no repeat of its own; it takes the map form's as a
    // raw field and is built through `MapScheme::new`
    let build = || {
        Scheme::<Tail>::new(
            1,
            [
                SchemeItem::Field(repeat(0, vec![u8("v")])),
                BoundField::u8(1, |r: &Tail| r.x, |r: &mut Tail, v| r.x = v).into(),
            ],
        )
    };

    // Act
    let refused = panic_of(build);

    // Assert: a bound field is named by its id
    assert_eq!(refused, followed(0, "\"1\""));
}

// AC-1: a field after the repeat that cannot write a byte

#[test]
fn ac1_fields_after_a_repeat_that_cannot_write_a_byte_build() {
    // Arrange (AC-1): (what, the scheme)
    let cases: Vec<(&str, Vec<Field>)> = vec![
        (
            "a zero-width bytes",
            vec![repeat(0, vec![u8("v")]), bytes("z", 0)],
        ),
        ("a u2 with no name", vec![repeat(0, vec![u8("v")]), u2(&[])]),
        (
            "a when that holds nothing that counts",
            vec![
                u8("k"),
                repeat(1, vec![u8("v")]),
                when_k(2, 1, vec![bytes("z", 0)]),
            ],
        ),
        (
            "a group that holds nothing that counts",
            vec![repeat(0, vec![u8("v")]), group(1, "g", vec![bytes("z", 0)])],
        ),
        (
            "a times whose body cannot write a byte",
            vec![
                u8("k"),
                repeat(1, vec![u8("v")]),
                times(2, "k", vec![bytes("z", 0)]),
            ],
        ),
    ];

    for (what, fields) in cases {
        // Act
        let refused = refusal(|| fields);

        // Assert
        assert_eq!(refused, None, "{what}");
    }
}

#[test]
fn ac1_a_zero_width_bytes_after_a_repeat_reads_back() {
    // Arrange (AC-1)
    let scheme = MapScheme::new(1, vec![repeat(0, vec![u8("v")]), bytes("z", 0)]);
    let row = v(&[("__repeat__", rounds(&[5, 6])), ("z", Value::Bytes(vec![]))]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert
    assert_eq!(packet, "010506");
    assert_eq!(round_values(&back, "__repeat__"), [Some(n(5)), Some(n(6))]);
    assert_eq!(value(&back, "z"), Some(Value::Bytes(vec![])));
}

// AC-2: a repeat that is last still builds, with the same bytes

#[test]
fn ac2_k1_a_repeat_after_a_field_packs_the_contract_packet_and_reads_back() {
    // Arrange (AC-2)
    let scheme = MapScheme::new(1, vec![u8("x"), repeat(1, vec![u8("v")])]);
    let row = v(&[("x", n(9)), ("__repeat__", rounds(&[5, 6]))]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert
    assert_eq!(packet, "01090506");
    assert_eq!(back, row);
}

#[test]
fn ac2_k2_a_repeat_last_in_a_when_that_nothing_follows_packs_and_reads_back() {
    // Arrange (AC-2)
    let scheme = MapScheme::new(
        1,
        vec![u8("k"), when_k(1, 1, vec![repeat(1, vec![u8("v")])])],
    );
    let row = v(&[("k", n(1)), ("__repeat__", rounds(&[5, 6]))]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert
    assert_eq!(packet, "01010506");
    assert_eq!(back, row);
}

#[test]
fn ac2_k3_a_repeat_as_the_last_member_of_a_flags_packs_and_reads_back() {
    // Arrange (AC-2)
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![u8("x"), repeat(1, vec![u8("v")])])],
    );
    let row = v(&[("x", n(9)), ("__repeat__", rounds(&[5, 6]))]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert: unpack also returns the flags byte under its name
    assert_eq!(packet, "0103090506");
    assert_eq!(value(&back, "x"), Some(n(9)));
    assert_eq!(round_values(&back, "__repeat__"), [Some(n(5)), Some(n(6))]);
    assert_eq!(value(&back, "f"), Some(n(3)));
}

#[test]
fn ac2_k4_a_times_has_a_count_so_a_field_may_follow_it() {
    // Arrange (AC-2)
    let scheme = MapScheme::new(1, vec![u8("k"), times(1, "k", vec![u8("v")]), u8("x")]);
    let row = v(&[
        ("k", n(2)),
        ("v", Value::List(vec![n(5), n(6)])),
        ("x", n(9)),
    ]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert
    assert_eq!(packet, "0102050609");
    assert_eq!(value(&back, "k"), Some(n(2)));
    assert_eq!(round_values(&back, "__times_1"), [Some(n(5)), Some(n(6))]);
    assert_eq!(value(&back, "x"), Some(n(9)));
}

#[test]
fn ac2_k5_a_bool_bit_of_an_earlier_flag_byte_after_the_repeat_builds_and_reads_back() {
    // Arrange (AC-2): the bool after the repeat is a bit of the byte written before it
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![
            m.byte(),
            m.bit(u8("x")),
            repeat(2, vec![u8("v")]),
            m.bit(group(3, "on", vec![])),
        ],
    );
    let row = v(&[("x", n(9)), ("__repeat__", rounds(&[5, 6])), ("on", n(1))]);

    // Act
    let (packet, back) = round_trip(&scheme, &row);

    // Assert
    assert_eq!(packet, "0103090506");
    assert_eq!(value(&back, "x"), Some(n(9)));
    assert_eq!(round_values(&back, "__repeat__"), [Some(n(5)), Some(n(6))]);
    assert_eq!(value(&back, "on"), Some(n(1)));
}
