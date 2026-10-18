use crate::walk::{pack, unpack};
use crate::{
    bytes, flag_byte, insert, sized, times, to_hex, u8, utf8, MapScheme, PackError, Value, Values,
};

// AZ-2332: a lone byte buffer for a `bytes` or `sized` name of a `times` round is refused naming
// the name, not sent to every round; a list with one buffer per round packs as before. A lone
// `utf8` string still goes to every round.

fn buf(items: &[u8]) -> Value {
    Value::Bytes(items.to_vec())
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

/// `u8 n; times n { bytes(2) d }`
fn bytes_rounds() -> MapScheme {
    MapScheme::new(1, vec![u8("n"), times(1, "n", vec![bytes("d", 2)])])
}

/// `u8 n; times n { u8 l; sized d(l) }`
fn sized_rounds() -> MapScheme {
    MapScheme::new(
        1,
        vec![u8("n"), times(1, "n", vec![u8("l"), sized("d", "l")])],
    )
}

/// `u8 n; times n { flagbyte m; bit m { bytes(2) d } }`
fn flag_bit_rounds() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![u8("n"), times(1, "n", vec![m.byte(), m.bit(bytes("d", 2))])],
    )
}

#[test]
fn ac1_a_lone_buffer_for_a_bytes_name_is_refused_naming_it() {
    // Arrange
    let vals = row(&[("n", Value::U8(2)), ("d", buf(&[1, 2]))]);

    // Act
    let message = refusal(&bytes_rounds(), &vals);

    // Assert
    assert!(message.contains("'d'"), "{message}");
}

#[test]
fn ac1_a_lone_buffer_with_one_round_is_refused_too() {
    // Arrange
    let vals = row(&[("n", Value::U8(1)), ("d", buf(&[1, 2]))]);

    // Act
    let message = refusal(&bytes_rounds(), &vals);

    // Assert
    assert!(message.contains("'d'"), "{message}");
}

#[test]
fn ac1_a_lone_buffer_of_the_wrong_size_is_refused_naming_it() {
    // Arrange: a hostile buffer that no round could hold
    let vals = row(&[("n", Value::U8(2)), ("d", buf(&[1, 2, 3, 4, 5]))]);

    // Act
    let message = refusal(&bytes_rounds(), &vals);

    // Assert
    assert!(message.contains("'d'"), "{message}");
}

#[test]
fn ac1_a_lone_buffer_for_a_sized_name_is_refused_naming_it() {
    // Arrange
    let vals = row(&[
        ("n", Value::U8(2)),
        ("l", Value::U8(2)),
        ("d", buf(&[1, 2])),
    ]);

    // Act
    let message = refusal(&sized_rounds(), &vals);

    // Assert
    assert!(message.contains("'d'"), "{message}");
}

#[test]
fn ac1_a_lone_buffer_for_a_bytes_name_under_a_flag_bit_is_refused() {
    // Arrange
    let vals = row(&[("n", Value::U8(2)), ("d", buf(&[1, 2]))]);

    // Act
    let message = refusal(&flag_bit_rounds(), &vals);

    // Assert
    assert!(message.contains("'d'"), "{message}");
}

#[test]
fn ac2_a_list_with_one_buffer_per_round_packs_as_before() {
    // Arrange
    let per_round = Value::List(vec![buf(&[1, 2]), buf(&[3, 4])]);
    let vals = row(&[("n", Value::U8(2)), ("d", per_round.clone())]);
    let sized_vals = row(&[
        ("n", Value::U8(2)),
        ("l", Value::U8(2)),
        ("d", per_round.clone()),
    ]);

    // Act
    let plain = hex(&bytes_rounds(), &vals);
    let counted = hex(&sized_rounds(), &sized_vals);
    let flagged = hex(&flag_bit_rounds(), &vals);
    let back = unpack(&bytes_rounds(), &[1, 2, 1, 2, 3, 4]).expect("unpack");

    // Assert
    assert_eq!(plain, "010201020304");
    assert_eq!(counted, "0102020102020304");
    assert_eq!(flagged, "0102010102010304");
    assert_eq!(back.get("d"), Some(&Some(per_round)));
}

#[test]
fn ac2_a_lone_string_for_a_utf8_name_still_goes_to_every_round() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("n"), times(1, "n", vec![utf8("s")])]);
    let vals = row(&[("n", Value::U8(2)), ("s", Value::Str("a".to_string()))]);

    // Act
    let wire = hex(&scheme, &vals);

    // Assert
    assert_eq!(wire, "0102021061021061");
}
