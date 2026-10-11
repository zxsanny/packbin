use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, group, insert, times, to_hex, u8, when, BinaryPacker, MapScheme,
    PackError, Scheme, SchemeItem, Value, Values,
};

// Loop 20 parity: AZ-2356 (split count 0 after the byte), AZ-2360 (combined `flags` with a skipped
// count and values given) and AZ-2359 (what a u8 slot takes).

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|n| Value::U8(*n)).collect())
}

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
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

const SKIPPED: &str = "a value is given, but the count of its times is not written, so its bit is clear; write the count before the times";

/// AZ-2356: `flagbyte fb; u8 n; bit fb { times n { u8 pt } }`, the count follows the byte.
fn count_after_the_byte() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![fb.byte(), u8("n"), fb.bit(times(2, "n", vec![u8("pt")]))],
    )
}

/// AZ-2360: `flags { u8 n; times n { u8 pt } }`, the count is the flags' own first member.
fn combined_count() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(0, "f", vec![u8("n"), times(1, "n", vec![u8("pt")])])],
    )
}

#[test]
fn az2356_ac1_count_zero_after_the_byte_with_a_list_is_refused_naming_the_member() {
    // Arrange
    let vals = row(&[("n", Value::U8(0)), ("pt", ints(&[5, 6]))]);

    // Act
    let message = refusal(&count_after_the_byte(), &vals);

    // Assert
    assert!(message.contains("'pt'"), "{message}");
}

#[test]
fn az2356_ac2_count_zero_after_the_byte_with_a_lone_scalar_packs_zero_rounds() {
    // Arrange
    let vals = row(&[("n", Value::U8(0)), ("pt", Value::U8(5))]);

    // Act
    let wire = hex(&count_after_the_byte(), &vals);

    // Assert
    assert_eq!(wire, "010000");
}

#[test]
fn az2360_ac1_a_skipped_count_with_values_is_refused_naming_the_member() {
    // Arrange
    let listed = row(&[("pt", ints(&[5, 6]))]);
    let lone = row(&[("pt", Value::U8(5))]);

    // Act
    let by_list = refusal(&combined_count(), &listed);
    let by_scalar = refusal(&combined_count(), &lone);

    // Assert
    assert_eq!(by_list, format!("pt: {SKIPPED}"));
    assert_eq!(by_scalar, format!("pt: {SKIPPED}"));
}

#[test]
fn az2360_ac1_rounds_given_for_a_skipped_count_are_refused_naming_the_first_member() {
    // Arrange
    let mut round = Values::new();
    insert(&mut round, "pt", Some(Value::U8(5)));
    let vals = row(&[("__times_1", Value::Groups(vec![round]))]);

    // Act
    let message = refusal(&combined_count(), &vals);

    // Assert
    assert_eq!(message, format!("pt: {SKIPPED}"));
}

#[test]
fn az2360_ac1_a_times_under_a_taken_when_inside_flags_is_refused_a_false_when_stays_silent() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![
                    u8("n"),
                    when(
                        2,
                        eq("mode", Value::U8(1)),
                        vec![times(2, "n", vec![u8("pt")])],
                    ),
                ],
            ),
        ],
    );

    // Act
    let taken = refusal(&scheme, &row(&[("mode", Value::U8(1)), ("pt", ints(&[5]))]));
    let false_when = hex(&scheme, &row(&[("mode", Value::U8(0)), ("pt", ints(&[5]))]));

    // Assert
    assert_eq!(taken, format!("pt: {SKIPPED}"));
    assert_eq!(false_when, "010000");
}

#[test]
fn az2360_ac2_no_values_or_an_empty_list_packs_the_bit_clear_and_a_written_count_is_unchanged() {
    // Arrange
    let scheme = combined_count();

    // Act
    let none = hex(&scheme, &Values::new());
    let empty = hex(&scheme, &row(&[("pt", ints(&[]))]));
    let counted = hex(&scheme, &row(&[("n", Value::U8(2)), ("pt", ints(&[5, 6]))]));

    // Assert
    assert_eq!([none, empty, counted], ["0100", "0100", "0103020506"]);
}

#[test]
fn az2360_ac1_a_times_in_a_group_under_flags_is_refused_too() {
    // Arrange: the count `n` sits behind a `when` that is false, so it is skipped
    let scheme = MapScheme::new(
        1,
        vec![
            u8("m"),
            when(1, eq("m", Value::U8(9)), vec![u8("n")]),
            flags(
                2,
                "f",
                vec![group(2, "g", vec![times(2, "n", vec![u8("pt")])])],
            ),
        ],
    );
    let vals = row(&[("m", Value::U8(0)), ("pt", ints(&[5]))]);

    // Act
    let message = refusal(&scheme, &vals);

    // Assert
    assert_eq!(message, format!("pt: {SKIPPED}"));
}

/// AZ-2359: Rust enums are not numbers. The typed API takes the integer a caller converts to
/// (`Level::High as u8`); a value of another kind in a `u8` slot is a type error.
#[test]
fn az2359_ac1_a_u8_slot_takes_only_an_integer_value() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("level")]);

    // Act
    let numeric = hex(&scheme, &row(&[("level", Value::U8(200))]));
    let text = pack(&scheme, &row(&[("level", Value::Str("High".to_string()))]));
    let wide = pack(&scheme, &row(&[("level", Value::U16(200))]));

    // Assert
    assert_eq!(numeric, "01c8");
    assert_eq!(text, Err(PackError::Type("int".to_string())));
    assert_eq!(wide, Err(PackError::Type("int".to_string())));
}

#[test]
fn az2359_ac1_the_typed_scheme_packs_the_converted_integer() {
    // Arrange
    #[derive(Default, Clone, Copy)]
    enum Level {
        #[default]
        Low = 1,
        High = 200,
    }
    #[derive(Default)]
    struct Row {
        level: u8,
    }
    let scheme: Scheme<Row> = Scheme::new(
        1,
        vec![SchemeItem::from(crate::BoundField::u8(
            0,
            |r: &Row| r.level,
            |r: &mut Row, v| r.level = v,
        ))],
    );

    // Act
    let low = BinaryPacker::pack(
        &scheme,
        &Row {
            level: Level::Low as u8,
        },
    );
    let high = BinaryPacker::pack(
        &scheme,
        &Row {
            level: Level::High as u8,
        },
    );

    // Assert
    assert_eq!(low.map(|b| to_hex(&b)), Ok("0101".to_string()));
    assert_eq!(high.map(|b| to_hex(&b)), Ok("01c8".to_string()));
    assert_eq!(
        unpack(&MapScheme::new(1, vec![u8("level")]), &[1, 200]).map(|v| v.len()),
        Ok(1)
    );
}
