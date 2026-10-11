use crate::walk::pack;
use crate::{
    eq, flag_byte, flags, i8, insert, to_hex, u16, u2, u64, u8, when, BoundField, Field, MapScheme,
    Scheme, SchemeItem, Value, Values,
};

// AZ-2338: `eq(source, value)` is refused when the scheme is built if the value is not an
// integer or is outside what the source field holds, since the comparison could never match.
// Rust has no bool value, so the Python `eq(u8, True)` row has no Rust form.

fn scheme_with(source: Field, expect: Value) -> MapScheme {
    MapScheme::new(1, vec![source, when(1, eq("s", expect), vec![u8("b")])])
}

fn row(source: Value) -> Values {
    let mut values = Values::new();
    insert(&mut values, "s", Some(source));
    insert(&mut values, "b", Some(Value::U8(9)));
    values
}

#[test]
#[should_panic(expected = "when at id 1 compares field \"s\" with 300, which is outside")]
fn ac1_a_value_above_a_u8_source_is_refused() {
    scheme_with(u8("s"), Value::U16(300));
}

#[test]
#[should_panic(expected = "compares field \"s\" with -1, which is outside")]
fn ac1_a_negative_value_for_an_unsigned_source_is_refused() {
    scheme_with(u8("s"), Value::I8(-1));
}

#[test]
#[should_panic(expected = "compares field \"s\" with -1, which is outside")]
fn ac1_a_negative_value_for_a_u64_source_is_refused() {
    scheme_with(u64("s"), Value::I64(-1));
}

#[test]
#[should_panic(expected = "compares field \"s\" with 200, which is outside the -128 to 127")]
fn ac1_a_value_above_an_i8_source_is_refused() {
    scheme_with(i8("s"), Value::I16(200));
}

#[test]
#[should_panic(expected = "compares field \"s\" with 70000, which is outside the 0 to 65535")]
fn ac1_a_value_above_a_u16_source_is_refused() {
    scheme_with(u16("s"), Value::U32(70_000));
}

#[test]
#[should_panic(expected = "compares field \"s\" with 4, which is outside the 0 to 3")]
fn ac1_a_value_above_a_u2_slot_is_refused() {
    MapScheme::new(
        1,
        vec![u2(&["s"]), when(1, eq("s", Value::U8(4)), vec![u8("b")])],
    );
}

#[test]
#[should_panic(expected = "compares field \"s\" with 256, which is outside the 0 to 255")]
fn ac1_a_value_above_a_flag_byte_is_refused() {
    let m = flag_byte("s");
    MapScheme::new(
        1,
        vec![m.byte(), when(1, eq("s", Value::U16(256)), vec![u8("b")])],
    );
}

#[test]
#[should_panic(expected = "compares field \"f\" with 256, which is outside the 0 to 255")]
fn ac1_a_value_above_a_flags_byte_is_refused() {
    MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![u8("a")]),
            when(1, eq("f", Value::U16(256)), vec![u8("b")]),
        ],
    );
}

#[test]
#[should_panic(expected = "compares field \"0\" with 300, which is outside")]
fn ac1_the_typed_scheme_refuses_it_too() {
    #[derive(Default)]
    struct Row {
        a: u8,
        b: u8,
    }
    let _ = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Row| r.a, |r: &mut Row, v| r.a = v).into(),
            SchemeItem::when(
                1,
                eq(0, Value::U16(300)),
                [BoundField::u8(1, |r: &Row| r.b, |r: &mut Row, v| r.b = v).into()],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "with a value that is not an integer")]
fn ac2_a_string_value_is_refused() {
    scheme_with(u8("s"), Value::Str("x".to_string()));
}

#[test]
#[should_panic(expected = "with a value that is not an integer")]
fn ac2_a_nan_value_is_refused() {
    scheme_with(u8("s"), Value::F64(f64::NAN));
}

#[test]
fn ac4_values_at_the_edge_of_the_source_range_build_and_pack() {
    // Arrange
    let top = scheme_with(u8("s"), Value::U16(255));
    let bottom = scheme_with(i8("s"), Value::I64(-128));

    // Act
    let at_top = pack(&top, &row(Value::U8(255))).expect("pack");
    let at_bottom = pack(&bottom, &row(Value::I8(-128))).expect("pack");
    let missed = pack(&top, &row(Value::U8(254))).expect("pack");

    // Assert
    assert_eq!(to_hex(&at_top), "01ff09");
    assert_eq!(to_hex(&at_bottom), "018009");
    assert_eq!(to_hex(&missed), "01fe");
}
