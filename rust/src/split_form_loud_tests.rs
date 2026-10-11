use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, insert, times, to_hex, u16, u8, when, MapScheme, PackError, Value, Values,
};

// AZ-2331: a split flag byte decides its `when` / `times` bits where the byte is written, from
// what is written so far. A body whose condition does not hold then, or whose count is not
// written then, is refused naming the value; shapes whose source is written before the byte pack
// as before (reference rows WS and TS of loop 18).

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|n| Value::U8(*n)).collect())
}

fn refusal(scheme: &MapScheme, vals: &Values) -> String {
    match pack(scheme, vals) {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

fn hex(scheme: &MapScheme, vals: &Values) -> String {
    to_hex(&pack(scheme, vals).expect("pack"))
}

/// `flagbyte m; u8 mode; bit m { when mode == 1 { u8 speed } }`: the condition follows the byte.
fn when_after_the_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("mode"),
            m.bit(when(2, eq("mode", Value::U8(1)), vec![u8("speed")])),
        ],
    )
}

/// WS: `u8 mode; flagbyte m; bit m { when mode == 1 { u8 speed } }; bit m { u16 heading }`.
fn ws() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            m.byte(),
            m.bit(when(2, eq("mode", Value::U8(1)), vec![u8("speed")])),
            m.bit(u16("heading")),
        ],
    )
}

/// `flagbyte m; u8 n; bit m { times n { u8 pt } }`: the count follows the byte.
fn count_after_the_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![m.byte(), u8("n"), m.bit(times(2, "n", vec![u8("pt")]))],
    )
}

/// `u8 k; when k == 1 { u8 n }; flagbyte m; bit m { times n { u8 pt } }`: the count may be skipped.
fn skipped_count() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("k"),
            when(1, eq("k", Value::U8(1)), vec![u8("n")]),
            m.byte(),
            m.bit(times(3, "n", vec![u8("pt")])),
        ],
    )
}

#[test]
fn ac1_a_condition_written_after_the_byte_with_the_body_given_names_the_body() {
    // Arrange
    let vals = row(&[("mode", Value::U8(1)), ("speed", Value::U8(7))]);

    // Act
    let message = refusal(&when_after_the_byte(), &vals);

    // Assert
    assert!(
        message.contains("'speed'") && message.contains("'mode'"),
        "{message}"
    );
}

#[test]
fn ac1_the_same_scheme_without_a_body_value_still_packs() {
    // Arrange
    let vals = row(&[("mode", Value::U8(1))]);

    // Act
    let wire = hex(&when_after_the_byte(), &vals);

    // Assert
    assert_eq!(wire, "010001");
}

#[test]
fn ac2_a_count_written_after_the_byte_with_values_given_names_the_value() {
    // Arrange
    let vals = row(&[("n", Value::U8(2)), ("pt", ints(&[5, 6]))]);

    // Act
    let message = refusal(&count_after_the_byte(), &vals);

    // Assert
    assert!(
        message.contains("'pt'") && message.contains("'n'"),
        "{message}"
    );
}

#[test]
fn ac2_a_skipped_count_with_values_given_names_the_value() {
    // Arrange
    let vals = row(&[("k", Value::U8(0)), ("pt", ints(&[5]))]);

    // Act
    let message = refusal(&skipped_count(), &vals);

    // Assert
    assert!(message.contains("'pt'"), "{message}");
}

#[test]
fn ac2_a_skipped_count_with_rounds_given_names_the_rounds_key() {
    // Arrange
    let mut round = Values::new();
    insert(&mut round, "pt", Some(Value::U8(5)));
    let mut vals = row(&[("k", Value::U8(0))]);
    insert(&mut vals, "__times_3", Some(Value::Groups(vec![round])));

    // Act
    let message = refusal(&skipped_count(), &vals);

    // Assert
    assert!(message.contains("__times_3"), "{message}");
}

#[test]
fn ac2_a_skipped_count_with_no_values_packs_a_clear_bit() {
    // Arrange
    let vals = row(&[("k", Value::U8(0))]);

    // Act
    let wire = hex(&skipped_count(), &vals);

    // Assert
    assert_eq!(wire, "010000");
}

#[test]
fn ac2_a_count_written_before_the_byte_still_packs() {
    // Arrange
    let vals = row(&[("k", Value::U8(1)), ("n", Value::U8(1)), ("pt", ints(&[5]))]);

    // Act
    let wire = hex(&skipped_count(), &vals);

    // Assert
    assert_eq!(wire, "0101010105");
}

#[test]
fn ac3_a_false_condition_before_the_byte_with_a_body_given_packs_without_it() {
    // Arrange: WS, the condition is written before the byte and is false
    let vals = row(&[
        ("mode", Value::U8(0)),
        ("speed", Value::U8(7)),
        ("heading", Value::U16(90)),
    ]);

    // Act
    let wire = hex(&ws(), &vals);

    // Assert
    assert_eq!(wire, "0100025a00");
}

#[test]
fn ac3_a_false_condition_after_the_byte_with_a_body_given_packs_without_it() {
    // Arrange: the condition follows the byte and is false
    let vals = row(&[("mode", Value::U8(0)), ("speed", Value::U8(7))]);

    // Act
    let wire = hex(&when_after_the_byte(), &vals);

    // Assert
    assert_eq!(wire, "010000");
}

#[test]
fn ac3_a_false_condition_outside_the_range_of_its_source_is_still_false() {
    // Arrange: a hostile source value (255) that is not the expected 1
    let vals = row(&[("mode", Value::U8(255)), ("speed", Value::U8(7))]);

    // Act
    let wire = hex(&when_after_the_byte(), &vals);

    // Assert
    assert_eq!(wire, "0100ff");
}

#[test]
fn ac4_the_reference_rows_with_the_source_before_the_byte_pack_unchanged() {
    // Arrange
    let cases = [
        (
            &[
                ("mode", Value::U8(1)),
                ("speed", Value::U8(7)),
                ("heading", Value::U16(90)),
            ][..],
            "010103075a00",
        ),
        (
            &[("mode", Value::U8(0)), ("heading", Value::U16(90))][..],
            "0100025a00",
        ),
        (
            &[("mode", Value::U8(1)), ("heading", Value::U16(90))][..],
            "0101025a00",
        ),
    ];

    for (pairs, expected) in cases {
        // Act
        let vals = row(pairs);
        let wire = hex(&ws(), &vals);
        let back = unpack(&ws(), &to_bytes(&wire)).expect("unpack");

        // Assert
        assert_eq!(wire, expected);
        assert_eq!(hex(&ws(), &back), expected);
    }
}

#[test]
fn ac4_the_combined_form_keeps_dropping_a_body_whose_condition_is_false() {
    // Arrange: `flags` decides its bits in member order, so the rows of the table are unchanged
    let scheme = MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![
                    when(1, eq("mode", Value::U8(1)), vec![u8("speed")]),
                    u16("heading"),
                ],
            ),
        ],
    );
    let vals = row(&[
        ("mode", Value::U8(0)),
        ("speed", Value::U8(7)),
        ("heading", Value::U16(90)),
    ]);

    // Act
    let wire = hex(&scheme, &vals);

    // Assert
    assert_eq!(wire, "0100025a00");
}

fn to_bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// `flagbyte m; bit m { u8 mode }; bit m { when mode == 1 { u8 speed } }; bit m { u16 heading }`:
/// the condition is a plain optional field under a bit; nothing may write it before the byte.
fn optional_source() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            m.bit(u8("mode")),
            m.bit(when(2, eq("mode", Value::U8(1)), vec![u8("speed")])),
            m.bit(u16("heading")),
        ],
    )
}

#[test]
fn review_a2_a_source_never_written_and_absent_packs_the_body_away_silently() {
    // Arrange: mode has no value, so the when cannot match; before the fix this was a type error
    let vals = row(&[("speed", Value::U8(7)), ("heading", Value::U16(90))]);

    // Act
    let wire = hex(&optional_source(), &vals);

    // Assert
    assert_eq!(wire, "01045a00");
}

#[test]
fn review_a2_a_source_given_after_the_byte_that_matches_still_names_the_body() {
    // Arrange: mode=1 is written after the byte, so the body would be written with its bit clear
    let vals = row(&[("mode", Value::U8(1)), ("speed", Value::U8(7))]);

    // Act
    let message = refusal(&optional_source(), &vals);

    // Assert
    assert!(
        message.contains("'speed'") && message.contains("'mode'"),
        "{message}"
    );
}

#[test]
fn review_a2_a_source_given_after_the_byte_outside_the_expected_value_packs_silently() {
    // Arrange: a hostile value (255) that is not the expected 1
    let vals = row(&[("mode", Value::U8(255)), ("speed", Value::U8(7))]);

    // Act
    let wire = hex(&optional_source(), &vals);

    // Assert
    assert_eq!(wire, "0101ff");
}

#[test]
fn review_a6_a_count_written_before_the_byte_as_zero_packs_a_lone_value_away() {
    // Arrange: `u8 C; flagbyte m; bit m { times C { u8 Pt } }; bit m { u16 Heading }`, C = 0
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("C"),
            m.byte(),
            m.bit(times(2, "C", vec![u8("Pt")])),
            m.bit(u16("Heading")),
        ],
    );
    let vals = row(&[
        ("C", Value::U8(0)),
        ("Pt", Value::U8(5)),
        ("Heading", Value::U16(90)),
    ]);

    // Act
    let wire = hex(&scheme, &vals);

    // Assert
    assert_eq!(wire, "0100025a00");
}

#[test]
fn review_a3_a_combined_flags_inside_a_split_bit_with_the_when_true_names_the_body() {
    // Arrange: `flagbyte m; u8 Mode; bit m { flags f { when Mode == 1 { u8 Speed } } }; bit m { u16 Heading }`
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("Mode"),
            m.bit(flags(
                2,
                "f",
                vec![when(2, eq("Mode", Value::U8(1)), vec![u8("Speed")])],
            )),
            m.bit(u16("Heading")),
        ],
    );
    let vals = row(&[("Mode", Value::U8(1)), ("Speed", Value::U8(7))]);

    // Act
    let message = refusal(&scheme, &vals);

    // Assert
    assert!(
        message.contains("'Speed'") && message.contains("'Mode'"),
        "{message}"
    );
}
