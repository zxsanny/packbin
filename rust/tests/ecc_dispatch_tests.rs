#![cfg(feature = "std")]
mod ecc_support;

use ecc_support::{corrupt, position_row, position_scheme, PositionRow, Rng};
use packbin::{BinaryPacker, DispatchHandler, Scheme, UnpackError};

// AZ-2684: the dispatch same-n rule with repair first (EC-16).

fn second_scheme(parity: usize) -> Scheme<PositionRow> {
    position_scheme(0x41, parity)
}

#[test]
fn ec16_a_dispatch_of_mixed_parity_counts_is_refused_naming_both() {
    // Arrange
    let (a, b) = (position_scheme(0x40, 4), second_scheme(2));
    let (mut on_a, mut on_b) = (
        a.on(|_| panic!("handler ran")),
        b.on(|_| panic!("handler ran")),
    );
    let message = BinaryPacker::pack(&a, &position_row()).expect("pack");

    // Act
    let refused = BinaryPacker::unpack_with_repair(&message, &mut [&mut on_a, &mut on_b], 1);
    let plain = BinaryPacker::unpack_with(&message, &mut [&mut on_a, &mut on_b]);

    // Assert
    assert_eq!(
        refused,
        Err(UnpackError::MixedParity { first: 4, other: 2 })
    );
    assert_eq!(plain, Err(UnpackError::MixedParity { first: 4, other: 2 }));
}

// A hand-written handler: `parity()` is required (AZ-2704 AC-4, the compile-fail doc test on the trait).
struct Handwritten {
    type_number: u8,
    parity: usize,
    ran: bool,
}

impl DispatchHandler for Handwritten {
    fn type_number(&self) -> u8 {
        self.type_number
    }

    fn parity(&self) -> usize {
        self.parity
    }

    fn handle(&mut self, _body: &[u8]) -> Result<(), UnpackError> {
        self.ran = true;
        Ok(())
    }
}

#[test]
fn a_hand_written_handler_of_a_parity_scheme_gets_the_repair() {
    // Arrange
    let mut handler = Handwritten {
        type_number: 0x40,
        parity: 4,
        ran: false,
    };
    let mut message = BinaryPacker::pack(&position_scheme(0x40, 4), &position_row()).expect("pack");
    message[3] ^= 0x5A;

    // Act
    let read = BinaryPacker::unpack_with_repair(&message, &mut [&mut handler], 2);

    // Assert
    assert_eq!(read, Ok(1));
    assert!(handler.ran);
}

// AZ-2666 (loop 41 audit, R-1): a hand-written handler that declares more than 32 parity bytes is
// refused before any byte is read; it used to panic on any message of n to 254 bytes.
#[test]
fn a_hand_written_handler_above_32_parity_bytes_is_refused_without_reading() {
    // Arrange
    let message = [0u8; 254];
    let mut results = Vec::new();

    // Act
    for parity in [33, 254, usize::MAX] {
        let mut handler = Handwritten {
            type_number: 0x40,
            parity,
            ran: false,
        };
        let read = BinaryPacker::unpack_with_repair(&message, &mut [&mut handler], 0);
        results.push((read, handler.ran));
    }

    // Assert
    assert_eq!(
        results,
        vec![
            (Err(UnpackError::BadParity { parity: 33, max: 32 }), false),
            (Err(UnpackError::BadParity { parity: 254, max: 32 }), false),
            (Err(UnpackError::BadParity { parity: usize::MAX, max: 32 }), false),
        ]
    );
}

// AZ-2704: the checks run in one order in every package (no handler, duplicate type, parity mix, limit).
#[test]
fn an_empty_handler_list_is_refused() {
    // Arrange
    let message = BinaryPacker::pack(&position_scheme(0x40, 4), &position_row()).expect("pack");

    // Act
    let repaired = BinaryPacker::unpack_with_repair(&message, &mut [], 0);
    let plain = BinaryPacker::unpack_with(&message, &mut []);

    // Assert
    assert_eq!(repaired, Err(UnpackError::NoHandlers));
    assert_eq!(plain, Err(UnpackError::NoHandlers));
}

#[test]
fn a_duplicate_type_is_refused_before_a_parity_mix_and_a_bad_limit() {
    // Arrange
    let (a, b, twin) = (position_scheme(0x40, 4), second_scheme(2), position_scheme(0x40, 4));
    let (mut on_a, mut on_b, mut on_twin) = (
        a.on(|_| panic!("handler ran")),
        b.on(|_| panic!("handler ran")),
        twin.on(|_| panic!("handler ran")),
    );
    let duplicate = Err(UnpackError::DuplicateType { type_number: 0x40 });

    // Act
    let with_mix =
        BinaryPacker::unpack_with_repair(&[0; 8], &mut [&mut on_a, &mut on_b, &mut on_twin], 0);
    let with_limit = BinaryPacker::unpack_with_repair(&[0; 8], &mut [&mut on_a, &mut on_twin], 9);

    // Assert
    assert_eq!(with_mix, duplicate);
    assert_eq!(with_limit, duplicate);
}

#[test]
fn ec16_a_wrong_type_byte_is_repaired_and_the_right_handler_runs_in_1000_seeded_cases() {
    // Arrange
    let (a, b) = (position_scheme(0x40, 4), second_scheme(4));
    let mut rng = Rng(0xEC16);

    for case in 0..1000 {
        let (scheme, right, wrong) = if case % 2 == 0 {
            (&a, 0x40, 0x41)
        } else {
            (&b, 0x41, 0x40)
        };
        let mut message = BinaryPacker::pack(scheme, &position_row()).expect("pack");
        let k = 1 + rng.below(2);
        corrupt(&mut message, k, Some(0), &mut rng);
        let (mut ran_a, mut ran_b) = (0, 0);

        // Act
        let repaired = BinaryPacker::unpack_with_repair(
            &message,
            &mut [&mut a.on(|_| ran_a += 1), &mut b.on(|_| ran_b += 1)],
            2,
        );

        // Assert
        assert_eq!(repaired, Ok(k), "case {case}");
        let (right_runs, wrong_runs) = if right == 0x40 {
            (ran_a, ran_b)
        } else {
            (ran_b, ran_a)
        };
        assert_eq!(
            (right_runs, wrong_runs),
            (1, 0),
            "case {case}: type {right:#x} not {wrong:#x}"
        );
    }
}

#[test]
fn ec16_a_message_beyond_the_limit_runs_no_handler() {
    // Arrange
    let a = position_scheme(0x40, 4);
    let mut message = BinaryPacker::pack(&a, &position_row()).expect("pack");
    message[0] ^= 1;
    message[3] ^= 1;
    message[6] ^= 1;
    let mut ran = 0;

    // Act
    let read = BinaryPacker::unpack_with_repair(&message, &mut [&mut a.on(|_| ran += 1)], 2);

    // Assert
    assert_eq!(read, Err(UnpackError::Uncorrectable));
    assert_eq!(ran, 0);
}

#[test]
fn ec16_the_dispatch_of_schemes_without_parity_is_unchanged() {
    // Arrange
    let (a, b) = (position_scheme(0x40, 0), second_scheme(0));
    let message = BinaryPacker::pack(&b, &position_row()).expect("pack");
    let (mut ran_a, mut ran_b) = (0, 0);

    // Act
    let read = BinaryPacker::unpack_with(
        &message,
        &mut [&mut a.on(|_| ran_a += 1), &mut b.on(|_| ran_b += 1)],
    );
    let unknown = BinaryPacker::unpack_with(&[9, 1], &mut [&mut a.on(|_| {})]);

    // Assert
    assert_eq!((read, ran_a, ran_b), (Ok(()), 0, 1));
    assert_eq!(
        unknown,
        Err(UnpackError::Type {
            expected: 0,
            actual: 9
        })
    );
}
