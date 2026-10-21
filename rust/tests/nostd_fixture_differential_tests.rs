//! AZ-2757 AC-2: every fixture file read by both walkers. Golden, text vectors, ECC vectors, the
//! hostile cases, the fuzz corpus and mutations of it: the `std` walker and the core pack the same
//! bytes, refuse the same schemes and read the same values (card 4). Needs `std` and `text`.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::hostile::{cases, from_hex, nodes_of, CORPUS};
use nostd_support::random::pack_both;
use nostd_support::tree::{build, compare, std_refuses, Node};
use nostd_support::{golden, Slots};
use packbin::nostd::{bytes, pack, unpack, validate, Kind, Num, Row, Scheme, DEFAULT_MAX_SLOTS};

const TEXT: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/text/vectors.txt");
const ECC: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/ecc/vectors.txt");

fn rows(path: &str, kind: &str) -> Vec<Vec<String>> {
    std::fs::read_to_string(path)
        .expect("vectors")
        .lines()
        .filter(|l| l.split(' ').next() == Some(kind))
        .map(|l| l.split(' ').skip(1).map(str::to_string).collect())
        .collect()
}

fn hex(field: &str) -> Vec<u8> {
    if field == "-" {
        Vec::new()
    } else {
        from_hex(field)
    }
}

#[test]
fn ac2_the_golden_packet_reads_and_packs_alike() {
    // Arrange
    let nodes = [
        Node::Num(Kind::U16),
        Node::Num(Kind::I32),
        Node::Num(Kind::I32),
        Node::Num(Kind::U8),
        Node::Num(Kind::U8),
    ];
    let built = build(0x40, &nodes);
    let wire = golden();
    let scheme = Scheme::new(0x40, &built.fields);
    // Act
    let mut core = Slots::default();
    let used = unpack(&scheme, &wire, &mut core);
    let theirs = packbin::unpack(&built.reference, &wire).expect("std unpack");
    let mut out = [0u8; 32];
    let packed = pack(&scheme, &core, &mut out);
    // Assert
    assert_eq!(used, Ok(wire.len()));
    compare(&theirs, &core, &built.leaves).expect("same values");
    assert_eq!(packed.map(|n| out[..n].to_vec()), Ok(wire));
}

/// Packs a text row with both walkers (scratch and storage sized for the longest vector).
fn pack_text(built: &nostd_support::tree::Built, slots: &Slots) -> (Vec<u8>, Vec<u8>) {
    let scheme = Scheme::new(0x21, &built.fields);
    let mut out = vec![0u8; 70_000];
    let mut scratch = vec![0u32; 3 * 20_000];
    let n = packbin::nostd::pack_with(&scheme, slots, &mut out, &mut scratch).expect("core pack");
    let values = nostd_support::tree::values_of(slots, &built.leaves);
    let theirs = packbin::pack(&built.reference, &values).expect("std pack");
    (out[..n].to_vec(), theirs)
}

/// Both walkers read `wire` alike (accept or refuse, same values); true when accepted.
fn read_text_alike(built: &nostd_support::tree::Built, wire: &[u8], label: &str) -> bool {
    let scheme = Scheme::new(0x21, &built.fields);
    let mut back = Slots {
        cap: Some(20_000),
        ..Slots::default()
    };
    let ours = unpack(&scheme, wire, &mut back);
    let theirs = packbin::unpack(&built.reference, wire);
    assert_eq!(ours.is_ok(), theirs.is_ok(), "{label}: {ours:?} {theirs:?}");
    if let Ok(values) = theirs {
        compare(&values, &back, &built.leaves).unwrap_or_else(|e| panic!("{label}: {e}"));
    }
    ours.is_ok()
}

#[test]
fn ac2_every_text_vector_packs_and_reads_alike() {
    // Arrange
    let built = build(0x21, &[Node::Utf8]);
    let (mut packed, mut read) = (0, 0);
    for row in rows(TEXT, "enc") {
        let (id, text, field) = (&row[0], hex(&row[1]), hex(&row[2]));
        let slots = Slots::with(&[], &[(0, &text)]);
        // Act
        let (ours, theirs) = pack_text(&built, &slots);
        // Assert
        assert_eq!(ours, theirs, "{id}");
        assert_eq!(&ours[1..], field.as_slice(), "{id}");
        assert!(read_text_alike(&built, &ours, id), "{id}");
        packed += 1;
    }
    for row in rows(TEXT, "alt") {
        let wire = [vec![0x21], hex(&row[2])].concat();
        assert!(read_text_alike(&built, &wire, &row[0]), "{}", row[0]);
        read += 1;
    }
    for row in rows(TEXT, "bad") {
        let wire = [vec![0x21], hex(&row[2])].concat();
        assert!(!read_text_alike(&built, &wire, &row[0]), "{}", row[0]);
        read += 1;
    }
    assert_eq!((packed, read), (346, 42));
}

#[test]
fn ac2_every_ecc_vector_protects_alike() {
    // Arrange
    let mut checked = 0;
    for row in rows(ECC, "enc") {
        let (id, n, clear, want) = (
            &row[0],
            row[1].parse::<usize>().expect("n"),
            hex(&row[2]),
            hex(&row[3]),
        );
        let Some((&type_number, body)) = clear.split_first() else {
            continue;
        };
        let std_scheme = packbin::MapScheme::new(
            i32::from(type_number),
            vec![packbin::bytes("b", body.len())],
        )
        .with_parity(n);
        let mut values = packbin::Values::new();
        packbin::insert(&mut values, "b", Some(packbin::Value::Bytes(body.to_vec())));
        let fields = [bytes(0, body.len() as u16)];
        let scheme = Scheme::new(type_number, &fields).with_parity(n as u8);
        let slots = Slots::with(&[], &[(0, body)]);
        let mut out = [0u8; 300];
        // Act
        let ours = pack(&scheme, &slots, &mut out).map(|len| out[..len].to_vec());
        let theirs = packbin::pack(&std_scheme, &values);
        // Assert
        assert_eq!(ours.as_ref().ok(), theirs.as_ref().ok(), "{id}");
        assert_eq!(ours.expect("core pack"), want, "{id}");
        checked += 1;
    }
    assert_eq!(
        checked, 35,
        "42 rows less those with an empty clear message"
    );
}

/// The case schemes the two walkers can both be built for: (id, nodes, limits).
fn schemes() -> Vec<(String, Vec<Node>)> {
    cases()
        .into_iter()
        .filter(|c| c.stage != "pack")
        .filter_map(|c| nodes_of(&c.id).map(|nodes| (c.id, nodes)))
        .collect()
}

#[test]
fn ac2_every_construct_case_is_refused_by_both_walkers() {
    for c in cases().iter().filter(|c| c.stage == "construct") {
        let Some(nodes) = nodes_of(&c.id) else {
            continue;
        };
        // Arrange
        let fields = nostd_support::tree::nostd_fields(&nodes);
        // Act
        let core_refuses = validate(&Scheme::new(1, &fields)).is_err();
        // Assert
        assert!(core_refuses, "{}: the core accepts it", c.id);
        assert!(std_refuses(&nodes), "{}: std accepts it", c.id);
    }
}

/// Reads `wire` with both walkers under the schemes of the cases; a scheme `std` refuses is
/// refused by the core too. Returns how many reads both accepted.
fn read_alike_everywhere(wire: &[u8], label: &str) -> usize {
    let mut accepted = 0;
    for (id, nodes) in schemes() {
        let fields = nostd_support::tree::nostd_fields(&nodes);
        let limited = id.ends_with("_rounds_over_limit");
        let mut scheme = Scheme::new(1, &fields);
        if limited {
            scheme = scheme.with_limits(3, DEFAULT_MAX_SLOTS);
        }
        if std_refuses(&nodes) {
            assert!(
                validate(&scheme).is_err(),
                "{label}: {id}: std refuses, the core accepts"
            );
            continue;
        }
        let built = build(1, &nodes);
        let reference = if limited {
            built.reference.with_limits(3, DEFAULT_MAX_SLOTS)
        } else {
            built.reference
        };
        let mut back = Slots {
            cap: Some(1024),
            ..Slots::default()
        };
        let ours = unpack(&scheme, wire, &mut back);
        let theirs = packbin::unpack(&reference, wire);
        assert_eq!(
            ours.is_ok(),
            theirs.is_ok(),
            "{label}: {id}: {wire:02x?} {ours:?} {theirs:?}"
        );
        if let Ok(values) = theirs {
            if let Err(e) = compare(&values, &back, &built.leaves) {
                panic!("{label}: {id}: {e} for {wire:02x?}");
            }
            accepted += 1;
        }
    }
    accepted
}

#[test]
fn ac2_every_hostile_case_and_corpus_input_reads_alike_under_every_case_scheme() {
    // Arrange
    let mut inputs: Vec<(String, Vec<u8>)> = cases()
        .into_iter()
        .filter(|c| c.stage == "unpack" || c.stage == "limit")
        .map(|c| (c.id, from_hex(&c.hex)))
        .collect();
    for line in std::fs::read_to_string(CORPUS).expect("corpus").lines() {
        let f: Vec<&str> = line.split_whitespace().collect();
        if f.len() == 3 && !line.starts_with('#') {
            inputs.push((f[0].to_string(), from_hex(f[2])));
        }
    }
    // Act
    let accepted: usize = inputs
        .iter()
        .map(|(label, wire)| read_alike_everywhere(wire, label))
        .sum();
    // Assert
    assert!(inputs.len() >= 50);
    assert!(accepted > 0, "some input is accepted by some scheme");
}

#[test]
fn ac2_mutated_inputs_read_alike_under_every_case_scheme() {
    // Arrange
    let mut state = 0xC0FF_EE00_1234_5679u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    let seeds: Vec<Vec<u8>> = cases()
        .into_iter()
        .filter(|c| c.stage == "unpack" || c.stage == "limit")
        .map(|c| from_hex(&c.hex))
        .collect();
    // Act and Assert
    for (k, seed) in seeds.iter().enumerate() {
        for round in 0..25 {
            let mut m = seed.clone();
            let at = (next() as usize) % m.len().max(1);
            match next() % 3 {
                0 if !m.is_empty() => m[at] ^= (next() as u8) | 1,
                1 => m.truncate(at),
                _ => m.insert(at.min(m.len()), next() as u8),
            }
            read_alike_everywhere(&m, &format!("mutation {k}.{round}"));
        }
    }
}

#[test]
fn ac2_a_row_the_core_packs_is_read_back_by_std() {
    // Arrange
    let nodes = [
        Node::Num(Kind::U8),
        Node::Times(0, vec![Node::Num(Kind::U8)]),
    ];
    let built = build(0x21, &nodes);
    let mut row = Slots::with(&[(0, Num::U8(2))], &[]);
    nostd_support::random::set_items(
        &mut row,
        1,
        vec![
            Slots::with(&[(1, Num::U8(7))], &[]),
            Slots::with(&[(1, Num::U8(8))], &[]),
        ],
    );
    // Act
    let (ours, theirs) = pack_both(&built, &row);
    // Assert
    assert_eq!(ours.expect("core"), theirs.expect("std"));
    assert!(row.count(1).is_some());
}
