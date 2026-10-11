use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, insert, repeat, to_hex, u8, when, MapScheme, PackError, Value, Values,
    DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS,
};

// AZ-2355: pack refuses a `repeat` with more rounds than `max_rounds` before it writes any round,
// naming the first member the round holds; `max_rounds` rounds pack as before. Rows 1 to 9 of the
// AZ-2355 table of `reference_loop20_budget.md` (row 6 names the one list that is too long, and a
// Rust round is a `Values`, so it names the round's first member; row 10 needs a `repeat` in a list
// element, which Rust refuses at construction).

fn rounds(count: usize) -> Values {
    let rounds = (0..count)
        .map(|_| {
            let mut round = Values::new();
            insert(&mut round, "k", Some(Value::U8(7)));
            round
        })
        .collect::<Vec<_>>();
    let mut vals = Values::new();
    insert(&mut vals, "__repeat__", Some(Value::Groups(rounds)));
    vals
}

fn refusal(scheme: &MapScheme, vals: &Values) -> String {
    match pack(scheme, vals) {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

fn over(count: usize, limit: usize) -> String {
    format!("k: the repeat count is {count}, above the limit of {limit} rounds")
}

/// `repeat { u8 k }`
fn plain() -> MapScheme {
    MapScheme::new(1, vec![repeat(0, vec![u8("k")])])
}

#[test]
fn ac1_row1_a_repeat_one_round_over_the_limit_is_refused_naming_the_member() {
    // Act
    let message = refusal(&plain(), &rounds(DEFAULT_MAX_ROUNDS + 1));

    // Assert
    assert_eq!(message, over(65_536, 65_535));
}

#[test]
fn ac2_row2_a_repeat_at_the_limit_packs_and_round_trips() {
    // Act
    let wire = pack(&plain(), &rounds(DEFAULT_MAX_ROUNDS)).expect("pack at the limit");
    let back = unpack(&plain(), &wire).expect("unpack");
    let again = pack(&plain(), &back).expect("repack");

    // Assert
    assert_eq!(wire.len(), 65_536);
    assert_eq!(to_hex(&wire[..16]), format!("01{}", "07".repeat(15)));
    assert_eq!(to_hex(&wire[wire.len() - 16..]), "07".repeat(16));
    assert_eq!(again, wire);
}

#[test]
fn ac3_row3_a_raised_limit_packs_70000_rounds() {
    // Arrange
    let raised = plain().with_limits(70_000, DEFAULT_MAX_SLOTS);

    // Act
    let wire = pack(&raised, &rounds(70_000)).expect("pack 70000");

    // Assert
    assert_eq!(wire.len(), 70_001);
    assert_eq!(to_hex(&wire[..16]), format!("01{}", "07".repeat(15)));
}

#[test]
fn rows4_5_the_limit_is_exact() {
    // Arrange
    let scheme = plain().with_limits(3, DEFAULT_MAX_SLOTS);

    // Act
    let message = refusal(&scheme, &rounds(4));
    let wire = pack(&scheme, &rounds(3)).map(|raw| to_hex(&raw));

    // Assert
    assert_eq!(message, over(4, 3));
    assert_eq!(wire, Ok("01070707".to_string()));
}

#[test]
fn row6_a_refused_repeat_names_the_first_member_the_round_holds() {
    // Arrange
    let scheme = MapScheme::new(1, vec![repeat(0, vec![u8("a"), u8("b")])])
        .with_limits(3, DEFAULT_MAX_SLOTS);
    let round = || {
        let mut round = Values::new();
        insert(&mut round, "a", Some(Value::U8(1)));
        insert(&mut round, "b", Some(Value::U8(2)));
        round
    };
    let mut vals = Values::new();
    insert(
        &mut vals,
        "__repeat__",
        Some(Value::Groups((0..4).map(|_| round()).collect())),
    );

    // Act
    let message = refusal(&scheme, &vals);

    // Assert
    assert_eq!(
        message,
        "a: the repeat count is 4, above the limit of 3 rounds"
    );
}

#[test]
fn rows7_8_9_a_repeat_in_flags_a_split_bit_and_a_when_is_checked_before_any_round() {
    // Arrange
    let in_flags = MapScheme::new(1, vec![flags(0, "f", vec![repeat(0, vec![u8("k")])])]);
    let fb = flag_byte("m");
    let in_bit = MapScheme::new(1, vec![fb.byte(), fb.bit(repeat(1, vec![u8("k")]))]);
    let in_when = MapScheme::new(
        1,
        vec![
            u8("m"),
            when(1, eq("m", Value::U8(1)), vec![repeat(1, vec![u8("k")])]),
        ],
    );
    let mut with_m = rounds(4);
    insert(&mut with_m, "m", Some(Value::U8(1)));

    // Act
    let flagged = refusal(&in_flags.with_limits(3, DEFAULT_MAX_SLOTS), &rounds(4));
    let bit = refusal(&in_bit.with_limits(3, DEFAULT_MAX_SLOTS), &rounds(4));
    let conditional = refusal(&in_when.with_limits(3, DEFAULT_MAX_SLOTS), &with_m);

    // Assert
    assert_eq!(flagged, over(4, 3));
    assert_eq!(bit, over(4, 3));
    assert_eq!(conditional, over(4, 3));
}
