use crate::walk::{pack, unpack};
use crate::{
    bits, eq, packed, repeat, sized, times, u8, when, BoundField, MapScheme, Scheme, SchemeItem,
    Value, Values,
};

#[derive(Default)]
struct Hdr {
    n: u8,
}

#[derive(Default)]
struct Item {
    x: u8,
}

fn hdr_n() -> SchemeItem<Hdr> {
    BoundField::u8(0, |r: &Hdr| r.n, |r: &mut Hdr, v| r.n = v).into()
}

#[test]
#[should_panic(expected = "is not in the same scope")]
fn ac1_when_in_a_repeat_naming_an_outer_field_by_name_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("type"),
            repeat(1, vec![when(1, eq("type", Value::U8(1)), vec![u8("x")])]),
        ],
    );
}

#[test]
#[should_panic(expected = "which is not in the same scope")]
fn ac1_count_in_a_times_naming_an_outer_field_by_name_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            u8("m"),
            times(2, "n", vec![u8("a"), sized("b", "m")]),
        ],
    );
}

#[test]
fn ac2_named_references_in_the_same_scope_still_build_and_round_trip() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("kind"),
            when(1, eq("kind", Value::U8(1)), vec![u8("y")]),
            repeat(
                2,
                vec![u8("tag"), when(3, eq("tag", Value::U8(1)), vec![u8("x")])],
            ),
        ],
    );
    let wire = [0x01, 0x01, 0x05, 0x01, 0x07, 0x00];
    let got = unpack(&scheme, &wire).expect("unpack");
    assert_eq!(pack(&scheme, &got).expect("pack"), wire);
}

#[test]
#[should_panic(expected = "when at id 2 names field \"1\", which is not in the same scope")]
fn ac3_when_after_a_times_naming_a_body_field_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![u8("1")]),
            when(2, eq("1", Value::U8(1)), vec![u8("2")]),
        ],
    );
}

#[test]
#[should_panic(expected = "when at id 2 names field \"1\", which is not in the same scope")]
fn ac3_when_after_a_repeat_naming_a_body_field_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(1, vec![u8("1")]),
            when(2, eq("1", Value::U8(1)), vec![u8("2")]),
        ],
    );
}

#[test]
#[should_panic(expected = "the count of \"2\" names field \"1\", which is not in the same scope")]
fn ac3_sized_after_a_times_counting_a_body_field_is_refused() {
    MapScheme::new(
        1,
        vec![u8("0"), times(1, "0", vec![u8("1")]), sized("2", "1")],
    );
}

#[test]
#[should_panic(expected = "the count of \"2\" names field \"1\", which is not in the same scope")]
fn ac3_packed_after_a_repeat_counting_a_body_field_is_refused() {
    MapScheme::new(
        1,
        vec![u8("0"), repeat(1, vec![u8("1")]), packed(1, "2", "1", 0)],
    );
}

#[test]
#[should_panic(expected = "times at id 2 names field \"1\", which is not in the same scope")]
fn ac3_times_after_a_times_counting_a_body_field_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![u8("1")]),
            times(2, "1", vec![u8("2")]),
        ],
    );
}

#[test]
#[should_panic(expected = "when at id 2 names field \"1\", which is not in the same scope")]
fn ac3_typed_times_when_after_it_naming_an_element_field_is_refused() {
    let _ = Scheme::new(
        1,
        [
            hdr_n(),
            SchemeItem::times(
                1,
                0,
                |_: &Hdr| &[] as &[Item],
                |_: &mut Hdr, _: Vec<Item>| {},
                [BoundField::u8(1, |i: &Item| i.x, |i: &mut Item, v| i.x = v).into()],
            ),
            SchemeItem::when(
                2,
                eq(1, Value::U8(1)),
                [BoundField::u8(2, |r: &Hdr| r.n, |r: &mut Hdr, v| r.n = v).into()],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "when at id 1 names field \"zzz\", which is not in the same scope")]
fn ac4_when_naming_an_undeclared_name_is_refused() {
    MapScheme::new(
        1,
        vec![u8("0"), when(1, eq("zzz", Value::U8(1)), vec![u8("1")])],
    );
}

#[test]
#[should_panic(
    expected = "the count of \"1\" names field \"nope\", which is not in the same scope"
)]
fn ac4_count_naming_an_undeclared_name_is_refused() {
    MapScheme::new(1, vec![u8("0"), bits("1", "nope")]);
}

#[test]
#[should_panic(expected = "when at id 0 names field \"late\", which is not in the same scope")]
fn ac4_when_naming_a_field_declared_after_it_is_refused() {
    MapScheme::new(
        1,
        vec![when(0, eq("late", Value::U8(1)), vec![u8("0")]), u8("late")],
    );
}

#[test]
fn ac4_references_to_fields_in_a_when_or_flags_member_still_build() {
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", Value::U8(1)), vec![u8("1")]),
            when(2, eq("1", Value::U8(5)), vec![u8("2")]),
        ],
    );
    let mut values = Values::new();
    values.insert("0".into(), Some(Value::U8(1)));
    values.insert("1".into(), Some(Value::U8(5)));
    values.insert("2".into(), Some(Value::U8(9)));
    assert_eq!(
        pack(&scheme, &values).expect("pack"),
        [0x01, 0x01, 0x05, 0x09]
    );
}
