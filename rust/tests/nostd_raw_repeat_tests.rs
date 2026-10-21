//! AZ-2757 risk R-memo (security observation O2): a long text that the encoder writes raw, in many
//! rounds of a `times`. The C++ core keeps a memo of the last raw field in the caller's scratch
//! (AZ-2742, 1.9 s to 13 ms); the Rust core re-runs the parse each round. The small test proves the
//! packet is right; the `--ignored` test prints the figures of the C++ case (65,535 characters, 200
//! rounds) so the decision to port the memo rests on a number. Needs `std` and `text`.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::random::set_items;
use nostd_support::tree::{build, values_of, Node};
use nostd_support::Slots;
use packbin::nostd::{pack_with, unpack, Kind, Num, Scheme};
use std::time::Instant;

fn rounds_of(text: &str, rounds: usize) -> Slots {
    let mut row = Slots::with(&[(0, Num::U8(rounds as u8))], &[]);
    let item = Slots::with(&[], &[(1, text.as_bytes())]);
    set_items(&mut row, 1, vec![item; rounds]);
    row
}

fn layout() -> Vec<Node> {
    vec![Node::Num(Kind::U8), Node::Times(0, vec![Node::Utf8])]
}

/// The packet of `texts` as rounds of `layout`, with the given scratch words.
fn pack_rounds(texts: &[&str], scratch: &mut [u32]) -> Vec<u8> {
    let built = build(1, &layout());
    let scheme = Scheme::new(1, &built.fields);
    let mut row = Slots::with(&[(0, Num::U8(texts.len() as u8))], &[]);
    let items = texts
        .iter()
        .map(|t| Slots::with(&[], &[(1, t.as_bytes())]))
        .collect();
    set_items(&mut row, 1, items);
    let mut out = vec![0u8; 4096];
    let n = pack_with(&scheme, &row, &mut out, scratch).expect("core pack");
    out[..n].to_vec()
}

fn std_pack(texts: &[&str]) -> Vec<u8> {
    let built = build(1, &layout());
    let mut row = Slots::with(&[(0, Num::U8(texts.len() as u8))], &[]);
    let items = texts
        .iter()
        .map(|t| Slots::with(&[], &[(1, t.as_bytes())]))
        .collect();
    set_items(&mut row, 1, items);
    packbin::pack(&built.reference, &values_of(&row, &built.leaves)).expect("std pack")
}

#[test]
fn a_raw_text_repeated_over_rounds_packs_the_same_bytes_as_std() {
    // Arrange
    let q = "q".repeat(300);
    let mut scratch = vec![0u32; 3 * 300];
    // Act
    let ours = pack_rounds(&[&q, &q, &q, &q, &q], &mut scratch);
    // Assert
    assert_eq!(ours, std_pack(&[&q, &q, &q, &q, &q]));
}

#[test]
fn every_round_packs_to_the_bytes_it_packs_to_alone() {
    // Arrange: repeated raw texts, a raw text after a compact one, a changed last character, a
    // longer text with the same start, a shorter one, compact texts repeated, and the empty text
    // between two equal raw texts (the cases of the C++ test, AZ-2742 AC-2)
    let raw = "q".repeat(200);
    let changed = format!("{}x", &raw[..199]);
    let longer = format!("{raw}q");
    let shorter = raw[..199].to_string();
    let compact = "hello world hello world".to_string();
    let with_prefix = format!("{compact}{}", "q".repeat(250));
    let cyr = "Привіт".to_string();
    let cases: Vec<Vec<&str>> = vec![
        vec![&raw, &raw, &raw],
        vec![&raw, &compact, &raw],
        vec![&raw, &changed, &raw],
        vec![&raw, &longer, &raw, &shorter, &raw],
        vec![&compact, &compact],
        vec![&cyr, &cyr, &raw, &raw],
        vec![&raw, "", &raw],
        vec![&raw, &raw, &compact, &compact, &raw, &raw],
        vec![&with_prefix, &compact, &with_prefix],
    ];
    for texts in cases {
        // Act
        let mut scratch = vec![0u32; 3 * 400];
        let together = pack_rounds(&texts, &mut scratch);
        let mut expected = vec![together[0], texts.len() as u8];
        for t in &texts {
            expected.extend_from_slice(&pack_rounds(&[t], &mut vec![0u32; 3 * 400])[2..]);
        }
        // Assert
        assert_eq!(together, expected, "{texts:?}");
        assert_eq!(together, std_pack(&texts), "{texts:?}");
    }
}

#[test]
fn a_memo_left_in_the_scratch_is_not_believed() {
    // Arrange: the memo points at a raw field of 23 bytes inside the output where the same text sits
    let compact = "hello world hello world";
    let want = pack_rounds(&[compact], &mut vec![0u32; 3 * 64]);
    let mut scratch = vec![0u32; 3 * 64];
    scratch[0] = 1;
    scratch[1] = compact.len() as u32;
    // Act
    let got = pack_rounds(&[compact], &mut scratch);
    // Assert
    assert_eq!(got, want);
    assert_eq!(got, std_pack(&[compact]));
}

#[test]
fn a_compact_result_leaves_no_memo_in_the_scratch() {
    // Arrange
    let raw = "q".repeat(200);
    let compact = "hello world hello world";
    let mut scratch = vec![0u32; 3 * 400];
    // Act
    pack_rounds(&[&raw, compact], &mut scratch);
    // Assert
    assert_eq!(scratch[0], 0, "a compact field clears the memo");
    pack_rounds(&[&raw], &mut scratch);
    assert_ne!(scratch[0], 0, "a raw field leaves one");
    assert_eq!(scratch[1], 200);
}

#[test]
#[ignore = "a measurement: cargo test --release --features text --test nostd_raw_repeat_tests -- --ignored --nocapture"]
fn measure_200_rounds_of_a_65535_character_raw_text() {
    // Arrange
    let built = build(1, &layout());
    let scheme = Scheme::new(1, &built.fields);
    let text = "q".repeat(65_535);
    let row = rounds_of(&text, 200);
    let mut out = vec![0u8; 200 * 65_545 + 16];
    let mut scratch = vec![0u32; 3 * 65_535];
    // Act
    let started = Instant::now();
    let n = pack_with(&scheme, &row, &mut out, &mut scratch).expect("core pack");
    let packed = started.elapsed().as_secs_f64();
    let started = Instant::now();
    let mut back = Slots {
        cap: Some(70_000),
        ..Slots::default()
    };
    unpack(&scheme, &out[..n], &mut back).expect("core unpack");
    let unpacked = started.elapsed().as_secs_f64();
    // Assert
    eprintln!("raw repeat: 65535 characters x 200 rounds: core pack {packed:.3} s, unpack {unpacked:.3} s, {n} bytes");
    assert!(n > 200 * 65_535);
    assert!(
        packed < 2.0,
        "the memo is gone: {packed:.3} s (std 0.010 s, without the memo 6 s)"
    );
}
