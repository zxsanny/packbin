use crate::walk::pack;
use crate::{flag_byte, flags, insert, times, to_hex, u8, MapScheme, PackError, Value, Values};

// AZ-2335: a `times` count of 0 with values given for its rounds is refused naming the member,
// outside `flags`, inside it and in the split form; count 0 with no values packs no round.

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

/// `u8 n; times n { u8 pt }`
fn plain() -> MapScheme {
    MapScheme::new(1, vec![u8("n"), times(1, "n", vec![u8("pt")])])
}

/// `u8 n; flags { times n { u8 pt }, u8 h }`
fn in_flags() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            flags(1, "f", vec![times(1, "n", vec![u8("pt")]), u8("h")]),
        ],
    )
}

/// `u8 n; flagbyte m; bit m { times n { u8 pt } }; bit m { u8 h }`
fn split() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("n"),
            m.byte(),
            m.bit(times(2, "n", vec![u8("pt")])),
            m.bit(u8("h")),
        ],
    )
}

#[test]
fn ac1_count_zero_with_a_list_of_one_value_is_refused_naming_the_member() {
    // Arrange
    let vals = row(&[("n", Value::U8(0)), ("pt", ints(&[5]))]);

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert!(message.contains("'pt'"), "{message}");
}

#[test]
fn ac1_count_zero_with_a_long_list_is_refused_naming_the_member() {
    // Arrange: a hostile list far past the count
    let vals = row(&[("n", Value::U8(0)), ("pt", ints(&[1, 2, 3, 4, 5, 6, 7, 8]))]);

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert!(
        message.contains("'pt'") && message.contains("8 items"),
        "{message}"
    );
}

#[test]
fn ac1_count_zero_with_rounds_given_is_refused() {
    // Arrange
    let mut round = Values::new();
    insert(&mut round, "pt", Some(Value::U8(5)));
    let mut vals = row(&[("n", Value::U8(0))]);
    insert(&mut vals, "__times_1", Some(Value::Groups(vec![round])));

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert!(message.contains("count 0"), "{message}");
}

#[test]
fn ac1_count_zero_with_a_list_inside_flags_and_in_the_split_form_is_refused() {
    // Arrange
    let combined = row(&[("n", Value::U8(0)), ("pt", ints(&[5])), ("h", Value::U8(9))]);

    // Act
    let inside = refusal(&in_flags(), &combined);
    let separate = refusal(&split(), &combined);

    // Assert
    assert!(inside.contains("'pt'"), "{inside}");
    assert!(separate.contains("'pt'"), "{separate}");
}

#[test]
fn ac2_count_zero_without_values_packs_no_round() {
    // Arrange
    let none = row(&[("n", Value::U8(0))]);
    let empty = row(&[("n", Value::U8(0)), ("pt", ints(&[]))]);
    let beside = row(&[("n", Value::U8(0)), ("h", Value::U8(9))]);

    // Act and assert
    assert_eq!(hex(&plain(), &none), "0100");
    assert_eq!(hex(&plain(), &empty), "0100");
    assert_eq!(hex(&in_flags(), &beside), "01000209");
    assert_eq!(hex(&split(), &beside), "01000209");
}
