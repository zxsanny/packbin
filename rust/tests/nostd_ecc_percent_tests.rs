//! The parity percentage in the heap-free API (AZ-3506): every row of percent-vectors.txt through
//! the scheme walks, the setters and their validation, and every pair of percentage and length.
//! Needs the `ecc` feature.
#![cfg(feature = "ecc")]

mod nostd_support;

use nostd_support::{from_hex, Slots};
use packbin::nostd::{
    bytes, flags, pack, unpack, unpack_repair, validate, Error, Field, Row, Scheme, Unpacked,
};

const VECTORS: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../fixtures/ecc/percent-vectors.txt"
);

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

fn hex(field: &str) -> Vec<u8> {
    if field == "-" {
        Vec::new()
    } else {
        from_hex(field)
    }
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

/// The one clear length a sent length of `sent` bytes gives, by search.
fn clear_of(p: usize, sent: usize) -> Option<usize> {
    (0..=sent).find(|&len| len + expected_count(p, len) == sent)
}

/// A clear message of `clear` (at least 1) bytes: the type byte, then `clear - 1` bytes.
fn fields_of(clear: usize) -> [Field; 1] {
    [bytes(0, (clear - 1) as u16)]
}

fn row_of(clear: &[u8]) -> Slots {
    let mut row = Slots::default();
    row.set_bytes(0, &clear[1..]);
    row
}

fn pack_clear(clear: &[u8], p: u8) -> Result<Vec<u8>, packbin::nostd::Fault> {
    let fields = fields_of(clear.len());
    let scheme = Scheme::new(clear[0], &fields).with_parity_percent(p);
    let mut out = vec![0u8; 1200];
    let wrote = pack(&scheme, &row_of(clear), &mut out)?;
    out.truncate(wrote);
    Ok(out)
}

#[test]
fn pc1_the_setters_replace_each_other_and_validate_refuses_what_cannot_be_built() {
    // Arrange
    let fields = [bytes(0, 1)];
    let base = Scheme::new(1, &fields);

    // Act
    let by_percent = base.with_parity(4).with_parity_percent(25);
    let by_count = by_percent.with_parity(4);
    let limits = by_percent.with_limits(3, 9);
    let over = base.with_parity_percent(101);
    let both = Scheme {
        parity: 4,
        parity_percent: 20,
        ..base
    };

    // Assert
    assert_eq!((by_percent.parity, by_percent.parity_percent), (0, 25));
    assert_eq!((by_count.parity, by_count.parity_percent), (4, 0));
    assert_eq!((limits.parity, limits.parity_percent), (0, 25));
    assert_eq!((base.parity, base.parity_percent), (0, 0));
    assert!(validate(&base.with_parity_percent(100)).is_ok());
    assert!(validate(&base.with_parity_percent(0)).is_ok());
    for refused in [over, both, base.with_parity_percent(255)] {
        let fault = validate(&refused).expect_err("refused");
        assert_eq!((fault.error, fault.needed), (Error::SchemeInvalid, 100));
    }
}

#[test]
fn pc2_every_pct_and_encp_row_is_packed_to_its_count_and_bytes() {
    // Arrange
    let mut skipped = 0;

    for row in rows("pct") {
        let (id, p, len, n) = (&row[0], number(&row[1]), number(&row[2]), number(&row[3]));
        if len == 0 {
            skipped += 1;
            continue;
        }
        // Act
        let sent = pack_clear(&vec![0u8; len], p as u8);
        // Assert
        match sent {
            Ok(sent) => assert_eq!(sent.len(), len + n, "{id}"),
            Err(fault) => assert!(
                p > 0 && len > largest(p) && fault.error == Error::TooLong,
                "{id}: {fault:?}"
            ),
        }
    }
    for row in rows("encp") {
        let (id, p, clear, want) = (&row[0], number(&row[1]), hex(&row[2]), hex(&row[3]));
        if clear.is_empty() {
            skipped += 1;
            continue;
        }
        // Act
        let sent = pack_clear(&clear, p as u8).expect("pack");
        // Assert
        assert_eq!(sent, want, "{id}");
    }
    assert!(
        skipped < 30,
        "only the empty messages are skipped: {skipped}"
    );
}

#[test]
fn pc3_every_limp_row_is_packed_or_refused_naming_the_limit() {
    // Arrange and Act and Assert
    for row in rows("limp") {
        let (id, p, len) = (&row[0], number(&row[1]), number(&row[2]));
        let result = pack_clear(&vec![0u8; len], p as u8);
        match (row[3].as_str(), result) {
            ("ok", Ok(sent)) => assert_eq!(sent.len(), len + expected_count(p, len), "{id}"),
            ("too_long", Err(fault)) => {
                assert_eq!(fault.error, Error::TooLong, "{id}");
                assert_eq!((fault.offset, fault.needed), (len, largest(p)), "{id}");
            }
            (outcome, other) => panic!("{id}: expected {outcome}, got {other:?}"),
        }
    }
}

#[test]
fn pc4_every_inv_row_finds_its_length_or_is_uncorrectable() {
    // Arrange and Act and Assert
    for row in rows("inv") {
        let (id, p, sent) = (&row[0], number(&row[1]), number(&row[2]));
        match row[3].as_str() {
            "none" => {
                let fields = fields_of(2);
                let scheme = Scheme::new(0, &fields).with_parity_percent(p as u8);
                let fault = unpack(&scheme, &vec![0u8; sent], &mut Slots::default())
                    .expect_err("no clear length");
                assert_eq!(fault.error, Error::Uncorrectable, "{id}");
            }
            clear => {
                let clear = number(clear);
                assert_eq!(clear_of(p, sent), Some(clear), "{id}");
                if clear > 0 {
                    let wire = pack_clear(&vec![0u8; clear], p as u8).expect("pack");
                    assert_eq!(wire.len(), sent, "{id}");
                }
            }
        }
    }
}

#[test]
fn pc5_every_fixp_row_is_repaired_in_place_with_its_count() {
    // Arrange
    let fixes = rows("fixp");
    assert!(fixes.len() >= 100);

    for row in fixes {
        let (id, p, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (mut word, clear, count) = (hex(&row[3]), hex(&row[4]), number(&row[5]));
        if clear.is_empty() {
            continue;
        }
        let fields = fields_of(clear.len());
        let scheme = Scheme::new(clear[0], &fields).with_parity_percent(p as u8);
        let mut got = Slots::default();

        // Act
        let read = unpack_repair(&scheme, &mut word, &mut got, t)
            .unwrap_or_else(|e| panic!("{id}: {e:?}"));

        // Assert
        assert_eq!(read.repaired, count, "{id}");
        assert_eq!(read.bytes, word.len(), "{id}");
        assert_eq!(&word[..clear.len()], &clear[..], "{id}");
        assert_eq!(got, row_of(&clear), "{id}");
    }
}

#[test]
fn pc6_every_badp_row_is_refused_and_leaves_the_buffer() {
    // Arrange and Act and Assert
    for row in rows("badp") {
        let (id, p, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (mut word, kind) = (hex(&row[3]), row[4].as_str());
        let before = word.clone();
        let clear = clear_of(p, word.len()).filter(|&len| len > 0).unwrap_or(2);
        let fields = fields_of(clear);
        let scheme = Scheme::new(0, &fields).with_parity_percent(p as u8);

        let fault =
            unpack_repair(&scheme, &mut word, &mut Slots::default(), t).expect_err("refused");

        let want = if kind == "too_long" {
            Error::TooLong
        } else {
            Error::Uncorrectable
        };
        assert_eq!(fault.error, want, "{id}");
        assert_eq!(word, before, "{id}: the buffer changed");
    }
}

#[test]
fn pc7_every_parp_and_lmtp_row_is_refused_before_any_byte_is_read() {
    // Arrange
    let fields = [bytes(0, 1)];

    for row in rows("parp") {
        let (id, n) = (&row[0], number(&row[2]));
        let Ok(p) = row[1].parse::<u8>() else {
            // A percentage below 0 cannot be written, and one above 255 is not a `u8`.
            continue;
        };
        // Act
        let scheme = Scheme {
            parity: n as u8,
            parity_percent: p,
            ..Scheme::new(1, &fields)
        };
        let replaced = Scheme::new(1, &fields)
            .with_parity(n as u8)
            .with_parity_percent(p);
        // Assert
        let fault = validate(&scheme);
        if p > 100 || (p > 0 && n > 0) {
            assert_eq!(fault.expect_err(id).error, Error::SchemeInvalid, "{id}");
        }
        assert_eq!(
            validate(&replaced).is_ok(),
            p <= 100,
            "{id}: the last setter wins"
        );
    }
    for row in rows("lmtp") {
        let id = &row[0];
        let Ok(t) = row[1].parse::<usize>() else {
            continue;
        };
        let scheme = Scheme::new(1, &fields).with_parity_percent(25);
        // Act
        let fault = unpack_repair(&scheme, &mut [], &mut Slots::default(), t).expect_err(id);
        // Assert
        assert_eq!((fault.error, fault.needed), (Error::BadValue, 16), "{id}");
    }
}

#[test]
fn pc8_percentage_zero_is_the_plain_scheme_with_the_limit_rule_of_count_zero() {
    // Arrange
    let clear: Vec<u8> = (0..300usize).map(|i| i as u8).collect();
    let fields = fields_of(clear.len());
    let scheme = Scheme::new(clear[0], &fields).with_parity_percent(0);
    let mut out = vec![0u8; 400];

    // Act
    let wrote = pack(&scheme, &row_of(&clear), &mut out).expect("no limit of 254 bytes");
    let read = unpack_repair(&scheme, &mut out[..wrote], &mut Slots::default(), 0);
    let limit = unpack_repair(&scheme, &mut out[..wrote], &mut Slots::default(), 1);

    // Assert
    assert_eq!((wrote, &out[..wrote]), (300, &clear[..]));
    assert_eq!(read.map(|r| (r.bytes, r.repaired)), Ok((300, 0)));
    assert_eq!(limit.expect_err("refused").error, Error::BadValue);
}

#[test]
fn pc9_a_limit_above_half_the_count_is_lowered_and_a_wrong_byte_beyond_it_is_uncorrectable() {
    // Arrange: 40 clear bytes at 25 percent carry 10 parity bytes
    let clear: Vec<u8> = (1..=40u8).collect();
    let sent = pack_clear(&clear, 25).expect("pack");
    let fields = fields_of(40);
    let scheme = Scheme::new(clear[0], &fields).with_parity_percent(25);
    let hit = |k: usize| {
        let mut word = sent.clone();
        for i in 0..k {
            word[i * 3 + 1] ^= 0x5A;
        }
        word
    };

    // Act
    let mut five = hit(5);
    let mut six = hit(6);
    let lowered = unpack_repair(&scheme, &mut five, &mut Slots::default(), 16);
    let beyond = unpack_repair(&scheme, &mut six, &mut Slots::default(), 16);

    // Assert
    assert_eq!(lowered.map(|r| r.repaired), Ok(5));
    assert_eq!(five, sent);
    assert_eq!(beyond.expect_err("refused").error, Error::Uncorrectable);
    assert_eq!(
        unpack(&scheme, &hit(1), &mut Slots::default())
            .expect_err("detect")
            .error,
        Error::Uncorrectable
    );
}

#[test]
fn pc10_every_pair_of_percentage_and_length_round_trips_as_the_fixed_count_packs() {
    // Arrange
    let mut pairs = 0usize;

    for p in 0..=100usize {
        let top = if p == 0 { 254 } else { largest(p) };
        for len in 1..=top {
            let clear: Vec<u8> = (0..len).map(|i| (i * 7 + p) as u8).collect();
            let n = expected_count(p, len);
            let fields = fields_of(len);
            let fixed = Scheme::new(clear[0], &fields).with_parity(n as u8);
            let mut out = [0u8; 300];
            let wrote = pack(&fixed, &row_of(&clear), &mut out).expect("fixed");

            // Act
            let sent =
                pack_clear(&clear, p as u8).unwrap_or_else(|e| panic!("p {p} len {len}: {e:?}"));
            let scheme = Scheme::new(clear[0], &fields).with_parity_percent(p as u8);
            let mut back = Slots::default();
            let used = unpack(&scheme, &sent, &mut back)
                .unwrap_or_else(|e| panic!("p {p} len {len}: {e:?}"));

            // Assert
            assert_eq!(sent, &out[..wrote], "p {p} len {len}");
            assert_eq!(sent.len(), len + n, "p {p} len {len}");
            assert_eq!(
                (used, back),
                (sent.len(), row_of(&clear)),
                "p {p} len {len}"
            );
            pairs += 1;
        }
    }
    assert_eq!(
        pairs,
        22_752 - 101,
        "the 101 empty messages are in the std codec test"
    );
}

#[test]
fn pc11_a_message_above_the_largest_clear_length_is_too_long_and_writes_nothing() {
    // Arrange
    for (p, limit) in [(1u8, 251usize), (10, 230), (25, 222), (50, 222), (100, 222)] {
        let clear = vec![0xFFu8; limit + 1];
        let fields = fields_of(clear.len());
        let scheme = Scheme::new(0xFF, &fields).with_parity_percent(p);
        let mut out = vec![0xAAu8; 400];

        // Act
        let fault = pack(&scheme, &row_of(&clear), &mut out).expect_err("too long");

        // Assert
        assert_eq!(
            (fault.error, fault.offset, fault.needed),
            (Error::TooLong, limit + 1, limit),
            "p {p}"
        );
        assert!(
            out[..limit + 1].iter().all(|&b| b == 0),
            "p {p}: the written bytes are zeroed"
        );
    }
}

#[test]
fn pc12_a_message_with_an_optional_field_carries_the_count_of_its_own_length() {
    // Arrange: 10 clear bytes without the 3 optional ones, 13 with
    let fields = [bytes(0, 8), flags(1, 1), bytes(1, 3)];
    let scheme = Scheme::new(1, &fields).with_parity_percent(25);

    for (with, clear, parity) in [(true, 13usize, 4usize), (false, 10, 3)] {
        let mut row = Slots::default();
        row.set_bytes(0, &[1, 2, 3, 4, 5, 6, 7, 8]);
        if with {
            row.set_bytes(1, &[9, 10, 11]);
        }
        let mut out = [0u8; 40];

        // Act
        let wrote = pack(&scheme, &row, &mut out).expect("pack");
        let mut back = Slots::default();
        let used = unpack(&scheme, &out[..wrote], &mut back).expect("unpack");

        // Assert
        assert_eq!(wrote, clear + parity, "with {with}");
        assert_eq!(used, wrote, "with {with}");
        assert_eq!(back.bytes(0), row.bytes(0), "with {with}");
        assert_eq!(back.bytes(1), row.bytes(1), "with {with}");
    }
}

#[test]
fn pc13_a_bytes_field_is_read_after_the_repair_of_a_wrong_byte_inside_it() {
    // Arrange: 21 clear bytes at 25 percent carry 6 parity bytes
    let fields = [bytes(0, 20)];
    let scheme = Scheme::new(1, &fields).with_parity_percent(25);
    let mut row = Slots::default();
    row.set_bytes(0, &(0..20).map(|i| i * 3 + 1).collect::<Vec<u8>>());
    let mut out = [0u8; 40];
    let wrote = pack(&scheme, &row, &mut out).expect("pack");
    let sent = out[..wrote].to_vec();
    let mut word = sent.clone();
    word[7] ^= 0x5A;
    let mut back = Slots::default();

    // Act
    let read = unpack_repair(&scheme, &mut word, &mut back, 1);

    // Assert
    assert_eq!(
        read,
        Ok(Unpacked {
            bytes: wrote,
            repaired: 1
        })
    );
    assert_eq!(word, sent);
    assert_eq!(back.bytes(0), row.bytes(0));
}

#[cfg(feature = "text")]
#[test]
fn pc14_a_string_field_is_read_after_the_repair_of_a_wrong_byte_inside_it() {
    use packbin::nostd::{pack_with, utf8, SCRATCH_WORDS_PER_CHAR};

    // Arrange
    let text = "Привіт, світе!";
    let fields = [utf8(0)];
    let scheme = Scheme::new(1, &fields).with_parity_percent(25);
    let mut row = Slots::default();
    row.set_bytes(0, text.as_bytes());
    let mut scratch = vec![0u32; SCRATCH_WORDS_PER_CHAR * text.chars().count()];
    let mut out = [0u8; 64];
    let wrote = pack_with(&scheme, &row, &mut out, &mut scratch).expect("pack");
    let mut word = out[..wrote].to_vec();
    word[4] ^= 0x5A;
    let mut back = Slots::default();

    // Act
    let read = unpack_repair(&scheme, &mut word, &mut back, 1);

    // Assert
    assert_eq!(read.map(|r| r.repaired), Ok(1));
    assert_eq!(back.bytes(0), Some(text.as_bytes()));
}
