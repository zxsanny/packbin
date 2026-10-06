use packbin::{
    eq, flags, group, repeat, times, u32, u8, unpack, when, BinaryPacker, BoundField, MapScheme,
    Scheme, SchemeItem, ShortPacket, UnpackError, Value, Values, DEFAULT_MAX_ROUNDS,
    DEFAULT_MAX_SLOTS,
};

fn short(field: &str, needed: usize, left: usize) -> UnpackError {
    UnpackError::Short(ShortPacket {
        field: field.to_string(),
        needed,
        left,
    })
}

fn packet(head: &[u8], round: u8, rounds: usize) -> Vec<u8> {
    let mut bytes = head.to_vec();
    bytes.resize(head.len() + rounds, round);
    bytes
}

fn groups(values: &Values, key: &str) -> usize {
    match values.get(key) {
        Some(Some(Value::Groups(g))) => g.len(),
        other => panic!("{key} is not groups: {other:?}"),
    }
}

fn repeat_scheme() -> MapScheme {
    MapScheme::new(1, vec![repeat(0, vec![u8("0")])])
}

fn times_scheme() -> MapScheme {
    MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])
}

fn u32_times_scheme() -> MapScheme {
    MapScheme::new(1, vec![u32("0"), times(1, "0", vec![u8("1")])])
}

fn three_name_repeat() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![
                u8("0"),
                when(1, eq("0", Value::U8(1)), vec![u8("1"), u8("2")]),
            ],
        )],
    )
}

fn times_in_repeat() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(0, vec![u8("0"), times(1, "0", vec![u8("1")])])],
    )
}

#[derive(Default, Debug, PartialEq)]
struct Pt {
    v: u8,
}

#[derive(Default, Debug, PartialEq)]
struct Row {
    n: u8,
    pts: Vec<Pt>,
}

fn row_scheme(type_number: i32) -> Scheme<Row> {
    Scheme::new(
        type_number,
        [
            BoundField::u8(0, |r: &Row| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Row| &r.pts[..],
                |r, v| r.pts = v,
                [BoundField::u8(1, |p: &Pt| p.v, |p, v| p.v = v).into()],
            ),
        ],
    )
}

#[test]
fn ac1_defaults_constants_and_with_limits() {
    // Arrange
    let map = repeat_scheme();
    let typed = row_scheme(1);

    // Act
    let tuned = map.clone().with_limits(10, DEFAULT_MAX_SLOTS);
    let typed_tuned = row_scheme(1).with_limits(10, 20);

    // Assert
    assert_eq!(DEFAULT_MAX_ROUNDS, 65_535);
    assert_eq!(DEFAULT_MAX_SLOTS, 4_194_304);
    assert_eq!((map.max_rounds(), map.max_slots()), (65_535, 4_194_304));
    assert_eq!((typed.max_rounds(), typed.max_slots()), (65_535, 4_194_304));
    assert_eq!((tuned.max_rounds(), tuned.max_slots()), (10, 4_194_304));
    assert_eq!(
        (typed_tuned.max_rounds(), typed_tuned.max_slots()),
        (10, 20)
    );
}

#[test]
fn ac1_existing_call_sites_compile_and_behave_unchanged() {
    // Arrange: a scheme built, unpacked and dispatched with no mention of limits
    let map = MapScheme::new(1, vec![u8("0")]);
    let typed = row_scheme(2);
    let mut got = None;

    // Act
    let values = unpack(&map, &[1, 9]);
    let routed = BinaryPacker::unpack_with(&[2, 1, 7], &mut [&mut typed.on(|r| got = Some(r))]);

    // Assert
    assert_eq!(values.expect("unpack").get("0"), Some(&Some(Value::U8(9))));
    assert_eq!(routed, Ok(()));
    assert_eq!(
        got,
        Some(Row {
            n: 1,
            pts: vec![Pt { v: 7 }]
        })
    );
}

#[test]
fn ac2_repeat_default_limit_is_65535_rounds() {
    // Arrange
    let scheme = repeat_scheme();
    let at_limit = packet(&[1], 0xaa, 65_535);
    let past_limit = packet(&[1], 0xaa, 65_536);

    // Act
    let accepted = unpack(&scheme, &at_limit);
    let refused = unpack(&scheme, &past_limit);

    // Assert
    assert_eq!(
        groups(&accepted.expect("at the limit"), "__repeat__"),
        65_535
    );
    assert_eq!(refused, Err(short("repeat", 0, 1)));
}

#[test]
fn ac3_repeat_refused_when_round_four_would_start() {
    // Arrange
    let scheme = repeat_scheme().with_limits(3, DEFAULT_MAX_SLOTS);

    // Act
    let accepted = unpack(&scheme, &[1, 0xaa, 0xbb, 0xcc]);
    let refused = unpack(&scheme, &[1, 0xaa, 0xbb, 0xcc, 0xdd]);

    // Assert
    assert_eq!(groups(&accepted.expect("3 rounds"), "__repeat__"), 3);
    assert_eq!(refused, Err(short("repeat", 0, 1)));
}

#[test]
fn ac4_times_refused_when_round_four_would_start() {
    // Arrange
    let scheme = times_scheme().with_limits(3, DEFAULT_MAX_SLOTS);

    // Act
    let three = unpack(&scheme, &[1, 3, 9, 9, 9]);
    let four_present = unpack(&scheme, &[1, 4, 9, 9, 9, 9]);
    let four_counted = unpack(&scheme, &[1, 4, 9, 9, 9]);
    let huge_count = unpack(&scheme, &[1, 0xff, 9]);
    let two_present = unpack(&scheme, &[1, 3, 9, 9]);

    // Assert
    assert_eq!(groups(&three.expect("3 rounds"), "__times_1"), 3);
    assert_eq!(four_present, Err(short("times", 0, 1)));
    assert_eq!(four_counted, Err(short("times", 0, 0)));
    assert_eq!(huge_count, Err(short("1", 1, 0)));
    assert_eq!(two_present, Err(short("1", 1, 0)));
}

#[test]
fn ac5_times_default_limit_is_65535_rounds() {
    // Arrange
    let scheme = u32_times_scheme();
    let le = |count: u32| count.to_le_bytes();
    let with = |count: u32, rounds: usize| {
        let mut head = vec![1];
        head.extend_from_slice(&le(count));
        packet(&head, 9, rounds)
    };

    // Act
    let at_limit = unpack(&scheme, &with(65_535, 65_535));
    let past_limit = unpack(&scheme, &with(65_536, 65_536));
    let huge_long = unpack(&scheme, &with(u32::MAX, 65_536));
    let huge_exact = unpack(&scheme, &with(u32::MAX, 65_535));
    let huge_one = unpack(&scheme, &[1, 0xff, 0xff, 0xff, 0xff, 0]);

    // Assert
    assert_eq!(
        groups(&at_limit.expect("at the limit"), "__times_1"),
        65_535
    );
    assert_eq!(past_limit, Err(short("times", 0, 1)));
    assert_eq!(huge_long, Err(short("times", 0, 1)));
    assert_eq!(huge_exact, Err(short("times", 0, 0)));
    assert_eq!(huge_one, Err(short("1", 1, 0)));
}

#[test]
fn ac6_slot_limit_refuses_the_round_that_would_pass_it() {
    // Arrange: a round holds 3 slots
    let scheme = three_name_repeat().with_limits(DEFAULT_MAX_ROUNDS, 6);

    // Act
    let at_limit = unpack(&scheme, &[1, 0, 0]);
    let one_more = unpack(&scheme, &[1, 0, 0, 0]);
    let two_more = unpack(&scheme, &[1, 0, 0, 0, 0]);

    // Assert
    assert_eq!(groups(&at_limit.expect("2 x 3 = 6"), "__repeat__"), 2);
    assert_eq!(one_more, Err(short("repeat", 0, 1)));
    assert_eq!(two_more, Err(short("repeat", 0, 2)));
}

#[test]
fn ac7_slot_total_is_shared_by_the_fields_of_one_call() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            times(1, "0", vec![u8("1")]),
            times(2, "0", vec![u8("2")]),
        ],
    );
    let bytes = [1, 2, 0xaa, 0xbb, 0xcc, 0xdd];

    // Act
    let roomy = unpack(&scheme.clone().with_limits(3, 4), &bytes);
    let tight = unpack(&scheme.with_limits(3, 3), &bytes);

    // Assert
    let roomy = roomy.expect("2 + 2 slots");
    assert_eq!(groups(&roomy, "__times_1"), 2);
    assert_eq!(groups(&roomy, "__times_2"), 2);
    assert_eq!(tight, Err(short("times", 0, 1)));
}

#[test]
fn ac8_times_inside_repeat_counts_rounds_afresh_and_slots_together() {
    // Arrange
    let scheme = times_in_repeat();
    let rounds2 = scheme.clone().with_limits(2, DEFAULT_MAX_SLOTS);
    let slots5 = scheme.with_limits(DEFAULT_MAX_ROUNDS, 5);

    // Act
    let three_outer = unpack(&rounds2, &[1, 1, 7, 1, 7, 1, 7]);
    let inner_three = unpack(&rounds2, &[1, 3, 7, 7, 7]);
    let inner_two = unpack(&rounds2, &[1, 2, 7, 7]);
    let four_slots = unpack(&slots5, &[1, 2, 7, 7]);
    let six_slots = unpack(&slots5, &[1, 2, 7, 7, 0]);

    // Assert
    assert_eq!(three_outer, Err(short("repeat", 0, 2)));
    assert_eq!(inner_three, Err(short("times", 0, 1)));
    assert_eq!(groups(&inner_two.expect("2 inner rounds"), "__repeat__"), 1);
    assert_eq!(
        groups(&four_slots.expect("2 + 1 + 1 slots"), "__repeat__"),
        1
    );
    assert_eq!(six_slots, Err(short("repeat", 0, 1)));
}

#[test]
fn ac9_typed_times_rows_are_limited_and_the_handler_is_not_called() {
    // Arrange
    let scheme = row_scheme(1).with_limits(3, DEFAULT_MAX_SLOTS);
    let run = |bytes: &[u8]| {
        let mut rows = Vec::new();
        let result = BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(|r| rows.push(r))]);
        (result, rows)
    };

    // Act
    let (ok, ok_rows) = run(&[1, 3, 7, 8, 9]);
    let (refused, refused_rows) = run(&[1, 4, 7, 8, 9, 1]);
    let (short_read, short_rows) = run(&[1, 0xff, 7]);

    // Assert
    assert_eq!(ok, Ok(()));
    assert_eq!(
        ok_rows,
        vec![Row {
            n: 3,
            pts: vec![Pt { v: 7 }, Pt { v: 8 }, Pt { v: 9 }]
        }]
    );
    assert_eq!(refused, Err(short("times", 0, 1)));
    assert!(refused_rows.is_empty());
    assert_eq!(short_read, Err(short("1", 1, 0)));
    assert!(short_rows.is_empty());
}

fn flags_scheme() -> MapScheme {
    let bools = (0..8u32).map(|i| group(i, i.to_string(), vec![])).collect();
    MapScheme::new(1, vec![repeat(0, vec![flags(0, "f", bools)])])
}

#[test]
fn ac10_refused_one_mib_packets_stop_at_round_65536() {
    // Arrange
    let one_byte = repeat_scheme();
    let eight_bits = flags_scheme();
    let mib = 1_048_576;

    // Act
    let bytes_refused = unpack(&one_byte, &packet(&[1], 0, mib));
    let bytes_accepted = unpack(&one_byte, &packet(&[1], 0, 65_535));
    let flags_refused = unpack(&eight_bits, &packet(&[1], 0xff, mib));
    let flags_accepted = unpack(&eight_bits, &packet(&[1], 0xff, 65_535));

    // Assert
    assert_eq!(bytes_refused, Err(short("repeat", 0, 983_041)));
    assert_eq!(
        groups(&bytes_accepted.expect("65,535"), "__repeat__"),
        65_535
    );
    assert_eq!(flags_refused, Err(short("repeat", 0, 983_041)));
    assert_eq!(
        groups(&flags_accepted.expect("65,535"), "__repeat__"),
        65_535
    );
}

#[test]
fn ac11_limits_belong_to_the_scheme() {
    // Arrange
    let base = repeat_scheme();
    let strict = base.clone().with_limits(3, DEFAULT_MAX_SLOTS);
    let loose = row_scheme(1);
    let tight = row_scheme(2).with_limits(2, DEFAULT_MAX_SLOTS);
    let (mut rows, mut loose_two, mut tight_two, mut tight_one) =
        (Vec::new(), Vec::new(), Vec::new(), Vec::new());

    // Act
    let from_base = unpack(&base, &[1, 0xaa, 0xbb, 0xcc, 0xdd]);
    let from_strict = unpack(&strict, &[1, 0xaa, 0xbb, 0xcc, 0xdd]);
    let type_two = BinaryPacker::unpack_with(
        &[2, 3, 7, 8, 9],
        &mut [
            &mut loose.on(|r| loose_two.push(r)),
            &mut tight.on(|r| tight_two.push(r)),
        ],
    );
    let type_one = BinaryPacker::unpack_with(
        &[1, 3, 7, 8, 9],
        &mut [
            &mut loose.on(|r| rows.push(r)),
            &mut tight.on(|r| tight_one.push(r)),
        ],
    );

    // Assert
    assert_eq!(groups(&from_base.expect("default limits"), "__repeat__"), 4);
    assert_eq!(from_strict, Err(short("repeat", 0, 1)));
    assert_eq!(type_two, Err(short("times", 0, 1)));
    assert_eq!(type_one, Ok(()));
    assert_eq!(
        rows,
        vec![Row {
            n: 3,
            pts: vec![Pt { v: 7 }, Pt { v: 8 }, Pt { v: 9 }]
        }]
    );
    assert!(loose_two.is_empty() && tight_two.is_empty() && tight_one.is_empty());
}

#[test]
#[should_panic(expected = "max_rounds")]
fn ac12_zero_max_rounds_is_refused_on_a_map_scheme() {
    repeat_scheme().with_limits(0, 1);
}

#[test]
#[should_panic(expected = "max_slots")]
fn ac12_zero_max_slots_is_refused_on_a_map_scheme() {
    repeat_scheme().with_limits(1, 0);
}

#[test]
#[should_panic(expected = "max_rounds")]
fn ac12_zero_max_rounds_is_refused_on_a_typed_scheme() {
    row_scheme(1).with_limits(0, 1);
}

#[test]
#[should_panic(expected = "max_slots")]
fn ac12_zero_max_slots_is_refused_on_a_typed_scheme() {
    row_scheme(1).with_limits(1, 0);
}

#[test]
fn ac12_usize_max_is_valid_and_lifts_the_default() {
    // Arrange
    let scheme = repeat_scheme().with_limits(usize::MAX, usize::MAX);

    // Act
    let values = unpack(&scheme, &packet(&[1], 0xaa, 65_536));

    // Assert
    assert_eq!(groups(&values.expect("no limit"), "__repeat__"), 65_536);
}
