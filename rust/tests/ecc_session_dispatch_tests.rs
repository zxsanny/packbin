mod ecc_support;

use ecc_support::{corrupt, from_hex, position_row, position_scheme, PositionRow, Rng};
use packbin::{
    bytes, insert, pack, to_hex, BinaryPacker, BoundField, DispatchHandler, MapScheme, PackError, PackSession,
    Scheme, SessionPackError, UnpackError, Value, Values, NONCE_SIZE, SEED_SIZE,
};

// AZ-2684: the dispatch same-n rule with repair first (EC-16) and the session with parity over the padded bytes (EC-10).

const CIPHER_HEX: &str = "b55d0a29c56c203712b241232e";

fn seed() -> [u8; SEED_SIZE] {
    let mut s = [0u8; SEED_SIZE];
    for (i, b) in s.iter_mut().enumerate() {
        *b = (i + 1) as u8;
    }
    s
}

fn fixture_nonce() -> [u8; NONCE_SIZE] {
    let mut n = [0u8; NONCE_SIZE];
    n[0] = 0x01;
    n
}

fn pair() -> (PackSession, PackSession) {
    let mut opener = PackSession::load(&seed()).expect("load");
    let mut waiter = PackSession::load(&seed()).expect("load");
    let nonce = opener.start_with(&fixture_nonce()).expect("start");
    assert!(waiter.join(&nonce));
    (opener, waiter)
}

fn read_session(
    waiter: &mut PackSession,
    payload: &[u8],
    parity: usize,
    limit: usize,
) -> Result<(PositionRow, usize), UnpackError> {
    let scheme = position_scheme(0x40, parity);
    let mut got = None;
    let repaired =
        waiter.unpack_repair(payload, &mut [&mut scheme.on(|r| got = Some(r))], limit)?;
    Ok((got.expect("handler ran"), repaired))
}

#[test]
fn ec10_n0_session_payload_keeps_the_clear_length_and_bytes() {
    // Arrange
    let (mut opener, mut waiter) = pair();

    // Act
    let payload = opener
        .pack(&position_scheme(0x40, 0), &position_row())
        .expect("pack");
    let read = read_session(&mut waiter, &payload, 0, 0);

    // Assert
    assert_eq!(to_hex(&payload), CIPHER_HEX);
    assert_eq!(read, Ok((position_row(), 0)));
}

#[test]
fn ec10_the_parity_covers_the_padded_bytes() {
    // Arrange: the same 13 padded bytes protected through a scheme whose type byte is the first padded byte
    let (mut opener, _) = pair();
    let padded = from_hex(CIPHER_HEX);
    let oracle = MapScheme::new(padded[0] as i32, vec![bytes("b", 12)]).with_parity(4);
    let mut values = Values::new();
    insert(&mut values, "b", Some(Value::Bytes(padded[1..].to_vec())));

    // Act
    let payload = opener
        .pack(&position_scheme(0x40, 4), &position_row())
        .expect("pack");

    // Assert
    assert_eq!(payload.len(), 17);
    assert_eq!(payload, pack(&oracle, &values).expect("oracle"));
    assert_eq!(&payload[..13], &padded[..]);
}

#[test]
fn ec10_n4_two_wrong_bytes_are_repaired_and_the_row_is_returned() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let payload = opener
        .pack(&position_scheme(0x40, 4), &position_row())
        .expect("pack");
    let mut rng = Rng(0xEC10);

    for case in 0..500 {
        let mut word = payload.clone();
        corrupt(&mut word, 2, None, &mut rng);
        let mut reader = PackSession::load(&seed()).expect("load");
        assert!(reader.join(&fixture_nonce()));

        // Act
        let read = read_session(&mut reader, &word, 4, 2);

        // Assert
        assert_eq!(read, Ok((position_row(), 2)), "case {case}");
    }
    assert_eq!(
        read_session(&mut waiter, &payload, 4, 2),
        Ok((position_row(), 0))
    );
}

#[test]
fn ec10_three_wrong_bytes_with_t2_are_refused_and_the_next_payload_is_still_read() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let scheme = position_scheme(0x40, 4);
    let first = opener.pack(&scheme, &position_row()).expect("pack");
    let second = opener.pack(&scheme, &position_row()).expect("pack");
    let mut broken = first.clone();
    broken[0] ^= 0x11;
    broken[5] ^= 0x22;
    broken[9] ^= 0x33;

    // Act
    let refused = read_session(&mut waiter, &broken, 4, 2);
    let next = read_session(&mut waiter, &second, 4, 2);

    // Assert
    assert_eq!(refused, Err(UnpackError::Uncorrectable));
    assert_eq!(next, Ok((position_row(), 0)));
}

#[test]
fn ec10_a_limit_above_half_n_is_refused_without_moving_the_receive_index() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let payload = opener
        .pack(&position_scheme(0x40, 4), &position_row())
        .expect("pack");

    // Act
    let refused = read_session(&mut waiter, &payload, 4, 3);
    let read = read_session(&mut waiter, &payload, 4, 0);

    // Assert
    assert_eq!(refused, Err(UnpackError::BadLimit { limit: 3, max: 2 }));
    assert_eq!(read, Ok((position_row(), 0)));
}

#[test]
fn ec4_a_session_pack_above_the_limit_is_refused_and_uses_no_pad_position() {
    // Arrange
    let long = |parity: usize| {
        Scheme::<Vec<u8>>::new(
            1,
            [
                BoundField::bytes(0, 222, |r: &Vec<u8>| r.clone(), |r: &mut Vec<u8>, v| *r = v)
                    .into(),
            ],
        )
        .with_parity(parity)
    };
    let (mut opener, _) = pair();
    let (mut fresh, _) = pair();

    // Act
    let refused = opener.pack(&long(32), &vec![9u8; 222]);
    let after = opener
        .pack(&position_scheme(0x40, 0), &position_row())
        .expect("pack");
    let first = fresh
        .pack(&position_scheme(0x40, 0), &position_row())
        .expect("pack");

    // Assert
    match refused {
        Err(SessionPackError::Pack(PackError::Type(text))) => {
            assert!(
                text.contains("223") && text.contains("limit of 222"),
                "{text}"
            )
        }
        other => panic!("expected the size refusal, got {other:?}"),
    }
    assert_eq!(after, first);
}

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

#[test]
fn ec16_a_duplicate_type_is_refused_before_the_receive_index_advances() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let scheme = position_scheme(0x40, 4);
    let twin = position_scheme(0x40, 4);
    let payload = opener.pack(&scheme, &position_row()).expect("pack");
    let (mut on_a, mut on_b) = (
        scheme.on(|_| panic!("handler ran")),
        twin.on(|_| panic!("handler ran")),
    );

    // Act
    let refused = waiter.unpack_repair(&payload, &mut [&mut on_a, &mut on_b], 0);
    let read = read_session(&mut waiter, &payload, 4, 0);

    // Assert
    assert_eq!(refused, Err(UnpackError::DuplicateType { type_number: 0x40 }));
    assert_eq!(read, Ok((position_row(), 0)));
}

// A handler written against loop 37: it defines no parity().
struct Loop37Handler {
    type_number: u8,
    ran: bool,
}

impl DispatchHandler for Loop37Handler {
    fn type_number(&self) -> u8 {
        self.type_number
    }

    fn handle(&mut self, _body: &[u8]) -> Result<(), UnpackError> {
        self.ran = true;
        Ok(())
    }
}

#[test]
fn a_handler_without_parity_compiles_has_parity_0_and_dispatches() {
    // Arrange
    let mut handler = Loop37Handler {
        type_number: 0x40,
        ran: false,
    };
    let message = BinaryPacker::pack(&position_scheme(0x40, 0), &position_row()).expect("pack");

    // Act
    let parity = handler.parity();
    let read = BinaryPacker::unpack_with(&message, &mut [&mut handler]);

    // Assert
    assert_eq!(parity, 0);
    assert_eq!(read, Ok(()));
    assert!(handler.ran);
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
