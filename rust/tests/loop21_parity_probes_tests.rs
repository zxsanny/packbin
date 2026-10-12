use packbin::{
    flag_byte, flags, group, insert, pack, repeat, times, to_hex, u16, u8, MapScheme, PackError,
    Value, Values,
};

// Loop 21 probes of Rust against `_docs/03_implementation/reference_loop21_slots.md`:
// AZ-2383 (section 3, rows 27 to 39) and AZ-2384 (rows 40 to 43); AZ-2386 and AZ-2387 are in
// `count_behind_clear_when_tests.rs`. Rust takes the rounds of a `repeat` as `Value::Groups` under
// `__repeat__` and has no per-name list form for it, and an error is a `PackError`; the texts are
// Rust's own where it already had one, and TypeScript's where the row is new.

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

fn with_rounds(key: &str, rows: &[Values]) -> Values {
    v(&[(key, Value::Groups(rows.to_vec()))])
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn text(result: Result<String, PackError>) -> String {
    match result {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

// ---- AZ-2383: a short list in an optional flags position of a repeat (rows 27 to 39) ----

/// `repeat { u8 w; flags { u8 v } }`
fn repeat_optional() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(0, vec![u8("w"), flags(1, "f", vec![u8("v")])])],
    )
}

#[test]
fn az2383_rows_27_to_30_a_repeat_names_its_rounds_so_an_absent_member_is_a_round_without_it() {
    // Arrange: one `Values` per round says which round has `v`; there is no list to be too short
    let scheme = repeat_optional();
    let rounds = |rows: &[Values]| with_rounds("__repeat__", rows);

    // Act
    let one_absent = hex_of(&scheme, &rounds(&[v(&[("w", n(1)), ("v", n(5))]), v(&[("w", n(2))])]));
    let both = hex_of(
        &scheme,
        &rounds(&[v(&[("w", n(1)), ("v", n(5))]), v(&[("w", n(2)), ("v", n(6))])]),
    );
    let none = hex_of(&scheme, &rounds(&[v(&[("w", n(1))]), v(&[("w", n(2))])]));

    // Assert: the bytes of rows 29 and 30 (row 27's short list has no Rust spelling)
    assert_eq!(one_absent, Ok("010101050200".to_string()));
    assert_eq!(both, Ok("01010105020106".to_string()));
    assert_eq!(none, Ok("0101000200".to_string()));
}

#[test]
fn az2383_row_27_per_name_lists_without_groups_are_refused_naming_the_member() {
    // Arrange: TypeScript's `{w:[1,2], v:[5]}`; Rust's pack reads `__repeat__` only, and since
    // AZ-2412 (U13) it refuses lists given without groups instead of packing no rounds
    let vals = v(&[
        ("w", Value::List(vec![n(1), n(2)])),
        ("v", Value::List(vec![n(5)])),
    ]);

    // Act
    let result = hex_of(&repeat_optional(), &vals);

    // Assert
    assert_eq!(
        result,
        Err(PackError::Type(
            "repeat at id 0: 'w' is given without '__repeat__' groups; give the rounds of a \
             repeat as '__repeat__' groups, one per round"
                .to_string()
        ))
    );
}

#[test]
fn az2383_row_31_a_required_member_missing_in_a_round_is_still_missing() {
    // Arrange
    let vals = with_rounds("__repeat__", &[v(&[("w", n(1))]), v(&[("v", n(6))])]);

    // Act
    let result = hex_of(&repeat_optional(), &vals);

    // Assert
    assert_eq!(result, Err(PackError::Missing("w".to_string())));
}

#[test]
fn az2383_row_32_a_bool_in_flags_is_set_or_absent_per_round() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![repeat(0, vec![u8("w"), flags(1, "f", vec![group(1, "on", vec![])])])],
    );
    let vals = with_rounds("__repeat__", &[v(&[("w", n(1)), ("on", n(1))]), v(&[("w", n(2))])]);

    // Act
    let wire = hex_of(&scheme, &vals);

    // Assert
    assert_eq!(wire, Ok("0101010200".to_string()));
}

#[test]
fn az2383_row_33_a_split_bit_is_set_or_absent_per_round() {
    // Arrange: `repeat { u8 w; flagByte m; bit { u8 v } }`
    let m = flag_byte("m");
    let scheme = MapScheme::new(1, vec![repeat(0, vec![u8("w"), m.byte(), m.bit(u8("v"))])]);
    let vals = with_rounds("__repeat__", &[v(&[("w", n(1)), ("v", n(5))]), v(&[("w", n(2))])]);

    // Act
    let wire = hex_of(&scheme, &vals);

    // Assert
    assert_eq!(wire, Ok("010101050200".to_string()));
}

#[test]
fn az2383_row_39_times_takes_the_rounds_of_a_member_under_flags_as_groups() {
    // Arrange: `u8 c; times(c) { flags { u8 v } }`
    let scheme = MapScheme::new(
        1,
        vec![u8("c"), times(1, "c", vec![flags(1, "f", vec![u8("v")])])],
    );
    let mut vals = with_rounds("__times_1", &[v(&[("v", n(5))]), Values::new()]);
    insert(&mut vals, "c", Some(n(2)));
    let mut listed = v(&[("c", n(2))]);
    insert(&mut listed, "v", Some(Value::List(vec![n(5)])));

    // Act
    let by_rounds = hex_of(&scheme, &vals);
    let by_list = hex_of(&scheme, &listed);

    // Assert: TypeScript packs the list `{c:2, v:[5]}` as `0102010500`; since AZ-2414 (U15) so does
    // Rust, the missing item meaning the member is absent in that round
    assert_eq!(by_rounds, Ok("0102010500".to_string()));
    assert_eq!(by_list, Ok("0102010500".to_string()));
}

// ---- AZ-2384: a split-bit times, count above 0 after the byte, body absent (rows 40 to 43) ----

/// `flagByte fb; u8 n; bit { times(n) { u8 pt } }; bit { u16 heading }`
fn split_times_after_byte() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![
            fb.byte(),
            u8("n"),
            fb.bit(times(2, "n", vec![u8("pt")])),
            fb.bit(u16("heading")),
        ],
    )
}

fn heading_row(extra: &[(&str, Value)]) -> Values {
    let mut vals = v(&[("heading", Value::U16(90))]);
    for (name, value) in extra {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

#[test]
fn az2384_row_40_count_above_zero_and_no_body_packs_a_clear_bit() {
    // Arrange
    let vals = heading_row(&[("n", n(2))]);

    // Act
    let wire = hex_of(&split_times_after_byte(), &vals);

    // Assert
    assert_eq!(wire, Ok("0102025a00".to_string()));
}

#[test]
fn az2384_row_41_an_empty_body_list_packs_a_clear_bit() {
    // Arrange
    let vals = heading_row(&[("n", n(2)), ("pt", Value::List(vec![]))]);

    // Act
    let wire = hex_of(&split_times_after_byte(), &vals);

    // Assert
    assert_eq!(wire, Ok("0102025a00".to_string()));
}

#[test]
fn az2384_row_42_count_zero_packs_a_clear_bit() {
    // Arrange
    let vals = heading_row(&[("n", n(0))]);

    // Act
    let wire = hex_of(&split_times_after_byte(), &vals);

    // Assert
    assert_eq!(wire, Ok("0102005a00".to_string()));
}

#[test]
fn az2384_row_43_a_body_given_while_the_count_follows_the_byte_is_refused_naming_it() {
    // Arrange
    let vals = heading_row(&[("n", n(2)), ("pt", Value::List(vec![n(5), n(6)]))]);

    // Act
    let message = text(hex_of(&split_times_after_byte(), &vals));

    // Assert
    assert_eq!(
        message,
        "'pt' is given, but its times count 'n' is not written where the flag byte is written \
         (skipped or written after it); write 'n' before the flag byte"
    );
}

#[test]
fn az2384_ac2_the_body_present_with_the_count_before_the_byte_is_unchanged() {
    // Arrange: `u8 n; flagByte fb; bit { times(n) { u8 pt } }; bit { u16 heading }`
    let fb = flag_byte("fb");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            fb.byte(),
            fb.bit(times(2, "n", vec![u8("pt")])),
            fb.bit(u16("heading")),
        ],
    );
    let vals = heading_row(&[("n", n(2)), ("pt", Value::List(vec![n(5), n(6)]))]);

    // Act
    let wire = hex_of(&scheme, &vals);

    // Assert
    assert_eq!(wire, Ok("01020305065a00".to_string()));
}
