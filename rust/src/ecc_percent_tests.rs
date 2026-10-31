use crate::ecc::{append, append_for, check_limit, unprotect, unprotect_for, unprotect_percent};
use crate::ecc_core::{clear_length, largest_clear, parity_count};
use crate::timing_support::{assert_within, load_factor};
use crate::{u8, MapScheme, PackError, UnpackError};
use std::panic::catch_unwind;
use std::time::Instant;

// AZ-3506: every row of fixtures/ecc/percent-vectors.txt (pct, encp, inv, limp, fixp, badp, parp, lmtp)
// against the codec, the 22,752 round trips, the setters and the timing of the search for the length.

const VECTORS: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../fixtures/ecc/percent-vectors.txt"
);

fn from_hex(hex: &str) -> Vec<u8> {
    if hex == "-" {
        return Vec::new();
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

fn rows(kind: &str) -> Vec<Vec<String>> {
    let text = std::fs::read_to_string(VECTORS).expect("vectors file");
    let found: Vec<Vec<String>> = text
        .lines()
        .filter(|line| line.split(' ').next() == Some(kind))
        .map(|line| line.split(' ').skip(1).map(str::to_string).collect())
        .collect();
    assert!(!found.is_empty(), "no {kind} rows");
    found
}

fn number(field: &str) -> usize {
    field.parse().expect("number")
}

/// The count of the contract, written out apart from the code under test.
fn expected_count(p: usize, len: usize) -> usize {
    (p * len).div_ceil(100).min(32)
}

fn largest(p: usize) -> usize {
    (0..=254usize)
        .rev()
        .find(|&len| len + expected_count(p, len) <= 254)
        .expect("a length")
}

#[test]
fn pc1_every_pct_row_gives_its_parity_count() {
    // Arrange
    let rows = rows("pct");
    assert!(rows.len() >= 300);

    for row in &rows {
        let (id, p, len, n) = (&row[0], number(&row[1]), number(&row[2]), number(&row[3]));

        // Act
        let got = parity_count(p, len);

        // Assert
        assert_eq!(got, n, "{id}");
    }
}

#[test]
fn pc2_every_encp_row_appends_its_parity_as_the_fixed_count_does() {
    // Arrange
    let rows = rows("encp");

    for row in &rows {
        let (id, p, clear, protected) = (&row[0], number(&row[1]), from_hex(&row[2]), &row[3]);
        let mut bytes = clear.clone();
        let mut fixed = clear.clone();

        // Act
        append_for(&mut bytes, 0, p).expect("append");
        append(&mut fixed, parity_count(p, clear.len())).expect("fixed");

        // Assert
        assert_eq!(bytes, from_hex(protected), "{id}");
        assert_eq!(bytes, fixed, "{id}: the bytes of the fixed count");
        assert_eq!(&bytes[..clear.len()], &clear[..], "{id}: clear bytes first");
    }
}

#[test]
fn pc3_every_inv_row_finds_its_clear_length_or_none() {
    // Arrange
    let rows = rows("inv");

    for row in &rows {
        let (id, p, sent) = (&row[0], number(&row[1]), number(&row[2]));

        // Act
        let got = clear_length(p, sent);

        // Assert
        let want = (row[3] != "none").then(|| number(&row[3]));
        assert_eq!(got, want, "{id}");
        if want.is_none() {
            let read = unprotect_percent(&vec![0u8; sent], p, 0).map(|(clear, _)| clear.len());
            assert_eq!(read, Err(UnpackError::Uncorrectable), "{id}");
        }
    }
}

#[test]
fn pc4_every_limp_row_is_accepted_or_refused_naming_length_and_limit() {
    // Arrange
    let rows = rows("limp");

    for row in &rows {
        let (id, p, len, outcome) = (&row[0], number(&row[1]), number(&row[2]), row[3].as_str());
        let mut bytes = vec![0u8; len];

        // Act
        let result = append_for(&mut bytes, 0, p);

        // Assert
        match (outcome, result) {
            ("ok", Ok(())) => assert_eq!(bytes.len(), len + parity_count(p, len), "{id}"),
            ("too_long", Err(PackError::Type(text))) => {
                assert!(text.contains(&len.to_string()), "{id}: {text}");
                assert!(
                    text.contains(&format!("limit of {} bytes", largest_clear(p))),
                    "{id}: {text}"
                );
                assert_eq!(bytes.len(), len, "{id}: nothing appended");
            }
            (_, other) => panic!("{id}: expected {outcome}, got {other:?}"),
        }
    }
}

#[test]
fn pc5_every_fixp_row_returns_its_clear_bytes_and_count() {
    // Arrange
    let rows = rows("fixp");
    assert!(rows.len() >= 100);

    for row in &rows {
        let (id, p, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (received, clear, count) = (from_hex(&row[3]), from_hex(&row[4]), number(&row[5]));

        // Act
        let (got, repaired) =
            unprotect_for(&received, 0, p, t).unwrap_or_else(|e| panic!("{id}: {e:?}"));

        // Assert
        assert_eq!(&*got, &clear[..], "{id}");
        assert_eq!(repaired, count, "{id}");
    }
}

#[test]
fn pc6_every_badp_row_is_refused_with_its_kind() {
    // Arrange
    let rows = rows("badp");
    let mut kinds = std::collections::BTreeSet::new();

    for row in &rows {
        let (id, p, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (received, kind) = (from_hex(&row[3]), row[4].as_str());
        kinds.insert(kind.to_string());

        // Act
        let result = unprotect_for(&received, 0, p, t).map(|(b, c)| (b.len(), c));

        // Assert
        match (kind, result) {
            ("uncorrectable", Err(UnpackError::Uncorrectable)) => {}
            ("too_long", Err(UnpackError::TooLong { len, limit })) => {
                assert_eq!((len, limit), (received.len(), 254), "{id}");
            }
            (_, other) => panic!("{id}: expected {kind}, got {other:?}"),
        }
    }
    assert_eq!(kinds.len(), 2, "uncorrectable and too_long rows all ran");
}

#[test]
fn pc7_every_parp_row_is_refused_or_replaced_by_the_last_setter() {
    // Arrange
    let rows = rows("parp");

    for row in &rows {
        let id = &row[0];
        let Ok(p) = row[1].parse::<usize>() else {
            // A negative percentage cannot be written: the setter takes a `usize`.
            assert!(row[1].starts_with('-'), "{id}");
            continue;
        };
        let n = number(&row[2]);

        // Act
        let built = catch_unwind(|| MapScheme::new(1, vec![u8("a")]).with_parity_percent(p));
        let count_then_percent = catch_unwind(|| {
            MapScheme::new(1, vec![u8("a")])
                .with_parity(n)
                .with_parity_percent(p)
        });
        let percent_then_count = catch_unwind(|| {
            MapScheme::new(1, vec![u8("a")])
                .with_parity_percent(p)
                .with_parity(n)
        });

        // Assert
        if p > 100 {
            for result in [built, count_then_percent, percent_then_count] {
                let text = result
                    .err()
                    .unwrap_or_else(|| panic!("{id}: scheme was built"))
                    .downcast_ref::<String>()
                    .cloned()
                    .unwrap_or_default();
                assert!(text.contains(&p.to_string()), "{id}: {text}");
                assert!(text.contains("100"), "{id}: {text}");
            }
        } else {
            let scheme = count_then_percent.expect("percent replaces the count");
            assert_eq!((scheme.parity(), scheme.parity_percent()), (0, p), "{id}");
            let scheme = percent_then_count.expect("count replaces the percentage");
            assert_eq!((scheme.parity(), scheme.parity_percent()), (n, 0), "{id}");
        }
    }
}

#[test]
fn pc8_every_lmtp_row_is_refused_before_any_byte_is_read() {
    // Arrange
    let rows = rows("lmtp");

    for row in &rows {
        let id = &row[0];
        let Ok(t) = row[1].parse::<usize>() else {
            // A negative limit cannot be written: the limit is a `usize`.
            assert!(row[1].starts_with('-'), "{id}");
            continue;
        };

        // Act
        let unread = unprotect_for(&[], 0, 25, t).map(|(b, c)| (b.len(), c));

        // Assert
        let expected = UnpackError::BadLimit { limit: t, max: 16 };
        assert_eq!(
            unread,
            Err(expected),
            "{id}: refused before the empty buffer"
        );
    }
}

#[test]
fn pc9_every_pair_of_percentage_and_length_round_trips_with_the_formula_count() {
    // Arrange
    let mut pairs = 0usize;
    let mut fixed = Vec::new();

    for p in 0..=100usize {
        let top = if p == 0 { 254 } else { largest(p) };
        assert!(p == 0 || largest_clear(p) == top, "p {p}");
        for len in 0..=top {
            let clear: Vec<u8> = (0..len).map(|i| (i * 7 + p) as u8).collect();
            let n = expected_count(p, len);
            let mut sent = clear.clone();

            // Act
            append_for(&mut sent, 0, p).unwrap_or_else(|e| panic!("p {p} len {len}: {e:?}"));
            let (back, repaired) =
                unprotect_for(&sent, 0, p, 0).unwrap_or_else(|e| panic!("p {p} len {len}: {e:?}"));

            // Assert
            assert_eq!(sent.len(), len + n, "p {p} len {len}");
            assert_eq!((&*back, repaired), (&clear[..], 0), "p {p} len {len}");
            fixed.clear();
            fixed.extend_from_slice(&clear);
            append(&mut fixed, n).expect("fixed");
            assert_eq!(sent, fixed, "p {p} len {len}: the bytes of the fixed count");
            pairs += 1;
        }
    }
    assert_eq!(pairs, 22_752);
}

#[test]
fn pc10_a_length_no_clear_length_gives_is_uncorrectable_and_a_buffer_above_254_is_too_long() {
    // Arrange
    let none: Vec<usize> = (0..=254)
        .filter(|&n| clear_length(100, n).is_none())
        .collect();

    // Act and Assert
    assert_eq!(none.len(), 32);
    assert!(none.iter().all(|&n| n % 2 == 1 && n < 64));
    let counts = [(1usize, 3usize), (10, 24), (25, 32), (50, 32)];
    for (p, missing) in counts {
        let found = (0..=254).filter(|&n| clear_length(p, n).is_none()).count();
        assert_eq!(found, missing, "p {p}");
    }
    for n in [3usize, 63] {
        assert_eq!(
            unprotect_percent(&vec![0u8; n], 100, 0).map(|(b, _)| b.len()),
            Err(UnpackError::Uncorrectable),
            "n {n}"
        );
    }
    for p in 1..=100 {
        assert_eq!(
            unprotect_percent(&[0u8; 255], p, 0).map(|(b, _)| b.len()),
            Err(UnpackError::TooLong {
                len: 255,
                limit: 254
            }),
            "p {p}"
        );
    }
}

#[test]
fn pc11_percentage_zero_is_a_scheme_without_parity() {
    // Arrange
    let bytes = vec![3u8; 300];

    // Act
    let (clear, repaired) = unprotect_for(&bytes, 0, 0, 0).expect("no limit of 254 bytes");
    let refused = unprotect_for(&bytes, 0, 0, 1).map(|(b, c)| (b.len(), c));
    let mut packed = bytes.clone();
    append_for(&mut packed, 0, 0).expect("nothing is added");

    // Assert
    assert_eq!((clear.len(), repaired), (300, 0));
    assert_eq!(refused, Err(UnpackError::BadLimit { limit: 1, max: 0 }));
    assert_eq!(packed, bytes);
    assert_eq!(
        check_limit(0, 1),
        Err(UnpackError::BadLimit { limit: 1, max: 0 })
    );
}

#[test]
fn pc12_a_limit_above_half_the_count_of_the_message_is_lowered_to_it() {
    // Arrange: 40 clear bytes at 25 percent carry 10 parity bytes
    let clear: Vec<u8> = (0..40u8).collect();
    let mut sent = clear.clone();
    append_for(&mut sent, 0, 25).expect("append");
    assert_eq!(sent.len(), 50);
    let mut five = sent.clone();
    let mut six = sent.clone();
    for i in 0..5 {
        five[i * 3] ^= 0x55;
    }
    for i in 0..6 {
        six[i * 3] ^= 0x55;
    }

    // Act
    let lowered = unprotect_percent(&five, 25, 16).expect("five repaired");
    let fixed = unprotect(&five, 10, 5).expect("five repaired");
    let refused = unprotect_percent(&six, 25, 16).map(|(b, c)| (b.len(), c));

    // Assert
    assert_eq!((&*lowered.0, lowered.1), (&clear[..], 5));
    assert_eq!(lowered, fixed);
    assert_eq!(refused, Err(UnpackError::Uncorrectable));
    assert_eq!(
        unprotect(&sent, 10, 6).map(|(b, c)| (b.len(), c)),
        Err(UnpackError::BadLimit { limit: 6, max: 5 }),
        "a fixed count keeps its exact rule"
    );
}

#[test]
fn pc13_one_thousand_percentage_repairs_of_a_245_byte_message_stay_within_the_bound() {
    // Arrange: 222 clear bytes at 10 percent carry 23 parity bytes
    let clear: Vec<u8> = (0..222usize).map(|i| (i * 13) as u8).collect();
    let mut word = clear.clone();
    append_for(&mut word, 0, 10).expect("append");
    for i in 0..8 {
        word[i * 20] ^= 0x5a;
    }
    let bound = if cfg!(debug_assertions) { 6.0 } else { 1.0 };

    // Act
    let factor = load_factor();
    let started = Instant::now();
    for _ in 0..1000 {
        let (got, repaired) = unprotect_percent(&word, 10, 8).expect("repair");
        assert_eq!((got.len(), repaired), (clear.len(), 8));
    }
    let seconds = started.elapsed().as_secs_f64();

    // Assert
    assert_within("1000 percentage repairs", seconds, bound, factor);
}
