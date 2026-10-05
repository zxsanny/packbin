use crate::walk::pack;
use crate::{
    dict, flag_byte, flags, group, insert, list, repeat, times, u8, when, BoundField, MapScheme,
    PackError, Scheme, SchemeItem, Value, Values,
};

// A `repeat` takes its rounds only as `Value::Groups`.

#[test]
fn repeat_value_that_is_not_groups_is_a_type_error() {
    let scheme = MapScheme::new(1, vec![u8("0"), repeat(1, vec![u8("1")])]);
    let mut vals = Values::new();
    insert(&mut vals, "0", Some(Value::U8(7)));
    insert(
        &mut vals,
        "__repeat__",
        Some(Value::List(vec![Value::U8(1)])),
    );
    assert_eq!(
        pack(&scheme, &vals),
        Err(PackError::Type("__repeat__".to_string()))
    );
}

#[test]
fn repeat_with_no_value_packs_no_rounds() {
    let scheme = MapScheme::new(1, vec![u8("0"), repeat(1, vec![u8("1")])]);
    let mut vals = Values::new();
    insert(&mut vals, "0", Some(Value::U8(7)));
    assert_eq!(pack(&scheme, &vals), Ok(vec![0x01, 0x07]));
}

// No repeat inside a round and no times inside a times round: unpack keeps no inner repeat
// rounds, and a times round passes no values to an inner times. Times inside repeat works.

#[test]
#[should_panic(expected = "repeat at id 1 is inside a repeat or times round")]
fn repeat_inside_a_repeat_round_is_refused() {
    MapScheme::new(1, vec![repeat(0, vec![u8("x"), repeat(1, vec![u8("y")])])]);
}

#[test]
#[should_panic(expected = "repeat at id 2 is inside a repeat or times round")]
fn repeat_inside_a_when_inside_times_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![
                    u8("1"),
                    when(
                        2,
                        crate::eq("1", Value::U8(1)),
                        vec![repeat(2, vec![u8("2")])],
                    ),
                ],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "repeat at id 1 is inside a repeat or times round")]
fn repeat_inside_a_group_inside_repeat_is_refused() {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![u8("0"), group(1, "g", vec![repeat(1, vec![u8("1")])])],
        )],
    );
}

#[test]
#[should_panic(expected = "repeat at id 1 is inside a repeat or times round")]
fn repeat_as_a_flags_member_inside_repeat_is_refused() {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![u8("0"), flags(1, "f", vec![repeat(1, vec![u8("1")])])],
        )],
    );
}

#[test]
#[should_panic(expected = "repeat at id 3 is inside a repeat or times round")]
fn repeat_under_a_flag_bit_inside_times_is_refused() {
    let f = flag_byte("f");
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![u8("1"), f.byte(), f.bit(repeat(3, vec![u8("3")]))],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "times at id 2 is inside a times round")]
fn times_inside_a_times_round_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![u8("1"), times(2, "1", vec![u8("2")])]),
        ],
    );
}

#[test]
#[should_panic(expected = "times at id 2 is inside a times round")]
fn times_inside_a_group_inside_times_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![u8("1"), group(2, "g", vec![times(2, "1", vec![u8("2")])])],
            ),
        ],
    );
}

#[test]
fn times_inside_a_repeat_round_still_builds() {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![u8("0"), group(1, "g", vec![times(1, "0", vec![u8("1")])])],
        )],
    );
}

#[test]
#[should_panic(expected = "times at id 2 is inside a times round")]
fn typed_times_inside_times_is_refused() {
    #[derive(Default)]
    struct Row {
        n: u8,
        m: u8,
        v: u8,
    }
    let _ = Scheme::<Row>::new(
        1,
        [
            BoundField::u8(0, |r: &Row| r.n, |r: &mut Row, x| r.n = x).into(),
            SchemeItem::times(
                1,
                0,
                [
                    BoundField::u8(1, |r: &Row| r.m, |r: &mut Row, x| r.m = x).into(),
                    SchemeItem::times(
                        2,
                        1,
                        [BoundField::u8(2, |r: &Row| r.v, |r: &mut Row, x| r.v = x).into()],
                    ),
                ],
            ),
        ],
    );
}

// A list or dict element is a single value, so a repeat or times inside one is refused.

#[test]
#[should_panic(expected = "list \"L\" cannot carry element \"g\"")]
fn repeat_inside_a_list_element_is_refused() {
    MapScheme::new(
        1,
        vec![list("L", group(0, "g", vec![repeat(0, vec![u8("0")])]))],
    );
}

#[test]
#[should_panic(expected = "dict \"D\" cannot carry element \"g\"")]
fn times_inside_a_dict_element_is_refused() {
    MapScheme::new(
        1,
        vec![dict(
            "D",
            group(0, "g", vec![u8("0"), times(1, "0", vec![u8("1")])]),
        )],
    );
}

#[test]
#[should_panic(expected = "list \"L\" cannot carry element \"g\"")]
fn repeat_inside_a_list_element_inside_times_is_refused() {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![list("L", group(0, "g", vec![repeat(0, vec![u8("0")])]))],
            ),
        ],
    );
}
