use crate::hostile_tests::within_one_second;
use crate::walk::unpack;
use crate::{
    bytes, dict, eq, flag_byte, list, times, u8, when, BoundField, MapScheme, Scheme, SchemeItem,
    ShortPacket, UnpackError, Value,
};

fn zero_width(label: &str, left: usize) -> UnpackError {
    UnpackError::Short(ShortPacket {
        field: label.to_string(),
        needed: 0,
        left,
    })
}

#[test]
fn zero_width_list_element_is_error() {
    let result = within_one_second("list of list of bytes(0)", || {
        let scheme = MapScheme::new(1, vec![list("0", list("0", bytes("0", 0)))]);
        unpack(&scheme, &[0x01, 0xff, 0xff, 0xff, 0xff]).map(|_| ())
    });
    assert_eq!(result, Err(zero_width("0", 0)));
}

#[test]
fn zero_width_dict_value_is_error() {
    let result = within_one_second("dict of bytes(0)", || {
        let scheme = MapScheme::new(1, vec![dict("0", bytes("0", 0))]);
        unpack(&scheme, &[0x01, 0xff, 0xff, 0x01, 0x00, 0x61]).map(|_| ())
    });
    assert_eq!(result, Err(zero_width("0", 0)));
}

#[test]
fn never_matching_when_element_is_error() {
    let result = within_one_second("list of never-matching when", || {
        let scheme = MapScheme::new(
            1,
            vec![list("0", when(0, eq("x", Value::U8(1)), vec![u8("0")]))],
        );
        unpack(&scheme, &[0x01, 0x03, 0x00]).map(|_| ())
    });
    assert_eq!(result, Err(zero_width("0", 0)));
}

#[test]
fn empty_list_of_zero_width_still_unpacks() {
    let got = within_one_second("empty list", || {
        let scheme = MapScheme::new(1, vec![list("0", bytes("0", 0))]);
        unpack(&scheme, &[0x01, 0x00, 0x00])
            .map(|values| values.get("0") == Some(&Some(Value::List(vec![]))))
    });
    assert_eq!(got, Ok(true));
}

#[test]
fn empty_dict_of_zero_width_still_unpacks() {
    let got = within_one_second("empty dict", || {
        let scheme = MapScheme::new(1, vec![dict("0", bytes("0", 0))]);
        unpack(&scheme, &[0x01, 0x00, 0x00]).map(|values| values.contains_key("0"))
    });
    assert_eq!(got, Ok(true));
}

#[test]
fn list_of_real_elements_is_unchanged() {
    let scheme = MapScheme::new(1, vec![list("0", u8("0"))]);
    let got = unpack(&scheme, &[0x01, 0x02, 0x00, 0x07, 0x08]).expect("unpack");
    assert_eq!(
        got.get("0"),
        Some(&Some(Value::List(vec![Value::U8(7), Value::U8(8)])))
    );
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn orphan_flag_bit_after_a_when_is_a_construction_error() {
    let f = flag_byte("f");
    MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", Value::U8(1)), vec![f.byte()]),
            f.bit(u8("2")),
        ],
    );
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn flag_bit_in_a_list_element_with_the_byte_outside_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(1, vec![f.byte(), list("L", f.bit(u8("0")))]);
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn flag_bit_in_a_dict_element_with_the_byte_outside_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(1, vec![f.byte(), dict("D", f.bit(u8("0")))]);
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn flag_bit_in_a_times_round_with_the_byte_outside_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(
        1,
        vec![u8("0"), f.byte(), times(2, "0", vec![f.bit(u8("2"))])],
    );
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn flag_bit_before_its_byte_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(1, vec![f.bit(u8("0")), f.byte()]);
}

#[test]
fn flag_byte_and_bit_inside_one_when_still_build() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", Value::U8(1)), vec![f.byte(), f.bit(u8("2"))]),
        ],
    );
    let got = unpack(&scheme, &[0x01, 0x01, 0x01, 0x07]).expect("unpack");
    assert_eq!(got.get("2"), Some(&Some(Value::U8(7))));
}

#[test]
fn typed_scheme_with_split_flag_fields_still_builds() {
    #[derive(Default)]
    struct Row {
        a: u8,
    }
    let f = flag_byte("f");
    let _ = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Row| r.a, |r: &mut Row, v| r.a = v).into(),
            SchemeItem::Field(f.byte()),
            SchemeItem::Field(f.bit(u8("2"))),
        ],
    );
}

#[test]
fn flag_bit_inside_a_when_may_use_the_byte_of_the_enclosing_scope() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            f.byte(),
            when(2, eq("0", Value::U8(1)), vec![f.bit(u8("2"))]),
        ],
    );
    let got = unpack(&scheme, &[0x01, 0x01, 0x01, 0x07]).expect("unpack");
    assert_eq!(got.get("2"), Some(&Some(Value::U8(7))));
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte")]
fn typed_scheme_with_orphan_flag_bit_is_refused() {
    #[derive(Default)]
    struct Row {
        a: u8,
    }
    let f = flag_byte("f");
    let _ = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Row| r.a, |r: &mut Row, v| r.a = v).into(),
            SchemeItem::when(1, eq(0, Value::U8(1)), [SchemeItem::Field(f.byte())]),
            SchemeItem::Field(f.bit(u8("2"))),
        ],
    );
}

#[test]
#[should_panic(expected = "flag bit 0 of flag byte \"f\" is not in the same scope")]
fn orphan_flag_bit_is_construction_error() {
    let f = flag_byte("f");
    MapScheme::new(1, vec![f.bit(u8("0")), f.byte()]);
}

#[test]
fn same_scope_flag_bit_still_builds() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(1, vec![f.byte(), f.bit(u8("1"))]);
    let got = unpack(&scheme, &[0x01, 0x01, 0x07]).expect("unpack");
    assert_eq!(got.get("1"), Some(&Some(Value::U8(7))));
}
