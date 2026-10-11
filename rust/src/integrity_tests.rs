use crate::{
    be, dict, eq, f32, flag_byte, flags, group, i8, insert, list, pack, repeat, sized, times, u16,
    u2, u64, u8, unpack, utf8, when, Field, MapScheme, Value, Values,
};

// `when` compares by number, so the width or sign of `eq`'s value does not matter.

fn when_scheme(source: Field, expect: Value) -> MapScheme {
    MapScheme::new(1, vec![source, when(1, eq("0", expect), vec![u8("1")])])
}

fn row(source: Value) -> Values {
    let mut values = Values::new();
    insert(&mut values, "0", Some(source));
    insert(&mut values, "1", Some(Value::U8(9)));
    values
}

#[test]
fn when_matches_an_eq_value_of_any_integer_width() {
    for expect in [
        Value::U8(1),
        Value::U16(1),
        Value::U32(1),
        Value::U64(1),
        Value::I8(1),
        Value::I16(1),
        Value::I32(1),
        Value::I64(1),
    ] {
        // Arrange
        let scheme = when_scheme(u8("0"), expect.clone());

        // Act
        let bytes = pack(&scheme, &row(Value::U8(1))).expect("pack");
        let back = unpack(&scheme, &[1, 1, 9]).expect("unpack");

        // Assert
        assert_eq!(bytes, vec![1, 1, 9], "{expect:?}");
        assert_eq!(back.get("1"), Some(&Some(Value::U8(9))), "{expect:?}");
    }
}

#[test]
fn when_skips_its_members_when_the_numbers_differ() {
    // Arrange
    let scheme = when_scheme(u8("0"), Value::U16(2));

    // Act
    let bytes = pack(&scheme, &row(Value::U8(1))).expect("pack");

    // Assert
    assert_eq!(bytes, vec![1, 1]);
}

#[test]
fn when_compares_a_negative_source_by_value() {
    // Arrange
    let same = when_scheme(i8("0"), Value::I64(-1));
    let other = when_scheme(i8("0"), Value::I16(-2));

    // Act
    let matched = pack(&same, &row(Value::I8(-1))).expect("pack");
    let unmatched = pack(&other, &row(Value::I8(-1))).expect("pack");

    // Assert
    assert_eq!(matched, vec![1, 0xff, 9]);
    assert_eq!(unmatched, vec![1, 0xff]);
}

#[test]
fn when_compares_u64_above_i64_max_by_value() {
    // Arrange
    let top = u64::MAX;
    let same = when_scheme(u64("0"), Value::U64(top));
    let wrapped = when_scheme(u64("0"), Value::I64(i64::MAX));
    let mut wire = vec![1];
    wire.extend_from_slice(&top.to_le_bytes());

    // Act
    let matched = pack(&same, &row(Value::U64(top))).expect("pack");
    let unmatched = pack(&wrapped, &row(Value::U64(top))).expect("pack");
    wire.push(9);
    let back = unpack(&same, &wire).expect("unpack");

    // Assert
    assert_eq!(matched, wire);
    assert_eq!(unmatched, wire[..9].to_vec());
    assert_eq!(back.get("1"), Some(&Some(Value::U8(9))));
}

#[test]
fn when_on_a_bool_builds() {
    MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![group(0, "on", vec![])]),
            when(1, eq("on", Value::U8(1)), vec![u8("1")]),
        ],
    );
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn when_on_a_float_source_is_refused() {
    when_scheme(f32("0"), Value::U8(1));
}

#[test]
#[should_panic(expected = "tests field \"0\"")]
fn when_on_a_utf8_source_is_refused() {
    when_scheme(utf8("0"), Value::U8(1));
}

#[test]
#[should_panic(expected = "compares field \"0\" with a value that is not an integer")]
fn when_with_a_float_eq_value_is_refused() {
    when_scheme(u8("0"), Value::F32(1.0));
}

#[test]
#[should_panic(expected = "compares field \"0\" with a value that is not an integer")]
fn when_with_a_text_eq_value_is_refused() {
    when_scheme(u8("0"), Value::Str("1".to_string()));
}

// A list or dict element is one integer, float, bytes, utf8, list or dict; any other shape
// loses data in the walker, so it is refused when the scheme is built.

#[test]
#[should_panic(expected = "list \"xs\" cannot carry element \"f\"")]
fn list_of_flags_is_refused() {
    MapScheme::new(1, vec![list("xs", flags(0, "f", vec![u8("a")]))]);
}

#[test]
#[should_panic(expected = "list \"xs\" cannot carry element \"g\"")]
fn list_of_group_is_refused() {
    MapScheme::new(1, vec![list("xs", group(0, "g", vec![u8("0"), u8("1")]))]);
}

#[test]
#[should_panic(expected = "dict \"d\" cannot carry element \"g\"")]
fn dict_of_group_is_refused() {
    MapScheme::new(1, vec![dict("d", group(0, "g", vec![u8("0")]))]);
}

#[test]
#[should_panic(expected = "list \"xs\" cannot carry element \"a\"")]
fn list_of_a_two_name_u2_is_refused() {
    MapScheme::new(1, vec![list("xs", u2(&["a", "b"]))]);
}

#[test]
#[should_panic(expected = "list \"xs\" cannot carry element \"a\"")]
fn list_of_sized_is_refused() {
    MapScheme::new(1, vec![u8("n"), list("xs", sized("a", "n"))]);
}

#[test]
#[should_panic(expected = "dict \"d\" cannot carry element \"f\"")]
fn dict_of_a_flag_byte_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(1, vec![dict("d", f.byte())]);
}

#[test]
#[should_panic(expected = "list \"inner\" cannot carry element \"g\"")]
fn nested_list_of_group_is_refused() {
    MapScheme::new(
        1,
        vec![list("outer", list("inner", group(0, "g", vec![u8("0")])))],
    );
}

#[test]
#[should_panic(expected = "repeat at id 1 is inside a repeat or times round")]
fn repeat_inside_a_repeat_is_refused() {
    MapScheme::new(1, vec![repeat(0, vec![u8("0"), repeat(1, vec![u8("1")])])]);
}

#[test]
fn single_value_elements_still_round_trip() {
    // Arrange
    let nested = MapScheme::new(1, vec![list("0", list("0", u8("0")))]);
    let one_name = MapScheme::new(1, vec![list("0", u2(&["a"]))]);
    let wide = MapScheme::new(1, vec![list("0", be(u16("0")))]);
    let table = MapScheme::new(1, vec![dict("0", list("0", dict("0", utf8("0"))))]);

    // Act
    let nested_back = unpack(&nested, &[1, 1, 0, 2, 0, 5, 6]).expect("nested list");
    let one_name_back = unpack(&one_name, &[1, 2, 0, 1, 2]).expect("one-name u2");
    let wide_back = unpack(&wide, &[1, 1, 0, 0x12, 0x34]).expect("be list");
    let table_back = unpack(
        &table,
        &[1, 1, 0, 1, 0, b'k', 1, 0, 1, 0, 1, 0, b'n', 1, 0, b'v'],
    )
    .expect("dict of lists of dicts");

    // Assert
    assert_eq!(
        nested_back.get("0"),
        Some(&Some(Value::List(vec![Value::List(vec![
            Value::U8(5),
            Value::U8(6)
        ])])))
    );
    assert_eq!(
        one_name_back.get("0"),
        Some(&Some(Value::List(vec![Value::U8(1), Value::U8(2)])))
    );
    assert_eq!(
        wide_back.get("0"),
        Some(&Some(Value::List(vec![Value::U16(0x1234)])))
    );
    assert!(table_back.contains_key("0"));
}

// AZ-2126: a member of a `flags` cannot name the flags byte it sits in, because pack writes that
// byte after its members; a sibling after the container and a member before it may.

#[test]
#[should_panic(expected = "names field \"f\", which is not in the same scope")]
fn az2126_when_member_naming_its_own_flags_byte_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            flags(
                1,
                "f",
                vec![u8("a"), when(2, eq("f", Value::U8(1)), vec![u8("speed")])],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "names field \"f\", which is not in the same scope")]
fn az2126_times_member_counted_by_its_own_flags_byte_is_refused() {
    MapScheme::new(
        1,
        vec![flags(0, "f", vec![u8("a"), times(1, "f", vec![u8("pt")])])],
    );
}

#[test]
#[should_panic(expected = "names field \"f\", which is not in the same scope")]
fn az2126_when_inside_a_group_under_its_flags_byte_is_refused() {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![
                u8("a"),
                group(
                    1,
                    "g",
                    vec![when(1, eq("f", Value::U8(1)), vec![u8("speed")])],
                ),
            ],
        )],
    );
}

#[test]
fn az2126_when_naming_an_earlier_member_of_the_same_flags_builds() {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![
                u8("mode"),
                when(1, eq("mode", Value::U8(1)), vec![u8("speed")]),
            ],
        )],
    );
}

#[test]
fn az2126_sibling_after_the_flags_container_may_name_its_byte() {
    MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![u8("a")]),
            when(1, eq("f", Value::U8(1)), vec![u8("speed")]),
            sized("s", "f"),
        ],
    );
}
