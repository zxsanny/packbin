use crate::walk::{pack, unpack};
use crate::{
    flags, insert, repeat, times, to_hex, u32, u8, MapScheme, PackError, Value, Values,
    DEFAULT_MAX_ROUNDS,
};

// AZ-2329: pack refuses a `times` count above the scheme's `max_rounds` before it writes a round,
// naming the member; a count at the limit packs as before.

fn row(n: u32, pt: Option<Value>) -> Values {
    let mut vals = Values::new();
    insert(&mut vals, "n", Some(Value::U32(n)));
    if let Some(v) = pt {
        insert(&mut vals, "pt", Some(v));
    }
    vals
}

/// `u32 n; times(n) { u8 pt }`
fn scheme() -> MapScheme {
    MapScheme::new(1, vec![u32("n"), times(1, "n", vec![u8("pt")])])
}

fn refusal(result: Result<Vec<u8>, PackError>) -> String {
    match result {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

#[test]
fn ac1_a_count_over_the_limit_with_a_lone_scalar_is_refused_naming_the_member() {
    // Arrange
    let over = DEFAULT_MAX_ROUNDS as u32 + 1;

    // Act
    let message = refusal(pack(&scheme(), &row(over, Some(Value::U8(5)))));

    // Assert
    assert!(message.contains("'pt'"), "{message}");
    assert!(message.contains("65536"), "{message}");
}

#[test]
fn ac1_a_count_of_billions_returns_at_once_without_building_rounds() {
    // Arrange: 4 billion rounds of one byte would be 4 GiB
    let hostile = row(4_000_000_000, Some(Value::U8(5)));

    // Act
    let message = refusal(pack(&scheme(), &hostile));

    // Assert
    assert!(message.contains("'pt'"), "{message}");
}

#[test]
fn ac1_a_count_over_the_limit_with_rounds_given_is_refused_too() {
    // Arrange: the rounds are all there, and still past the limit unpack would accept
    let limited = scheme().with_limits(2, 100);
    let mut rounds = Vec::new();
    for _ in 0..3 {
        let mut round = Values::new();
        insert(&mut round, "pt", Some(Value::U8(1)));
        rounds.push(round);
    }
    let mut vals = row(3, None);
    insert(&mut vals, "__times_1", Some(Value::Groups(rounds)));

    // Act
    let message = refusal(pack(&limited, &vals));

    // Assert
    assert!(message.contains("'pt'"), "{message}");
}

#[test]
fn ac1_a_times_inside_flags_and_inside_a_repeat_round_is_checked() {
    // Arrange
    let in_flags = MapScheme::new(
        1,
        vec![u8("0"), flags(1, "f", vec![times(1, "0", vec![u8("1")])])],
    )
    .with_limits(2, 100);
    let mut vals = Values::new();
    insert(&mut vals, "0", Some(Value::U8(3)));
    insert(&mut vals, "1", Some(Value::U8(9)));

    let in_repeat = MapScheme::new(
        1,
        vec![repeat(0, vec![u8("0"), times(1, "0", vec![u8("1")])])],
    )
    .with_limits(2, 100);
    let mut round = Values::new();
    insert(&mut round, "0", Some(Value::U8(3)));
    insert(&mut round, "1", Some(Value::U8(9)));
    let mut outer = Values::new();
    insert(&mut outer, "__repeat__", Some(Value::Groups(vec![round])));

    // Act
    let flagged = refusal(pack(&in_flags, &vals));
    let repeated = refusal(pack(&in_repeat, &outer));

    // Assert
    assert!(flagged.contains("count 3"), "{flagged}");
    assert!(repeated.contains("count 3"), "{repeated}");
}

#[test]
fn ac2_a_count_at_the_limit_packs_and_round_trips() {
    // Arrange
    let at = DEFAULT_MAX_ROUNDS as u32;
    let vals = row(at, Some(Value::U8(5)));

    // Act
    let wire = pack(&scheme(), &vals).expect("pack at the limit");
    let back = unpack(&scheme(), &wire).expect("unpack");

    // Assert
    assert_eq!(wire.len(), 1 + 4 + DEFAULT_MAX_ROUNDS);
    assert_eq!(to_hex(&wire[..6]), "01ffff000005");
    assert_eq!(
        back.get("pt"),
        Some(&Some(Value::List(vec![Value::U8(5); DEFAULT_MAX_ROUNDS])))
    );
}

#[test]
fn ac2_a_small_count_is_unchanged() {
    // Arrange
    let vals = row(2, Some(Value::U8(5)));

    // Act
    let wire = pack(&scheme(), &vals).map(|raw| to_hex(&raw));

    // Assert
    assert_eq!(wire, Ok("01020000000505".to_string()));
}

#[test]
fn ac3_a_scheme_with_a_raised_limit_packs_a_larger_count() {
    // Arrange
    let raised = scheme().with_limits(70_000, 4_194_304);

    // Act
    let wire = pack(&raised, &row(70_000, Some(Value::U8(5)))).expect("pack 70000");
    let back = unpack(&raised, &wire).expect("unpack 70000");

    // Assert
    assert_eq!(wire.len(), 1 + 4 + 70_000);
    assert_eq!(
        back.get("pt"),
        Some(&Some(Value::List(vec![Value::U8(5); 70_000])))
    );
}

#[test]
fn ac1_a_missing_value_under_the_limit_still_names_the_value() {
    // Arrange: below the cap the missing value is the error, as before
    let vals = row(100, None);

    // Act
    let result = pack(&scheme(), &vals);

    // Assert
    assert_eq!(result, Err(PackError::Missing("pt".to_string())));
}
