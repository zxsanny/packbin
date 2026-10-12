use crate::walk::pack;
use crate::{flag_byte, flags, insert, repeat, to_hex, u8, MapScheme, PackError, Value, Values};

// AZ-2412 (owner decision U13 of loop 22): a `repeat` takes its rounds only as `__repeat__`
// groups. A row that gives a value under a name of its body with no groups is refused naming
// the member, not packed as the bare scheme byte with the value dropped. A row with groups, or
// with nothing given for the members, packs as at HEAD.

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn items(bytes: &[u8]) -> Value {
    Value::List(bytes.iter().map(|b| Value::U8(*b)).collect())
}

fn rounds(pairs: &[&[(&str, Value)]]) -> Value {
    Value::Groups(pairs.iter().map(|round| row(round)).collect())
}

fn two_rounds() -> Value {
    rounds(&[
        &[("n", Value::U8(1)), ("x", Value::U8(5))],
        &[("n", Value::U8(2)), ("x", Value::U8(6))],
    ])
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

/// `repeat { u8 n, u8 x }`
fn plain() -> MapScheme {
    MapScheme::new(1, vec![repeat(0, vec![u8("n"), u8("x")])])
}

fn refused(member: &str) -> String {
    refused_at(0, member)
}

fn refused_at(id: u32, member: &str) -> String {
    format!(
        "repeat at id {id}: '{member}' is given without '__repeat__' groups; give the rounds of a \
         repeat as '__repeat__' groups, one per round"
    )
}

#[test]
fn ac1_two_per_name_lists_without_groups_are_refused_naming_the_first_member() {
    // Arrange
    let vals = row(&[("n", items(&[1, 2])), ("x", items(&[5, 6]))]);

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert_eq!(message, refused("n"));
}

#[test]
fn ac1_one_list_without_groups_is_refused_naming_that_member() {
    // Arrange
    let vals = row(&[("x", items(&[5, 6]))]);

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert_eq!(message, refused("x"));
}

#[test]
fn ac1_a_lone_value_without_groups_is_refused() {
    // Arrange
    let vals = row(&[("n", Value::U8(1))]);

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert_eq!(message, refused("n"));
}

#[test]
fn ac1_empty_groups_with_a_list_is_refused() {
    // Arrange
    let mut vals = row(&[("n", items(&[1, 2]))]);
    insert(&mut vals, "__repeat__", Some(Value::Groups(Vec::new())));

    // Act
    let message = refusal(&plain(), &vals);

    // Assert
    assert_eq!(message, refused("n"));
}

#[test]
fn ac1_lists_for_a_repeat_under_a_clear_flags_bit_are_refused() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![repeat(0, vec![u8("n")]), u8("z")])],
    );
    let vals = row(&[("n", items(&[1, 2]))]);

    // Act
    let message = refusal(&scheme, &vals);

    // Assert
    assert_eq!(message, refused("n"));
}

#[test]
fn ac1_lists_for_a_repeat_under_a_clear_split_flag_bit_are_refused() {
    // Arrange
    let fb = flag_byte("fb");
    let scheme = MapScheme::new(1, vec![fb.byte(), fb.bit(repeat(1, vec![u8("n")]))]);
    let vals = row(&[("n", items(&[1, 2]))]);

    // Act
    let message = refusal(&scheme, &vals);

    // Assert
    assert_eq!(message, refused_at(1, "n"));
}

#[test]
fn ac2_groups_pack_as_at_head() {
    // Arrange
    let vals = row(&[("__repeat__", two_rounds())]);

    // Act
    let bytes = hex(&plain(), &vals);

    // Assert
    assert_eq!(bytes, "0101050206");
}

#[test]
fn ac2_groups_beside_the_same_lists_pack_the_groups() {
    // Arrange
    let mut vals = row(&[("__repeat__", two_rounds())]);
    insert(&mut vals, "n", Some(items(&[1, 2])));

    // Act
    let bytes = hex(&plain(), &vals);

    // Assert
    assert_eq!(bytes, "0101050206");
}

#[test]
fn ac2_nothing_given_for_the_members_packs_no_rounds() {
    // Act
    let bytes = hex(&plain(), &Values::new());

    // Assert
    assert_eq!(bytes, "01");
}

#[test]
fn ac2_empty_lists_and_empty_groups_pack_no_rounds() {
    // Arrange
    let mut vals = row(&[("n", items(&[])), ("x", items(&[]))]);
    insert(&mut vals, "__repeat__", Some(Value::Groups(Vec::new())));

    // Act
    let bytes = hex(&plain(), &vals);

    // Assert
    assert_eq!(bytes, "01");
}

#[test]
fn ac2_flags_and_split_bits_with_groups_or_nothing_pack_as_at_head() {
    // Arrange
    let combined = MapScheme::new(
        1,
        vec![flags(0, "f", vec![repeat(0, vec![u8("n")]), u8("z")])],
    );
    let fb = flag_byte("fb");
    let split = MapScheme::new(1, vec![fb.byte(), fb.bit(repeat(1, vec![u8("n")]))]);
    let groups = row(&[(
        "__repeat__",
        rounds(&[&[("n", Value::U8(1))], &[("n", Value::U8(2))]]),
    )]);

    // Act
    let bytes = [
        hex(&combined, &groups),
        hex(&combined, &Values::new()),
        hex(&split, &groups),
        hex(&split, &Values::new()),
    ];

    // Assert
    assert_eq!(bytes, ["01010102", "0100", "01010102", "0100"]);
}
