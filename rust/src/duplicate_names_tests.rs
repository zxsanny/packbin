use crate::{
    bits, bytes, dict, eq, f32, flag_byte, flags, group, list, packed, repeat, sized, times,
    to_hex, u16, u2, u8, utf8, when, BoundField, Field, MapScheme, Scheme, SchemeItem, Value,
};
use std::panic::{catch_unwind, AssertUnwindSafe};

/// What `build` panics with; fails the test when it returns.
fn panic_text<R>(build: impl FnOnce() -> R) -> String {
    let Err(payload) = catch_unwind(AssertUnwindSafe(build)) else {
        panic!("the scheme was built; it should have been refused");
    };
    match payload.downcast::<String>() {
        Ok(text) => *text,
        Err(other) => other
            .downcast_ref::<&str>()
            .expect("a panic with a text")
            .to_string(),
    }
}

fn twice(name: &str) -> String {
    format!(
        "member \"{name}\" is declared twice in one scope; a row holds one value per name, so one \
         would be lost"
    )
}

fn assert_refused(name: &str, fields: Vec<Field>) {
    assert_eq!(panic_text(|| MapScheme::new(1, fields)), twice(name));
}

fn byte(n: u8) -> Value {
    Value::U8(n)
}

fn branch(anchor: u32, tested: u8, member: Field) -> Field {
    when(anchor, eq("k", byte(tested)), vec![member])
}

#[test]
fn ac1_the_same_name_twice_at_one_level_is_refused() {
    // Arrange
    let fields = vec![u8("x"), u8("x")];

    // Act and Assert
    assert_refused("x", fields);
}

#[test]
fn ac2_a_name_outside_then_inside_a_times_round_is_refused() {
    // Arrange
    let fields = vec![u8("x"), u8("c"), times(2, "c", vec![u8("x")])];

    // Act and Assert
    assert_refused("x", fields);
}

#[test]
fn ac2_a_name_inside_a_times_round_then_outside_is_refused() {
    // Arrange
    let fields = vec![u8("c"), times(1, "c", vec![u8("x")]), u8("x")];

    // Act and Assert
    assert_refused("x", fields);
}

#[test]
fn ac3_two_times_bodies_that_share_a_name_are_refused() {
    // Arrange
    let fields = vec![
        u8("n"),
        times(1, "n", vec![u8("v")]),
        u8("m"),
        times(3, "m", vec![u8("v")]),
    ];

    // Act and Assert
    assert_refused("v", fields);
}

#[test]
fn ac3_a_times_body_that_names_a_member_twice_is_refused() {
    // Arrange
    let fields = vec![u8("c"), times(1, "c", vec![u8("a"), u8("b"), u8("a")])];

    // Act and Assert
    assert_refused("a", fields);
}

#[test]
fn ac4_a_name_outside_and_inside_a_repeat_round_is_refused() {
    // Arrange
    let fields = vec![u8("x"), repeat(1, vec![u8("x")])];

    // Act and Assert
    assert_refused("x", fields);
}

#[test]
fn ac5_every_data_kind_and_every_container_that_shares_the_scope_is_refused() {
    // Arrange
    let m = flag_byte("m");
    let shapes: Vec<(&str, Vec<Field>)> = vec![
        ("a", vec![u2(&["a", "b"]), u8("a")]),
        ("a", vec![u2(&["a", "a"])]),
        ("b", vec![u8("n"), sized("b", "n"), sized("b", "n")]),
        ("a", vec![u8("n"), bits("a", "n"), packed(1, "a", "n", 0)]),
        ("a", vec![f32("a"), utf8("a")]),
        ("a", vec![u8("a"), bytes("a", 2)]),
        ("d", vec![dict("d", u8("e")), list("d", u8("e"))]),
        ("xs", vec![list("xs", u8("e")), u8("xs")]),
        ("a", vec![flags(0, "f", vec![u8("a"), u8("a")])]),
        (
            "on",
            vec![u8("on"), flags(1, "f", vec![group(1, "on", vec![])])],
        ),
        (
            "on",
            vec![flags(
                0,
                "f",
                vec![group(0, "on", vec![]), group(1, "on", vec![])],
            )],
        ),
        ("a", vec![u8("a"), group(1, "g", vec![u8("a")])]),
        ("a", vec![u8("a"), m.byte(), m.bit(u8("a"))]),
        (
            "a",
            vec![u8("a"), m.byte(), m.bit(group(2, "g", vec![u8("a")]))],
        ),
    ];

    for (name, fields) in shapes {
        // Act
        let text = panic_text(|| MapScheme::new(1, fields.clone()));

        // Assert
        assert_eq!(text, twice(name), "{fields:?}");
    }
}

#[test]
fn ac6_a_name_under_a_when_and_twice_outside_is_refused() {
    // Arrange
    let fields = vec![u8("k"), branch(1, 1, u8("s")), u8("s"), u8("s")];

    // Act and Assert
    assert_refused("s", fields);
}

#[derive(Default)]
struct Row {
    k: u8,
    xs: Vec<Item>,
}

#[derive(Default)]
struct Item {
    v: u8,
}

fn first_id() -> SchemeItem<Row> {
    BoundField::u8(0, |r: &Row| r.k, |r: &mut Row, v| r.k = v).into()
}

fn typed_times(anchor: u32, members: Vec<SchemeItem<Item>>) -> SchemeItem<Row> {
    SchemeItem::times(anchor, 0, |r: &Row| &r.xs[..], |r, v| r.xs = v, members)
}

#[test]
fn ac9_a_raw_field_twice_in_a_typed_scheme_is_refused() {
    // Arrange
    let items = [
        SchemeItem::<Row>::Field(u8("x")),
        SchemeItem::Field(u8("x")),
    ];

    // Act
    let text = panic_text(|| Scheme::<Row>::new(1, items));

    // Assert
    assert_eq!(text, twice("x"));
}

#[test]
fn ac9_a_raw_field_outside_and_inside_a_typed_times_is_refused() {
    // Arrange
    let items = [
        first_id(),
        SchemeItem::Field(u8("x")),
        typed_times(2, vec![SchemeItem::Field(u8("x"))]),
    ];

    // Act
    let text = panic_text(|| Scheme::<Row>::new(1, items));

    // Assert
    assert_eq!(text, twice("x"));
}

#[test]
fn ac9_two_bound_fields_with_one_id_keep_the_id_message() {
    // Arrange
    let items = [first_id(), first_id()];

    // Act
    let text = panic_text(|| Scheme::<Row>::new(1, items));

    // Assert
    assert_eq!(text, "field id 0 is not the next order 1");
}

#[test]
fn ac9_a_typed_times_element_that_reuses_an_id_keeps_the_id_message() {
    // Arrange
    let reused: SchemeItem<Item> = BoundField::u8(0, |i: &Item| i.v, |i, v| i.v = v).into();
    let items = [first_id(), typed_times(1, vec![reused])];

    // Act
    let text = panic_text(|| Scheme::<Row>::new(1, items));

    // Assert
    assert_eq!(text, "field id 0 is not the next order 1");
}

#[test]
fn ac9_a_typed_scheme_with_distinct_ids_and_alternate_when_branches_builds() {
    // Arrange
    let scheme = Scheme::<Row>::new(
        1,
        [
            first_id(),
            SchemeItem::when(1, eq(0, byte(0)), [SchemeItem::Field(u8("s"))]),
            SchemeItem::when(2, eq(0, byte(1)), [SchemeItem::Field(u16("s"))]),
        ],
    );
    let row = Row {
        k: 2,
        xs: Vec::new(),
    };

    // Act
    let bytes = crate::BinaryPacker::pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&bytes), "0102");
}

#[test]
fn ac10_a_when_naming_a_missing_field_keeps_its_message_after_a_duplicate() {
    // Arrange
    let fields = vec![u8("x"), u8("x"), when(2, eq("zz", byte(1)), vec![u8("y")])];

    // Act
    let text = panic_text(|| MapScheme::new(1, fields));

    // Assert
    assert_eq!(
        text,
        "when at id 2 names field \"zz\", which is not in the same scope (a field must be \
         declared earlier in the same container; a repeat, times, list or dict body is a scope \
         of its own)"
    );
}

#[test]
fn ac10_an_id_out_of_order_keeps_its_message_after_a_duplicate() {
    // Arrange
    let fields = vec![u8("x"), u8("x"), u8("5")];

    // Act
    let text = panic_text(|| MapScheme::new(1, fields));

    // Assert
    assert_eq!(text, "field id 5 is not the next order 2");
}

#[test]
fn ac10_a_repeat_in_a_repeat_keeps_its_message_after_a_duplicate() {
    // Arrange
    let fields = vec![u8("x"), u8("x"), repeat(2, vec![repeat(2, vec![u8("y")])])];

    // Act
    let text = panic_text(|| MapScheme::new(1, fields));

    // Assert
    assert_eq!(
        text,
        "repeat at id 2 is inside a repeat or times round; a round keeps no inner repeat rounds"
    );
}

#[test]
fn ac10_a_ninth_flag_bit_keeps_its_message_after_a_duplicate() {
    // Arrange
    let m = flag_byte("m");
    let mut fields = vec![u8("x"), u8("x"), m.byte()];
    fields.extend((0..9).map(|i| m.bit(u8(format!("b{i}")))));

    // Act
    let text = panic_text(|| MapScheme::new(1, fields));

    // Assert
    assert_eq!(
        text,
        "flag byte \"m\" has more than 8 bits; the 9th is field \"b8\""
    );
}

#[test]
fn ac10_a_numeric_name_twice_keeps_the_id_message() {
    // Arrange
    let fields = vec![u8("0"), u8("0")];

    // Act
    let text = panic_text(|| MapScheme::new(1, fields));

    // Assert
    assert_eq!(text, "field id 0 is not the next order 1");
}
