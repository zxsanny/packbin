//! Message ECC in the heap-free API (AZ-2755): the vectors file against the codec, the position
//! message under every parity count, repair in place, the 254-byte limit, and the `std` walker
//! on random messages. Needs the `ecc` feature.
#![cfg(feature = "ecc")]

mod nostd_support;

use nostd_support::{from_hex, Slots};
use packbin::nostd::ecc::{protect, repair, EccKind};
use packbin::nostd::{
    bytes, i32, pack, u16, u8, unpack, unpack_repair, validate, Error, Field, Num, Row, Scheme,
    Unpacked, MAX_PARITY,
};

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/ecc/vectors.txt");
const POSITION: [Field; 5] = [u16(0), i32(1), i32(2), u8(3), u8(4)];
const FIXTURE: &str = "4001000065cd1d00a3e1110100";

fn position(n: u8) -> Scheme<'static> {
    Scheme::new(0x40, &POSITION).with_parity(n)
}

fn position_row() -> Slots {
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

#[cfg(feature = "std")]
fn row_bytes(row: &Slots) -> Vec<u8> {
    row.bytes(0).expect("bytes").to_vec()
}

fn packed(n: u8) -> Vec<u8> {
    let mut out = [0u8; 64];
    let len = pack(&position(n), &position_row(), &mut out).expect("pack");
    out[..len].to_vec()
}

#[test]
fn ac4_every_enc_row_is_protected_to_its_bytes() {
    // Arrange
    for row in rows("enc") {
        let (id, n, clear, want) = (&row[0], number(&row[1]), hex(&row[2]), hex(&row[3]));
        let mut parity = [0u8; 32];
        // Act
        let kind = protect(&clear, n, &mut parity);
        // Assert
        assert_eq!(kind, EccKind::Ok, "{id}");
        assert_eq!([clear, parity[..n].to_vec()].concat(), want, "{id}");
    }
}

#[test]
fn ac1_every_fix_row_is_repaired_in_place_and_counted() {
    // Arrange
    let fixes = rows("fix");
    assert!(fixes.len() >= 100);
    for row in fixes {
        let (id, n, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (mut word, clear, count) = (hex(&row[3]), hex(&row[4]), number(&row[5]));
        // Act
        let outcome = repair(&mut word, n, t);
        // Assert
        assert_eq!(outcome.kind, EccKind::Ok, "{id}");
        assert_eq!(outcome.repaired, count, "{id}");
        assert_eq!(&word[..word.len() - n], &clear[..], "{id}");
    }
}

#[test]
fn ac1_every_bad_row_is_refused_with_its_kind_and_leaves_the_buffer() {
    // Arrange
    for row in rows("bad") {
        let (id, n, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (mut word, kind) = (hex(&row[3]), row[4].as_str());
        let before = word.clone();
        // Act
        let outcome = repair(&mut word, n, t);
        // Assert
        let want = match kind {
            "uncorrectable" => EccKind::Uncorrectable,
            "short" => EccKind::Short,
            "too_long" => EccKind::TooLong,
            other => panic!("{id}: kind {other}"),
        };
        assert_eq!(outcome.kind, want, "{id}");
        assert_eq!(word, before, "{id}: the buffer changed");
    }
}

#[test]
fn ac2_every_lim_par_and_lmt_row_is_decided_as_the_reference_does() {
    // Arrange and Act and Assert
    for row in rows("lim") {
        let (id, n, len) = (&row[0], number(&row[1]), number(&row[2]));
        let kind = protect(&vec![0u8; len], n, &mut [0u8; 32]);
        let want = if row[3] == "ok" {
            EccKind::Ok
        } else {
            EccKind::TooLong
        };
        assert_eq!(kind, want, "{id}");
    }
    for row in rows("par") {
        let n = number(&row[1]);
        assert_eq!(
            protect(&[], n, &mut [0u8; 40]),
            EccKind::BadParity,
            "{}",
            row[0]
        );
    }
    for row in rows("lmt") {
        let (n, t) = (number(&row[1]), number(&row[2]));
        assert_eq!(repair(&mut [], n, t).kind, EccKind::BadLimit, "{}", row[0]);
    }
}

#[test]
fn ac4_the_position_message_is_packed_with_the_protected_bytes_of_every_count() {
    // Arrange
    let want: std::collections::BTreeMap<usize, Vec<u8>> = rows("enc")
        .into_iter()
        .filter(|row| row[0].starts_with("enc.pos."))
        .map(|row| (number(&row[1]), hex(&row[3])))
        .collect();
    assert_eq!(want.len(), 7);
    for (n, bytes) in want {
        // Act
        let wire = packed(n as u8);
        // Assert
        assert_eq!(wire, bytes, "n {n}");
        let mut back = Slots::default();
        assert_eq!(
            unpack(&position(n as u8), &wire, &mut back),
            Ok(wire.len()),
            "n {n}"
        );
        assert_eq!(back, position_row(), "n {n}");
    }
    assert_eq!(packed(0), from_hex(FIXTURE));
}

#[test]
fn ac1_wrong_bytes_up_to_the_limit_are_repaired_in_place_and_more_are_uncorrectable() {
    // Arrange
    for n in [2u8, 4, 8, 16, 32] {
        let good = packed(n);
        for wrong in 0..=usize::from(n / 2) + 2 {
            let mut data = good.clone();
            for k in 0..wrong {
                let at = (k * 3 + 1) % data.len();
                data[at] ^= 0x5A;
            }
            let damaged = data.clone();
            let mut row = Slots::default();
            // Act
            let result = unpack_repair(&position(n), &mut data, &mut row, usize::from(n / 2));
            // Assert
            if wrong <= usize::from(n / 2) {
                let distinct = damaged.iter().zip(&good).filter(|(a, b)| a != b).count();
                assert_eq!(
                    result,
                    Ok(Unpacked {
                        bytes: good.len(),
                        repaired: distinct
                    }),
                    "n {n} wrong {wrong}"
                );
                assert_eq!(data, good, "n {n} wrong {wrong}: repaired in place");
                assert_eq!(row, position_row());
            } else if let Err(fault) = result {
                assert_eq!(fault.error, Error::Uncorrectable, "n {n} wrong {wrong}");
                assert_eq!(data, damaged, "n {n} wrong {wrong}: the buffer changed");
            }
        }
    }
}

#[test]
fn ac1_unpack_detects_and_never_touches_the_buffer() {
    // Arrange
    let mut wire = packed(4);
    wire[3] ^= 1;
    let before = wire.clone();
    // Act
    let fault = unpack(&position(4), &wire, &mut Slots::default()).expect_err("detect");
    // Assert
    assert_eq!(fault.error, Error::Uncorrectable);
    assert_eq!(wire, before);
}

#[test]
fn ac2_a_message_over_254_bytes_is_too_long_on_pack_and_unpack() {
    // Arrange: 250 clear bytes under 8 parity bytes is 258 sent
    let fields = [bytes(0, 250)];
    let scheme = Scheme::new(1, &fields).with_parity(8);
    let mut row = Slots::default();
    row.set_bytes(0, &[7; 250]);
    let mut out = [0xEEu8; 512];
    // Act
    let packed = pack(&scheme, &row, &mut out).expect_err("too long");
    let received = vec![0u8; 255];
    let read = unpack(&scheme, &received, &mut Slots::default()).expect_err("too long");
    // Assert
    assert_eq!(packed.error, Error::TooLong);
    assert_eq!(packed.offset, 251);
    assert_eq!(packed.needed, 254 - 8);
    assert!(out[..251].iter().all(|b| *b == 0), "left zeroed");
    assert_eq!(read.error, Error::TooLong);
    assert_eq!(read.needed, 254);
}

#[test]
fn ac2_the_largest_protected_message_packs_and_reads() {
    // Arrange: 245 clear bytes + 8 parity = 253... 246 + 8 = 254
    let fields = [bytes(0, 245)];
    let scheme = Scheme::new(1, &fields).with_parity(8);
    let mut row = Slots::default();
    row.set_bytes(0, &[9; 245]);
    let mut out = [0u8; 300];
    // Act
    let n = pack(&scheme, &row, &mut out).expect("254 bytes");
    // Assert
    assert_eq!(n, 254);
    assert_eq!(unpack(&scheme, &out[..n], &mut Slots::default()), Ok(254));
}

#[test]
fn ac1_a_limit_above_half_the_parity_is_refused_before_any_byte_is_read() {
    // Arrange
    let mut data = packed(4);
    // Act
    let fault =
        unpack_repair(&position(4), &mut data, &mut Slots::default(), 3).expect_err("limit");
    // Assert
    assert_eq!((fault.error, fault.needed), (Error::BadValue, 2));
}

#[test]
fn ac1_a_message_shorter_than_its_parity_is_a_short_packet() {
    // Arrange and Act
    let fault = unpack(&position(8), &[0x40, 1, 2], &mut Slots::default()).expect_err("short");
    // Assert
    assert_eq!((fault.error, fault.needed), (Error::ShortPacket, 8));
}

#[test]
fn ac3_a_parity_count_above_32_is_refused_and_zero_is_the_plain_scheme() {
    // Arrange and Act and Assert
    assert_eq!(
        validate(&position(33)).expect_err("33").error,
        Error::SchemeInvalid
    );
    assert!(validate(&position(32)).is_ok());
    assert_eq!(MAX_PARITY, 32);
    assert_eq!(packed(0), from_hex(FIXTURE));
}

#[cfg(feature = "std")]
#[test]
fn ac4_random_messages_are_protected_and_repaired_as_the_std_walker_does() {
    // Arrange
    let mut seed = 0x2755_0001u64;
    let mut next = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        seed
    };
    for round in 0..400 {
        let n = [1usize, 2, 4, 8, 16, 32][(next() % 6) as usize];
        let len = (next() % 40) as usize + 1;
        let blob: Vec<u8> = (0..len).map(|_| next() as u8).collect();
        let std_scheme = packbin::MapScheme::new(1, vec![packbin::bytes("b", len)]).with_parity(n);
        let mut values = packbin::Values::new();
        packbin::insert(&mut values, "b", Some(packbin::Value::Bytes(blob.clone())));
        let want = packbin::pack(&std_scheme, &values).expect("std pack");
        let fields = [bytes(0, len as u16)];
        let scheme = Scheme::new(1, &fields).with_parity(n as u8);
        let mut row = Slots::default();
        row.set_bytes(0, &blob);
        let mut out = vec![0u8; 300];
        // Act
        let wrote = pack(&scheme, &row, &mut out).expect("pack");
        // Assert
        assert_eq!(&out[..wrote], want.as_slice(), "round {round}: bytes");
        let mut damaged = want.clone();
        for _ in 0..(next() % (n as u64 / 2 + 3)) {
            let at = (next() % damaged.len() as u64) as usize;
            damaged[at] ^= (next() % 255 + 1) as u8;
        }
        let limit = (next() % (n as u64 / 2 + 1)) as usize;
        let theirs = packbin::unpack_repair(&std_scheme, &damaged, limit);
        let mut mine = damaged.clone();
        let mut read = Slots::default();
        let ours = unpack_repair(&scheme, &mut mine, &mut read, limit);
        assert_eq!(
            ours.is_ok(),
            theirs.is_ok(),
            "round {round} n {n} limit {limit}: {ours:?} {theirs:?}"
        );
        if let (Ok(a), Ok((values, repaired))) = (ours, theirs) {
            // More wrong bytes than the code corrects can land on another code word: both
            // walkers then read the same other message.
            assert_eq!(a.repaired, repaired, "round {round}");
            let sent = packbin::Value::Bytes(row_bytes(&read));
            assert_eq!(
                values["b"].clone(),
                Some(sent),
                "round {round}: the message"
            );
            assert_eq!(
                packbin::nostd::ecc::check(&mine, n).kind,
                EccKind::Ok,
                "round {round}: repaired in place"
            );
        }
    }
}
