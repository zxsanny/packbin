//! The session on the heap-free core (AZ-2756): the same bytes as the `std` `PackSession` for one
//! seed and nonce, a packet each opens for the other, and a refusal for every bad argument, nonce,
//! seed and tampered payload. Needs the `session` feature; the cross-open tests also need `std`.
#![cfg(feature = "session")]

mod nostd_support;

use nostd_support::{from_hex, Slots};
use packbin::nostd::{
    bytes, i32, u16, u8, Error, Field, Num, Row, Scheme, Session, NONCE_SIZE, SEED_SIZE,
};

const POSITION: [Field; 5] = [u16(0), i32(1), i32(2), u8(3), u8(4)];
const CIPHER: &str = "b55d0a29c56c203712b241232e";

fn seed() -> [u8; SEED_SIZE] {
    let mut s = [0u8; SEED_SIZE];
    for (i, b) in s.iter_mut().enumerate() {
        *b = (i + 1) as u8;
    }
    s
}

fn nonce() -> [u8; NONCE_SIZE] {
    let mut n = [0u8; NONCE_SIZE];
    n[0] = 1;
    n
}

fn scheme(parity: u8) -> Scheme<'static> {
    Scheme::new(0x40, &POSITION).with_parity(parity)
}

fn row() -> Slots {
    Slots::with(
        &[
            (0, Num::U16(1)),
            (1, Num::I32(500_000_000)),
            (2, Num::I32(300_000_000)),
            (3, Num::U8(1)),
            (4, Num::U8(0)),
        ],
        &[],
    )
}

fn same_row(a: &Slots) {
    for id in 0..5 {
        assert_eq!(a.num(id), row().num(id), "field {id}");
    }
}

fn pair() -> (Session, Session) {
    let mut opener = Session::load(&seed()).expect("load");
    let mut waiter = Session::load(&seed()).expect("load");
    opener.start(&nonce()).expect("start");
    waiter.join(&nonce()).expect("join");
    (opener, waiter)
}

fn sealed(session: &mut Session, parity: u8) -> Vec<u8> {
    let mut out = [0u8; 64];
    let n = session
        .pack(&scheme(parity), &row(), &mut out)
        .expect("pack");
    out[..n].to_vec()
}

#[test]
fn ac1_the_opener_packet_is_the_fixture_cipher() {
    // Arrange
    let (mut opener, _) = pair();
    // Act
    let wire = sealed(&mut opener, 0);
    // Assert
    assert_eq!(wire, from_hex(CIPHER));
}

#[test]
fn ac1_the_waiter_opens_what_the_opener_sealed_in_order() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let (mut first, mut second) = (sealed(&mut opener, 0), sealed(&mut opener, 0));
    let (mut back, mut again) = (Slots::default(), Slots::default());
    // Act
    let a = waiter.unpack(&scheme(0), &mut first, &mut back);
    let b = waiter.unpack(&scheme(0), &mut second, &mut again);
    // Assert
    assert_eq!((a, b), (Ok(13), Ok(13)));
    same_row(&back);
    same_row(&again);
    assert_eq!(first, from_hex("4001000065cd1d00a3e1110100"));
}

#[test]
fn ac1_each_direction_has_its_own_key() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let mut from_waiter = sealed(&mut waiter, 0);
    let mut back = Slots::default();
    // Act
    let by_opener = opener.unpack(&scheme(0), &mut from_waiter, &mut back);
    // Assert
    assert_eq!(by_opener, Ok(13));
    same_row(&back);
}

#[test]
fn ac1_the_second_packet_uses_the_next_pad_position() {
    // Arrange
    let (mut opener, _) = pair();
    // Act
    let (first, second) = (sealed(&mut opener, 0), sealed(&mut opener, 0));
    // Assert
    assert_ne!(first, second);
}

#[cfg(feature = "std")]
mod against_std {
    use super::*;
    use packbin::{BoundField, PackSession, Scheme as StdScheme};

    #[derive(Default, Clone, Debug, PartialEq, Eq)]
    struct P {
        sid: u16,
        lat: i32,
        lon: i32,
        profile: u8,
        tail: u8,
    }

    fn std_scheme(parity: usize) -> StdScheme<P> {
        StdScheme::new(
            0x40,
            [
                BoundField::u16(0, |r: &P| r.sid, |r: &mut P, v| r.sid = v).into(),
                BoundField::i32(1, |r: &P| r.lat, |r: &mut P, v| r.lat = v).into(),
                BoundField::i32(2, |r: &P| r.lon, |r: &mut P, v| r.lon = v).into(),
                BoundField::u8(3, |r: &P| r.profile, |r: &mut P, v| r.profile = v).into(),
                BoundField::u8(4, |r: &P| r.tail, |r: &mut P, v| r.tail = v).into(),
            ],
        )
        .with_parity(parity)
    }

    fn std_row() -> P {
        P {
            sid: 1,
            lat: 500_000_000,
            lon: 300_000_000,
            profile: 1,
            tail: 0,
        }
    }

    fn std_pair() -> (PackSession, PackSession) {
        let mut opener = PackSession::load(&seed()).expect("load");
        let mut waiter = PackSession::load(&seed()).expect("load");
        let n = opener.start_with(&nonce()).expect("start");
        assert!(waiter.join(&n));
        (opener, waiter)
    }

    fn std_opens(waiter: &mut PackSession, parity: usize, wire: &[u8]) -> P {
        let scheme = std_scheme(parity);
        let mut got = None;
        let mut on = scheme.on(|r| got = Some(r));
        waiter.unpack(wire, &mut [&mut on]).expect("std unpack");
        got.expect("row")
    }

    fn check(parity: u8) {
        // Arrange
        let (mut std_opener, mut std_waiter) = std_pair();
        let (mut core_opener, mut core_waiter) = pair();
        for round in 0..3 {
            // Act
            let theirs = std_opener
                .pack(&std_scheme(usize::from(parity)), &std_row())
                .expect("std");
            let ours = sealed(&mut core_opener, parity);
            // Assert: same bytes, and each opens the other's packet
            assert_eq!(ours, theirs, "round {round} parity {parity}");
            let mut copy = theirs.clone();
            let mut back = Slots::default();
            let used = core_waiter.unpack(&scheme(parity), &mut copy, &mut back);
            assert_eq!(used, Ok(theirs.len()));
            same_row(&back);
            assert_eq!(
                std_opens(&mut std_waiter, usize::from(parity), &ours),
                std_row()
            );
        }
    }

    #[test]
    fn ac1_same_bytes_and_cross_open_without_parity() {
        check(0);
    }

    #[cfg(feature = "ecc")]
    #[test]
    fn ac1_same_bytes_and_cross_open_with_parity() {
        for n in [2, 4, 8, 32] {
            check(n);
        }
    }

    #[test]
    fn ac1_the_std_waiter_opens_what_the_core_waiter_sealed() {
        // Arrange
        let (mut std_opener, _) = std_pair();
        let (_, mut core_waiter) = pair();
        let mut wire = std_opener.pack(&std_scheme(0), &std_row()).expect("pack");
        let mut back = Slots::default();
        // Act
        let used = core_waiter.unpack(&scheme(0), &mut wire, &mut back);
        // Assert
        assert_eq!(used, Ok(13));
        same_row(&back);
    }
}

#[test]
fn ac3_a_seed_of_the_wrong_size_is_refused() {
    for len in [0, 1, 31, 33, 64] {
        // Act
        let loaded = Session::load(&vec![7u8; len]);
        // Assert
        let fault = loaded.err().expect("refused");
        assert_eq!(
            (fault.error, fault.needed),
            (Error::BadValue, SEED_SIZE),
            "{len}"
        );
    }
}

#[test]
fn ac3_a_nonce_of_the_wrong_size_is_refused_and_leaves_the_session_closed() {
    for len in [0, 15, 17, 32] {
        // Arrange
        let mut session = Session::load(&seed()).expect("load");
        // Act
        let fault = session.start(&vec![1u8; len]).err().expect("refused");
        let joined = session.join(&vec![1u8; len]).err().expect("refused");
        // Assert
        assert_eq!(
            (fault.error, fault.needed),
            (Error::BadValue, NONCE_SIZE),
            "{len}"
        );
        assert_eq!(joined.error, Error::BadValue);
        assert!(!session.is_open());
        assert!(
            session.start(&nonce()).is_ok(),
            "the seed is kept after a refusal"
        );
    }
}

#[test]
fn ac3_a_session_that_is_not_open_or_already_open_is_refused() {
    // Arrange
    let mut closed = Session::load(&seed()).expect("load");
    let (mut open, _) = pair();
    let mut out = [0u8; 32];
    let mut data = from_hex(CIPHER);
    // Act
    let packed = closed.pack(&scheme(0), &row(), &mut out);
    let read = closed.unpack(&scheme(0), &mut data, &mut Slots::default());
    // Assert
    assert_eq!(packed.err().map(|f| f.error), Some(Error::BadValue));
    assert_eq!(read.err().map(|f| f.error), Some(Error::BadValue));
    assert_eq!(out, [0u8; 32]);
    assert_eq!(
        data,
        from_hex(CIPHER),
        "a refused call leaves the bytes alone"
    );
    assert_eq!(
        open.start(&nonce()).err().map(|f| f.error),
        Some(Error::BadValue)
    );
    assert_eq!(
        open.join(&nonce()).err().map(|f| f.error),
        Some(Error::BadValue)
    );
}

#[test]
fn ac3_a_full_buffer_writes_nothing_and_keeps_the_send_position() {
    // Arrange
    let (mut opener, _) = pair();
    let mut small = [0xAAu8; 5];
    // Act
    let refused = opener.pack(&scheme(0), &row(), &mut small);
    // Assert
    let fault = refused.err().expect("refused");
    assert_eq!(fault.error, Error::BufferFull);
    assert!(
        small[..fault.offset].iter().all(|b| *b == 0),
        "no partial output"
    );
    assert_eq!(
        sealed(&mut opener, 0),
        from_hex(CIPHER),
        "the position was not used"
    );
}

#[test]
fn ac3_a_row_without_a_value_is_refused_without_output() {
    // Arrange
    let (mut opener, _) = pair();
    let mut out = [0xAAu8; 32];
    // Act
    let refused = opener.pack(&scheme(0), &Slots::default(), &mut out);
    // Assert
    let fault = refused.err().expect("refused");
    assert_eq!(fault.error, Error::BadValue);
    assert!(
        out[..fault.offset].iter().all(|b| *b == 0),
        "no partial output"
    );
    assert_eq!(sealed(&mut opener, 0), from_hex(CIPHER));
}

#[test]
fn ac3_a_refused_bits_value_leaves_no_plaintext_anywhere_in_the_buffer() {
    // Arrange: the third value is out of range, found after the first two were counted
    const FIELDS: [Field; 2] = [u8(0), packbin::nostd::bits(1, 0)];
    let scheme = Scheme::new(1, &FIELDS);
    let row = Slots::with(&[(0, Num::U8(4))], &[(1, &[1, 1, 1, 2])]);
    let (mut opener, _) = pair();
    let mut out = [0xAAu8; 16];
    // Act
    let refused = opener.pack(&scheme, &row, &mut out);
    // Assert
    assert_eq!(refused.err().map(|f| f.error), Some(Error::BadValue));
    assert!(out.iter().all(|b| *b == 0xAA || *b == 0), "{out:02x?}");
}

#[test]
fn ac3_a_tampered_type_number_is_refused_and_the_next_packet_still_opens() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let mut first = sealed(&mut opener, 0);
    let mut second = sealed(&mut opener, 0);
    first[0] ^= 0x01;
    // Act
    let refused = waiter.unpack(&scheme(0), &mut first, &mut Slots::default());
    let mut back = Slots::default();
    let next = waiter.unpack(&scheme(0), &mut second, &mut back);
    // Assert
    assert_eq!(refused.err().map(|f| f.error), Some(Error::TypeMismatch));
    assert_eq!(next, Ok(13));
    same_row(&back);
}

#[test]
fn ac3_a_short_or_long_payload_is_an_error_kind() {
    // Arrange
    let (mut opener, mut waiter) = pair();
    let whole = sealed(&mut opener, 0);
    let mut short = whole[..6].to_vec();
    let mut long = [whole.as_slice(), &[9u8]].concat();
    // Act
    let a = waiter.unpack(&scheme(0), &mut short, &mut Slots::default());
    let b = waiter.unpack(&scheme(0), &mut long, &mut Slots::default());
    // Assert
    assert!(matches!(a.err().map(|f| f.error), Some(Error::ShortPacket)));
    assert!(matches!(
        b.err().map(|f| f.error),
        Some(Error::TrailingBytes | Error::TypeMismatch)
    ));
}

#[test]
fn ac3_random_bytes_of_every_length_never_panic() {
    // Arrange
    let (_, mut waiter) = pair();
    let mut state = 0x2545_F491_4F6C_DD1Du64;
    for len in 0..80 {
        let mut data: Vec<u8> = (0..len)
            .map(|_| {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                state as u8
            })
            .collect();
        // Act
        let result = waiter.unpack(&scheme(0), &mut data, &mut Slots::default());
        // Assert
        assert!(result.is_ok() || result.is_err());
    }
}

#[cfg(feature = "ecc")]
mod protected {
    use super::*;

    #[test]
    fn ac3_wrong_bytes_beyond_the_limit_are_uncorrectable_and_the_position_moves() {
        // Arrange
        let (mut opener, mut waiter) = pair();
        let mut first = sealed(&mut opener, 4);
        let mut second = sealed(&mut opener, 4);
        for at in [1, 4, 7] {
            first[at] ^= 0x55;
        }
        let damaged = first.clone();
        // Act
        let refused = waiter.unpack_repair(&scheme(4), &mut first, &mut Slots::default(), 2);
        let mut back = Slots::default();
        let next = waiter.unpack_repair(&scheme(4), &mut second, &mut back, 2);
        // Assert
        assert_eq!(refused.err().map(|f| f.error), Some(Error::Uncorrectable));
        assert_eq!(first, damaged, "the bytes are not changed");
        assert_eq!(next.map(|u| (u.bytes, u.repaired)), Ok((17, 0)));
        same_row(&back);
    }

    #[test]
    fn ac3_repair_fixes_wrong_bytes_up_to_the_limit() {
        // Arrange
        let (mut opener, mut waiter) = pair();
        let mut wire = sealed(&mut opener, 4);
        wire[2] ^= 0xFF;
        wire[9] ^= 0x01;
        let mut back = Slots::default();
        // Act
        let done = waiter.unpack_repair(&scheme(4), &mut wire, &mut back, 2);
        // Assert
        assert_eq!(done.map(|u| (u.bytes, u.repaired)), Ok((17, 2)));
        same_row(&back);
    }

    #[test]
    fn ac3_detect_only_refuses_any_wrong_byte() {
        // Arrange
        let (mut opener, mut waiter) = pair();
        let mut wire = sealed(&mut opener, 4);
        wire[3] ^= 0x10;
        // Act
        let refused = waiter.unpack(&scheme(4), &mut wire, &mut Slots::default());
        // Assert
        assert_eq!(refused.err().map(|f| f.error), Some(Error::Uncorrectable));
    }

    #[test]
    fn ac3_a_limit_above_half_the_parity_leaves_the_position_alone() {
        // Arrange
        let (mut opener, mut waiter) = pair();
        let mut wire = sealed(&mut opener, 4);
        let copy = wire.clone();
        // Act
        let refused = waiter.unpack_repair(&scheme(4), &mut wire, &mut Slots::default(), 3);
        let untouched = wire.clone();
        let mut back = Slots::default();
        let done = waiter.unpack_repair(&scheme(4), &mut wire, &mut back, 2);
        // Assert
        assert_eq!(
            refused.err().map(|f| (f.error, f.needed)),
            Some((Error::BadValue, 2))
        );
        assert_eq!(untouched, copy);
        assert_eq!(done.map(|u| u.repaired), Ok(0));
        same_row(&back);
    }

    #[test]
    fn ac3_a_message_above_254_bytes_is_too_long_and_leaves_no_output() {
        // Arrange
        const BIG: [Field; 1] = [bytes(0, 250)];
        let big = Scheme::new(0x41, &BIG).with_parity(8);
        let (mut opener, _) = pair();
        let row = Slots::with(&[], &[(0, &[7u8; 250])]);
        let mut out = [0xAAu8; 300];
        // Act
        let refused = opener.pack(&big, &row, &mut out);
        // Assert
        assert_eq!(refused.err().map(|f| f.error), Some(Error::TooLong));
        assert!(
            out[..251].iter().all(|b| *b == 0),
            "the written bytes are zeroed"
        );
        assert_eq!(
            sealed(&mut opener, 0),
            from_hex(CIPHER),
            "the position was not used"
        );
    }

    #[test]
    fn ac3_a_buffer_without_room_for_the_parity_is_refused_before_the_pad() {
        // Arrange
        let (mut opener, _) = pair();
        let mut out = [0xAAu8; 14];
        // Act
        let refused = opener.pack(&scheme(4), &row(), &mut out);
        // Assert
        assert_eq!(refused.err().map(|f| f.error), Some(Error::BufferFull));
        assert!(out[..13].iter().all(|b| *b == 0));
        assert_eq!(sealed(&mut opener, 0), from_hex(CIPHER));
    }
}
