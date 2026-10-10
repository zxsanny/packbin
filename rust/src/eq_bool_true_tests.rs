use crate::{
    bits, bytes, eq, f32, f64, flags, group, list, pack, packed, sized, times, to_hex, u8, unpack,
    utf8, when, BinaryPacker, BoundField, Field, MapScheme, Scheme, SchemeItem, Value, Values,
};
use std::panic::{catch_unwind, AssertUnwindSafe};

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        crate::insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

/// `flags(0, "f", [bool "on"]); when(1, eq("on", test), [u8 "v"])`
fn bool_when(test: Value) -> MapScheme {
    MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![group(0, "on", vec![])]),
            when(1, eq("on", test), vec![u8("v")]),
        ],
    )
}

fn panic_text(build: impl FnOnce()) -> String {
    let panic = catch_unwind(AssertUnwindSafe(build)).expect_err("construction must be refused");
    if let Some(text) = panic.downcast_ref::<String>() {
        text.clone()
    } else if let Some(text) = panic.downcast_ref::<&str>() {
        (*text).to_string()
    } else {
        String::new()
    }
}

// AC-1

#[test]
fn ac1_eq_bool_false_is_a_scheme_error_naming_the_when_and_the_field() {
    // Arrange
    let build = || {
        bool_when(Value::U8(0));
    };

    // Act
    let text = panic_text(build);

    // Assert
    assert!(text.contains("when at id 1"), "{text}");
    assert!(text.contains("\"on\""), "{text}");
}

#[test]
fn ac1_eq_bool_with_any_value_but_one_is_a_scheme_error() {
    for test in [
        Value::U8(2),
        Value::U16(0),
        Value::I8(-1),
        Value::I64(0),
        Value::U64(257),
    ] {
        // Arrange
        let expected = format!("{test:?}");

        // Act
        let text = panic_text(|| {
            bool_when(test);
        });

        // Assert
        assert!(text.contains("when at id 1"), "{expected}: {text}");
        assert!(text.contains("\"on\""), "{expected}: {text}");
    }
}

#[test]
fn ac1_eq_by_id_on_a_bool_false_is_a_scheme_error_naming_field_0() {
    // Arrange
    let build = || {
        MapScheme::new(
            1,
            vec![
                flags(0, "f", vec![group(0, "0", vec![])]),
                when(1, eq(0, Value::U8(0)), vec![u8("1")]),
            ],
        );
    };

    // Act
    let text = panic_text(build);

    // Assert
    assert!(text.contains("when at id 1"), "{text}");
    assert!(text.contains("\"0\""), "{text}");
}

#[test]
fn ac1_eq_bool_false_through_the_typed_scheme_is_a_scheme_error() {
    // Arrange
    #[derive(Default)]
    struct Row {
        on: Option<bool>,
        v: u8,
    }
    let build = || {
        let _ = Scheme::<Row>::new(
            1,
            [
                SchemeItem::flags(
                    0,
                    [BoundField::bool_flag(0, |r: &Row| r.on, |r: &mut Row, v| r.on = v).into()],
                ),
                SchemeItem::when(
                    1,
                    eq(0, Value::U8(0)),
                    [BoundField::u8(1, |r: &Row| r.v, |r: &mut Row, v| r.v = v).into()],
                ),
            ],
        );
    };

    // Act
    let text = panic_text(build);

    // Assert
    assert!(text.contains("when at id 1"), "{text}");
    assert!(text.contains("\"0\""), "{text}");
}

// AC-2

#[test]
fn ac2_eq_bool_true_packs_010105_and_round_trips() {
    for test in [Value::U8(1), Value::U16(1), Value::I64(1)] {
        // Arrange
        let scheme = bool_when(test.clone());
        let row = values(&[("on", Value::U8(1)), ("v", Value::U8(5))]);

        // Act
        let raw = pack(&scheme, &row).expect("pack");
        let back = unpack(&scheme, &raw).expect("unpack");

        // Assert
        assert_eq!(to_hex(&raw), "010105", "{test:?}");
        assert_eq!(back.get("on"), Some(&Some(Value::U8(1))), "{test:?}");
        assert_eq!(back.get("v"), Some(&Some(Value::U8(5))), "{test:?}");
    }
}

#[test]
fn ac2_eq_bool_true_with_a_clear_bit_writes_no_body() {
    // Arrange
    let scheme = bool_when(Value::U8(1));
    let row = values(&[("on", Value::U8(0)), ("v", Value::U8(5))]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "0100");
}

#[test]
fn ac2_eq_bool_true_through_the_typed_scheme_round_trips() {
    // Arrange
    #[derive(Default, Debug, PartialEq)]
    struct Row {
        on: Option<bool>,
        v: u8,
    }
    let scheme = Scheme::<Row>::new(
        1,
        [
            SchemeItem::flags(
                0,
                [BoundField::bool_flag(0, |r: &Row| r.on, |r: &mut Row, v| r.on = v).into()],
            ),
            SchemeItem::when(
                1,
                eq(0, Value::U8(1)),
                [BoundField::u8(1, |r: &Row| r.v, |r: &mut Row, v| r.v = v).into()],
            ),
        ],
    );
    let row = Row {
        on: Some(true),
        v: 5,
    };

    // Act
    let raw = BinaryPacker::pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010105");
}

// A `when` names an integer or a bool; float, utf8 and bytes are refused.

fn when_on(source: Field) -> MapScheme {
    MapScheme::new(
        1,
        vec![source, when(1, eq("0", Value::U8(1)), vec![u8("1")])],
    )
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn ac_when_on_an_f32_source_is_refused() {
    when_on(f32("0"));
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn ac_when_on_an_f64_source_is_refused() {
    when_on(f64("0"));
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn ac_when_on_a_utf8_source_is_refused() {
    when_on(utf8("0"));
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn ac_when_on_a_bytes_source_is_refused() {
    when_on(bytes("0", 2));
}

#[test]
#[should_panic(expected = "tests field \"xs\"")]
fn ac_when_on_a_list_source_is_refused() {
    MapScheme::new(
        1,
        vec![
            list("xs", u8("0")),
            when(0, eq("xs", Value::U8(1)), vec![u8("v")]),
        ],
    );
}

// A count names an integer field only; a bool and a float are refused.

fn counted(count_source: Field, count_field: Field) -> MapScheme {
    MapScheme::new(1, vec![count_source, count_field])
}

fn with_bool() -> Field {
    flags(0, "f", vec![group(0, "on", vec![])])
}

#[test]
#[should_panic(expected = "the count of \"s\" names field \"on\", which is not an integer")]
fn ac_sized_count_on_a_bool_is_refused() {
    counted(with_bool(), sized("s", "on"));
}

#[test]
#[should_panic(expected = "the count of \"s\" names field \"on\", which is not an integer")]
fn ac_bits_count_on_a_bool_is_refused() {
    counted(with_bool(), bits("s", "on"));
}

#[test]
#[should_panic(expected = "the count of \"s\" names field \"on\", which is not an integer")]
fn ac_packed_count_on_a_bool_is_refused() {
    counted(with_bool(), packed(2, "s", "on", 0));
}

#[test]
#[should_panic(expected = "times at id 1 names field \"on\", which is not an integer")]
fn ac_times_count_on_a_bool_is_refused() {
    counted(with_bool(), times(1, "on", vec![u8("v")]));
}

#[test]
#[should_panic(expected = "the count of \"s\" names field \"n\", which is not an integer")]
fn ac_sized_count_on_a_float_is_refused() {
    counted(f32("n"), sized("s", "n"));
}

#[test]
#[should_panic(expected = "the count of \"s\" names field \"n\", which is not an integer")]
fn ac_packed_count_on_an_f64_is_refused() {
    counted(f64("n"), packed(1, "s", "n", 0));
}

#[test]
#[should_panic(expected = "times at id 1 names field \"n\", which is not an integer")]
fn ac_times_count_on_a_float_is_refused() {
    counted(f32("n"), times(1, "n", vec![u8("v")]));
}

#[test]
fn ac_counts_on_an_integer_field_still_build() {
    // Arrange
    let sized_scheme = counted(u8("n"), sized("s", "n"));
    let times_scheme = counted(u8("n"), times(1, "n", vec![u8("v")]));

    // Act
    let raw = pack(
        &sized_scheme,
        &values(&[("n", Value::U8(2)), ("s", Value::Bytes(vec![7, 8]))]),
    )
    .expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01020708");
    assert_eq!(times_scheme.type_number(), 1);
}
