use crate::walk::{pack, unpack};
use crate::{
    eq, f32, f64, flag_byte, group, insert, list as list_field, times, to_hex, u2, u8, when,
    MapScheme, PackError, Value, Values,
};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn bytes(items: &[u8]) -> Option<Value> {
    Some(Value::List(items.iter().map(|b| Value::U8(*b)).collect()))
}

fn stale(name: &str) -> PackError {
    PackError::Type(format!(
        "times at id 1: list for '{name}' disagrees with its rounds"
    ))
}

fn unpacked(scheme: &MapScheme, hex: &str) -> Values {
    unpack(scheme, &parse_hex(hex)).expect("unpack")
}

fn one_u8() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])
}

fn two_u8() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1"), u8("2")])])
}

fn under_when() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![u8("1"), when(2, eq("1", Value::U8(1)), vec![u8("2")])],
            ),
        ],
    )
}

fn under_u2() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u2(&["1", "2"])])])
}

fn under_flag_bit() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![m.byte(), m.bit(group(2, "g", vec![u8("2")]))]),
        ],
    )
}

fn f64_member() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![f64("1")])])
}

fn f32_list_member() -> MapScheme {
    MapScheme::new(
        1,
        vec![u8("n"), times(1, "n", vec![list_field("l", f32("0"))])],
    )
}

const WHEN_HEX: &str = "0102010502";
const U2_HEX: &str = "01020609";
const FLAG_BIT_HEX: &str = "0102010500";
const F64_NAN_HEX: &str = "0101000000000000f87f";
const F32_LIST_HEX: &str = "010102000000c07f0000803f";

#[test]
fn scalar_beside_the_rounds_that_differs_fails_pack() {
    // Arrange
    let scheme = one_u8();
    let mut values = unpacked(&scheme, "010107");
    insert(&mut values, "1", Some(Value::U8(99)));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("1")));
}

#[test]
fn scalar_beside_the_rounds_that_equals_the_round_packs() {
    // Arrange
    let scheme = one_u8();
    let mut values = unpacked(&scheme, "010107");
    insert(&mut values, "1", Some(Value::U8(7)));

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010107");
}

#[test]
fn list_edited_at_its_second_item_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = two_u8();
    let mut values = unpacked(&scheme, "01020a140b15");
    insert(&mut values, "1", bytes(&[10, 98]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("1")));
}

#[test]
fn list_under_a_when_edited_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = under_when();
    let mut values = unpacked(&scheme, WHEN_HEX);
    insert(&mut values, "2", bytes(&[6]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("2")));
}

#[test]
fn list_of_the_second_u2_name_edited_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = under_u2();
    let mut values = unpacked(&scheme, U2_HEX);
    insert(&mut values, "2", bytes(&[1, 3]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("2")));
}

#[test]
fn list_inside_a_group_under_a_flag_bit_edited_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = under_flag_bit();
    let mut values = unpacked(&scheme, FLAG_BIT_HEX);
    insert(&mut values, "2", bytes(&[6]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("2")));
}

#[test]
fn list_member_edited_at_its_second_item_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = f32_list_member();
    let mut values = unpacked(&scheme, F32_LIST_HEX);
    let edited = Value::List(vec![Value::F32(f32::NAN), Value::F32(2.0)]);
    insert(&mut values, "l", Some(Value::List(vec![edited])));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale("l")));
}

#[test]
fn unedited_values_under_when_u2_and_a_flag_bit_repack_the_same_bytes() {
    // Arrange
    let cases = [
        (under_when(), WHEN_HEX),
        (under_u2(), U2_HEX),
        (under_flag_bit(), FLAG_BIT_HEX),
    ];

    for (scheme, hex) in cases {
        // Act
        let values = unpacked(&scheme, hex);
        let raw = pack(&scheme, &values).expect("pack");

        // Assert
        assert_eq!(to_hex(&raw), hex);
    }
}

#[test]
fn unedited_f64_nan_repacks_the_same_bytes() {
    // Arrange
    let scheme = f64_member();
    let values = unpacked(&scheme, F64_NAN_HEX);

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), F64_NAN_HEX);
}

#[test]
fn unedited_list_member_holding_nan_repacks_the_same_bytes() {
    // Arrange
    let scheme = f32_list_member();
    let values = unpacked(&scheme, F32_LIST_HEX);

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), F32_LIST_HEX);
}
