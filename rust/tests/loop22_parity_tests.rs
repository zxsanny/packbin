use packbin::{
    bits, eq, flag_byte, flags, group, insert, pack, packed, repeat, sized, times, to_hex, u32, u8,
    unpack, when, Field, MapScheme, PackError, ShortPacket, UnpackError, Value, Values,
    DEFAULT_MAX_SLOTS,
};

// Loop 22 against `_docs/03_implementation/reference_loop22.md`: AZ-2410 (U11, section 1),
// AZ-2414 (U15, section 3a) and AZ-2415 (U17, section 2). An error is a `PackError`; the texts are
// TypeScript's where the row is new and Rust's own where it already had one.

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|x| n(*x)).collect())
}

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn text(result: Result<String, PackError>) -> String {
    match result {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

// ---- AZ-2410: a bits / packed / sized count behind a clear when, no value (row 56) ----

fn head() -> Vec<Field> {
    vec![u8("mode"), when(1, eq("mode", n(1)), vec![u8("c")])]
}

type Member = fn() -> Field;

fn members() -> Vec<(&'static str, Member)> {
    vec![
        ("bits", || bits("v", "c")),
        ("packed", || packed(1, "v", "c", 0)),
        ("sized", || sized("v", "c")),
    ]
}

fn placed(position: &str, member: Field) -> MapScheme {
    let mut fields = head();
    match position {
        "split" => {
            let fb = flag_byte("fb");
            fields.extend([fb.byte(), fb.bit(member)]);
        }
        _ => fields.push(flags(2, "f", vec![member])),
    }
    MapScheme::new(1, fields)
}

fn no_value(count: &Value) -> String {
    let n = match count {
        Value::U8(x) => u64::from(*x),
        Value::U64(x) => *x,
        other => panic!("not a count: {other:?}"),
    };
    format!(
        "v: the count c is {n} in the row, but no field wrote it (the when that holds it is \
         clear), so the member reads nothing; give the count 0, leave it out, or make the when \
         hold"
    )
}

#[test]
fn az2410_ac1_row_56_the_three_kinds_in_a_split_bit_and_a_combined_flags_are_refused() {
    for (kind, member) in members() {
        for position in ["split", "flags"] {
            // Arrange
            let scheme = placed(position, member());

            // Act
            let by_u8 = text(hex_of(&scheme, &v(&[("mode", n(0)), ("c", n(3))])));
            let by_u64 = text(hex_of(&scheme, &v(&[("mode", n(0)), ("c", Value::U64(4))])));

            // Assert: no bytes; the count prints as the row gives it
            assert_eq!(by_u8, no_value(&n(3)), "{kind} {position}");
            assert_eq!(by_u64, no_value(&Value::U64(4)), "{kind} {position}");
        }
    }
}

#[test]
fn az2410_ac2_rows_56a_to_56c_count_zero_count_left_out_and_a_holding_when_pack_unchanged() {
    for (kind, member) in members() {
        for position in ["split", "flags"] {
            // Arrange
            let scheme = placed(position, member());

            // Act
            let zero = hex_of(&scheme, &v(&[("mode", n(0)), ("c", n(0))]));
            let left_out = hex_of(&scheme, &v(&[("mode", n(0))]));
            let holding = hex_of(&scheme, &v(&[("mode", n(1)), ("c", n(3))]));

            // Assert
            assert_eq!(zero, Ok("010000".to_string()), "{kind} {position}");
            assert_eq!(left_out, Ok("010000".to_string()), "{kind} {position}");
            assert_eq!(holding, Ok("01010300".to_string()), "{kind} {position}");
        }
    }
}

#[test]
fn az2410_row_56d_a_packed_count_is_compared_after_its_bias() {
    // Arrange
    let scheme = placed("split", packed(1, "v", "c", -1));

    // Act
    let one = hex_of(&scheme, &v(&[("mode", n(0)), ("c", n(1))]));
    let three = text(hex_of(&scheme, &v(&[("mode", n(0)), ("c", n(3))])));

    // Assert
    assert_eq!(one, Ok("010000".to_string()));
    assert_eq!(three, no_value(&n(3)));
}

#[test]
fn az2410_ac3_the_plain_position_still_names_the_unwritten_count() {
    for (kind, member) in members() {
        // Arrange
        let mut fields = head();
        fields.push(member());
        let scheme = MapScheme::new(1, fields);

        // Act
        let result = pack(&scheme, &v(&[("mode", n(0)), ("c", n(3))]));

        // Assert
        assert_eq!(result, Err(PackError::Missing("c".to_string())), "{kind}");
    }
}

// ---- AZ-2414: a short list for a member under a flags in a times body ----

/// `u8 c; times(c) { flags { u8 v } }`
fn flags_only() -> MapScheme {
    MapScheme::new(
        1,
        vec![u8("c"), times(1, "c", vec![flags(1, "f", vec![u8("v")])])],
    )
}

/// `u8 c; times(c) { u8 w; flags { u8 v } }`
fn flags_beside_required() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("c"),
            times(1, "c", vec![u8("w"), flags(2, "f", vec![u8("v")])]),
        ],
    )
}

#[test]
fn az2414_ac1_rows_a1_to_a7_a_short_empty_full_or_lone_list_packs_the_typescript_bytes() {
    // Arrange
    let scheme = flags_only();
    let row = |extra: &[(&str, Value)]| {
        let mut vals = v(&[("c", n(2))]);
        for (name, value) in extra {
            insert(&mut vals, name, Some(value.clone()));
        }
        hex_of(&scheme, &vals)
    };

    // Act
    let (short, empty, absent, full, lone) = (
        row(&[("v", ints(&[5]))]),
        row(&[("v", ints(&[]))]),
        row(&[]),
        row(&[("v", ints(&[5, 6]))]),
        row(&[("v", n(5))]),
    );
    let zero = hex_of(&scheme, &v(&[("c", n(0))]));

    // Assert: A5 (`[5, undefined]`) has no Rust spelling, a list holds no null
    assert_eq!(short, Ok("0102010500".to_string()));
    assert_eq!(empty, Ok("01020000".to_string()));
    assert_eq!(absent, Ok("01020000".to_string()));
    assert_eq!(full, Ok("010201050106".to_string()));
    assert_eq!(lone, Ok("010201050105".to_string()));
    assert_eq!(zero, Ok("0100".to_string()));
}

#[test]
fn az2414_ac1_rows_a8_to_a11_a_required_member_beside_the_flags() {
    // Arrange
    let scheme = flags_beside_required();
    let row = |c: u8, w: &[u8], vs: &[u8]| {
        hex_of(&scheme, &v(&[("c", n(c)), ("w", ints(w)), ("v", ints(vs))]))
    };

    // Act
    let (short, empty, full, three) = (
        row(2, &[1, 2], &[5]),
        row(2, &[1, 2], &[]),
        row(2, &[1, 2], &[5, 6]),
        row(3, &[1, 2, 3], &[5]),
    );

    // Assert
    assert_eq!(short, Ok("01020101050200".to_string()));
    assert_eq!(empty, Ok("010201000200".to_string()));
    assert_eq!(full, Ok("0102010105020106".to_string()));
    assert_eq!(three, Ok("010301010502000300".to_string()));
}

#[test]
fn az2414_two_members_under_one_flags_are_read_by_round_independently() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("c"),
            times(1, "c", vec![flags(1, "f", vec![u8("v"), u8("x")])]),
        ],
    );

    // Act
    let both = hex_of(
        &scheme,
        &v(&[("c", n(2)), ("v", ints(&[5])), ("x", ints(&[7, 8]))]),
    );
    let second_only = hex_of(&scheme, &v(&[("c", n(2)), ("x", ints(&[7]))]));

    // Assert: TypeScript gives the same two rows
    assert_eq!(both, Ok("01020305070208".to_string()));
    assert_eq!(second_only, Ok("0102020700".to_string()));
}

#[test]
fn az2414_a_list_longer_than_the_count_or_for_count_zero_is_refused_a_lone_value_for_zero_packs() {
    // Arrange
    let scheme = flags_only();

    // Act
    let longer = text(hex_of(&scheme, &v(&[("c", n(2)), ("v", ints(&[5, 6, 7]))])));
    let zero_list = text(hex_of(&scheme, &v(&[("c", n(0)), ("v", ints(&[5]))])));
    let zero_lone = hex_of(&scheme, &v(&[("c", n(0)), ("v", n(5))]));
    let zero_empty = hex_of(&scheme, &v(&[("c", n(0)), ("v", ints(&[]))]));

    // Assert: TypeScript: `v: 3 items, times count 2`, `v: 1 items, times count 0`, then packs
    assert_eq!(longer, "times at id 1: 'v' has 3 items, count is 2");
    assert_eq!(zero_list, "times at id 1: 'v' has 1 items, count is 0");
    assert_eq!(zero_lone, Ok("0100".to_string()));
    assert_eq!(zero_empty, Ok("0100".to_string()));
}

#[test]
fn az2414_a_list_for_a_member_under_a_when_is_still_refused() {
    // Arrange: out of the spec's scope; the README rule for a `when` member stays
    let scheme = MapScheme::new(
        1,
        vec![
            u8("c"),
            times(1, "c", vec![u8("k"), when(2, eq("k", n(1)), vec![u8("w")])]),
        ],
    );

    // Act
    let message = text(hex_of(
        &scheme,
        &v(&[("c", n(2)), ("k", ints(&[1, 0])), ("w", ints(&[7]))]),
    ));

    // Assert
    assert_eq!(
        message,
        "times at id 1: 'w' is under a flags or when; give its values per round under '__times_1'"
    );
}

#[test]
fn az2414_ac2_a_repeat_given_per_name_lists_is_still_refused() {
    // Arrange: the AZ-2383 row `repeat { u8 w; flags { u8 v } }`, `{w:[1,2], v:[5]}`
    let scheme = MapScheme::new(
        1,
        vec![repeat(0, vec![u8("w"), flags(1, "f", vec![u8("v")])])],
    );

    // Act
    let result = hex_of(&scheme, &v(&[("w", ints(&[1, 2])), ("v", ints(&[5]))]));

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(m)) if m.starts_with("repeat at id 0: 'w' is given without '__repeat__' groups")),
        "{result:?}"
    );
}

#[test]
fn az2414_shape_b_a_times_that_is_a_flags_member_is_refused_for_a_short_list_as_in_typescript() {
    // Arrange: rows B1 to B6; each scheme puts the times in the flag bit
    let fb = flag_byte("fb");
    let combined = MapScheme::new(
        1,
        vec![flags(0, "f", vec![u8("n"), times(1, "n", vec![u8("pt")])])],
    );
    let after_count = MapScheme::new(
        1,
        vec![u8("n"), flags(1, "f", vec![times(1, "n", vec![u8("pt")])])],
    );
    let split = MapScheme::new(
        1,
        vec![u8("n"), fb.byte(), fb.bit(times(2, "n", vec![u8("pt")]))],
    );
    let missing = Err(PackError::Missing("pt".to_string()));

    for (label, scheme) in [("B1", &combined), ("B4", &after_count), ("B6", &split)] {
        // Act
        let short = hex_of(scheme, &v(&[("n", n(2)), ("pt", ints(&[5]))]));
        let empty = hex_of(scheme, &v(&[("n", n(2)), ("pt", ints(&[]))]));

        // Assert
        assert_eq!(short, missing, "{label}");
        assert_eq!(empty, missing, "{label}");
    }
    let full = hex_of(&combined, &v(&[("n", n(2)), ("pt", ints(&[5, 6]))]));
    let lone = hex_of(&combined, &v(&[("n", n(2)), ("pt", n(5))]));
    assert_eq!(full, Ok("0103020506".to_string()));
    assert_eq!(lone, Ok("0103020505".to_string()));
    assert_eq!(
        hex_of(&after_count, &v(&[("n", n(2)), ("pt", ints(&[5, 6]))])),
        Ok("0102010506".to_string())
    );
    assert_eq!(
        hex_of(&after_count, &v(&[("n", n(0))])),
        Ok("010000".to_string())
    );
}

#[test]
fn az2414_ac3_the_packed_bytes_unpack_to_the_rounds_and_pack_again() {
    // Arrange
    let scheme = flags_only();
    let raw = pack(&scheme, &v(&[("c", n(2)), ("v", ints(&[5]))])).expect("pack");

    // Act
    let back = unpack(&scheme, &raw).expect("unpack");
    let again = pack(&scheme, &back).expect("repack");

    // Assert: the rounds say which one holds `v`; the list holds the rounds that read it
    assert_eq!(to_hex(&raw), "0102010500");
    assert_eq!(back.get("v"), Some(&Some(ints(&[5]))));
    assert_eq!(to_hex(&again), "0102010500");
}

#[test]
fn az2414_a_group_under_the_flags_is_read_by_round_too() {
    // Arrange: `bool on` is an empty group; the second round's bit is clear
    let scheme = MapScheme::new(
        1,
        vec![
            u8("c"),
            times(1, "c", vec![flags(1, "f", vec![group(1, "on", vec![])])]),
        ],
    );

    // Act
    let wire = hex_of(&scheme, &v(&[("c", n(2)), ("on", ints(&[1]))]));

    // Assert: README, `u8 c; times(c, flags(bool on))` with `{c: 2, on: [True]}` packs `01 02 01 00`
    assert_eq!(wire, Ok("01020100".to_string()));
}

// ---- AZ-2415: default maxSlots 1 048 576 ----

/// `u32 n; times(n) { 64 u8 }`, the widest body that fits 65 535 rounds under the old limit.
fn sixty_four_wide() -> MapScheme {
    let body: Vec<Field> = (0..64).map(|i| u8(format!("k{i}"))).collect();
    MapScheme::new(1, vec![u32("n"), times(1, "n", body)])
}

fn sixty_four_wide_packet() -> Vec<u8> {
    let mut raw = vec![1u8; 1 + 4 + 65_535 * 64];
    raw[1..5].copy_from_slice(&65_535u32.to_le_bytes());
    raw
}

#[test]
fn az2415_ac1_the_default_is_a_quarter_of_the_old_one() {
    assert_eq!(DEFAULT_MAX_SLOTS, 1_048_576);
    assert_eq!(sixty_four_wide().max_slots(), 1_048_576);
}

#[test]
fn az2415_ac2_a_4_2_mb_packet_of_64_slot_rounds_is_refused_at_the_slot_limit() {
    // Arrange: 4 194 240 slots, under the old limit and four times the new one
    let raw = sixty_four_wide_packet();

    // Act
    let result = unpack(&sixty_four_wide(), &raw);

    // Assert: 16 384 rounds of 64 slots fill 1 048 576; round 16 385 is the refused one, with
    // the 3 145 664 bytes of the other 49 151 rounds still unread
    assert_eq!(
        result,
        Err(UnpackError::Short(ShortPacket {
            field: "times".to_string(),
            needed: 0,
            left: 3_145_664
        }))
    );
}
