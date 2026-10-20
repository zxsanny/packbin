//! The heap-free API on flat schemes (AZ-2749). Runs with and without default features.

mod nostd_support;

use nostd_support::{from_hex, golden, Slots};
use packbin::nostd::{
    be, bytes, f32, f64, i16, i32, i64, i8, pack, u16, u32, u64, u8, unpack, validate, Error,
    Field, Num, Scheme, MAX_FIELDS,
};

// The position report of the cross-language vectors; byte 12 is a flags byte, read here as u8.
const POSITION: Scheme = Scheme::new(0x40, &[u16(0), i32(1), i32(2), u8(3), u8(4)]);

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

#[test]
fn ac1_golden_fixture_decodes_with_the_same_code() {
    // Arrange
    let wire = golden();
    let mut row = Slots::default();
    // Act
    let n = unpack(&POSITION, &wire, &mut row).expect("unpack");
    // Assert
    assert_eq!(n, 13);
    assert_eq!(row, position_row());
}

#[test]
fn ac2_pack_writes_the_golden_bytes_and_the_length() {
    // Arrange
    let mut out = [0u8; 64];
    // Act
    let n = pack(&POSITION, &position_row(), &mut out).expect("pack");
    // Assert
    assert_eq!(&out[..n], golden().as_slice());
}

#[test]
fn ac3_a_short_buffer_is_buffer_full_and_nothing_goes_past_cap() {
    // Arrange
    let full = golden().len();
    for cap in 0..full {
        let mut buf = vec![0xEEu8; full + 4];
        // Act
        let fault = pack(&POSITION, &position_row(), &mut buf[..cap]).expect_err("too small");
        // Assert
        assert_eq!(fault.error, Error::BufferFull, "cap {cap}");
        assert!(fault.needed > 0, "cap {cap}");
        assert!(
            buf[cap..].iter().all(|b| *b == 0xEE),
            "cap {cap}: wrote past cap"
        );
    }
    let mut exact = vec![0u8; full];
    let n = pack(&POSITION, &position_row(), &mut exact).expect("exact fit");
    assert_eq!(n, full);
    let mut back = Slots::default();
    unpack(&POSITION, &exact, &mut back).expect("unpack");
    assert_eq!(back, position_row());
}

#[test]
fn ac4_cut_and_extended_packets_give_error_kinds_only() {
    // Arrange
    let wire = golden();
    // Act and Assert
    for cut in 0..wire.len() {
        let fault = unpack(&POSITION, &wire[..cut], &mut Slots::default()).expect_err("cut");
        assert_eq!(fault.error, Error::ShortPacket, "cut {cut}");
        assert!(fault.offset <= cut, "cut {cut}");
    }
    let mut longer = wire.clone();
    longer.push(0);
    let fault = unpack(&POSITION, &longer, &mut Slots::default()).expect_err("trailing");
    assert_eq!(fault.error, Error::TrailingBytes);
    assert_eq!(fault.offset, wire.len());
    let mut other = wire.clone();
    other[0] = 0x41;
    let fault = unpack(&POSITION, &other, &mut Slots::default()).expect_err("type");
    assert_eq!((fault.error, fault.needed), (Error::TypeMismatch, 0x40));
}

#[test]
fn ac4_a_short_read_names_the_field_and_the_bytes_needed() {
    // Arrange: the packet ends inside the first i32 (id 1).
    let wire = golden();
    // Act
    let fault = unpack(&POSITION, &wire[..5], &mut Slots::default()).expect_err("cut");
    // Assert
    assert_eq!(
        (fault.error, fault.offset, fault.field, fault.needed),
        (Error::ShortPacket, 3, 1, 4)
    );
}

#[test]
fn ac5_an_invalid_scheme_is_refused_before_any_byte_moves() {
    // Arrange
    let duplicate = [u8(0), u8(0)];
    let skipped = [u8(0), u8(2)];
    let outside = [Field {
        id: 40_000,
        ..u8(0)
    }];
    let sized_number = [Field { size: 3, ..u8(0) }];
    let too_many = vec![u8(0); MAX_FIELDS + 1];
    let cases: Vec<&[Field]> = vec![&duplicate, &skipped, &outside, &sized_number, &too_many];
    for (n, fields) in cases.into_iter().enumerate() {
        let scheme = Scheme::new(1, fields);
        let mut buf = [0xEEu8; 8];
        // Act
        let checked = validate(&scheme).expect_err("validate");
        let packed = pack(&scheme, &Slots::default(), &mut buf).expect_err("pack");
        let read = unpack(&scheme, &[1, 0], &mut Slots::default()).expect_err("unpack");
        // Assert
        assert_eq!(checked.error, Error::SchemeInvalid, "case {n}");
        assert_eq!(packed.error, Error::SchemeInvalid, "case {n}");
        assert_eq!(read.error, Error::SchemeInvalid, "case {n}");
        assert!(buf.iter().all(|b| *b == 0xEE), "case {n}: wrote a byte");
    }
}

#[test]
fn ac5_a_valid_scheme_passes_and_the_empty_scheme_is_the_type_byte() {
    assert!(validate(&POSITION).is_ok());
    let empty = Scheme::new(9, &[]);
    let mut out = [0u8; 4];
    assert_eq!(pack(&empty, &Slots::default(), &mut out), Ok(1));
    assert_eq!(out[0], 9);
}

#[test]
fn ac6_numbers_keep_their_bits_and_byte_order_follows_the_field() {
    // Arrange
    let fields = [
        u8(0),
        i8(1),
        u16(2),
        be(i16(3)),
        u32(4),
        be(u32(5)),
        u64(6),
        be(i64(7)),
        f32(8),
        be(f64(9)),
        bytes(10, 3),
    ];
    let scheme = Scheme::new(7, &fields);
    let row = Slots::with(
        &[
            (0, Num::U8(u8::MAX)),
            (1, Num::I8(i8::MIN)),
            (2, Num::U16(0x0102)),
            (3, Num::I16(i16::MIN)),
            (4, Num::U32(0x0102_0304)),
            (5, Num::U32(0x0102_0304)),
            (6, Num::U64(u64::MAX)),
            (7, Num::I64(i64::MIN)),
            (8, Num::F32(f32::from_bits(0x7fc0_1234))),
            (9, Num::F64(f64::from_bits(0x7ff8_0000_dead_beef))),
        ],
        &[(10, &[1, 2, 3])],
    );
    let mut out = [0u8; 64];
    // Act
    let n = pack(&scheme, &row, &mut out).expect("pack");
    let mut back = Slots::default();
    unpack(&scheme, &out[..n], &mut back).expect("unpack");
    // Assert
    let want = from_hex(concat!(
        "07",
        "ff",
        "80",
        "0201",
        "8000",
        "04030201",
        "01020304",
        "ffffffffffffffff",
        "8000000000000000",
        "3412c07f",
        "7ff80000deadbeef",
        "010203"
    ));
    assert_eq!(&out[..n], want.as_slice());
    assert_eq!(back.num(8).map(bits), row.num(8).map(bits));
    assert_eq!(back.num(9).map(bits), row.num(9).map(bits));
    assert_eq!(back.blobs[10].as_deref(), Some(&[1u8, 2, 3][..]));
    for id in 0..8 {
        assert_eq!(back.num(id), row.num(id), "id {id}");
    }
}

use packbin::nostd::Row;

fn bits(n: Num) -> u64 {
    match n {
        Num::F32(v) => u64::from(v.to_bits()),
        Num::F64(v) => v.to_bits(),
        other => panic!("not a float: {other:?}"),
    }
}

#[test]
fn a_row_without_the_value_or_with_another_kind_is_bad_value_naming_the_field() {
    // Arrange
    let missing = Slots::with(&[(0, Num::U16(1))], &[]);
    let wrong = Slots::with(
        &[
            (0, Num::U32(1)),
            (1, Num::I32(0)),
            (2, Num::I32(0)),
            (3, Num::U8(0)),
            (4, Num::U8(0)),
        ],
        &[],
    );
    let mut out = [0u8; 32];
    // Act
    let none = pack(&POSITION, &missing, &mut out).expect_err("missing");
    let kind = pack(&POSITION, &wrong, &mut out).expect_err("wrong kind");
    // Assert
    assert_eq!((none.error, none.field), (Error::BadValue, 1));
    assert_eq!((kind.error, kind.field), (Error::BadValue, 0));
}

#[test]
fn a_blob_of_the_wrong_length_is_bad_value() {
    // Arrange
    let fields = [bytes(0, 4)];
    let scheme = Scheme::new(1, &fields);
    let mut out = [0u8; 8];
    // Act
    let short = pack(&scheme, &Slots::with(&[], &[(0, &[1, 2, 3])]), &mut out).expect_err("short");
    let long = pack(
        &scheme,
        &Slots::with(&[], &[(0, &[1, 2, 3, 4, 5])]),
        &mut out,
    )
    .expect_err("long");
    // Assert
    assert_eq!((short.error, short.field), (Error::BadValue, 0));
    assert_eq!((long.error, long.field), (Error::BadValue, 0));
}

#[cfg(feature = "alloc")]
#[test]
fn pack_vec_returns_exactly_the_packet() {
    // Arrange and Act
    let packed = packbin::nostd::pack_vec(&POSITION, &position_row(), 64).expect("pack_vec");
    let small = packbin::nostd::pack_vec(&POSITION, &position_row(), 4).expect_err("limit");
    // Assert
    assert_eq!(packed, golden());
    assert_eq!(small.error, Error::BufferFull);
}
