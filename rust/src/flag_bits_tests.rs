use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, group, insert, list, repeat, times, to_hex, u8, when, BinaryPacker,
    BoundField, Field, MapScheme, Scheme, SchemeItem, Value, Values,
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

fn nine_u8(prefix: &str) -> Vec<Field> {
    (0..9).map(|i| u8(format!("{prefix}{i}"))).collect()
}

#[derive(Default, Debug, PartialEq)]
struct BoolRow {
    on: Option<bool>,
    n: u8,
}

fn on_field(id: u32) -> BoundField<BoolRow> {
    BoundField::bool_flag(id, |r: &BoolRow| r.on, |r: &mut BoolRow, v| r.on = v)
}

fn n_field(id: u32) -> BoundField<BoolRow> {
    BoundField::u8(id, |r: &BoolRow| r.n, |r: &mut BoolRow, v| r.n = v)
}

// AC-1

#[test]
fn ac1_one_handle_two_schemes_pack_the_same_bytes() {
    let m = flag_byte("m");
    let first = MapScheme::new(1, vec![m.byte(), m.bit(u8("x"))]);
    let second = MapScheme::new(1, vec![m.byte(), m.bit(u8("x"))]);
    let vals = values(&[("x", Value::U8(5))]);
    assert_eq!(hex(&first, &vals), "010105");
    assert_eq!(hex(&second, &vals), "010105");
}

#[test]
fn ac1_bit_position_is_field_order_not_call_order() {
    let m = flag_byte("m");
    let late = m.bit(u8("b"));
    let early = m.bit(u8("a"));
    let scheme = MapScheme::new(1, vec![m.byte(), early, late]);
    assert_eq!(hex(&scheme, &values(&[("a", Value::U8(5))])), "010105");
    assert_eq!(hex(&scheme, &values(&[("b", Value::U8(6))])), "010206");
}

#[test]
fn flag_bits_inside_times_number_from_zero_in_their_own_scope() {
    let f = flag_byte("f");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            f.byte(),
            f.bit(u8("2")),
            times(3, "0", vec![f.byte(), f.bit(u8("4"))]),
        ],
    );
    let vals = values(&[("0", Value::U8(1)), ("4", Value::List(vec![Value::U8(9)]))]);
    let raw = pack(&scheme, &vals).expect("pack");
    assert_eq!(to_hex(&raw), "0101000109");
    let got = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(got.get("2"), None);
    assert_eq!(got.get("4"), Some(&Some(Value::List(vec![Value::U8(9)]))));
}

// AC-3

#[test]
#[should_panic(expected = "flags at id 0 has more than 8 members; the 9th is field \"8\"")]
fn ac3_nine_flags_members_are_refused() {
    MapScheme::new(1, vec![flags(0, "f", nine_u8(""))]);
}

#[test]
#[should_panic(expected = "flag byte \"m\" has more than 8 bits; the 9th is field \"x8\"")]
fn ac3_nine_flag_byte_bits_are_refused() {
    let m = flag_byte("m");
    let mut fields = vec![m.byte()];
    fields.extend(nine_u8("x").into_iter().map(|f| m.bit(f)));
    MapScheme::new(1, fields);
}

#[test]
#[should_panic(expected = "flag byte \"m\" has more than 8 bits; the 9th is field \"x8\"")]
fn ac3_ninth_bit_inside_a_when_counts_against_the_same_byte() {
    let m = flag_byte("m");
    let mut fields = vec![m.byte()];
    let mut bits = nine_u8("x");
    let ninth = bits.pop().expect("ninth");
    fields.extend(bits.into_iter().map(|f| m.bit(f)));
    fields.push(when(9, eq("x0", Value::U8(1)), vec![m.bit(ninth)]));
    MapScheme::new(1, fields);
}

#[test]
fn ac3_eight_flags_members_round_trip_bit_7() {
    let members = (0..8).map(|i| u8(i.to_string())).collect();
    let scheme = MapScheme::new(1, vec![flags(0, "f", members)]);
    let raw = pack(&scheme, &values(&[("7", Value::U8(9))])).expect("pack");
    assert_eq!(to_hex(&raw), "018009");
    let got = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(got.get("7"), Some(&Some(Value::U8(9))));
    assert_eq!(got.get("0"), None);
}

#[test]
fn ac3_eight_flag_byte_bits_round_trip_bit_7() {
    let m = flag_byte("m");
    let mut fields = vec![m.byte()];
    fields.extend((0..8).map(|i| m.bit(u8(format!("x{i}")))));
    let scheme = MapScheme::new(1, fields);
    let raw = pack(&scheme, &values(&[("x7", Value::U8(9))])).expect("pack");
    assert_eq!(to_hex(&raw), "018009");
    let got = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(got.get("x7"), Some(&Some(Value::U8(9))));
    assert_eq!(got.get("x0"), None);
}

// AC-4

#[test]
#[should_panic(
    expected = "field id 0: a bool or empty group is allowed only directly inside flags or under a flag bit"
)]
fn ac4_top_level_empty_group_is_refused() {
    MapScheme::new(1, vec![group(0, "0", vec![]), u8("1")]);
}

#[test]
#[should_panic(
    expected = "field id 0: a bool or empty group is allowed only directly inside flags or under a flag bit"
)]
fn ac4_typed_bool_at_top_level_is_refused() {
    let _ = Scheme::<BoolRow>::new(1, [on_field(0).into(), n_field(1).into()]);
}

#[test]
#[should_panic(expected = "field id 1: a bool or empty group is allowed only directly inside")]
fn ac4_typed_bool_inside_when_is_refused() {
    let _ = Scheme::<BoolRow>::new(
        1,
        [
            n_field(0).into(),
            SchemeItem::when(1, eq(0, Value::U8(1)), [on_field(1).into()]),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 1: a bool or empty group is allowed only directly inside")]
fn ac4_typed_bool_inside_times_is_refused() {
    let _ = Scheme::<BoolRow>::new(
        1,
        [
            n_field(0).into(),
            SchemeItem::times(1, 0, [on_field(1).into()]),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 0: a bool or empty group is allowed only directly inside")]
fn ac4_empty_group_inside_a_plain_group_is_refused() {
    MapScheme::new(1, vec![group(0, "g", vec![group(0, "0", vec![]), u8("1")])]);
}

#[test]
#[should_panic(expected = "field id 0: a bool or empty group is allowed only directly inside")]
fn ac4_empty_group_inside_a_group_under_flags_is_refused() {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g", vec![group(0, "0", vec![]), u8("1")])],
        )],
    );
}

#[test]
#[should_panic(expected = "field id 0: a bool or empty group is allowed only directly inside")]
fn ac4_empty_group_inside_repeat_is_refused() {
    MapScheme::new(1, vec![repeat(0, vec![group(0, "0", vec![])])]);
}

#[test]
#[should_panic(expected = "field id 0: a bool or empty group is allowed only directly inside")]
fn ac4_empty_group_as_a_list_element_is_refused() {
    MapScheme::new(1, vec![list("L", group(0, "0", vec![]))]);
}

// AC-5

fn typed_flags_scheme() -> Scheme<BoolRow> {
    Scheme::new(
        1,
        [SchemeItem::flags(
            0,
            [on_field(0).into(), n_field(1).into()],
        )],
    )
}

fn typed_unpack(scheme: &Scheme<BoolRow>, raw: &[u8]) -> BoolRow {
    let mut got = BoolRow::default();
    BinaryPacker::unpack_with(raw, &mut [&mut scheme.on(|row| got = row)]).expect("unpack");
    got
}

#[test]
fn ac5_typed_bool_in_flags_sets_the_bit_only_for_true() {
    let scheme = typed_flags_scheme();
    let pack_hex = |on| to_hex(&BinaryPacker::pack(&scheme, &BoolRow { on, n: 7 }).expect("pack"));
    assert_eq!(pack_hex(Some(true)), "010307");
    assert_eq!(pack_hex(Some(false)), "010207");
    assert_eq!(pack_hex(None), "010207");
    assert_eq!(
        typed_unpack(&scheme, &[0x01, 0x03, 0x07]),
        BoolRow {
            on: Some(true),
            n: 7
        }
    );
    assert_eq!(
        typed_unpack(&scheme, &[0x01, 0x02, 0x07]),
        BoolRow { on: None, n: 7 }
    );
}

fn flag_byte_bool_scheme() -> MapScheme {
    let f = flag_byte("f");
    MapScheme::new(1, vec![f.byte(), f.bit(group(1, "1", vec![]))])
}

#[test]
fn ac5_flag_byte_bool_round_trips_when_set() {
    let scheme = flag_byte_bool_scheme();
    let raw = pack(&scheme, &values(&[("1", Value::U8(1))])).expect("pack");
    assert_eq!(to_hex(&raw), "0101");
    let got = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(got.get("1"), Some(&Some(Value::U8(1))));
}

#[test]
fn ac5_flag_byte_bool_absent_when_clear() {
    let scheme = flag_byte_bool_scheme();
    let raw = pack(&scheme, &Values::new()).expect("pack");
    assert_eq!(to_hex(&raw), "0100");
    let got = unpack(&scheme, &raw).expect("unpack");
    assert_eq!(got.get("1"), None);
}

#[test]
fn ac5_map_bool_zero_under_flags_leaves_the_bit_clear() {
    let scheme = MapScheme::new(1, vec![flags(0, "f", vec![group(0, "0", vec![]), u8("1")])]);
    let vals = values(&[("0", Value::U8(0)), ("1", Value::U8(7))]);
    assert_eq!(hex(&scheme, &vals), "010207");
    let vals = values(&[("0", Value::U8(1)), ("1", Value::U8(7))]);
    assert_eq!(hex(&scheme, &vals), "010307");
}

#[test]
fn ac5_map_bool_zero_under_a_flag_bit_leaves_the_bit_clear() {
    let scheme = flag_byte_bool_scheme();
    assert_eq!(hex(&scheme, &values(&[("1", Value::U8(0))])), "0100");
}
