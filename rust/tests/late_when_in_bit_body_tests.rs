use packbin::{
    eq, flag_byte, group, insert, pack, times, to_hex, u8, when, Field, MapScheme, PackError,
    Value, Values,
};

// AZ-2385 (U5) in Rust: a split flag bit whose body holds a `when` or `times` that waits for a source
// written after the flag byte is set by another member of the bit, and the late member is written
// where the walk reaches it (bytes as TypeScript and C++). A bit held only by late members stays
// refused, naming the value (`_docs/03_implementation/reference_loop21_slots.md`,
// `fixtures/hostile/README.md` section pack_late_when_in_bit_body).

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn refusal(scheme: &MapScheme, vals: &Values) -> String {
    match pack(scheme, vals) {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

/// `flagByte m; u8 mode; bit { group { u8 d; when mode == 1 { u8 a }; when mode == 2 { u8 b } } }`
fn late_whens() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("mode"),
            m.bit(group(
                2,
                "g",
                vec![
                    u8("d"),
                    when(3, eq("mode", n(1)), vec![u8("a")]),
                    when(4, eq("mode", n(2)), vec![u8("b")]),
                ],
            )),
        ],
    )
}

/// The same, with the late `when` inside a nested group.
fn nested_late_when() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("mode"),
            m.bit(group(
                2,
                "g",
                vec![
                    u8("d"),
                    group(3, "h", vec![when(3, eq("mode", n(1)), vec![u8("a")])]),
                ],
            )),
        ],
    )
}

/// `flagByte m; u8 n; bit { group { <members> } }` with a `times` over `n`.
fn late_times(members: impl FnOnce() -> Vec<Field>) -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![m.byte(), u8("n"), m.bit(group(2, "g", members()))],
    )
}

fn x_then_times() -> Vec<Field> {
    vec![u8("x"), times(3, "n", vec![u8("pt")])]
}

fn times_then_x() -> Vec<Field> {
    vec![times(2, "n", vec![u8("pt")]), u8("x")]
}

fn rounds(pt: &[u8]) -> Value {
    Value::List(pt.iter().map(|b| n(*b)).collect())
}

#[test]
fn ac1_the_readme_row_packs_with_the_other_member_setting_the_bit() {
    // Arrange
    let vals = row(&[("mode", n(1)), ("d", n(5)), ("a", n(9))]);

    // Act
    let wire = hex_of(&late_whens(), &vals);

    // Assert
    assert_eq!(wire, Ok("0101010509".to_string()));
}

#[test]
fn ac1_the_second_late_when_packs_and_a_quiet_row_packs_without_either() {
    // Arrange
    let second = row(&[("mode", n(2)), ("d", n(5)), ("b", n(9))]);
    let quiet = row(&[("mode", n(3)), ("d", n(5))]);

    // Act
    let by_second = hex_of(&late_whens(), &second);
    let by_quiet = hex_of(&late_whens(), &quiet);

    // Assert
    assert_eq!(by_second, Ok("0101020509".to_string()));
    assert_eq!(by_quiet, Ok("01010305".to_string()));
}

#[test]
fn ac1_a_late_when_in_a_nested_group_packs_with_the_other_member() {
    // Arrange
    let vals = row(&[("mode", n(1)), ("d", n(5)), ("a", n(9))]);

    // Act
    let wire = hex_of(&nested_late_when(), &vals);

    // Assert
    assert_eq!(wire, Ok("0101010509".to_string()));
}

#[test]
fn ac1_a_late_times_packs_with_the_other_member_before_or_after_it() {
    // Arrange
    let vals = row(&[("n", n(2)), ("x", n(5)), ("pt", rounds(&[7, 8]))]);

    // Act
    let after = hex_of(&late_times(x_then_times), &vals);
    let before = hex_of(&late_times(times_then_x), &vals);

    // Assert
    assert_eq!(after, Ok("010102050708".to_string()));
    assert_eq!(before, Ok("010102070805".to_string()));
}

#[test]
fn ac2_a_bit_held_only_by_late_whens_is_still_refused_naming_the_value() {
    // Arrange
    let only_a = row(&[("mode", n(1)), ("a", n(9))]);
    let only_b = row(&[("mode", n(2)), ("b", n(9))]);

    // Act
    let by_a = refusal(&late_whens(), &only_a);
    let by_b = refusal(&late_whens(), &only_b);
    let nested = refusal(&nested_late_when(), &only_a);

    // Assert
    assert!(by_a.starts_with("'a' is given, but its when on 'mode'"), "{by_a}");
    assert!(by_b.starts_with("'b' is given, but its when on 'mode'"), "{by_b}");
    assert!(nested.starts_with("'a' is given, but its when on 'mode'"), "{nested}");
}

#[test]
fn ac2_a_bit_held_only_by_a_late_times_is_still_refused_naming_the_value() {
    // Arrange
    let only = row(&[("n", n(2)), ("pt", rounds(&[7, 8]))]);

    // Act
    let by_after = refusal(&late_times(x_then_times), &only);
    let by_before = refusal(&late_times(times_then_x), &only);

    // Assert
    assert!(by_after.starts_with("'pt' is given, but its times count 'n'"), "{by_after}");
    assert!(by_before.starts_with("'pt' is given, but its times count 'n'"), "{by_before}");
}
