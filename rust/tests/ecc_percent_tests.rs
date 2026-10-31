#![cfg(feature = "std")]
mod ecc_support;

use ecc_support::{position_row, position_scheme, PositionRow};
use packbin::{
    bytes, flags, insert, pack, unpack, unpack_repair, utf8, BinaryPacker, DispatchHandler,
    MapScheme, PackError, UnpackError, Value, Values,
};
use std::panic::catch_unwind;

// AZ-3506: the parity percentage through the public API (AC-1 to AC-7); the codec and the rows of
// percent-vectors.txt are read by src/ecc_percent_tests.rs.

fn count(p: usize, len: usize) -> usize {
    (p * len).div_ceil(100).min(32)
}

fn largest(p: usize) -> usize {
    (0..=254usize)
        .rev()
        .find(|&l| l + count(p, l) <= 254)
        .expect("a length")
}

/// A scheme whose clear message is `clear` bytes: the type byte and `clear - 1` bytes.
fn scheme_of(clear: usize) -> MapScheme {
    MapScheme::new(1, vec![bytes("b", clear - 1)])
}

fn values_of(clear: usize) -> Values {
    let blob: Vec<u8> = (0..clear - 1).map(|i| (i * 31 + clear) as u8).collect();
    let mut values = Values::new();
    insert(&mut values, "b", Some(Value::Bytes(blob)));
    values
}

#[test]
fn ac1_the_setters_report_replace_each_other_and_keep_the_other_limits() {
    // Arrange
    let plain = scheme_of(5);

    // Act
    let by_percent = plain.clone().with_parity_percent(25);
    let by_count = by_percent.clone().with_parity(4);
    let back = by_count.clone().with_parity_percent(10);
    let limits = by_percent.clone().with_limits(3, 9).with_max_bytes(500);
    let counted = by_count.clone().with_limits(3, 9);

    // Assert
    assert_eq!((plain.parity(), plain.parity_percent()), (0, 0));
    assert_eq!((by_percent.parity(), by_percent.parity_percent()), (0, 25));
    assert_eq!((by_count.parity(), by_count.parity_percent()), (4, 0));
    assert_eq!((back.parity(), back.parity_percent()), (0, 10));
    assert_eq!((limits.parity(), limits.parity_percent()), (0, 25));
    assert_eq!((counted.parity(), counted.parity_percent()), (4, 0));
}

#[test]
fn ac1_a_percentage_above_100_is_refused_naming_it_and_100() {
    // Arrange and Act
    let result = catch_unwind(|| scheme_of(5).with_parity_percent(101));
    let typed = catch_unwind(|| position_scheme(0x40, 0).with_parity_percent(101));

    // Assert
    for refused in [result.err(), typed.err()] {
        let text = refused
            .expect("refused")
            .downcast_ref::<String>()
            .cloned()
            .unwrap_or_default();
        assert!(text.contains("101") && text.contains("100"), "{text}");
    }
    assert_eq!(scheme_of(5).with_parity_percent(100).parity_percent(), 100);
    assert_eq!(scheme_of(5).with_parity_percent(0).parity_percent(), 0);
}

#[test]
fn ac2_counts_and_bytes_are_those_of_the_fixed_count_with_that_count() {
    // Arrange
    let percentages = [0usize, 10, 25, 50, 100];
    let lengths = [1usize, 3, 10, 40, 100, 222];

    for p in percentages {
        for clear in lengths {
            let values = values_of(clear);

            // Act
            let sent = pack(&scheme_of(clear).with_parity_percent(p), &values).expect("pack");
            let fixed =
                pack(&scheme_of(clear).with_parity(count(p, clear)), &values).expect("fixed");

            // Assert
            assert_eq!(sent.len(), clear + count(p, clear), "p {p} clear {clear}");
            assert_eq!(sent, fixed, "p {p} clear {clear}");
        }
    }
}

#[test]
fn ac3_a_message_above_the_largest_clear_length_is_refused_and_zero_has_no_limit() {
    // Arrange
    let percentages = [1usize, 10, 25, 50, 100];
    let limits = [251usize, 230, 222, 222, 222];

    for (p, limit) in percentages.into_iter().zip(limits) {
        // Act
        let fits = pack(&scheme_of(limit).with_parity_percent(p), &values_of(limit));
        let over = pack(
            &scheme_of(limit + 1).with_parity_percent(p),
            &values_of(limit + 1),
        );

        // Assert
        assert_eq!(largest(p), limit, "p {p}");
        assert!(fits.is_ok(), "p {p}");
        match over {
            Err(PackError::Type(text)) => {
                assert!(text.contains(&(limit + 1).to_string()), "{text}");
                assert!(text.contains(&format!("limit of {limit} bytes")), "{text}");
            }
            other => panic!("p {p}: {other:?}"),
        }
    }
    let long = pack(&scheme_of(300).with_parity_percent(0), &values_of(300)).expect("no limit");
    assert_eq!(long.len(), 300);
}

#[test]
fn ac4_every_pair_of_percentage_and_length_round_trips_through_a_scheme() {
    // Arrange
    let mut pairs = 0usize;

    for p in 0..=100usize {
        let top = if p == 0 { 254 } else { largest(p) };
        for clear in 1..=top {
            let scheme = scheme_of(clear).with_parity_percent(p);
            let values = values_of(clear);

            // Act
            let sent = pack(&scheme, &values).expect("pack");
            let (back, repaired) = unpack_repair(&scheme, &sent, 0).expect("unpack");

            // Assert
            assert_eq!(sent.len(), clear + count(p, clear), "p {p} clear {clear}");
            assert_eq!((back, repaired), (values, 0), "p {p} clear {clear}");
            assert_eq!(unpack(&scheme, &sent).map(|_| ()), Ok(()));
            pairs += 1;
        }
    }
    assert_eq!(
        pairs,
        22_752 - 101,
        "the 101 empty messages are in the codec test"
    );
}

#[test]
fn ac4_a_length_no_clear_length_gives_is_uncorrectable_and_above_254_is_too_long() {
    // Arrange
    let scheme = scheme_of(2).with_parity_percent(100);

    // Act
    let odd = unpack(&scheme, &[1u8; 3]);
    let long = unpack(&scheme, &[1u8; 255]);
    let plain = unpack(&scheme_of(2).with_parity_percent(0), &[1u8; 3]);

    // Assert
    assert_eq!(odd.map(|_| ()), Err(UnpackError::Uncorrectable));
    assert_eq!(
        long.map(|_| ()),
        Err(UnpackError::TooLong {
            len: 255,
            limit: 254
        })
    );
    assert_eq!(
        plain.map(|_| ()),
        Err(UnpackError::Trailing { left: 1 }),
        "percentage 0 reads the bytes as they are"
    );
}

fn damaged(mut sent: Vec<u8>, k: usize) -> Vec<u8> {
    for i in 0..k {
        sent[i * 3 + 1] ^= 0x5A;
    }
    sent
}

#[test]
fn ac5_the_count_of_the_message_is_the_repaired_count_for_each_percentage() {
    // Arrange: 40 clear bytes carry 20 parity bytes at 50 percent and 10 at 25 percent
    for (p, wrong) in [(50usize, 10usize), (25, 5)] {
        let scheme = scheme_of(40).with_parity_percent(p);
        let values = values_of(40);
        let sent = pack(&scheme, &values).expect("pack");

        // Act
        let repaired = unpack_repair(&scheme, &damaged(sent.clone(), wrong), wrong);
        let beyond = unpack_repair(&scheme, &damaged(sent, wrong + 1), wrong);

        // Assert
        assert_eq!(repaired, Ok((values, wrong)), "p {p}");
        assert_eq!(beyond.map(|_| ()), Err(UnpackError::Uncorrectable), "p {p}");
    }
}

#[test]
fn ac6_a_limit_outside_0_to_16_is_refused_before_any_byte_is_read() {
    // Arrange
    let scheme = scheme_of(40).with_parity_percent(25);
    let sent = pack(&scheme, &values_of(40)).expect("pack");

    // Act
    let low = unpack_repair(&scheme, &[], 17);
    let high = unpack_repair(&scheme, &sent, 17);
    let lowered = unpack_repair(&scheme, &damaged(sent.clone(), 5), 16);
    let counted = unpack_repair(&scheme_of(40).with_parity(10), &sent, 6);
    let plain = unpack_repair(&scheme_of(40).with_parity_percent(0), &sent[..40], 1);

    // Assert
    let refused = Err(UnpackError::BadLimit { limit: 17, max: 16 });
    assert_eq!(low.map(|_| ()), refused);
    assert_eq!(high.map(|_| ()), refused);
    assert_eq!(
        lowered.map(|(_, repaired)| repaired),
        Ok(5),
        "16 behaves as 5"
    );
    assert_eq!(
        counted.map(|_| ()),
        Err(UnpackError::BadLimit { limit: 6, max: 5 }),
        "a fixed count keeps its exact rule"
    );
    assert_eq!(
        plain.map(|_| ()),
        Err(UnpackError::BadLimit { limit: 1, max: 0 }),
        "percentage 0 has the limit rule of count 0"
    );
}

fn percent_position(type_number: i32, p: usize) -> packbin::Scheme<PositionRow> {
    position_scheme(type_number, 0).with_parity_percent(p)
}

#[test]
fn ac7_handlers_of_one_percentage_dispatch_after_the_repair() {
    // Arrange
    let (a, b) = (percent_position(0x40, 50), percent_position(0x41, 50));
    let mut message = BinaryPacker::pack(&a, &position_row()).expect("pack");
    message[3] ^= 0x5A;
    message[7] ^= 0x33;
    let mut seen = Vec::new();

    // Act
    let read = BinaryPacker::unpack_with_repair(
        &message,
        &mut [
            &mut a.on(|row| seen.push(row)),
            &mut b.on(|_| panic!("wrong handler")),
        ],
        2,
    );

    // Assert
    assert_eq!(read, Ok(2));
    assert_eq!(seen, vec![position_row()]);
    assert_eq!(message.len(), 13 + count(50, 13));
}

#[test]
fn ac7_a_mix_of_settings_is_refused_when_the_call_is_built_before_any_byte_is_read() {
    // Arrange
    let (ten, quarter) = (percent_position(0x40, 10), percent_position(0x41, 25));
    let counted = position_scheme(0x42, 4);
    let message = BinaryPacker::pack(&ten, &position_row()).expect("pack");

    // Act
    let two_percentages = BinaryPacker::unpack_with_repair(
        &message,
        &mut [
            &mut ten.on(|_| panic!("handler ran")),
            &mut quarter.on(|_| panic!("handler ran")),
        ],
        99,
    );
    let with_count = BinaryPacker::unpack_with(
        &[],
        &mut [
            &mut quarter.on(|_| panic!("handler ran")),
            &mut counted.on(|_| panic!("handler ran")),
        ],
    );
    let limit =
        BinaryPacker::unpack_with_repair(&[], &mut [&mut ten.on(|_| panic!("handler ran"))], 17);

    // Assert
    assert_eq!(
        two_percentages,
        Err(UnpackError::MixedParity {
            first: 10,
            other: 25,
            first_percent: true,
            other_percent: true
        })
    );
    assert_eq!(
        with_count,
        Err(UnpackError::MixedParity {
            first: 25,
            other: 4,
            first_percent: true,
            other_percent: false
        })
    );
    assert_eq!(limit, Err(UnpackError::BadLimit { limit: 17, max: 16 }));
}

struct Counted {
    ran: bool,
}

impl DispatchHandler for Counted {
    fn type_number(&self) -> u8 {
        0x40
    }

    fn parity(&self) -> usize {
        0
    }

    fn handle(&mut self, _body: &[u8]) -> Result<(), UnpackError> {
        self.ran = true;
        Ok(())
    }
}

struct Percent(Counted);

impl DispatchHandler for Percent {
    fn type_number(&self) -> u8 {
        0x41
    }

    fn parity(&self) -> usize {
        0
    }

    fn parity_percent(&self) -> usize {
        50
    }

    fn handle(&mut self, body: &[u8]) -> Result<(), UnpackError> {
        self.0.handle(body)
    }
}

#[test]
fn ac7_a_hand_written_handler_defaults_to_no_percentage_and_may_declare_one() {
    // Arrange
    let mut plain = Counted { ran: false };
    let mut declared = Percent(Counted { ran: false });
    let message = [0x40u8, 1, 2];

    // Act
    let default = BinaryPacker::unpack_with(&message, &mut [&mut plain]);
    let mixed = BinaryPacker::unpack_with(&message, &mut [&mut plain, &mut declared]);

    // Assert
    assert_eq!((plain.parity_percent(), declared.parity_percent()), (0, 50));
    assert_eq!(default, Ok(()));
    assert!(plain.ran);
    assert_eq!(
        mixed,
        Err(UnpackError::MixedParity {
            first: 0,
            other: 50,
            first_percent: false,
            other_percent: true
        })
    );
}

#[test]
fn ac3_a_percentage_and_a_count_of_the_same_number_are_told_apart_in_the_mix_error() {
    // Arrange
    let percent = percent_position(0x40, 25);
    let counted = position_scheme(0x41, 25);

    // Act
    let percent_first = BinaryPacker::unpack_with(
        &[],
        &mut [
            &mut percent.on(|_| panic!("handler ran")),
            &mut counted.on(|_| panic!("handler ran")),
        ],
    );
    let count_first = BinaryPacker::unpack_with(
        &[],
        &mut [
            &mut counted.on(|_| panic!("handler ran")),
            &mut percent.on(|_| panic!("handler ran")),
        ],
    );

    // Assert
    assert_eq!(
        percent_first,
        Err(UnpackError::MixedParity {
            first: 25,
            other: 25,
            first_percent: true,
            other_percent: false
        })
    );
    assert_eq!(
        count_first,
        Err(UnpackError::MixedParity {
            first: 25,
            other: 25,
            first_percent: false,
            other_percent: true
        })
    );
}

/// 8 bytes, then a presence byte and the optional 3 bytes: 10 clear bytes without, 13 with.
fn optional_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![bytes("b", 8), flags(1, "f", vec![bytes("o", 3)])],
    )
    .with_parity_percent(25)
}

fn optional_values(with: bool) -> Values {
    let mut values = Values::new();
    insert(&mut values, "b", Some(Value::Bytes(vec![1, 2, 3, 4, 5, 6, 7, 8])));
    insert(
        &mut values,
        "o",
        with.then(|| Value::Bytes(vec![9, 10, 11])),
    );
    values
}

#[test]
fn ac1_a_message_with_an_optional_field_carries_the_count_of_its_own_length() {
    // Arrange
    let scheme = optional_scheme();

    for (with, clear, parity) in [(true, 13usize, 4usize), (false, 10, 3)] {
        let values = optional_values(with);

        // Act
        let sent = pack(&scheme, &values).expect("pack");
        let back = unpack(&scheme, &sent).expect("unpack");

        // Assert
        assert_eq!(sent.len(), clear + parity, "with {with}");
        assert_eq!(back["b"], values["b"], "with {with}");
        assert_eq!(back.get("o").cloned().flatten(), values["o"], "with {with}");
    }
}

#[test]
fn ac2_a_string_field_is_read_after_the_repair_of_a_wrong_byte_inside_it() {
    // Arrange
    let scheme = MapScheme::new(1, vec![utf8("s")]).with_parity_percent(25);
    let mut values = Values::new();
    insert(&mut values, "s", Some(Value::Str("Привіт, світе!".into())));
    let sent = pack(&scheme, &values).expect("pack");
    let mut word = sent.clone();
    word[5] ^= 0x5A;

    // Act
    let repaired = unpack_repair(&scheme, &word, 1);

    // Assert
    assert_eq!(repaired, Ok((values, 1)));
}
