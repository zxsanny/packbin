use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, insert, list, repeat, times, to_hex, u16, u8, utf8, when, Field,
    MapScheme, Value, Values,
};

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex(scheme: &MapScheme, vals: &Values) -> String {
    to_hex(&pack(scheme, vals).expect("pack"))
}

fn unpacked(scheme: &MapScheme, wire: &str) -> Values {
    let raw: Vec<u8> = (0..wire.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&wire[i..i + 2], 16).expect("hex"))
        .collect();
    unpack(scheme, &raw).expect("unpack")
}

fn got(vals: &Values, name: &str) -> Option<Value> {
    vals.get(name).cloned().flatten()
}

fn byte(n: u8) -> Value {
    Value::U8(n)
}

fn branch(anchor: u32, tested: u8, member: Field) -> Field {
    when(anchor, eq("k", byte(tested)), vec![member])
}

#[test]
fn ac6_alternate_when_branches_keep_sharing_a_name() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![u8("k"), branch(1, 0, u8("s")), branch(2, 1, u16("s"))],
    );
    let row = values(&[("k", byte(1)), ("s", Value::U16(300))]);

    // Act
    let bytes = hex(&scheme, &row);
    let back = unpacked(&scheme, "01012c01");

    // Assert
    assert_eq!(bytes, "01012c01");
    assert_eq!(got(&back, "k"), Some(byte(1)));
    assert_eq!(got(&back, "s"), Some(Value::U16(300)));
}

#[test]
fn ac6_alternate_when_branches_in_a_repeat_round_keep_sharing_a_name() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![u8("k"), branch(1, 0, u8("s")), branch(2, 1, u16("s"))],
        )],
    );
    let round = |k: u8, s: Value| values(&[("k", byte(k)), ("s", s)]);
    let rounds = Value::Groups(vec![round(0, byte(7)), round(1, Value::U16(300))]);

    // Act
    let bytes = hex(&scheme, &values(&[("__repeat__", rounds.clone())]));
    let back = unpacked(&scheme, "010007012c01");

    // Assert
    assert_eq!(bytes, "010007012c01");
    assert_eq!(got(&back, "__repeat__"), Some(rounds));
}

#[test]
fn ac6_a_name_outside_then_under_a_when_builds() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("k"), u8("s"), branch(2, 1, u16("s"))]);

    // Act
    let back = unpacked(&scheme, "010107ff00");

    // Assert
    assert_eq!(got(&back, "k"), Some(byte(1)));
    assert_eq!(got(&back, "s"), Some(Value::U16(255)));
}

#[test]
fn ac6_a_name_under_a_when_then_outside_builds() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("k"), branch(1, 1, u8("s")), u8("s")]);

    // Act
    let back = unpacked(&scheme, "01010708");

    // Assert
    assert_eq!(got(&back, "s"), Some(byte(8)));
}

#[test]
fn ac6_a_name_twice_in_one_when_body_builds() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![u8("k"), when(1, eq("k", byte(1)), vec![u8("s"), u8("s")])],
    );

    // Act
    let back = unpacked(&scheme, "01010708");

    // Assert
    assert_eq!(got(&back, "s"), Some(byte(8)));
}

#[test]
fn ac7_a_flag_byte_read_twice_builds_and_round_trips() {
    // Arrange
    let m = flag_byte("m");
    let scheme = MapScheme::new(1, vec![m.byte(), m.bit(u8("a")), m.byte(), m.bit(u8("b"))]);
    let row = values(&[("a", byte(5)), ("b", byte(9))]);

    // Act
    let bytes = hex(&scheme, &row);
    let back = unpacked(&scheme, "0101050109");

    // Assert
    assert_eq!(bytes, "0101050109");
    assert_eq!(got(&back, "a"), Some(byte(5)));
    assert_eq!(got(&back, "b"), Some(byte(9)));
    assert_eq!(got(&back, "m"), Some(byte(1)));
}

#[test]
fn ac7_a_flag_byte_read_in_a_times_round_and_at_the_top_level_builds() {
    // Arrange
    let m = flag_byte("m");

    // Act
    let scheme = MapScheme::new(
        1,
        vec![
            u8("c"),
            times(1, "c", vec![m.byte(), m.bit(u8("a"))]),
            m.byte(),
            m.bit(u8("b")),
        ],
    );

    // Assert
    assert_eq!(scheme.type_number(), 1);
}

#[test]
fn ac7_two_flags_bytes_named_alike_build_and_pack() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![u8("a")]), flags(1, "f", vec![u8("b")])],
    );
    let row = values(&[("a", byte(5)), ("b", byte(9))]);

    // Act
    let bytes = hex(&scheme, &row);

    // Assert
    assert_eq!(bytes, "0101050109");
}

#[test]
fn ac8_a_list_element_named_like_a_row_member_builds_and_packs() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("e"), list("xs", u8("e"))]);
    let row = values(&[("e", byte(7)), ("xs", Value::List(vec![byte(1), byte(2)]))]);

    // Act
    let bytes = hex(&scheme, &row);

    // Assert
    assert_eq!(bytes, "010702000102");
}

#[test]
fn ac8_a_utf8_list_element_named_like_a_row_member_builds_and_packs() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("x"), list("l", utf8("x"))]);
    let row = values(&[
        ("x", byte(1)),
        ("l", Value::List(vec![Value::Str("a".into())])),
    ]);

    // Act
    let bytes = hex(&scheme, &row);

    // Assert
    assert_eq!(bytes, "01010100010061");
}

#[test]
fn ac8_a_nested_list_element_named_like_a_row_member_builds() {
    // Arrange and Act
    let scheme = MapScheme::new(1, vec![list("l", list("m", u8("e"))), u8("m")]);

    // Assert
    assert_eq!(scheme.type_number(), 1);
}
