use crate::walk::{pack, unpack};
use crate::{
    dict, eq, flag_byte, flags, group, insert, list, repeat, times, to_hex, u2, u32, u8, utf8,
    when, BinaryPacker, BoundField, MapScheme, PackError, Scheme, SchemeItem, ShortPacket,
    UnpackError, Value, Values, DEFAULT_MAX_BYTES, DEFAULT_MAX_SLOTS,
};
use std::time::Instant;

// AZ-2354: pack has one output budget, `max_bytes` (default 16 MiB, type byte included), and
// charges `max_slots` per round as unpack does. Rows of `reference_loop20_budget.md` that Rust can
// express; a list or dict element cannot hold a `times` here, so rows 2, 3, 22, 23 do not apply.

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn refusal(scheme: &MapScheme, vals: &Values) -> String {
    match pack(scheme, vals) {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

fn over_bytes(member: &str, need: usize, limit: usize) -> String {
    format!("{member}: the packet would be {need} bytes, above the limit of {limit} bytes")
}

fn over_slots(member: &str, need: usize, limit: usize) -> String {
    format!("{member}: the rounds would hold {need} slots, above the limit of {limit} slots")
}

fn a_text(len: usize) -> Value {
    Value::Str("a".repeat(len))
}

fn short(field: &str, left: usize) -> UnpackError {
    UnpackError::Short(ShortPacket {
        field: field.to_string(),
        needed: 0,
        left,
    })
}

/// Row 1: `u32 n; times n { utf8 s }`
fn lone_utf8() -> MapScheme {
    MapScheme::new(1, vec![u32("n"), times(1, "n", vec![utf8("s")])])
}

/// Rows 17 to 21: `u32 n; times n { u8 k }`
fn counted_k() -> MapScheme {
    MapScheme::new(1, vec![u32("n"), times(1, "n", vec![u8("k")])])
}

/// Rows 14 to 16: `u32 n; times n { u8 m0 ... u8 m64 }`, 65 members.
fn wide_round() -> MapScheme {
    let members = (0..65).map(|i| u8(format!("m{i}"))).collect();
    MapScheme::new(1, vec![u32("n"), times(1, "n", members)])
}

fn wide_row() -> Values {
    let mut vals = row(&[("n", Value::U32(65_535))]);
    for i in 0..65 {
        insert(&mut vals, format!("m{i}"), Some(Value::U8(1)));
    }
    vals
}

#[test]
fn ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_at_once_naming_the_member() {
    // Arrange
    let vals = row(&[("n", Value::U32(65_535)), ("s", a_text(65_535))]);
    let started = Instant::now();

    // Act
    let message = refusal(&lone_utf8(), &vals);

    // Assert: refused at round 255, with 16 711 940 bytes written
    assert_eq!(message, over_bytes("s", 16_777_477, 16_777_216));
    assert!(
        started.elapsed().as_millis() < 1000,
        "{:?}",
        started.elapsed()
    );
}

#[test]
fn ac3_rows4_5_a_packet_of_exactly_max_bytes_packs_and_one_more_byte_is_refused() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]).with_max_bytes(64);

    // Act
    let at = pack(&scheme, &row(&[("s", a_text(61))])).expect("64 bytes");
    let over = refusal(&scheme, &row(&[("s", a_text(62))]));

    // Assert
    assert_eq!(to_hex(&at), format!("013d00{}", "61".repeat(61)));
    assert_eq!(over, over_bytes("s", 65, 64));
}

fn rounds_of_k(count: usize) -> Values {
    let rounds = (0..count)
        .map(|_| row(&[("k", Value::U8(7))]))
        .collect::<Vec<_>>();
    row(&[("__repeat__", Value::Groups(rounds))])
}

#[test]
fn ac3_rows6_7_a_repeat_round_that_passes_max_bytes_is_refused_at_the_64th_round() {
    // Arrange
    let scheme = MapScheme::new(1, vec![repeat(0, vec![u8("k")])]).with_max_bytes(64);

    // Act
    let at = pack(&scheme, &rounds_of_k(63)).expect("64 bytes");
    let over = refusal(&scheme, &rounds_of_k(64));

    // Assert
    assert_eq!(to_hex(&at), format!("01{}", "07".repeat(63)));
    assert_eq!(over, over_bytes("k", 65, 64));
}

#[test]
fn ac3_rows8_9_the_type_byte_counts() {
    // Arrange
    let bare = MapScheme::new(1, vec![]).with_max_bytes(1);
    let one = MapScheme::new(1, vec![u8("a")]).with_max_bytes(1);

    // Act
    let packed = pack(&bare, &Values::new()).map(|raw| to_hex(&raw));
    let over = refusal(&one, &row(&[("a", Value::U8(1))]));

    // Assert
    assert_eq!(packed, Ok("01".to_string()));
    assert_eq!(over, over_bytes("a", 2, 1));
}

#[test]
fn ac3_rows10_11_12_a_flag_byte_is_named_by_its_name_a_combined_flags_byte_by_its_first_member() {
    // Arrange
    let fb = flag_byte("m");
    let split = MapScheme::new(1, vec![fb.byte(), fb.bit(u8("c"))]).with_max_bytes(1);
    let combined = MapScheme::new(1, vec![flags(0, "f", vec![u8("c")])]).with_max_bytes(1);
    let through_times = MapScheme::new(
        1,
        vec![u8("n"), flags(1, "f", vec![times(1, "n", vec![u8("k")])])],
    )
    .with_max_bytes(2);
    let c = row(&[("c", Value::U8(1))]);

    // Act
    let by_split = refusal(&split, &c);
    let by_combined = refusal(&combined, &c);
    let by_times = refusal(
        &through_times,
        &row(&[("n", Value::U8(1)), ("k", Value::U8(3))]),
    );

    // Assert
    assert_eq!(by_split, over_bytes("m", 2, 1));
    assert_eq!(by_combined, over_bytes("c", 2, 1));
    assert_eq!(by_times, over_bytes("k", 3, 2));
}

#[test]
fn ac3_row13_a_list_count_prefix_is_named_by_the_list_and_a_dict_key_by_the_dict() {
    // Arrange
    let empty = MapScheme::new(1, vec![list("xs", u8("v"))]).with_max_bytes(2);
    let keyed = MapScheme::new(1, vec![dict("d", u8("v"))]).with_max_bytes(6);
    let mut map = std::collections::BTreeMap::new();
    map.insert("key".to_string(), Value::U8(1));

    // Act
    let by_count = refusal(&empty, &row(&[("xs", Value::List(vec![]))]));
    let by_key = refusal(&keyed, &row(&[("d", Value::Map(map))]));

    // Assert
    assert_eq!(by_count, over_bytes("xs", 3, 2));
    assert_eq!(by_key, over_bytes("d", 8, 6));
}

#[test]
fn ac3_a_u2_is_named_by_its_first_slot() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u2(&["a", "b"])]).with_max_bytes(1);

    // Act
    let message = refusal(&scheme, &row(&[("a", Value::U8(1)), ("b", Value::U8(2))]));

    // Assert
    assert_eq!(message, over_bytes("a", 2, 1));
}

#[test]
fn ac4_row14_a_round_that_passes_max_slots_is_refused_before_its_first_byte() {
    // Act
    let message = refusal(&wide_round(), &wide_row());

    // Assert: 64 527 rounds of 65 slots are charged, the next would hold 4 194 320
    assert_eq!(message, over_slots("m0", 4_194_320, DEFAULT_MAX_SLOTS));
}

#[test]
fn ac4_rows15_16_with_max_slots_raised_it_packs_and_unpack_refuses_at_the_same_round() {
    // Arrange
    let raised = wide_round().with_limits(65_535, 4_259_775);

    // Act
    let wire = pack(&raised, &wide_row()).expect("pack");
    let back = unpack(&raised, &wire).expect("unpack");
    let by_default = unpack(&wide_round(), &wire);

    // Assert
    assert_eq!(wire.len(), 4_259_780);
    assert_eq!(to_hex(&wire[..16]), "01ffff00000101010101010101010101");
    assert_eq!(to_hex(&wire[wire.len() - 16..]), "01".repeat(16));
    assert_eq!(
        back.get("m64"),
        Some(&Some(Value::List(vec![Value::U8(1); 65_535])))
    );
    assert_eq!(by_default, Err(short("times", 65_520)));
}

#[test]
fn row17_a_packet_at_both_limits_packs() {
    // Arrange
    let scheme = counted_k().with_limits(65_535, 3).with_max_bytes(8);

    // Act
    let wire = pack(&scheme, &row(&[("n", Value::U32(3)), ("k", Value::U8(7))]));

    // Assert
    assert_eq!(
        wire.map(|raw| to_hex(&raw)),
        Ok("0103000000070707".to_string())
    );
}

#[test]
fn order_rows18_to_21_slots_are_checked_before_the_bytes_of_a_round() {
    // Arrange
    let ten = row(&[("n", Value::U32(10)), ("k", Value::U8(7))]);
    let both = counted_k().with_limits(65_535, 3).with_max_bytes(8);
    let bytes_first = counted_k().with_limits(65_535, 3).with_max_bytes(7);
    let rounds = counted_k().with_limits(5, 3).with_max_bytes(8);
    let count_field = counted_k().with_limits(5, 3).with_max_bytes(4);

    // Act
    let by_slots = refusal(&both, &ten);
    let by_bytes = refusal(&bytes_first, &ten);
    let by_rounds = refusal(&rounds, &ten);
    let by_count = refusal(&count_field, &ten);

    // Assert
    assert_eq!(by_slots, over_slots("k", 4, 3));
    assert_eq!(by_bytes, over_bytes("k", 8, 7));
    assert!(
        by_rounds.contains("count 10") && by_rounds.contains("'k'"),
        "{by_rounds}"
    );
    assert_eq!(by_count, over_bytes("n", 5, 4));
}

#[test]
fn width_a_round_is_charged_what_unpack_charges_and_pack_refuses_where_unpack_would() {
    // Arrange: `repeat { u8 a; group g { u8 b } }`, a round holds a, g and b
    let scheme = |slots| {
        MapScheme::new(
            1,
            vec![repeat(0, vec![u8("a"), group(1, "g", vec![u8("b")])])],
        )
        .with_limits(65_535, slots)
    };
    let rounds = (1..=2u8)
        .map(|i| row(&[("a", Value::U8(i)), ("b", Value::U8(i + 2))]))
        .collect::<Vec<_>>();
    let vals = row(&[("__repeat__", Value::Groups(rounds))]);

    // Act
    let wire = pack(&scheme(6), &vals).map(|raw| to_hex(&raw));
    let by_pack = refusal(&scheme(5), &vals);
    let by_unpack = unpack(&scheme(5), &[1, 1, 3, 2, 4]);

    // Assert
    assert_eq!(wire, Ok("0101030204".to_string()));
    assert_eq!(by_pack, over_slots("a", 6, 5));
    assert_eq!(by_unpack, Err(short("repeat", 2)));
}

#[test]
fn scope_one_slot_counter_is_shared_by_a_repeat_round_and_the_times_inside_it() {
    // Arrange: `repeat { u8 n; times n { u8 k } }`: a round holds n and k (2 slots), the inner
    // times charges 1 per round
    let scheme = MapScheme::new(
        1,
        vec![repeat(0, vec![u8("n"), times(1, "n", vec![u8("k")])])],
    )
    .with_limits(65_535, 5);
    let round = |k: u8| {
        let mut r = row(&[("n", Value::U8(2))]);
        let mut inner = Values::new();
        insert(&mut inner, "k", Some(Value::U8(k)));
        insert(
            &mut r,
            "__times_1",
            Some(Value::Groups(vec![inner.clone(), inner])),
        );
        r
    };
    let one = row(&[("__repeat__", Value::Groups(vec![round(1)]))]);
    let two = row(&[("__repeat__", Value::Groups(vec![round(1), round(2)]))]);

    // Act
    let packed = pack(&scheme, &one).map(|raw| to_hex(&raw));
    let message = refusal(&scheme, &two);

    // Assert: a round of n = 2 charges 2 for itself and 1 for each inner round, 4 in all
    assert_eq!(packed, Ok("01020101".to_string()));
    assert_eq!(message, over_slots("n", 6, 5));
}

#[test]
fn ac5_rows26_28_limits_api() {
    // Arrange
    let scheme = counted_k();

    // Act
    let raised = scheme.clone().with_max_bytes(64);
    let kept = raised.clone().with_limits(9, 9);
    let wire = counted_k().with_limits(3, 3).max_bytes();

    // Assert
    assert_eq!(scheme.max_bytes(), DEFAULT_MAX_BYTES);
    assert_eq!(DEFAULT_MAX_BYTES, 16_777_216);
    assert_eq!(kept.max_bytes(), 64);
    assert_eq!(wire, DEFAULT_MAX_BYTES);
    assert_eq!(
        pack(
            &counted_k().with_limits(3, 3),
            &row(&[("n", Value::U32(3)), ("k", Value::U8(7))])
        )
        .map(|raw| to_hex(&raw)),
        Ok("0103000000070707".to_string())
    );
}

#[test]
#[should_panic(expected = "max_bytes must be at least 1")]
fn ac5_row27_a_zero_max_bytes_is_refused() {
    let _ = counted_k().with_max_bytes(0);
}

#[test]
#[should_panic(expected = "max_bytes must be at least 1")]
fn ac5_row27_a_zero_max_bytes_is_refused_on_a_typed_scheme_too() {
    let _: Scheme<Typed> = typed().with_max_bytes(0);
}

#[derive(Default)]
struct Typed {
    a: u8,
}

fn typed() -> Scheme<Typed> {
    Scheme::new(
        1,
        vec![SchemeItem::from(BoundField::u8(
            0,
            |r: &Typed| r.a,
            |r: &mut Typed, v| r.a = v,
        ))],
    )
}

#[test]
fn ac5_a_typed_scheme_carries_max_bytes() {
    // Arrange
    let scheme = typed().with_max_bytes(1);

    // Act
    let result = BinaryPacker::pack(&scheme, &Typed { a: 1 });
    let fits = BinaryPacker::pack(&typed().with_max_bytes(2), &Typed { a: 1 });

    // Assert
    assert_eq!(scheme.max_bytes(), 1);
    assert_eq!(result, Err(PackError::Type(over_bytes("0", 2, 1))));
    assert_eq!(fits.map(|raw| to_hex(&raw)), Ok("0101".to_string()));
}

#[test]
fn ac6_a_when_and_flags_row_under_the_budget_keeps_its_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("mode"),
            when(1, eq("mode", Value::U8(1)), vec![u8("speed")]),
        ],
    );

    // Act
    let wire = pack(
        &scheme,
        &row(&[("mode", Value::U8(1)), ("speed", Value::U8(9))]),
    );

    // Assert
    assert_eq!(wire.map(|raw| to_hex(&raw)), Ok("010109".to_string()));
}
