use crate::walk::{pack, unpack};
use crate::{bytes, dict, insert, times, to_hex, u8, utf8, MapScheme, PackError, Value, Values};
use std::collections::BTreeMap;

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

fn hex(scheme: &MapScheme, row: &Values) -> Result<String, PackError> {
    pack(scheme, row).map(|raw| to_hex(&raw))
}

/// `u8 "0"; times(1, "0", [u8 "1", u8 "2"])`
fn two_members() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1"), u8("2")])])
}

// AZ-2311 AC-2: the bytes are those of the TypeScript package for `{n: 2, x: 1, y: [4, 5]}`.

#[test]
fn az2311_ac2_a_lone_scalar_beside_a_list_is_in_every_round() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::U8(1)),
        ("2", ints(&[4, 5])),
    ]);

    // Act
    let wire = hex(&two_members(), &row);

    // Assert
    assert_eq!(wire, Ok("010201040105".to_string()));
}

#[test]
fn az2311_ac2_a_lone_scalar_is_in_all_three_rounds() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(3)),
        ("1", Value::U8(1)),
        ("2", ints(&[4, 5, 6])),
    ]);

    // Act
    let wire = hex(&two_members(), &row);

    // Assert
    assert_eq!(wire, Ok("0103010401050106".to_string()));
}

#[test]
fn az2311_ac2_two_lone_scalars_are_in_every_round() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::U8(1)),
        ("2", Value::U8(4)),
    ]);

    // Act
    let wire = hex(&two_members(), &row);

    // Assert
    assert_eq!(wire, Ok("010201040104".to_string()));
}

#[test]
fn az2311_ac2_a_lone_scalar_repacks_from_its_own_unpack() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::U8(1)),
        ("2", ints(&[4, 5])),
    ]);
    let raw = pack(&two_members(), &row).expect("pack");

    // Act
    let again = pack(
        &two_members(),
        &unpack(&two_members(), &raw).expect("unpack"),
    );

    // Assert
    assert_eq!(again, Ok(raw));
}

#[test]
fn az2311_ac2_a_lone_utf8_and_a_lone_byte_string_are_in_every_round() {
    // Arrange
    let text = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![utf8("1"), u8("2")])]);
    let raw = MapScheme::new(
        1,
        vec![u8("0"), times(1, "0", vec![bytes("1", 2), u8("2")])],
    );
    let text_row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::Str("a".to_string())),
        ("2", ints(&[4, 5])),
    ]);
    let raw_row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::Bytes(vec![1, 2])),
        ("2", ints(&[4, 5])),
    ]);

    // Act
    let (text_wire, raw_wire) = (hex(&text, &text_row), hex(&raw, &raw_row));

    // Assert
    assert_eq!(text_wire, Ok("01020100610401006105".to_string()));
    assert_eq!(raw_wire, Ok("0102010204010205".to_string()));
}

// AZ-2311 AC-3

#[test]
fn az2311_ac3_one_round_and_per_round_lists_keep_their_bytes() {
    // Arrange
    let one_round = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(1)),
        ("2", Value::U8(4)),
    ]);
    let lists = values(&[
        ("0", Value::U8(2)),
        ("1", ints(&[1, 2])),
        ("2", ints(&[4, 5])),
    ]);

    // Act
    let (single, per_round) = (hex(&two_members(), &one_round), hex(&two_members(), &lists));

    // Assert
    assert_eq!(single, Ok("01010104".to_string()));
    assert_eq!(per_round, Ok("010201040205".to_string()));
}

#[test]
fn az2311_ac3_a_list_shorter_than_the_count_is_still_missing() {
    // Arrange
    let row = values(&[("0", Value::U8(2)), ("1", ints(&[1])), ("2", ints(&[4, 5]))]);

    // Act
    let result = hex(&two_members(), &row);

    // Assert
    assert_eq!(result, Err(PackError::Missing("1".to_string())));
}

// AZ-2308

/// `u8 "0"; times(1, "0", [dict "m" of utf8 "v", u8 "1"])`
fn with_dict() -> MapScheme {
    MapScheme::new(
        1,
        vec![u8("0"), times(1, "0", vec![dict("m", utf8("v")), u8("1")])],
    )
}

fn table(key: &str, text: &str) -> Value {
    Value::Map(BTreeMap::from([(
        key.to_string(),
        Value::Str(text.to_string()),
    )]))
}

fn lone_dictionary() -> PackError {
    PackError::Type(
        "times at id 1: 'm' is one dictionary; give a list with one dictionary per round"
            .to_string(),
    )
}

#[test]
fn az2308_ac2_a_lone_dictionary_in_a_times_round_is_refused_naming_the_member() {
    for count in [1u8, 2] {
        // Arrange
        let row = values(&[
            ("0", Value::U8(count)),
            ("m", table("k", "a")),
            ("1", ints(&[4, 5][..count as usize])),
        ]);

        // Act
        let result = hex(&with_dict(), &row);

        // Assert
        assert_eq!(result, Err(lone_dictionary()), "count {count}");
    }
}

#[test]
fn az2308_ac3_a_list_of_dictionaries_packs_one_per_round() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("m", Value::List(vec![table("k", "a"), table("k", "b")])),
        ("1", ints(&[4, 5])),
    ]);

    // Act
    let wire = hex(&with_dict(), &row);

    // Assert
    assert_eq!(
        wire,
        Ok(["0102", "0100", "01006b", "010061", "04", "0100", "01006b", "010062", "05"].concat())
    );
}

#[test]
fn az2311_ac2_a_lone_value_outside_the_member_range_is_a_type_error() {
    // Arrange
    let row = values(&[
        ("0", Value::U8(2)),
        ("1", Value::U64(300)),
        ("2", ints(&[4, 5])),
    ]);

    // Act
    let result = hex(&two_members(), &row);

    // Assert
    assert_eq!(result, Err(PackError::Type("int".to_string())));
}
