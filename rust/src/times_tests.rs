use crate::walk::{pack, unpack};
use crate::{
    eq, f32, flags, i32, insert, list as list_field, times, to_hex, u16, u8, when, MapScheme,
    PackError, Value, Values,
};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn rp6_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![flags(1, "f", vec![u8("1")]), u8("2")]),
        ],
    )
}

#[test]
fn ac4_map_optional_member_repacks_the_same_bytes() {
    // Arrange
    let scheme = rp6_scheme();
    let raw = parse_hex("01020005010906");

    // Act
    let values = unpack(&scheme, &raw).expect("unpack");
    let again = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&again), "01020005010906");
}

#[test]
fn ac4_map_unpack_still_lists_each_name() {
    // Arrange
    let scheme = rp6_scheme();
    let raw = parse_hex("01020005010906");

    // Act
    let values = unpack(&scheme, &raw).expect("unpack");

    // Assert
    assert_eq!(
        values.get("1"),
        Some(&Some(Value::List(vec![Value::U8(9)])))
    );
    assert_eq!(
        values.get("2"),
        Some(&Some(Value::List(vec![Value::U8(5), Value::U8(6)])))
    );
}

#[test]
fn map_unpack_returns_each_round_under_the_anchor() {
    // Arrange
    let scheme = rp6_scheme();
    let raw = parse_hex("01020005010906");
    let mut first = Values::new();
    insert(&mut first, "f", Some(Value::U8(0)));
    insert(&mut first, "2", Some(Value::U8(5)));
    let mut second = Values::new();
    insert(&mut second, "f", Some(Value::U8(1)));
    insert(&mut second, "1", Some(Value::U8(9)));
    insert(&mut second, "2", Some(Value::U8(6)));

    // Act
    let values = unpack(&scheme, &raw).expect("unpack");

    // Assert
    assert_eq!(
        values.get("__times_1"),
        Some(&Some(Value::Groups(vec![first, second])))
    );
}

#[test]
fn map_rounds_with_a_different_count_fail_pack() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = unpack(&scheme, &parse_hex("01020005010906")).expect("unpack");
    insert(&mut values, "0", Some(Value::U8(3)));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(name)) if name.starts_with("times")),
        "{result:?}"
    );
}

#[test]
fn map_rounds_that_are_not_groups_fail_pack() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(1)));
    insert(&mut values, "__times_1", Some(Value::U8(0)));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(name)) if name == "__times_1"),
        "{result:?}"
    );
}

fn pairs_scheme() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1"), u8("2")])])
}

fn list(items: &[u8]) -> Option<Value> {
    Some(Value::List(items.iter().map(|b| Value::U8(*b)).collect()))
}

fn stale_list_error(name: &str) -> PackError {
    PackError::Type(format!(
        "times at id 1: list for '{name}' disagrees with its rounds"
    ))
}

#[test]
fn map_edited_list_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = pairs_scheme();
    let mut values = unpack(&scheme, &parse_hex("01020a140b15")).expect("unpack");
    insert(&mut values, "1", list(&[99, 98]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale_list_error("1")));
}

#[test]
fn map_edited_list_without_the_rounds_packs_the_edit() {
    // Arrange
    let scheme = pairs_scheme();
    let mut values = unpack(&scheme, &parse_hex("01020a140b15")).expect("unpack");
    values.remove("__times_1");
    insert(&mut values, "1", list(&[99, 98]));

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010263146215");
}

#[test]
fn map_unedited_values_repack_the_same_bytes() {
    // Arrange
    let scheme = pairs_scheme();
    let values = unpack(&scheme, &parse_hex("01020a140b15")).expect("unpack");

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01020a140b15");
}

#[test]
fn map_edited_list_under_flags_beside_the_rounds_fails_pack() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = unpack(&scheme, &parse_hex("01020005010906")).expect("unpack");
    insert(&mut values, "1", list(&[8]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale_list_error("1")));
}

#[test]
fn map_list_for_a_member_no_round_read_fails_pack() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = unpack(&scheme, &parse_hex("01010005")).expect("unpack");
    insert(&mut values, "1", list(&[3]));

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(stale_list_error("1")));
}

#[test]
fn map_unpacked_nan_repacks_the_same_bytes() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![f32("1")])]);
    let values = unpack(&scheme, &parse_hex("01010000c07f")).expect("unpack");

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01010000c07f");
}

#[test]
fn map_unpack_keeps_every_round() {
    // Arrange
    let scheme = pairs_scheme();

    // Act
    let values = unpack(&scheme, &parse_hex("01040a140b150c160d17")).expect("unpack");

    // Assert
    assert_eq!(values.get("1"), Some(&list(&[10, 11, 12, 13])));
    assert_eq!(values.get("2"), Some(&list(&[20, 21, 22, 23])));
    assert!(
        matches!(values.get("__times_1"), Some(Some(Value::Groups(rounds))) if rounds.len() == 4)
    );
}

#[test]
fn map_unpack_of_count_zero_returns_no_rounds() {
    // Arrange
    let scheme = pairs_scheme();

    // Act
    let values = unpack(&scheme, &parse_hex("0100")).expect("unpack");

    // Assert
    assert_eq!(values.get("__times_1"), Some(&Some(Value::Groups(vec![]))));
}

#[test]
fn map_lists_around_a_times_with_its_own_list_keep_their_items() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("n"),
            list_field("pre", u16("0")),
            times(
                1,
                "n",
                vec![flags(1, "f", vec![u8("1")]), list_field("el", u16("0"))],
            ),
            list_field("post", u16("0")),
        ],
    );
    let raw = parse_hex("01020100070000010001000109000001000900");

    // Act
    let values = unpack(&scheme, &raw).expect("unpack");
    let again = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(
        values.get("pre"),
        Some(&Some(Value::List(vec![Value::U16(7)])))
    );
    assert_eq!(
        values.get("post"),
        Some(&Some(Value::List(vec![Value::U16(9)])))
    );
    assert_eq!(to_hex(&again), to_hex(&raw));
}

fn kept_value(values: &mut Values, name: &str, items: &[u8]) {
    insert(values, name, list(items));
}

fn unaligned_error(anchor: u32, name: &str) -> PackError {
    PackError::Type(format!(
        "times at id {anchor}: '{name}' is under a flags or when; give its values per round under \
         '__times_{anchor}'"
    ))
}

#[test]
fn ac1_map_per_name_list_for_a_member_under_flags_is_refused() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(2)));
    kept_value(&mut values, "1", &[9]);
    kept_value(&mut values, "2", &[5, 6]);

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(unaligned_error(1, "1")));
}

#[test]
fn ac1_map_single_value_for_a_member_under_flags_is_refused_like_a_list_of_one() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(1)));
    insert(&mut values, "1", Some(Value::U8(9)));
    kept_value(&mut values, "2", &[5]);

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(unaligned_error(1, "1")));
}

fn when_member_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            u8("1"),
            times(
                2,
                "0",
                vec![u8("2"), when(3, eq("2", Value::U8(1)), vec![u8("3")])],
            ),
        ],
    )
}

#[test]
fn ac2_map_per_name_list_for_a_member_under_when_is_refused() {
    // Arrange
    let scheme = when_member_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(2)));
    insert(&mut values, "1", Some(Value::U8(0)));
    kept_value(&mut values, "2", &[1, 2]);
    kept_value(&mut values, "3", &[7]);

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(unaligned_error(2, "3")));
}

#[test]
fn ac2_map_per_name_list_for_a_member_under_when_that_matches_no_round_is_refused() {
    // Arrange
    let scheme = when_member_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(2)));
    insert(&mut values, "1", Some(Value::U8(0)));
    kept_value(&mut values, "2", &[0, 0]);
    kept_value(&mut values, "3", &[7]);

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(unaligned_error(2, "3")));
}

#[test]
fn ac3_map_rounds_and_an_unpacked_row_still_pack() {
    // Arrange
    let scheme = rp6_scheme();
    let mut first = Values::new();
    insert(&mut first, "2", Some(Value::U8(5)));
    let mut second = Values::new();
    insert(&mut second, "1", Some(Value::U8(9)));
    insert(&mut second, "2", Some(Value::U8(6)));
    let mut by_hand = Values::new();
    insert(&mut by_hand, "0", Some(Value::U8(2)));
    insert(
        &mut by_hand,
        "__times_1",
        Some(Value::Groups(vec![first, second])),
    );
    let unpacked = unpack(&scheme, &parse_hex("01020005010906")).expect("unpack");

    // Act
    let from_rounds = pack(&scheme, &by_hand).expect("pack rounds");
    let from_unpack = pack(&scheme, &unpacked).expect("pack unpacked");

    // Assert
    assert_eq!(to_hex(&from_rounds), "01020005010906");
    assert_eq!(to_hex(&from_unpack), "01020005010906");
}

#[test]
fn ac4_map_direct_members_pack_per_name_lists() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![i32("1"), i32("2")])]);
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(2)));
    insert(
        &mut values,
        "1",
        Some(Value::List(vec![Value::I32(10), Value::I32(30)])),
    );
    insert(
        &mut values,
        "2",
        Some(Value::List(vec![Value::I32(20), Value::I32(40)])),
    );

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01020a000000140000001e00000028000000");
}

#[test]
fn ac4_map_absent_member_under_flags_packs_without_it() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(2)));
    kept_value(&mut values, "2", &[5, 6]);

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010200050006");
}

#[test]
fn ac4_map_empty_list_for_a_member_under_flags_packs_without_it() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(0)));
    kept_value(&mut values, "1", &[]);

    // Act
    let raw = pack(&scheme, &values).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "0100");
}

#[test]
fn ac1_map_non_empty_list_at_count_zero_for_a_member_under_flags_is_refused() {
    // Arrange
    let scheme = rp6_scheme();
    let mut values = Values::new();
    insert(&mut values, "0", Some(Value::U8(0)));
    kept_value(&mut values, "1", &[9]);

    // Act
    let result = pack(&scheme, &values);

    // Assert
    assert_eq!(result, Err(unaligned_error(1, "1")));
}
