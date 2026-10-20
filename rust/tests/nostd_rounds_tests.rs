//! AZ-2753: groups, `repeat`, `times` and lists in the heap-free core, in caller-owned items,
//! byte for byte against the `std` walker (card 4).
#![cfg(feature = "std")]

mod nostd_support;

use nostd_support::random::{assert_read_alike, pack_both, random_row, set_items, Rng};
use nostd_support::tree::{build, nostd_fields, std_refuses, values_of, Node};
use nostd_support::Slots;
use packbin::nostd::{self, Error, Fault, Kind, Num, Row};

use Kind::*;
use Node::{Bits, Bool, Bytes, FlagBit, FlagByte, Flags, Group, Repeat, Times, When, U2};

fn n(kind: Kind) -> Node {
    Node::Num(kind)
}

fn list(element: Node) -> Node {
    Node::List(Box::new(element))
}

fn bit(number: u16, inner: Node) -> Node {
    FlagBit(number, Box::new(inner))
}

fn layouts() -> Vec<(&'static str, Vec<Node>)> {
    vec![
        (
            "repeat of points",
            vec![n(U8), Repeat(vec![n(I32), n(I32)])],
        ),
        ("times", vec![n(U8), Times(0, vec![n(U16), n(U8)]), n(U8)]),
        (
            "times in flags",
            vec![n(U8), Flags(vec![Times(0, vec![n(U8)]), n(U16)])],
        ),
        (
            "groups in flags",
            vec![Flags(vec![
                Group(vec![n(U8), n(U16)]),
                Bool,
                Group(vec![Flags(vec![Bool])]),
            ])],
        ),
        ("list of numbers", vec![list(n(U16)), n(U8)]),
        ("list of lists", vec![list(list(n(U8)))]),
        ("lists of bytes and u2", vec![list(Bytes(2)), list(U2(1))]),
        (
            "times inside a repeat",
            vec![Repeat(vec![n(U8), Times(0, vec![n(U8)])])],
        ),
        (
            "flag byte in a round",
            vec![Repeat(vec![FlagByte(0), n(U8), bit(0, n(U16))])],
        ),
        (
            "when in a times round",
            vec![n(U8), Times(0, vec![n(U8), When(1, 1, vec![n(U8)])])],
        ),
        (
            "group with a when",
            vec![n(U8), Group(vec![n(U8), When(0, 2, vec![n(U8)])])],
        ),
        (
            "late times under a flag bit",
            vec![FlagByte(0), n(U8), bit(0, Times(0, vec![n(U8)]))],
        ),
        ("bits in a round", vec![Repeat(vec![n(U8), Bits(0)])]),
        (
            "list in a times round",
            vec![n(U8), Times(0, vec![list(n(I8))])],
        ),
    ]
}

#[test]
fn ac1_random_rows_pack_to_the_same_bytes_and_read_back_alike() {
    // Arrange
    let mut rng = Rng(0x2753_0001);
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
    // Arrange: a cut of a repeat at a round boundary is a valid packet, so both walkers decide
    let mut rng = Rng(0x2753_0004);
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
fn ac4_random_bytes_are_accepted_or_refused_alike() {
    // Arrange: packets of up to 24 bytes after the type byte, small bytes a third of the time
    let mut rng = Rng(0x2753_0044);
    for (name, nodes) in layouts() {
        let built = build(0x21, &nodes);
        for _ in 0..6_000 {
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
            assert_read_alike(&built, &wire, name);
        }
    }
}

fn fault(r: Result<usize, Fault>) -> (Error, i32, usize) {
    let f = r.expect_err("refused");
    (f.error, f.field, f.needed)
}

#[test]
fn ac2_rounds_at_the_limit_pass_and_one_above_is_too_many_like_std() {
    // Arrange: u8 c; times(c) { u8 }; and a repeat { u8 }, both limited to 3 rounds
    let times = build(0x21, &[n(U8), Times(0, vec![n(U8)])]);
    let repeat = build(0x21, &[Repeat(vec![n(U8)])]);
    for (label, built, at_limit, over) in [
        (
            "times",
            &times,
            vec![0x21, 3, 1, 2, 3],
            vec![0x21, 4, 1, 2, 3, 4],
        ),
        (
            "repeat",
            &repeat,
            vec![0x21, 1, 2, 3],
            vec![0x21, 1, 2, 3, 4],
        ),
    ] {
        let scheme = nostd::Scheme::new(0x21, &built.fields).with_limits(3, 100);
        let reference = built.reference.clone().with_limits(3, 100);
        // Act
        let ok = nostd::unpack(&scheme, &at_limit, &mut Slots::default());
        let refused = nostd::unpack(&scheme, &over, &mut Slots::default());
        // Assert
        assert_eq!(ok, Ok(at_limit.len()), "{label}");
        assert!(
            packbin::unpack(&reference, &at_limit).is_ok(),
            "{label}: std"
        );
        let id = if label == "times" { 1 } else { 0 };
        assert_eq!(fault(refused), (Error::TooMany, id, 3), "{label}");
        assert!(packbin::unpack(&reference, &over).is_err(), "{label}: std");
    }
}

#[test]
fn ac2_slots_above_the_limit_are_too_many_on_pack_and_unpack_like_std() {
    // Arrange: repeat { u8; u16 } charges 2 slots a round; 5 slots allow 2 rounds
    let built = build(0x21, &[Repeat(vec![n(U8), n(U16)])]);
    let scheme = nostd::Scheme::new(0x21, &built.fields).with_limits(100, 5);
    let reference = built.reference.clone().with_limits(100, 5);
    let round = |v: u8| Slots::with(&[(0, Num::U8(v)), (1, Num::U16(u16::from(v)))], &[]);
    let mut two = Slots::default();
    set_items(&mut two, 0, vec![round(1), round(2)]);
    let mut three = two.clone();
    set_items(&mut three, 0, vec![round(1), round(2), round(3)]);
    let mut out = [0u8; 32];
    // Act
    let packed_two = nostd::pack(&scheme, &two, &mut out);
    let packed_three = nostd::pack(&scheme, &three, &mut out);
    let read = nostd::unpack(
        &scheme,
        &[0x21, 1, 1, 0, 2, 2, 0, 3, 3, 0],
        &mut Slots::default(),
    );
    // Assert
    assert_eq!(packed_two, Ok(7));
    assert_eq!(fault(packed_three), (Error::TooMany, 0, 5));
    assert_eq!(fault(read), (Error::TooMany, 0, 5));
    assert!(packbin::pack(&reference, &values_of(&three, &built.leaves)).is_err());
    assert!(packbin::unpack(&reference, &[0x21, 1, 1, 0, 2, 2, 0, 3, 3, 0]).is_err());
}

#[test]
fn ac2_storage_smaller_than_the_count_is_too_many_and_nothing_goes_past_it() {
    // Arrange: u8 c; times(c) { u8 }; list(u16), with room for 2 items
    let built = build(0x21, &[n(U8), Times(0, vec![n(U8)]), list(n(U16))]);
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    let small = || Slots {
        cap: Some(2),
        ..Slots::default()
    };
    let mut rounds = small();
    let mut items = small();
    // Act
    let at_limit = nostd::unpack(&scheme, &[0x21, 2, 7, 8, 2, 0, 1, 0, 2, 0], &mut small());
    let times_over = nostd::unpack(&scheme, &[0x21, 3, 7, 8, 9, 0, 0], &mut rounds);
    let list_over = nostd::unpack(&scheme, &[0x21, 0, 3, 0, 1, 0, 2, 0, 3, 0], &mut items);
    // Assert
    assert_eq!(at_limit, Ok(10));
    assert_eq!(fault(times_over), (Error::TooMany, 1, 3));
    assert_eq!(rounds.items[1].as_ref().map(Vec::len), Some(2));
    assert_eq!(fault(list_over), (Error::TooMany, 2, 3));
    assert_eq!(items.items[2].as_ref().map(Vec::len), Some(2));
}

#[test]
fn ac4_hostile_counts_end_with_an_error_kind_at_once() {
    // Arrange: a times count of 2^32 - 1 and a list count of 65,535 over a few bytes
    let times = build(0x01, &[n(U32), Times(0, vec![n(U8)])]);
    let lists = build(0x01, &[list(n(U16))]);
    let rounds = nostd::Scheme::new(0x01, &times.fields);
    let items = nostd::Scheme::new(0x01, &lists.fields);
    let (mut round_row, mut item_row) = (Slots::default(), Slots::default());
    // Act
    let a = nostd::unpack(
        &rounds,
        &[0x01, 0xff, 0xff, 0xff, 0xff, 0x61],
        &mut round_row,
    );
    let b = nostd::unpack(&items, &[0x01, 0xff, 0xff, 1, 0], &mut item_row);
    // Assert: the read stopped in the round or item where the bytes ran out
    assert_eq!(a.map_err(|f| f.error), Err(Error::ShortPacket));
    assert_eq!(b.map_err(|f| f.error), Err(Error::ShortPacket));
    assert_eq!(round_row.items[1].as_ref().map(Vec::len), Some(2));
    assert_eq!(item_row.items[0].as_ref().map(Vec::len), Some(2));
}

#[test]
fn zero_progress_repeat_round_ends_it_and_the_rest_is_trailing() {
    // Arrange: repeat { u8 c; when (c == 9) { u8 } } over `21 01 02`: the first round reads
    // c = 1, the second c = 2; a round always reads its u8, so the repeat ends at the packet end
    let built = build(0x21, &[Repeat(vec![n(U8), When(0, 9, vec![n(U8)])])]);
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    // Act
    let read = nostd::unpack(&scheme, &[0x21, 1, 2], &mut Slots::default());
    // Assert
    assert_eq!(read, Ok(3));
    assert!(assert_read_alike(&built, &[0x21, 1, 2], "zero progress"));
}

#[test]
fn a_repeat_in_flags_whose_rounds_hold_no_value_is_off_like_std() {
    // Arrange: flags { repeat { u8 }; u8 } with one round that holds nothing
    let built = build(0x21, &[Flags(vec![Repeat(vec![n(U8)]), n(U8)])]);
    let mut empty = Slots::default();
    set_items(&mut empty, 0, vec![Slots::default()]);
    // Act
    let (ours, theirs) = pack_both(&built, &empty);
    // Assert
    assert_eq!(ours, Ok(vec![0x21, 0x00]));
    assert_eq!(theirs, Ok(vec![0x21, 0x00]));
}

#[test]
fn ac2_schemes_std_refuses_are_scheme_invalid() {
    // Arrange
    let cases: Vec<(&str, Vec<Node>)> = vec![
        (
            "repeat in a repeat",
            vec![Repeat(vec![Repeat(vec![n(U8)])])],
        ),
        (
            "repeat in a times round",
            vec![n(U8), Times(0, vec![Repeat(vec![n(U8)])])],
        ),
        (
            "times in a times round",
            vec![n(U8), Times(0, vec![n(U8), Times(1, vec![n(U8)])])],
        ),
        ("empty times body", vec![n(U8), Times(0, vec![])]),
        ("empty repeat body", vec![Repeat(vec![])]),
        (
            "times body of an empty when (hostile construct_empty_when_times_body)",
            vec![n(U8), n(U8), Times(1, vec![When(0, 1, vec![])])],
        ),
        (
            "when names a field outside the repeat",
            vec![n(U8), Repeat(vec![When(0, 1, vec![n(U8)])])],
        ),
        (
            "count names a field outside the times",
            vec![n(U8), n(U8), Times(0, vec![Bits(1)])],
        ),
        ("list of a group", vec![list(Group(vec![n(U8)]))]),
        ("list of a u2 with two members", vec![list(U2(2))]),
        ("bool in a round", vec![Repeat(vec![Bool])]),
    ];
    for (label, nodes) in cases {
        let fields = nostd_fields(&nodes);
        let scheme = nostd::Scheme::new(1, &fields);
        // Act
        let checked = nostd::validate(&scheme).map_err(|f| f.error);
        // Assert
        assert!(std_refuses(&nodes), "{label}: std accepted it");
        assert_eq!(checked, Err(Error::SchemeInvalid), "{label}");
    }
}

#[test]
fn ac2_tables_only_the_core_can_write_are_refused() {
    use nostd::{group, list as list_of, repeat, u8, Field};
    let cases: Vec<(&str, Vec<Field>)> = vec![
        (
            "an empty group (a presence bit is a boolean)",
            vec![nostd::flags(0, 1), group(0, 0)],
        ),
        (
            "a list with two element entries",
            vec![list_of(0, 2), u8(0), u8(1)],
        ),
        ("a list with no element", vec![list_of(0, 0)]),
        ("a list element id not 0", vec![list_of(0, 1), u8(1)]),
        (
            "a repeat id not its first member",
            vec![u8(0), repeat(0, 1), u8(1)],
        ),
        ("a list id out of order", vec![u8(0), list_of(0, 1), u8(0)]),
    ];
    for (label, fields) in cases {
        // Act
        let checked = nostd::validate(&nostd::Scheme::new(1, &fields)).map_err(|f| f.error);
        // Assert
        assert_eq!(checked, Err(Error::SchemeInvalid), "{label}");
    }
}

/// The worked example: a meshbell-style route, a count and up to eight points, in plain arrays.
#[derive(Default, Clone, Copy, PartialEq, Debug)]
struct Point {
    lat: i32,
    lon: i32,
}

#[derive(Default, PartialEq, Debug)]
struct Route {
    id: u16,
    /// The count on the wire; pack checks it equals `len`.
    n: u8,
    points: [Point; 8],
    len: usize,
}

impl Row for Point {
    fn num(&self, id: u16) -> Option<Num> {
        match id {
            2 => Some(Num::I32(self.lat)),
            3 => Some(Num::I32(self.lon)),
            _ => None,
        }
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (2, Num::I32(v)) => self.lat = v,
            (3, Num::I32(v)) => self.lon = v,
            _ => return false,
        }
        true
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
}

impl Row for Route {
    fn num(&self, id: u16) -> Option<Num> {
        match id {
            0 => Some(Num::U16(self.id)),
            1 => Some(Num::U8(self.n)),
            _ => None,
        }
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U16(v)) => self.id = v,
            (1, Num::U8(v)) => self.n = v,
            _ => return false,
        }
        true
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn count(&self, id: u16) -> Option<usize> {
        (id == 2).then_some(self.len)
    }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
        let points = self.points.get(..self.len)?;
        (id == 2)
            .then(|| points.get(k).map(|p| p as &dyn Row))
            .flatten()
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        (id == 2)
            .then(|| self.points.get_mut(k).map(|p| p as &mut dyn Row))
            .flatten()
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        if id != 2 || n > self.points.len() {
            return false;
        }
        self.len = n;
        true
    }
}

/// u16 id; u8 n; times(n) { i32 lat; i32 lon }
static ROUTE_FIELDS: [nostd::Field; 5] = [
    nostd::u16(0),
    nostd::u8(1),
    nostd::times(2, 1, 2),
    nostd::i32(2),
    nostd::i32(3),
];
static ROUTE: nostd::Scheme = nostd::Scheme::new(0x52, &ROUTE_FIELDS);

#[test]
fn worked_example_a_route_of_points_round_trips_in_fixed_arrays() {
    // Arrange
    let mut route = Route {
        id: 7,
        n: 3,
        len: 3,
        ..Route::default()
    };
    for (k, p) in route.points.iter_mut().take(3).enumerate() {
        *p = Point {
            lat: 500_000_000 + k as i32,
            lon: -(k as i32),
        };
    }
    let mut out = [0u8; 64];
    let reference = build(0x52, &[n(U16), n(U8), Times(1, vec![n(I32), n(I32)])]);
    // Act
    let len = nostd::pack(&ROUTE, &route, &mut out).expect("pack");
    let mut back = Route::default();
    nostd::unpack(&ROUTE, &out[..len], &mut back).expect("unpack");
    let mut nine = Route::default();
    let over = [&[0x52u8, 7, 0, 9][..], &[0u8; 72]].concat();
    let refused = nostd::unpack(&ROUTE, &over, &mut nine);
    // Assert
    assert_eq!(len, 1 + 2 + 1 + 3 * 8);
    assert_eq!(back, route);
    assert_eq!(fault(refused), (Error::TooMany, 2, 9));
    assert!(packbin::unpack(&reference.reference, &out[..len]).is_ok());
}
