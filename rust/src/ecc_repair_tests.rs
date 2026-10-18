use crate::ecc::{append, unprotect};
use crate::{to_hex, UnpackError};
use std::time::Instant;

// AZ-2684: repair and refusal on the 13-byte position fixture (EC-5 to EC-8, EC-14) and the speed bound (EC-13).

const FIXTURE: &str = "4001000065cd1d00a3e1110100";

/// splitmix64: a seeded stream, the same on every run.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }

    fn byte(&mut self) -> u8 {
        self.next() as u8
    }
}

fn fixture() -> Vec<u8> {
    (0..FIXTURE.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&FIXTURE[i..i + 2], 16).expect("hex"))
        .collect()
}

fn protected(clear: &[u8], n: usize) -> Vec<u8> {
    let mut bytes = clear.to_vec();
    append(&mut bytes, n).expect("append");
    bytes
}

/// Changes `k` distinct positions of `word`, each to a different value.
fn corrupt(word: &mut [u8], k: usize, rng: &mut Rng) {
    let mut hit = Vec::new();
    while hit.len() < k {
        let p = rng.below(word.len());
        if !hit.contains(&p) {
            hit.push(p);
            word[p] ^= rng.byte() | 1;
        }
    }
}

#[test]
fn ec5_n2_every_position_and_every_wrong_value_is_repaired() {
    // Arrange
    let clear = fixture();
    let sent = protected(&clear, 2);
    assert_eq!(sent.len(), 15);
    let mut recovered = 0;

    for p in 0..sent.len() {
        for flip in 1..=255u8 {
            let mut word = sent.clone();
            word[p] ^= flip;

            // Act
            let (got, repaired) = unprotect(&word, 2, 1).expect("repair");

            // Assert
            assert_eq!(
                (&*got, repaired),
                (&clear[..], 1),
                "position {p} flip {flip}"
            );
            recovered += 1;
        }
    }
    assert_eq!(recovered, 15 * 255);
}

#[test]
fn ec5_seeded_cases_up_to_t_wrong_bytes_are_repaired() {
    // Arrange
    let clear = fixture();
    let mut rng = Rng(0xEC05);

    for n in [4usize, 8, 16] {
        let t = n / 2;
        let sent = protected(&clear, n);
        for case in 0..1000 {
            let k = 1 + rng.below(t);
            let mut word = sent.clone();
            corrupt(&mut word, k, &mut rng);

            // Act
            let (got, repaired) = unprotect(&word, n, t).expect("repair");

            // Assert
            assert_eq!((&*got, repaired), (&clear[..], k), "n {n} case {case}");
        }
    }
}

#[test]
fn ec5_a_longer_clear_message_is_repaired_with_every_byte_value_wrong() {
    // Arrange
    let mut rng = Rng(0xEC50);
    let clear: Vec<u8> = (0..200).map(|_| rng.byte()).collect();
    let sent = protected(&clear, 32);

    for case in 0..300 {
        let k = 1 + rng.below(16);
        let mut word = sent.clone();
        corrupt(&mut word, k, &mut rng);

        // Act
        let (got, repaired) = unprotect(&word, 32, 16).expect("repair");

        // Assert
        assert_eq!((&*got, repaired), (&clear[..], k), "case {case}");
    }
}

fn refused_all(
    n: usize,
    t: usize,
    sizes: std::ops::RangeInclusive<usize>,
    seed: u64,
    cases: usize,
) {
    let clear = fixture();
    let sent = protected(&clear, n);
    let mut rng = Rng(seed);
    for case in 0..cases {
        let k = sizes.start() + rng.below(sizes.end() - sizes.start() + 1);
        let mut word = sent.clone();
        corrupt(&mut word, k, &mut rng);

        // Act
        let result = unprotect(&word, n, t);

        // Assert
        match result {
            Err(UnpackError::Uncorrectable) => {}
            other => panic!(
                "n {n} t {t} case {case}: {} accepted as {:?}",
                to_hex(&word),
                other.map(|(b, c)| (to_hex(&b), c))
            ),
        }
    }
}

#[test]
fn ec6_two_or_three_wrong_bytes_with_n4_t1_are_all_refused() {
    refused_all(4, 1, 2..=3, 0xEC06, 10_000);
}

#[test]
fn ec6_one_to_four_wrong_bytes_with_n4_t0_are_all_refused() {
    refused_all(4, 0, 1..=4, 0xEC60, 10_000);
}

#[test]
fn ec6_t_plus_one_to_n_minus_t_wrong_bytes_are_refused_for_other_n() {
    refused_all(8, 2, 3..=6, 0xEC61, 2_000);
    refused_all(16, 4, 5..=12, 0xEC62, 2_000);
    refused_all(2, 0, 1..=2, 0xEC63, 2_000);
}

#[test]
fn ec7_garbage_with_n2_t0_is_accepted_at_most_12_of_200000() {
    // Arrange
    let mut rng = Rng(0xEC07);
    let mut accepted = 0;

    // Act
    for _ in 0..200_000 {
        let word: Vec<u8> = (0..15).map(|_| rng.byte()).collect();
        if unprotect(&word, 2, 0).is_ok() {
            accepted += 1;
        }
    }

    // Assert
    assert!(accepted <= 12, "accepted {accepted}");
}

#[test]
fn ec14_n4_t0_a_changed_length_is_refused_in_every_seeded_case() {
    // Arrange
    let sent = protected(&fixture(), 4);
    let mut rng = Rng(0xEC14);

    for case in 0..10_000 {
        let mut word = sent.clone();
        let cut = 1 + rng.below(3);
        if case % 2 == 0 {
            word.truncate(word.len() - cut);
        } else {
            word.extend((0..cut).map(|_| rng.byte()));
        }

        // Act
        let result = unprotect(&word, 4, 0);

        // Assert
        assert!(result.is_err(), "case {case}: {}", to_hex(&word));
    }
}

#[test]
fn ec14_a_shift_by_exactly_one_byte_is_refused() {
    // Arrange
    let sent = protected(&fixture(), 4);
    let mut with_zero = sent.clone();
    with_zero.push(0);
    let without_last = sent[..sent.len() - 1].to_vec();

    // Act and Assert
    assert_eq!(
        unprotect(&with_zero, 4, 0).err(),
        Some(UnpackError::Uncorrectable)
    );
    assert_eq!(
        unprotect(&without_last, 4, 0).err(),
        Some(UnpackError::Uncorrectable)
    );
}

#[test]
fn ec14_a_message_whose_last_parity_byte_is_zero_is_refused_when_shifted() {
    // Arrange
    let mut rng = Rng(0xEC41);
    let mut checked = 0;
    while checked < 20 {
        let clear: Vec<u8> = (0..1 + rng.below(40)).map(|_| rng.byte()).collect();
        let sent = protected(&clear, 4);
        if *sent.last().unwrap() != 0 {
            continue;
        }
        checked += 1;

        // Act
        let dropped = unprotect(&sent[..sent.len() - 1], 4, 0);
        let mut padded = sent.clone();
        padded.push(0);
        let added = unprotect(&padded, 4, 0);

        // Assert
        assert!(dropped.is_err() && added.is_err(), "{}", to_hex(&sent));
    }
}

#[test]
fn ec14_an_unprotected_message_read_with_n4_t0_is_refused() {
    // Arrange
    let unprotected = fixture();

    // Act
    let result = unprotect(&unprotected, 4, 0);

    // Assert
    assert_eq!(result.err(), Some(UnpackError::Uncorrectable));
}

#[test]
fn hostile_random_buffers_of_any_size_never_panic_and_a_repair_is_a_code_word() {
    // Arrange
    let mut rng = Rng(0xBAD5);

    for _ in 0..20_000 {
        let n = rng.below(33);
        let t = rng.below(n / 2 + 1);
        let len = rng.below(260);
        let word: Vec<u8> = (0..len).map(|_| rng.byte()).collect();

        // Act
        let result = unprotect(&word, n, t);

        // Assert
        if let Ok((clear, repaired)) = result {
            assert!(repaired <= t);
            if n > 0 {
                assert_eq!(
                    protected(&clear, n).len(),
                    word.len(),
                    "repaired message re-protects"
                );
            }
        }
    }
}

/// 238 clear bytes and 16 parity bytes: a 254-byte message.
fn full_block() -> (Vec<u8>, Vec<u8>) {
    let mut rng = Rng(0xEC13);
    let clear: Vec<u8> = (0..238).map(|_| rng.byte()).collect();
    let sent = protected(&clear, 16);
    assert_eq!(sent.len(), 254);
    (clear, sent)
}

#[test]
fn ec13_one_thousand_repairs_of_a_254_byte_message_with_8_wrong_bytes_stay_within_the_bound() {
    // Arrange
    let (clear, sent) = full_block();
    let mut rng = Rng(0xEC31);
    let mut word = sent.clone();
    corrupt(&mut word, 8, &mut rng);
    let bound = if cfg!(debug_assertions) { 6.0 } else { 1.0 };

    // Act
    let started = Instant::now();
    for _ in 0..1000 {
        let (got, repaired) = unprotect(&word, 16, 8).expect("repair");
        assert_eq!((got.len(), repaired), (clear.len(), 8));
    }
    let seconds = started.elapsed().as_secs_f64();

    // Assert
    assert!(
        seconds <= bound,
        "1000 repairs took {seconds} s, bound {bound} s"
    );
}

#[test]
fn ec13_one_thousand_packs_of_a_254_byte_message_stay_within_the_bound() {
    // Arrange
    let (clear, sent) = full_block();
    let clear = &clear[..];
    let bound = if cfg!(debug_assertions) { 6.0 } else { 1.0 };

    // Act
    let started = Instant::now();
    let mut last = Vec::new();
    for _ in 0..1000 {
        last = protected(clear, 16);
    }
    let seconds = started.elapsed().as_secs_f64();

    // Assert
    assert_eq!(last, sent);
    assert!(
        seconds <= bound,
        "1000 packs took {seconds} s, bound {bound} s"
    );
}
