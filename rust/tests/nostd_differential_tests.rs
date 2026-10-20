//! The `std` walker and the `nostd` walker write and read the same bytes (AZ-2749, card 4).
#![cfg(feature = "std")]

mod nostd_support;

use nostd_support::{golden, Slots};
use packbin::nostd::{self, Kind, Num};
use packbin::{insert, MapScheme, Value, Values};

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }
}

#[derive(Clone, Copy)]
struct Spec {
    kind: Kind,
    big_endian: bool,
    size: u16,
}

const fn spec(kind: Kind, big_endian: bool) -> Spec {
    Spec {
        kind,
        big_endian,
        size: 0,
    }
}

fn layouts() -> Vec<(&'static str, Vec<Spec>)> {
    use Kind::*;
    let all = [U8, I8, U16, I16, U32, I32, U64, I64, F32, F64];
    let le: Vec<Spec> = all.iter().map(|k| spec(*k, false)).collect();
    let be: Vec<Spec> = all.iter().map(|k| spec(*k, true)).collect();
    let blob = |n| Spec {
        kind: Bytes,
        big_endian: false,
        size: n,
    };
    vec![
        (
            "position",
            vec![
                spec(U16, false),
                spec(I32, false),
                spec(I32, false),
                spec(U8, false),
                spec(U8, false),
            ],
        ),
        ("all little-endian", le.clone()),
        ("all big-endian", be),
        (
            "bytes first and last",
            [vec![blob(3)], le.clone(), vec![blob(1), blob(8)]].concat(),
        ),
        ("bytes only", vec![blob(0), blob(5)]),
    ]
}

fn nostd_fields(specs: &[Spec]) -> Vec<nostd::Field> {
    specs
        .iter()
        .enumerate()
        .map(|(i, s)| {
            let id = i as u16;
            let f = match s.kind {
                Kind::U8 => nostd::u8(id),
                Kind::U16 => nostd::u16(id),
                Kind::U32 => nostd::u32(id),
                Kind::U64 => nostd::u64(id),
                Kind::I8 => nostd::i8(id),
                Kind::I16 => nostd::i16(id),
                Kind::I32 => nostd::i32(id),
                Kind::I64 => nostd::i64(id),
                Kind::F32 => nostd::f32(id),
                Kind::F64 => nostd::f64(id),
                Kind::Bytes => nostd::bytes(id, s.size),
            };
            if s.big_endian {
                nostd::be(f)
            } else {
                f
            }
        })
        .collect()
}

fn std_scheme(type_number: u8, specs: &[Spec]) -> MapScheme {
    let fields = specs
        .iter()
        .enumerate()
        .map(|(i, s)| {
            let name = i.to_string();
            let f = match s.kind {
                Kind::U8 => packbin::u8(&name),
                Kind::U16 => packbin::u16(&name),
                Kind::U32 => packbin::u32(&name),
                Kind::U64 => packbin::u64(&name),
                Kind::I8 => packbin::i8(&name),
                Kind::I16 => packbin::i16(&name),
                Kind::I32 => packbin::i32(&name),
                Kind::I64 => packbin::i64(&name),
                Kind::F32 => packbin::f32(&name),
                Kind::F64 => packbin::f64(&name),
                Kind::Bytes => packbin::bytes(&name, usize::from(s.size)),
            };
            if s.big_endian {
                packbin::be(f)
            } else {
                f
            }
        })
        .collect();
    MapScheme::new(i32::from(type_number), fields)
}

fn random_row(rng: &mut Rng, specs: &[Spec]) -> Slots {
    let mut row = Slots::default();
    for (i, s) in specs.iter().enumerate() {
        let id = i as u16;
        let r = rng.next();
        let num = match s.kind {
            Kind::U8 => Num::U8(r as u8),
            Kind::U16 => Num::U16(r as u16),
            Kind::U32 => Num::U32(r as u32),
            Kind::U64 => Num::U64(r),
            Kind::I8 => Num::I8(r as i8),
            Kind::I16 => Num::I16(r as i16),
            Kind::I32 => Num::I32(r as i32),
            Kind::I64 => Num::I64(r as i64),
            Kind::F32 => Num::F32(f32::from_bits(r as u32)),
            Kind::F64 => Num::F64(f64::from_bits(r)),
            Kind::Bytes => {
                let blob: Vec<u8> = (0..s.size).map(|_| rng.next() as u8).collect();
                row.blobs.resize(i + 1, None);
                row.blobs[i] = Some(blob);
                continue;
            }
        };
        packbin::nostd::Row::set_num(&mut row, id, num);
    }
    row
}

fn to_value(num: Num) -> Value {
    match num {
        Num::U8(v) => Value::U8(v),
        Num::U16(v) => Value::U16(v),
        Num::U32(v) => Value::U32(v),
        Num::U64(v) => Value::U64(v),
        Num::I8(v) => Value::I8(v),
        Num::I16(v) => Value::I16(v),
        Num::I32(v) => Value::I32(v),
        Num::I64(v) => Value::I64(v),
        Num::F32(v) => Value::F32(v),
        Num::F64(v) => Value::F64(v),
    }
}

fn values_of(row: &Slots, specs: &[Spec]) -> Values {
    let mut values = Values::new();
    for (i, s) in specs.iter().enumerate() {
        let name = i.to_string();
        let value = match s.kind {
            Kind::Bytes => Value::Bytes(row.blobs[i].clone().expect("blob")),
            _ => to_value(packbin::nostd::Row::num(row, i as u16).expect("num")),
        };
        insert(&mut values, &name, Some(value));
    }
    values
}

fn same(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::F32(x), Value::F32(y)) => x.to_bits() == y.to_bits(),
        (Value::F64(x), Value::F64(y)) => x.to_bits() == y.to_bits(),
        _ => a == b,
    }
}

#[test]
fn std_and_nostd_write_and_read_the_same_bytes_for_random_rows() {
    // Arrange
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    for (name, specs) in layouts() {
        let fields = nostd_fields(&specs);
        let scheme = nostd::Scheme::new(0x31, &fields);
        let reference = std_scheme(0x31, &specs);
        for round in 0..500 {
            let row = random_row(&mut rng, &specs);
            let mut out = vec![0u8; 256];
            // Act
            let n = nostd::pack(&scheme, &row, &mut out).expect("nostd pack");
            let want = packbin::pack(&reference, &values_of(&row, &specs)).expect("std pack");
            let mut back = Slots::default();
            nostd::unpack(&scheme, &out[..n], &mut back).expect("nostd unpack");
            let read = packbin::unpack(&reference, &out[..n]).expect("std unpack");
            // Assert
            assert_eq!(&out[..n], want.as_slice(), "{name} round {round}: bytes");
            let sent = values_of(&row, &specs);
            let got = values_of(&back, &specs);
            for i in 0..specs.len() {
                let key = i.to_string();
                let from_std = read
                    .get(key.as_str())
                    .and_then(|v| v.as_ref())
                    .expect("std value");
                assert!(
                    same(&sent[key.as_str()].clone().unwrap(), from_std),
                    "{name} round {round} field {i}: std read"
                );
                assert!(
                    same(&got[key.as_str()].clone().unwrap(), from_std),
                    "{name} round {round} field {i}: nostd read"
                );
            }
        }
    }
}

#[test]
fn both_refuse_every_cut_extended_and_retyped_copy_of_a_packet() {
    // Arrange
    let mut rng = Rng(42);
    for (name, specs) in layouts() {
        let fields = nostd_fields(&specs);
        let scheme = nostd::Scheme::new(0x31, &fields);
        let reference = std_scheme(0x31, &specs);
        let row = random_row(&mut rng, &specs);
        let mut out = vec![0u8; 256];
        let n = nostd::pack(&scheme, &row, &mut out).expect("pack");
        let wire = out[..n].to_vec();
        let mut variants: Vec<Vec<u8>> = (0..wire.len()).map(|cut| wire[..cut].to_vec()).collect();
        variants.push([wire.clone(), vec![0]].concat());
        variants.push([vec![0x32], wire[1..].to_vec()].concat());
        for (v, bytes) in variants.iter().enumerate() {
            // Act
            let std_refused = packbin::unpack(&reference, bytes).is_err();
            let nostd_refused = nostd::unpack(&scheme, bytes, &mut Slots::default()).is_err();
            // Assert
            assert!(std_refused, "{name} variant {v}: std accepted");
            assert!(nostd_refused, "{name} variant {v}: nostd accepted");
        }
    }
}

#[test]
fn the_golden_fixture_is_the_same_packet_for_both() {
    // Arrange
    let specs = &layouts()[0].1;
    let fields = nostd_fields(specs);
    let scheme = nostd::Scheme::new(0x40, &fields);
    let reference = std_scheme(0x40, specs);
    let wire = golden();
    // Act
    let mut row = Slots::default();
    nostd::unpack(&scheme, &wire, &mut row).expect("nostd");
    let read = packbin::unpack(&reference, &wire).expect("std");
    // Assert
    assert_eq!(packbin::pack(&reference, &read).expect("repack"), wire);
    let mut out = [0u8; 32];
    let n = nostd::pack(&scheme, &row, &mut out).expect("repack nostd");
    assert_eq!(&out[..n], wire.as_slice());
}
