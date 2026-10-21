use crate::walk::{pack, unpack};
use crate::{eq, flags, group, insert, to_hex, u8, when, MapScheme, Value, Values};

// AZ-3133 AC-3: a presence bit (an empty `group` under `flags`) that sits in a `when` that is clear
// is absent, so the `when` that names it is false whatever the row holds. In Rust the empty group
// is also the `bool`, so this is the shape of the shared hostile cases
// `pack_when_of_*_bool_source*` spelled with the group.

/// `u8 mode; when mode = 1 { flags { group (empty) on }; u8 a }; when on = true { u8 b }`
fn scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            when(
                1,
                eq("mode", Value::U8(1)),
                vec![flags(1, "f", vec![group(1, "on", vec![])]), u8("a")],
            ),
            when(3, eq("on", Value::U8(1)), vec![u8("b")]),
        ],
    )
}

fn row(mode: u8, on: u8) -> Values {
    let mut vals = Values::new();
    for (name, value) in [("mode", mode), ("on", on), ("a", 7), ("b", 5)] {
        insert(&mut vals, name, Some(Value::U8(value)));
    }
    vals
}

fn get(vals: &Values, name: &str) -> Option<Value> {
    vals.get(name).cloned().flatten()
}

#[test]
fn ac3_empty_group_source_in_a_clear_when_is_absent_and_the_second_when_is_false() {
    // Arrange: mode 0, the row holds a set presence bit that would match
    let scheme = scheme();

    // Act
    let packet = pack(&scheme, &row(0, 1)).expect("pack");
    let back = unpack(&scheme, &packet).expect("unpack");

    // Assert
    assert_eq!(to_hex(&packet), "0100");
    assert_eq!(get(&back, "mode"), Some(Value::U8(0)));
    assert_eq!(get(&back, "on"), None);
    assert_eq!(get(&back, "b"), None);
}

#[test]
fn ac3_empty_group_source_written_set_keeps_the_second_when_body() {
    // Arrange
    let scheme = scheme();

    // Act
    let packet = pack(&scheme, &row(1, 1)).expect("pack");
    let back = unpack(&scheme, &packet).expect("unpack");

    // Assert
    assert_eq!(to_hex(&packet), "0101010705");
    assert_eq!(get(&back, "on"), Some(Value::U8(1)));
    assert_eq!(get(&back, "a"), Some(Value::U8(7)));
    assert_eq!(get(&back, "b"), Some(Value::U8(5)));
}

#[test]
fn ac3_empty_group_source_written_clear_leaves_the_second_when_body_out() {
    // Arrange
    let scheme = scheme();

    // Act
    let packet = pack(&scheme, &row(1, 0)).expect("pack");
    let back = unpack(&scheme, &packet).expect("unpack");

    // Assert
    assert_eq!(to_hex(&packet), "01010007");
    assert_eq!(get(&back, "a"), Some(Value::U8(7)));
    assert_eq!(get(&back, "b"), None);
}
