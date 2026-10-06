use crate::walk::{pack, unpack};
use crate::{flag_byte, flags, insert, times, to_hex, u8, MapScheme, PackError, Value, Values};

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|n| Value::U8(*n)).collect())
}

fn longer(name: &str, items: usize, count: usize) -> Result<Vec<u8>, PackError> {
    Err(PackError::Type(format!(
        "times at id 1: '{name}' has {items} items, count is {count}"
    )))
}

fn longer_at(anchor: u32, name: &str, items: usize, count: usize) -> Result<Vec<u8>, PackError> {
    Err(PackError::Type(format!(
        "times at id {anchor}: '{name}' has {items} items, count is {count}"
    )))
}

fn hex(result: Result<Vec<u8>, PackError>) -> Result<String, PackError> {
    result.map(|raw| to_hex(&raw))
}

/// `u8 "0"; times(1, "0", [u8 "1"])`
fn one_member() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])
}

/// `u8 "0"; times(1, "0", [u8 "1", u8 "2"])`
fn two_members() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1"), u8("2")])])
}

/// `u8 "0"; times(1, "0", [flags(1, "f", [u8 "1"]), u8 "2"])`
fn flags_member() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![flags(1, "f", vec![u8("1")]), u8("2")]),
        ],
    )
}

// AC-6

#[test]
fn ac6_a_list_longer_than_the_count_is_refused() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", ints(&[1, 2, 3]))]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(result, longer("1", 3, 2));
}

#[test]
fn ac6_a_list_beside_a_count_of_zero_is_refused() {
    // Arrange
    let row = values(&[("0", Value::U8(0)), ("1", ints(&[1]))]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(result, longer("1", 1, 0));
}

#[test]
fn ac6_the_second_member_is_refused_by_name() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", ints(&[1, 2])),
        ("2", ints(&[3, 4, 5])),
    ]);

    // Act
    let result = pack(&two_members(), &row);

    // Assert
    assert_eq!(result, longer("2", 3, 2));
}

#[test]
fn ac6_a_direct_member_beside_a_flags_member_is_refused_by_name() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("2", ints(&[5, 6, 7]))]);

    // Act
    let result = pack(&flags_member(), &row);

    // Assert
    assert_eq!(result, longer("2", 3, 2));
}

#[test]
fn ac6_the_first_member_in_field_order_is_the_one_named() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", ints(&[1, 2])),
        ("2", ints(&[3, 4, 5])),
    ]);

    // Act
    let result = pack(&two_members(), &row);

    // Assert
    assert_eq!(result, longer("1", 2, 1));
}

// AC-7

#[test]
fn ac7_a_list_as_long_as_the_count_packs() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", ints(&[1, 2]))]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(hex(result), Ok("01020102".to_string()));
}

#[test]
fn ac7_a_list_shorter_than_the_count_is_still_missing() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", ints(&[1]))]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(result, Err(PackError::Missing("1".to_string())));
}

#[test]
fn ac7_an_empty_list_and_an_absent_list_beside_a_count_of_zero_pack() {
    // Arrange
    let empty = values(&[("0", Value::U8(0)), ("1", ints(&[]))]);
    let absent = values(&[("0", Value::U8(0))]);

    // Act
    let (with_empty, with_none) = (pack(&one_member(), &empty), pack(&one_member(), &absent));

    // Assert
    assert_eq!(hex(with_empty), Ok("0100".to_string()));
    assert_eq!(hex(with_none), Ok("0100".to_string()));
}

#[test]
fn ac7_a_lone_value_for_a_member_is_still_missing_after_round_zero() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", Value::U8(5))]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(result, Err(PackError::Missing("1".to_string())));
}

#[test]
fn ac7_a_longer_list_kept_beside_rounds_still_disagrees_with_them() {
    // Arrange
    let rounds = Value::Groups(vec![
        values(&[("1", Value::U8(1))]),
        values(&[("1", Value::U8(2))]),
    ]);
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", ints(&[1, 2, 3])),
        ("__times_1", rounds),
    ]);

    // Act
    let result = pack(&one_member(), &row);

    // Assert
    assert_eq!(
        result,
        Err(PackError::Type(
            "times at id 1: list for '1' disagrees with its rounds".to_string()
        ))
    );
}

#[test]
fn ac7_a_value_under_a_flags_member_is_still_refused_first() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", ints(&[9])), ("2", ints(&[5, 6]))]);

    // Act
    let result = pack(&flags_member(), &row);

    // Assert
    assert_eq!(
        result,
        Err(PackError::Type(
            "times at id 1: '1' is under a flags or when; give its values per round under \
             '__times_1'"
                .to_string()
        ))
    );
}

// A list that pack never reads is not a list it drops: the name of a flags member, of a flag byte
// or of a group is not data.

#[test]
fn a_list_under_the_name_of_a_flags_member_is_not_refused() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("2", ints(&[5, 6])),
        ("f", ints(&[1, 2, 3])),
    ]);

    // Act
    let result = pack(&flags_member(), &row);

    // Assert
    assert_eq!(hex(result), Ok("010200050006".to_string()));
}

/// `u8 "0"; m.byte(); times(2, "0", [n.byte(), n.bit(u8 "3"), u8 "4"])`
fn flag_byte_in_rounds() -> MapScheme {
    let (m, n) = (flag_byte("m"), flag_byte("n"));
    MapScheme::new(
        1,
        vec![
            u8("0"),
            m.byte(),
            times(2, "0", vec![n.byte(), n.bit(u8("3")), u8("4")]),
        ],
    )
}

#[test]
fn a_row_edited_down_to_a_smaller_count_keeps_the_flag_byte_list_unpack_gave() {
    // Arrange
    let scheme = flag_byte_in_rounds();
    let raw = [0x01, 0x03, 0x00, 0x01, 0x0a, 0x0b, 0x00, 0x0c, 0x00, 0x0d];
    let mut row = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(row.get("n"), Some(&Some(ints(&[1, 0, 0]))));
    insert(&mut row, "0", Some(Value::U8(2)));
    insert(&mut row, "3", Some(ints(&[0x0a])));
    insert(&mut row, "4", Some(ints(&[0x0b, 0x0c])));
    row.remove("__times_2");

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(hex(result), Ok("010200010a0b000c".to_string()));
}

#[test]
fn a_flag_bit_inner_longer_than_the_count_is_still_refused() {
    // Arrange
    let scheme = flag_byte_in_rounds();
    let row = values(&[("0", Value::U8(1)), ("3", ints(&[1, 2])), ("4", ints(&[3]))]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, longer_at(2, "3", 2, 1));
}
