//! AZ-2752: flags, flag bytes, booleans, bits, u2, packed, sized and `when` in the heap-free core,
//! byte for byte against the `std` walker (card 4).
#![cfg(feature = "std")]

mod nostd_support;

use nostd_support::random::{assert_read_alike, pack_both, random_row, Rng};
use nostd_support::tree::{build, std_refuses, values_of, Node};
use nostd_support::Slots;
use packbin::nostd::{self, Error, Kind, Num, Row};

use Kind::*;
use Node::{Be, Bits, Bool, Bytes, FlagBit, FlagByte, Flags, Packed, Sized, When, U2};

fn n(kind: Kind) -> Node {
    Node::Num(kind)
}

fn bit(number: u16, inner: Node) -> Node {
    FlagBit(number, Box::new(inner))
}

fn layouts() -> Vec<(&'static str, Vec<Node>)> {
    vec![
        (
            "flags of numbers",
            vec![
                n(U8),
                Flags(vec![n(U16), Be(I32), Bool, Bytes(2), n(F32)]),
                n(U8),
            ],
        ),
        (
            "split flag bytes with a late when",
            vec![
                FlagByte(0),
                n(U8),
                bit(0, n(U16)),
                bit(0, Bool),
                FlagByte(1),
                bit(1, n(U8)),
                bit(0, When(0, 1, vec![n(U8)])),
            ],
        ),
        (
            "split flag byte after the when source",
            vec![
                n(U8),
                FlagByte(0),
                bit(0, When(0, 1, vec![n(U16)])),
                bit(0, n(I8)),
            ],
        ),
        (
            "when chain",
            vec![
                n(U8),
                When(0, 1, vec![n(U16), n(U8)]),
                When(2, 2, vec![n(U8)]),
                When(0, 0, vec![n(I8)]),
                n(U8),
            ],
        ),
        (
            "counts",
            vec![
                n(U8),
                Sized(0),
                Bits(0),
                Packed(2, 0, -1),
                Packed(1, 0, 0),
                n(U16),
                When(5, 1, vec![n(U8)]),
                Bits(6),
            ],
        ),
        (
            "u2",
            vec![U2(5), When(2, 2, vec![n(U8)]), Flags(vec![U2(2), n(U8)])],
        ),
        (
            "flags with a bool source",
            vec![
                Flags(vec![Bool, When(0, 1, vec![n(U8)]), n(U16)]),
                When(2, 7, vec![n(U8)]),
            ],
        ),
        (
            "nested flags",
            vec![Flags(vec![
                Flags(vec![n(U8), n(U8)]),
                n(U8),
                Flags(vec![Bool]),
            ])],
        ),
        (
            "flag bits in and after flags",
            vec![
                FlagByte(0),
                Flags(vec![n(U8), bit(0, n(U8))]),
                bit(0, n(U16)),
            ],
        ),
        (
            "two reads of one flag byte number",
            vec![
                FlagByte(0),
                bit(0, n(U8)),
                FlagByte(0),
                bit(0, n(U8)),
                bit(0, Bool),
            ],
        ),
        (
            "count behind a clear flag",
            vec![Flags(vec![n(U8)]), Bits(0), Sized(0)],
        ),
        (
            "flag bit inside a when",
            vec![
                n(U8),
                When(
                    0,
                    1,
                    vec![FlagByte(0), bit(0, n(U8)), bit(0, Flags(vec![n(U16)]))],
                ),
            ],
        ),
        (
            "u64 and signed sources",
            vec![
                n(U64),
                n(I16),
                When(0, 3, vec![n(U8)]),
                When(1, -2, vec![n(U8)]),
                n(U8),
                Sized(4),
            ],
        ),
    ]
}

#[test]
fn ac1_ac4_random_rows_pack_to_the_same_bytes_and_read_back_alike() {
    // Arrange
    let mut rng = Rng(0x2752_0001);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        let mut packed = 0;
        for round in 0..3_000 {
            let row = random_row(&mut rng, &built.leaves);
            // Act
            let (ours, theirs) = pack_both(&built, &row);
            // Assert
            assert_eq!(
                ours.is_ok(),
                theirs.is_ok(),
                "{name} round {round}: nostd {ours:?} std {theirs:?} row {row:?}"
            );
            if let (Ok(a), Ok(b)) = (&ours, &theirs) {
                assert_eq!(a, b, "{name} round {round}: bytes for {row:?}");
                assert!(
                    assert_read_alike(&built, a, name),
                    "{name} round {round}: reread"
                );
                packed += 1;
            }
        }
        assert!(packed > 100, "{name}: only {packed} rows packed");
    }
}

#[test]
fn ac3_every_cut_and_trailing_copy_is_short_or_trailing_for_both() {
    // Arrange
    let mut rng = Rng(0x2752_0003);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        let scheme = nostd::Scheme::new(0x21, &built.fields);
        let mut wires = Vec::new();
        while wires.len() < 40 {
            if let (Ok(w), Ok(_)) = pack_both(&built, &random_row(&mut rng, &built.leaves)) {
                wires.push(w);
            }
        }
        for wire in wires {
            let mut variants: Vec<(Vec<u8>, Error)> = (1..wire.len())
                .map(|cut| (wire[..cut].to_vec(), Error::ShortPacket))
                .collect();
            variants.push(([wire.clone(), vec![0x5A]].concat(), Error::TrailingBytes));
            for (bytes, want) in variants {
                // Act
                let ours = nostd::unpack(&scheme, &bytes, &mut Slots::default());
                let theirs = packbin::unpack(&built.reference, &bytes);
                // Assert
                assert_eq!(ours.map_err(|f| f.error), Err(want), "{name}: {bytes:02x?}");
                assert!(theirs.is_err(), "{name}: std read {bytes:02x?}");
            }
        }
    }
}

#[test]
fn ac3_random_bytes_are_accepted_or_refused_alike() {
    // Arrange: packets of up to 24 bytes after the type byte
    let mut rng = Rng(0x2752_0033);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        let mut accepted = 0;
        for _ in 0..8_000 {
            let len = rng.below(25) as usize;
            let mut wire = vec![0x21];
            wire.extend((0..len).map(|_| {
                let r = rng.next();
                if r % 3 == 0 {
                    (r >> 8) as u8 & 3
                } else {
                    (r >> 8) as u8
                }
            }));
            // Act + Assert
            if assert_read_alike(&built, &wire, name) {
                accepted += 1;
            }
        }
        assert!(accepted > 0, "{name}: no random packet was read");
    }
}

#[test]
fn ac4_every_presence_of_a_flags_and_when_row_packs_as_std() {
    // Arrange: u8 mode; flags { u16 a; bool b; when (mode == 1) { u8 c }; bytes(1) d }
    let built = build(
        0x21,
        &[
            n(U8),
            Flags(vec![n(U16), Bool, When(0, 1, vec![n(U8)]), Bytes(1)]),
        ],
    );
    for mode in 0..2u8 {
        for mask in 0..16u8 {
            let mut row = Slots::default();
            row.set_num(0, Num::U8(mode));
            if mask & 1 != 0 {
                row.set_num(1, Num::U16(0x0102));
            }
            row.set_flag(2, mask & 2 != 0);
            if mask & 4 != 0 {
                row.set_num(3, Num::U8(7));
            }
            if mask & 8 != 0 {
                row.set_bytes(4, &[9]);
            }
            // Act
            let (ours, theirs) = pack_both(&built, &row);
            // Assert
            let ours = ours.expect("nostd pack");
            assert_eq!(Ok(ours.clone()), theirs, "mode {mode} mask {mask}");
            let c_on = mask & 4 != 0 && mode == 1;
            let want_bits = (mask & 1) | (mask & 2) | (u8::from(c_on) << 2) | (mask & 8);
            assert_eq!(ours[2], want_bits, "mode {mode} mask {mask}: flag byte");
            assert!(assert_read_alike(&built, &ours, "presence"));
        }
    }
}

#[test]
fn ac4_unpack_leaves_a_member_the_packet_skips_absent() {
    // Arrange: a row with stale values for every member, and a packet that holds none of them
    let built = build(
        0x21,
        &[n(U8), Flags(vec![n(U16), Bool]), When(0, 1, vec![n(U8)])],
    );
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    let mut row = Slots::default();
    row.set_num(1, Num::U16(5));
    row.set_flag(2, true);
    row.set_num(3, Num::U8(6));
    // Act
    nostd::unpack(&scheme, &[0x21, 0x00, 0x00], &mut row).expect("unpack");
    // Assert
    assert_eq!((row.num(1), row.flag(2), row.num(3)), (None, false, None));
    assert_eq!(row.num(0), Some(Num::U8(0)));
}

fn assert_refused(label: &str, fields: &[nostd::Field]) {
    let scheme = nostd::Scheme::new(1, fields);
    let mut buf = [0xEEu8; 32];
    let checked = nostd::validate(&scheme).map_err(|f| f.error);
    let packed = nostd::pack(&scheme, &Slots::default(), &mut buf).map_err(|f| f.error);
    let read = nostd::unpack(&scheme, &[1, 0, 0, 0], &mut Slots::default()).map_err(|f| f.error);
    assert_eq!(checked, Err(Error::SchemeInvalid), "{label}: validate");
    assert_eq!(packed, Err(Error::SchemeInvalid), "{label}: pack");
    assert_eq!(read, Err(Error::SchemeInvalid), "{label}: unpack");
    assert!(buf.iter().all(|b| *b == 0xEE), "{label}: wrote a byte");
}

#[test]
fn ac2_schemes_std_refuses_are_scheme_invalid_before_any_byte_moves() {
    // Arrange
    let nine = vec![n(U8); 9];
    let cases: Vec<(&str, Vec<Node>)> = vec![
        (
            "when names a later field",
            vec![When(1, 1, vec![n(U8)]), n(U8)],
        ),
        ("when names itself", vec![When(0, 1, vec![n(U8)])]),
        ("count names a later field", vec![Bits(1), n(U8)]),
        ("sized names a float", vec![n(F32), Sized(0)]),
        ("count names a bool", vec![Flags(vec![Bool]), Bits(0)]),
        ("bool outside flags", vec![n(U8), Bool]),
        ("bool inside a when", vec![n(U8), When(0, 1, vec![Bool])]),
        (
            "eq bool false",
            vec![Flags(vec![Bool]), When(0, 0, vec![n(U8)])],
        ),
        ("eq u8 out of range", vec![n(U8), When(0, 256, vec![n(U8)])]),
        ("eq u8 negative", vec![n(U8), When(0, -1, vec![n(U8)])]),
        ("eq i8 out of range", vec![n(I8), When(0, 128, vec![n(U8)])]),
        ("eq u2 out of range", vec![U2(1), When(0, 4, vec![n(U8)])]),
        ("when tests a float", vec![n(F64), When(0, 1, vec![n(U8)])]),
        ("when tests bytes", vec![Bytes(1), When(0, 1, vec![n(U8)])]),
        ("nine flags members", vec![Flags(nine)]),
        (
            "nine split bits",
            std::iter::once(FlagByte(0))
                .chain((0..9).map(|_| bit(0, n(U8))))
                .collect(),
        ),
        ("flag bit with no byte", vec![bit(0, n(U8))]),
        (
            "flag bit with another byte number",
            vec![FlagByte(1), bit(0, n(U8))],
        ),
        (
            "flag bit after a when that holds its byte",
            vec![n(U8), When(0, 1, vec![FlagByte(0)]), bit(0, n(U8))],
        ),
        (
            "flag bit in the next flags member",
            vec![Flags(vec![FlagByte(0), bit(0, n(U8))])],
        ),
    ];
    for (label, nodes) in cases {
        // Act + Assert
        assert!(std_refuses(&nodes), "{label}: std accepted it");
        assert_refused(label, &nostd_support::tree::nostd_fields(&nodes));
    }
}

#[test]
fn ac2_tables_only_the_core_can_write_are_refused() {
    use nostd::{bits, flag_bit, flag_byte, flags, packed, u16, u2, u8, when, Field};
    let span = |f: Field, s: u16| Field { span: s, ..f };
    let cases: Vec<(&str, Vec<Field>)> = vec![
        (
            "when source above the id range",
            vec![u8(0), when(1, 40_000, 1, 1), u8(1)],
        ),
        ("count above the id range", vec![u8(0), bits(1, 32_768)]),
        ("duplicate member id", vec![flags(0, 2), u8(0), u8(0)]),
        ("skipped member id", vec![flags(0, 2), u8(0), u8(2)]),
        (
            "flags id not its first member",
            vec![u8(0), flags(0, 1), u8(1)],
        ),
        (
            "when id not its first member",
            vec![u8(0), when(2, 0, 1, 1), u8(1)],
        ),
        ("span past the end", vec![flags(0, 3), u8(0)]),
        (
            "span past the parent",
            vec![flags(0, 1), span(when(0, 0, 1, 1), 3), u8(0), u8(1)],
        ),
        ("zero span", vec![span(u8(0), 0)]),
        ("a number with members", vec![span(u8(0), 2), u8(1)]),
        (
            "flag bit with two members",
            vec![flag_byte(0), flag_bit(0, 2), u8(0), u8(1)],
        ),
        ("flag bit with none", vec![flag_byte(0), flag_bit(0, 0)]),
        (
            "flag byte number 8",
            vec![flag_byte(8), flag_bit(8, 1), u8(0)],
        ),
        ("packed width 3", vec![u8(0), packed(3, 1, 0, 0)]),
        ("packed bias 1", vec![u8(0), packed(2, 1, 0, 1)]),
        ("u2 of a u16", vec![u2(0, 1), u16(0)]),
        ("u2 with no member", vec![u2(0, 0)]),
        ("u2 id not its first member", vec![u2(1, 1), u8(0)]),
        ("sixty-five u2 members", {
            let mut t = vec![u2(0, 65)];
            t.extend((0..65).map(u8));
            t
        }),
    ];
    for (label, fields) in cases {
        // Act + Assert
        assert_refused(label, &fields);
    }
}

#[test]
fn hostile_split_false_condition_is_silent_and_late_sources_refuse() {
    // Arrange: u8 mode; flag byte; bit 0 { when (mode == 1) { u8 speed } }; bit 1 { u16 heading }
    let silent = build(
        0x01,
        &[
            n(U8),
            FlagByte(0),
            bit(0, When(0, 1, vec![n(U8)])),
            bit(0, n(U16)),
        ],
    );
    let late = build(0x01, &[FlagByte(0), n(U8), bit(0, When(0, 1, vec![n(U8)]))]);
    let row = Slots::with(&[(0, Num::U8(0)), (1, Num::U8(7)), (2, Num::U16(90))], &[]);
    let late_row = Slots::with(&[(0, Num::U8(1)), (1, Num::U8(7))], &[]);
    let mut out = [0u8; 16];
    // Act
    let n_silent = nostd::pack(&nostd::Scheme::new(1, &silent.fields), &row, &mut out);
    let silent_bytes = n_silent.map(|n| out[..n].to_vec());
    let refused = nostd::pack(&nostd::Scheme::new(1, &late.fields), &late_row, &mut out);
    // Assert
    assert_eq!(silent_bytes, Ok(vec![0x01, 0x00, 0x02, 0x5a, 0x00]));
    assert_eq!(
        refused.map_err(|f| (f.error, f.field)),
        Err((Error::BadValue, 1))
    );
    assert!(packbin::pack(&late.reference, &values_of(&late_row, &late.leaves)).is_err());
}

#[test]
fn hostile_a_count_behind_a_clear_flag_is_bad_value() {
    // Arrange: flags { u8 n }; bits(n) — packet 01 00 leaves n out
    let built = build(0x01, &[Flags(vec![n(U8)]), Bits(0)]);
    let scheme = nostd::Scheme::new(1, &built.fields);
    // Act
    let read = nostd::unpack(&scheme, &[0x01, 0x00], &mut Slots::default());
    // Assert
    assert_eq!(
        read.map_err(|f| (f.error, f.field)),
        Err((Error::BadValue, 1))
    );
}

#[test]
fn storage_shorter_than_the_count_is_too_many_and_nothing_is_written() {
    // Arrange: u8 n; bits(n); sized(n) with storage of 3
    let built = build(0x21, &[n(U8), Bits(0), Sized(0)]);
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    let mut row = Slots {
        cap: Some(3),
        ..Slots::default()
    };
    // Act
    let at_limit = nostd::unpack(&scheme, &[0x21, 3, 0b101, 7, 8, 9], &mut row.clone());
    let over = nostd::unpack(&scheme, &[0x21, 4, 0b1011, 7, 8, 9, 10], &mut row);
    // Assert
    assert_eq!(at_limit, Ok(6));
    let fault = over.expect_err("over");
    assert_eq!(
        (fault.error, fault.field, fault.needed),
        (Error::TooMany, 1, 4)
    );
    assert_eq!(row.blobs.get(1).cloned().flatten(), Some(vec![0, 0, 0]));
}

#[test]
fn a_bits_value_above_one_and_a_packed_value_above_its_width_are_bad_value() {
    // Arrange
    let built = build(0x21, &[n(U8), Bits(0), Packed(2, 0, 0)]);
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    let bad_bit = Slots::with(&[(0, Num::U8(2))], &[(1, &[1, 2]), (2, &[3, 0])]);
    let bad_pack = Slots::with(&[(0, Num::U8(2))], &[(1, &[1, 0]), (2, &[4, 0])]);
    let good = Slots::with(&[(0, Num::U8(2))], &[(1, &[1, 0]), (2, &[3, 2])]);
    let mut out = [0u8; 8];
    // Act + Assert
    let field = |r: &Slots, out: &mut [u8]| nostd::pack(&scheme, r, out).map_err(|f| f.field);
    assert_eq!(field(&bad_bit, &mut out), Err(1));
    assert_eq!(field(&bad_pack, &mut out), Err(2));
    assert_eq!(field(&good, &mut out), Ok(4));
    assert_eq!(&out[..4], &[0x21, 2, 0b01, 0b1011]);
}
