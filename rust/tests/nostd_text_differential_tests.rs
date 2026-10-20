//! AZ-2754: strings and dictionaries in the heap-free core against the `std` walker, byte for
//! byte, in every place a string can stand (card 4). Needs `text` and `std`.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::random::{assert_read_alike, pack_both, random_row, Rng};
use nostd_support::tree::{build, Node};
use packbin::nostd::Kind::*;

fn n(kind: packbin::nostd::Kind) -> Node {
    Node::Num(kind)
}

fn list(element: Node) -> Node {
    Node::List(Box::new(element))
}

fn dict(element: Node) -> Node {
    Node::Dict(Box::new(element))
}

fn bit(number: u16, inner: Node) -> Node {
    Node::FlagBit(number, Box::new(inner))
}

/// Strings in the top level, flags, a flag bit, a `when` body, a group, a `repeat` and `times`
/// round, a list and a dictionary; dictionaries of every element kind.
fn layouts() -> Vec<(&'static str, Vec<Node>)> {
    use Node::{Flags, Group, Repeat, Times, Utf8, When};
    vec![
        ("one string", vec![Utf8]),
        ("string between numbers", vec![n(U8), Utf8, n(U16), Utf8]),
        ("string in flags", vec![Flags(vec![Utf8, n(U8), Utf8])]),
        (
            "string under a flag bit",
            vec![Node::FlagByte(0), n(U8), bit(0, Utf8), bit(0, Utf8)],
        ),
        (
            "string in a when",
            vec![n(U8), When(0, 1, vec![Utf8, n(U8)])],
        ),
        ("string in a group", vec![Group(vec![Utf8, Utf8])]),
        ("string in a repeat", vec![n(U8), Repeat(vec![Utf8, n(U8)])]),
        ("string in a times", vec![n(U8), Times(0, vec![Utf8])]),
        ("list of strings", vec![list(Utf8), n(U8)]),
        ("list of lists of strings", vec![list(list(Utf8))]),
        ("dict of numbers", vec![dict(n(U16)), n(U8)]),
        ("dict of strings", vec![dict(Utf8)]),
        ("dict of bytes", vec![dict(Node::Bytes(2))]),
        ("dict of lists", vec![dict(list(Utf8)), n(U8)]),
        ("dict of dicts", vec![dict(dict(n(U8)))]),
        ("dict in a repeat", vec![Repeat(vec![dict(n(U8))])]),
        ("list of dicts", vec![list(dict(Utf8))]),
        ("dict in flags", vec![Flags(vec![dict(n(U8)), n(U8)])]),
        (
            "dict under a flag bit",
            vec![Node::FlagByte(0), bit(0, dict(n(U8)))],
        ),
        ("dict in a when", vec![n(U8), When(0, 1, vec![dict(Utf8)])]),
    ]
}

#[test]
fn ac1_random_rows_pack_to_the_same_bytes_and_read_back_alike() {
    // Arrange
    let mut rng = Rng(0x2754_0001);
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
fn ac4_every_cut_and_trailing_copy_is_read_alike() {
    // Arrange
    let mut rng = Rng(0x2754_0004);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        let mut wires = Vec::new();
        while wires.len() < 30 {
            if let (Ok(w), Ok(_)) = pack_both(&built, &random_row(&mut rng, &built.leaves)) {
                wires.push(w);
            }
        }
        for wire in wires {
            let mut variants: Vec<Vec<u8>> = (1..wire.len()).map(|c| wire[..c].to_vec()).collect();
            variants.push([wire.clone(), vec![0x5A]].concat());
            for bytes in variants {
                // Act + Assert
                assert_read_alike(&built, &bytes, name);
            }
        }
    }
}

#[test]
fn ac4_every_bit_flip_of_a_packet_is_read_alike() {
    // Arrange
    let mut rng = Rng(0x2754_0044);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        let mut wires = Vec::new();
        while wires.len() < 12 {
            if let (Ok(w), Ok(_)) = pack_both(&built, &random_row(&mut rng, &built.leaves)) {
                wires.push(w);
            }
        }
        for wire in wires {
            for bit in 8..8 * wire.len() {
                let mut damaged = wire.clone();
                damaged[bit / 8] ^= 0x80 >> (bit % 8);
                // Act + Assert
                assert_read_alike(&built, &damaged, name);
            }
        }
    }
}

#[test]
fn ac4_random_bytes_are_accepted_or_refused_alike() {
    // Arrange
    let mut rng = Rng(0x2754_0444);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        for _ in 0..6_000 {
            let len = rng.below(25) as usize;
            let mut wire = vec![0x21];
            wire.extend((0..len).map(|_| {
                let r = rng.next();
                if r % 3 == 0 {
                    (r >> 8) as u8 % 4
                } else {
                    (r >> 8) as u8
                }
            }));
            // Act + Assert
            assert_read_alike(&built, &wire, name);
        }
    }
}
