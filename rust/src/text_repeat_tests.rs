use crate::timing_support::{assert_within, load_factor};
use crate::walk::{encode_text, pack, unpack};
use crate::{insert, times, u8, utf8, MapScheme, Value, Values};
use std::time::Instant;

// AZ-2737 (CS-D7, TW-5): HD-2 of the Python and TypeScript suites for the Rust pack walker. One text of 65,535
// characters written in 200 rounds of `times` is packed and unpacked within a second nominal.

const ROUNDS: usize = 200;
const CHARACTERS: usize = 65_535;

#[test]
fn hd2_a_lone_65535_character_text_under_200_rounds_packs_and_unpacks_within_a_second() {
    // Arrange: u8 n; times(n) { utf8 s } with the text given once, so every round writes it
    let scheme = MapScheme::new(1, vec![u8("n"), times(1, "n", vec![utf8("s")])]);
    let text = "q".repeat(CHARACTERS);
    let mut values = Values::new();
    insert(&mut values, "n", Some(Value::U8(ROUNDS as u8)));
    insert(&mut values, "s", Some(Value::Str(text.clone())));
    let field = encode_text(&text).expect("the text encodes");
    let factor = load_factor();
    let started = Instant::now();

    // Act
    let packet = pack(&scheme, &values).expect("pack");
    let packed_at = started.elapsed().as_secs_f64();
    let unpacked = unpack(&scheme, &packet).expect("unpack");
    let elapsed = started.elapsed().as_secs_f64();

    // Assert
    eprintln!(
        "text repeat: {CHARACTERS} characters x {ROUNDS} rounds packed in {packed_at:.3} s, unpacked in {:.3} s \
         (nominal bound 1 s, load factor {factor:.2})",
        elapsed - packed_at
    );
    assert!(packet.len() > ROUNDS * CHARACTERS, "{} bytes", packet.len());
    assert_eq!(&packet[..2], &[1, ROUNDS as u8]);
    assert!(
        packet[2..]
            .chunks(field.len())
            .all(|round| round == field.as_slice())
            && packet.len() == 2 + ROUNDS * field.len(),
        "a round holds other bytes than the field of the text"
    );
    let rounds = match unpacked.get("s") {
        Some(Some(Value::List(rounds))) => rounds,
        other => panic!(
            "expected one list of rounds under s, got a {}",
            kind_of(other)
        ),
    };
    assert_eq!(rounds.len(), ROUNDS);
    assert!(
        rounds
            .iter()
            .all(|round| matches!(round, Value::Str(back) if *back == text)),
        "a round does not equal the input"
    );
    assert_within(
        "one 65535-character text under 200 rounds, packed and unpacked",
        elapsed,
        1.0,
        factor,
    );
}

/// The kind of an unexpected value, so that a failure does not print 13 MB of text.
fn kind_of(value: Option<&Option<Value>>) -> &'static str {
    match value {
        None => "missing name",
        Some(None) => "name without a value",
        Some(Some(Value::List(_))) => "list",
        Some(Some(Value::Str(_))) => "string",
        Some(Some(_)) => "value of another kind",
    }
}
