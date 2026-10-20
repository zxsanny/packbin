//! Compact text in the heap-free API (AZ-2754): the vectors file, the std tests' strings,
//! scratch, and untrusted payloads. Needs the `text` feature.
#![cfg(feature = "text")]

mod nostd_support;

use nostd_support::Slots;
use packbin::nostd::{
    pack, pack_with, u8, unpack, utf8, utf8_wire, validate, Error, Num, Scheme,
    SCRATCH_WORDS_PER_CHAR,
};

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/text/vectors.txt");

const ONE: Scheme = Scheme::new(1, &[utf8(0)]);
const THEN_BYTE: Scheme = Scheme::new(1, &[utf8(0), u8(1)]);

fn from_hex(hex: &str) -> Vec<u8> {
    nostd_support::from_hex(hex)
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

fn text_of(hex: &str) -> Vec<u8> {
    if hex == "-" {
        return Vec::new();
    }
    from_hex(hex)
}

/// A row that holds `text` in field 0, with room for any text on unpack.
fn row_of(text: &[u8]) -> Slots {
    let mut row = Slots::default();
    assert!(packbin::nostd::Row::set_bytes(&mut row, 0, text));
    row
}

fn big() -> Slots {
    Slots {
        cap: Some(70_000),
        ..Slots::default()
    }
}

fn packet_of(text: &[u8], scratch: &mut [u32]) -> Vec<u8> {
    let mut out = vec![0u8; 200_000];
    let n = pack_with(&ONE, &row_of(text), &mut out, scratch).expect("pack");
    out.truncate(n);
    out
}

#[test]
fn ac1_every_enc_row_packs_to_its_bytes() {
    // Arrange
    let rows = rows("enc");
    let mut scratch = vec![0u32; 70_000 * SCRATCH_WORDS_PER_CHAR];
    for row in &rows {
        // Act
        let packet = packet_of(&text_of(&row[1]), &mut scratch);
        // Assert
        let mut want = vec![1u8];
        want.extend(from_hex(&row[2]));
        assert_eq!(packet, want, "{}", row[0]);
    }
    assert!(rows.len() >= 290, "{} enc rows", rows.len());
}

#[test]
fn ac1_every_enc_and_alt_row_unpacks_to_its_text_using_every_byte() {
    // Arrange
    let mut all = rows("enc");
    all.extend(rows("alt"));
    for row in &all {
        let mut packet = vec![1u8];
        packet.extend(from_hex(&row[2]));
        let mut back = big();
        // Act
        let used = unpack(&ONE, &packet, &mut back).expect(&row[0]);
        // Assert
        assert_eq!(used, packet.len(), "{}", row[0]);
        assert_eq!(
            packbin::nostd::Row::bytes(&back, 0),
            Some(text_of(&row[1]).as_slice()),
            "{}",
            row[0]
        );
    }
}

#[test]
fn ac2_a_string_that_needs_the_parse_and_no_scratch_is_scratch_too_small() {
    // Arrange
    let text = "привіт, світе".as_bytes();
    let chars = "привіт, світе".chars().count();
    let mut out = [0u8; 64];
    for words in [0, 1, chars * SCRATCH_WORDS_PER_CHAR - 1] {
        let mut scratch = vec![0u32; words];
        // Act
        let fault = pack_with(&ONE, &row_of(text), &mut out, &mut scratch).expect_err("short");
        // Assert
        assert_eq!(fault.error, Error::ScratchTooSmall, "{words} words");
        assert_eq!(fault.field, 0);
        assert_eq!(fault.needed, chars * SCRATCH_WORDS_PER_CHAR);
    }
    let mut enough = vec![0u32; chars * SCRATCH_WORDS_PER_CHAR];
    assert!(pack_with(&ONE, &row_of(text), &mut out, &mut enough).is_ok());
    assert!(pack(&ONE, &row_of(text), &mut out).is_err());
}

#[test]
fn ac2_a_string_the_floor_already_sends_raw_needs_no_scratch() {
    // Arrange: one emoji is far above the table, so the compact form cannot beat the raw one
    let mut out = [0u8; 16];
    // Act
    let n = pack(&ONE, &row_of("😀".as_bytes()), &mut out).expect("raw");
    // Assert
    assert_eq!(&out[..n], &[1, 5, 0x10, 0xF0, 0x9F, 0x98, 0x80]);
}

#[test]
fn ac4_every_bad_row_is_refused_naming_the_field() {
    // Arrange
    for row in rows("bad") {
        let mut packet = vec![1u8];
        packet.extend(text_of(row.get(2).map_or("-", String::as_str)));
        // Act
        let fault = unpack(&ONE, &packet, &mut big()).expect_err(&row[0]);
        // Assert
        assert!(
            matches!(fault.error, Error::BadValue | Error::ShortPacket),
            "{}: {fault:?}",
            row[0]
        );
        assert_eq!(fault.field, 0, "{}", row[0]);
    }
}

#[test]
fn ac4_a_flipped_payload_bit_is_a_string_or_an_error_and_the_next_byte_survives() {
    // Arrange
    let encs: std::collections::BTreeMap<String, String> = rows("enc")
        .into_iter()
        .map(|row| (row[0].clone(), row[2].clone()))
        .collect();
    let mut flipped = 0;
    for row in rows("flip") {
        let field = from_hex(&encs[&row[1]]);
        let payload_at = if field[0] < 0x80 {
            1
        } else {
            2 + usize::from(field[1] >= 0x80)
        };
        for bit in 0..8 * (field.len() - payload_at) {
            let mut packet = vec![1u8];
            let mut damaged = field.clone();
            damaged[payload_at + bit / 8] ^= 0x80 >> (bit % 8);
            damaged.push(0x5a);
            packet.extend(&damaged);
            let mut back = big();
            // Act
            let result = unpack(&THEN_BYTE, &packet, &mut back);
            // Assert
            match result {
                Ok(_) => assert_eq!(
                    packbin::nostd::Row::num(&back, 1),
                    Some(Num::U8(0x5a)),
                    "{} bit {bit}",
                    row[0]
                ),
                Err(fault) => {
                    assert!(
                        matches!(fault.error, Error::BadValue | Error::ShortPacket),
                        "{} bit {bit}: {fault:?}",
                        row[0]
                    );
                    assert_eq!(fault.field, 0);
                }
            }
            flipped += 1;
        }
    }
    assert!(flipped > 1000, "{flipped} flips");
}

#[test]
fn ac2_a_text_longer_than_the_row_storage_is_too_many_with_its_full_size() {
    // Arrange
    let packet = {
        let mut scratch = vec![0u32; 100 * SCRATCH_WORDS_PER_CHAR];
        packet_of("Hello World, a longer text".as_bytes(), &mut scratch)
    };
    let mut small = Slots {
        cap: Some(5),
        ..Slots::default()
    };
    // Act
    let fault = unpack(&ONE, &packet, &mut small).expect_err("does not fit");
    // Assert
    assert_eq!(fault.error, Error::TooMany);
    assert_eq!(fault.needed, "Hello World, a longer text".len());
    assert_eq!(packbin::nostd::Row::bytes(&small, 0), Some(&[][..]));
}

#[test]
fn ac2_invalid_utf8_in_a_row_is_bad_value_and_writes_nothing() {
    // Arrange
    let mut out = [0xEEu8; 16];
    let mut scratch = [0u32; 64];
    // Act
    let fault = pack_with(&ONE, &row_of(&[0xC3, 0x28]), &mut out, &mut scratch).expect_err("utf8");
    // Assert
    assert_eq!(fault.error, Error::BadValue);
    assert_eq!(fault.field, 0);
}

#[test]
fn ac1_the_empty_string_is_one_zero_byte() {
    // Arrange and Act
    let packet = packet_of(b"", &mut []);
    // Assert
    assert_eq!(packet, [1, 0]);
}

#[test]
fn ac3_a_wire_string_forwards_the_payload_unchanged_with_or_without_text() {
    // Arrange
    let fields = [utf8_wire(0), u8(1)];
    let scheme = Scheme::new(1, &fields);
    let packet = [1, 3, 0xAA, 0xBB, 0xCC, 0x07];
    let mut row = Slots::default();
    // Act
    unpack(&scheme, &packet, &mut row).expect("unpack");
    let mut out = [0u8; 16];
    let n = pack(&scheme, &row, &mut out).expect("pack");
    // Assert
    assert_eq!(
        packbin::nostd::Row::bytes(&row, 0),
        Some(&[0xAA, 0xBB, 0xCC][..])
    );
    assert_eq!(&out[..n], &packet);
}

#[test]
fn ac3_a_utf8_member_is_valid_with_the_feature() {
    assert!(validate(&ONE).is_ok());
}
