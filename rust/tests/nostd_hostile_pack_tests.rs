//! AZ-2757 AC-1, the `pack` stage: the pack cases of `fixtures/hostile/cases.txt` the C++ runner runs
//! are run on the core with the same rows and must refuse with the same error naming the same
//! field (or pack the exact bytes); the cases a row cannot spell are skipped with the C++ reasons.
//! The three `novalue` cases the C++ runner skips (open row U24) run on the core, which refuses them.
//! Needs `std` and `text`.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::hostile::cases;
use nostd_support::random::set_items;
use nostd_support::tree::{nostd_fields, Node};
use nostd_support::{from_hex, Slots};
use packbin::nostd::{pack, Error, Kind, Num, Row, Scheme};

use Kind::*;
use Node::{Bits, Bool, FlagByte, Flags, Group, Packed, Repeat, Sized, Times, When};

fn n(kind: Kind) -> Node {
    Node::Num(kind)
}

fn bit(number: u16, inner: Node) -> Node {
    Node::FlagBit(number, Box::new(inner))
}

/// A row of numbers by id.
fn row(nums: &[(u16, Num)]) -> Slots {
    Slots::with(nums, &[])
}

fn round(nums: &[(u16, Num)]) -> Slots {
    row(nums)
}

/// What a pack case answers: the packet as lowercase hex, or the refusal (error, field id).
#[derive(Debug, PartialEq)]
enum Answer {
    Bytes(String),
    Refused(Error, i32),
}

fn answer(nodes: &[Node], row: &Slots) -> Answer {
    let fields = nostd_fields(nodes);
    let scheme = Scheme::new(1, &fields);
    let mut out = [0u8; 32];
    match pack(&scheme, row, &mut out) {
        Ok(len) => Answer::Bytes(out[..len].iter().map(|b| format!("{b:02x}")).collect()),
        Err(fault) => Answer::Refused(fault.error, fault.field),
    }
}

fn refused(field: i32) -> Answer {
    Answer::Refused(Error::BadValue, field)
}

fn bytes(hex: &str) -> Answer {
    Answer::Bytes(hex.to_string())
}

fn u8n(v: u8) -> Num {
    Num::U8(v)
}

/// `times(count = id 0)` with `listed` rounds, each `x = i + 1` at id 1.
fn counted(count: u8, listed: u8) -> Answer {
    let nodes = [n(U8), Times(0, vec![n(U8)])];
    let mut r = row(&[(0, u8n(count))]);
    set_items(
        &mut r,
        1,
        (1..=listed).map(|i| round(&[(1, u8n(i))])).collect(),
    );
    answer(&nodes, &r)
}

fn pt_rounds(values: &[u8]) -> Vec<Slots> {
    values.iter().map(|v| round(&[(2, u8n(*v))])).collect()
}

fn run(id: &str) -> Option<Answer> {
    Some(match id {
        "pack_missing_required_value" => answer(&[n(U8), n(U8)], &row(&[(0, u8n(1))])),
        "pack_times_list_too_long" => counted(2, 3),
        "pack_times_list_too_short" => counted(2, 1),
        "pack_times_zero_with_values" => counted(0, 1),
        "pack_aligned_round_row" => {
            let nodes = [Repeat(vec![Flags(vec![Bool, n(U8)])])];
            let mut r = Slots::default();
            let rounds = [(true, 1u8), (false, 2), (true, 3)]
                .iter()
                .map(|(on, v)| {
                    let mut item = round(&[(1, u8n(*v))]);
                    item.set_flag(0, *on);
                    item
                })
                .collect();
            set_items(&mut r, 0, rounds);
            answer(&nodes, &r)
        }
        "pack_split_when_source_after_byte" => {
            let nodes = [
                FlagByte(0),
                n(U8),
                bit(0, When(0, 1, vec![n(U8)])),
                bit(0, n(U16)),
            ];
            answer(&nodes, &row(&[(0, u8n(1)), (1, u8n(7))]))
        }
        "pack_split_times_count_after_byte" => {
            let nodes = [
                FlagByte(0),
                n(U8),
                bit(0, Times(0, vec![n(U8)])),
                bit(0, n(U16)),
            ];
            let mut r = row(&[(0, u8n(2))]);
            set_items(
                &mut r,
                1,
                vec![round(&[(1, u8n(5))]), round(&[(1, u8n(6))])],
            );
            answer(&nodes, &r)
        }
        "pack_split_times_count_skipped" => {
            let nodes = [
                n(U8),
                FlagByte(0),
                When(0, 1, vec![n(U8)]),
                bit(0, Times(1, vec![n(U8)])),
                bit(0, n(U16)),
            ];
            let mut r = row(&[(0, u8n(0))]);
            set_items(&mut r, 2, pt_rounds(&[5]));
            answer(&nodes, &r)
        }
        "pack_split_false_condition_silent" => {
            let nodes = [
                n(U8),
                FlagByte(0),
                bit(0, When(0, 1, vec![n(U8)])),
                bit(0, n(U16)),
            ];
            answer(&nodes, &row(&[(0, u8n(0)), (1, u8n(7)), (2, Num::U16(90))]))
        }
        "pack_split_count_zero_after_byte_list" => {
            let nodes = [
                FlagByte(0),
                n(U8),
                bit(0, Group(vec![n(U8), Times(0, vec![n(U8)])])),
            ];
            let mut r = row(&[(0, u8n(0)), (1, u8n(1))]);
            set_items(&mut r, 2, pt_rounds(&[5, 6]));
            answer(&nodes, &r)
        }
        "pack_flags_skipped_count_with_values" => {
            let nodes = [Flags(vec![n(U8), Times(0, vec![n(U8)])])];
            let mut r = Slots::default();
            set_items(
                &mut r,
                1,
                vec![round(&[(1, u8n(5))]), round(&[(1, u8n(6))])],
            );
            answer(&nodes, &r)
        }
        "pack_flags_short_list_filled" => {
            let nodes = [Repeat(vec![n(U8), Flags(vec![n(U8)])])];
            let mut r = Slots::default();
            set_items(
                &mut r,
                0,
                vec![round(&[(0, u8n(1)), (1, u8n(5))]), round(&[(0, u8n(2))])],
            );
            answer(&nodes, &r)
        }
        "pack_late_when_in_bit_body" => {
            let nodes = [
                FlagByte(0),
                n(U8),
                bit(
                    0,
                    Group(vec![
                        n(U8),
                        When(0, 1, vec![n(U8)]),
                        When(0, 2, vec![n(U8)]),
                    ]),
                ),
            ];
            answer(&nodes, &row(&[(0, u8n(1)), (1, u8n(5)), (2, u8n(9))]))
        }
        "pack_count_one_clear_when" => {
            let nodes = [
                n(U8),
                When(0, 1, vec![n(U8)]),
                FlagByte(0),
                bit(0, Times(1, vec![n(U8)])),
                bit(0, n(U16)),
            ];
            answer(&nodes, &row(&[(0, u8n(0)), (1, u8n(1)), (3, Num::U16(90))]))
        }
        "pack_when_of_skipped_source" => when_of_skipped_source(2),
        "pack_when_of_skipped_source_zero" => when_of_skipped_source(0),
        "pack_when_of_skipped_bool_source" => when_of_bool_source(0, true),
        "pack_when_of_held_bool_source" => when_of_bool_source(1, true),
        "pack_when_of_held_bool_source_clear" => when_of_bool_source(1, false),
        "pack_bits_count_clear_when" => counted_values(Bits(1), &[1, 0, 1]),
        "pack_packed_count_clear_when" => counted_values(Packed(1, 1, 0), &[1, 0, 1]),
        "pack_sized_count_clear_when" => counted_values(Sized(1), &[1, 2, 3]),
        // Beyond the C++ runner (open row U24 there): the core refuses these, as std does.
        "pack_novalue_count_clear_when_bits" => novalue(Bits(1)),
        "pack_novalue_count_clear_when_packed" => novalue(Packed(1, 1, 0)),
        "pack_novalue_count_clear_when_sized" => novalue(Sized(1)),
        _ => return None,
    })
}

/// `u8 mode; when mode = 1 { u16 a; u8 k }; when k = <k> { u8 b }` with mode 0: `k` sits in a clear
/// `when`, so it is absent and the second `when` is false although the row holds a matching `k`.
fn when_of_skipped_source(k: u8) -> Answer {
    let nodes = [
        n(U8),
        When(0, 1, vec![n(U16), n(U8)]),
        When(2, i64::from(k), vec![n(U8)]),
    ];
    let r = row(&[(0, u8n(0)), (1, Num::U16(7)), (2, u8n(k)), (3, u8n(5))]);
    answer(&nodes, &r)
}

/// `u8 mode; when mode = 1 { flags { bool on }; u8 a }; when on = true { u8 b }` with a 7 and b 5:
/// a `bool` in a clear `when` is absent, so the second `when` is false whatever the row holds.
fn when_of_bool_source(mode: u8, on: bool) -> Answer {
    let nodes = [
        n(U8),
        When(0, 1, vec![Flags(vec![Bool]), n(U8)]),
        When(1, 1, vec![n(U8)]),
    ];
    let mut r = row(&[(0, u8n(mode)), (2, u8n(7)), (3, u8n(5))]);
    r.set_flag(1, on);
    answer(&nodes, &r)
}

/// `u8 mode; when mode = 1 { u8 c }; <counted by c>` with mode 0 and c 3: the count is not
/// written, so the values have no count on the wire.
fn counted_values(member: Node, values: &[u8]) -> Answer {
    let nodes = [n(U8), When(0, 1, vec![n(U8)]), member];
    let r = Slots::with(&[(0, u8n(0)), (1, u8n(3))], &[(2, values)]);
    answer(&nodes, &r)
}

/// `u8 mode; when mode = 1 { u8 c }; flag byte; bit 0 { <counted by c> }` with mode 0, c 3 and no
/// value: `c` is never written, so the member has no count on the wire and the clear bit would hide it.
fn novalue(member: Node) -> Answer {
    let nodes = [n(U8), When(0, 1, vec![n(U8)]), FlagByte(0), bit(0, member)];
    answer(&nodes, &row(&[(0, u8n(0)), (1, u8n(3))]))
}

/// The answer each case of the C++ table must give: the packet, or `BadValue` naming this id.
fn expected(id: &str) -> Answer {
    match id {
        "pack_aligned_round_row" => bytes("01030102020303"),
        "pack_split_false_condition_silent" => bytes("0100025a00"),
        "pack_flags_short_list_filled" => bytes("010101050200"),
        "pack_late_when_in_bit_body" => bytes("0101010509"),
        "pack_when_of_skipped_source"
        | "pack_when_of_skipped_source_zero"
        | "pack_when_of_skipped_bool_source" => bytes("0100"),
        "pack_when_of_held_bool_source" => bytes("0101010705"),
        "pack_when_of_held_bool_source_clear" => bytes("01010007"),
        "pack_missing_required_value"
        | "pack_times_list_too_long"
        | "pack_times_list_too_short"
        | "pack_times_zero_with_values"
        | "pack_split_when_source_after_byte"
        | "pack_split_times_count_after_byte"
        | "pack_flags_skipped_count_with_values" => refused(1),
        "pack_split_times_count_skipped"
        | "pack_split_count_zero_after_byte_list"
        | "pack_count_one_clear_when"
        | "pack_bits_count_clear_when"
        | "pack_packed_count_clear_when"
        | "pack_sized_count_clear_when"
        | "pack_novalue_count_clear_when_bits"
        | "pack_novalue_count_clear_when_packed"
        | "pack_novalue_count_clear_when_sized" => refused(2),
        other => panic!("no expected answer for {other}"),
    }
}

/// The pack cases the C++ runner skips, with its reasons.
const SKIPS: [(&str, &str); 18] = [
    ("pack_out_of_range_integer", "a row holds a typed Num, so 300 cannot be written for a u8 (a Num::U16 is another kind: BadValue, covered by nostd_flat_tests)"),
    ("pack_times_count_over_limit", "the rounds are caller items and the count is checked against their number: a count of 65,536 is refused as a count that differs from the items, which pack_times_list_too_long already covers"),
    ("pack_lone_bytes_in_round", "a row holds items per round, so a lone buffer cannot be broadcast"),
    ("pack_lone_utf8_under_times_over_budget", "pack writes into a caller buffer: there is no output budget to pass"),
    ("pack_element_times_over_budget", "pack writes into a caller buffer: there is no output budget to pass"),
    ("pack_slots_over_limit", "the rounds are caller items and the slot budget is a scheme limit (round_limits tests cover it)"),
    ("pack_repeat_over_limit", "the rounds are caller items (round_limits tests cover the 65,535 limit)"),
    ("pack_split_count_zero_after_byte_scalar", "a row holds items, so a lone scalar cannot be written"),
    ("pack_repeat_unequal_lists_lone", "a row holds items per round, so a lone value for one round member cannot be written"),
    ("pack_repeat_unequal_lists_when", "a row holds items per round, so a shorter list for one round member cannot be written"),
    ("pack_times_short_list_flags", "a row holds one item per round, so a list shorter than the count cannot be written"),
    ("pack_element_times_over_bytes_budget", "a caller buffer: there is no output budget to pass"),
    ("pack_round_slots_at_limit", "the rounds are caller items and pack has no per-call slot counter to set apart from the scheme limits"),
    ("pack_round_slots_over_limit", "as pack_round_slots_at_limit"),
    ("pack_round_slots_flags_at_limit", "as pack_round_slots_at_limit"),
    ("pack_round_slots_flags_over_limit", "as pack_round_slots_at_limit"),
    ("pack_split_times_absent_body", "AZ-2384 excludes the C++ port: a count above 0 with no items is a count mismatch (late rule)"),
    ("pack_flags_short_list", "a row holds one item per round: a short list cannot be written"),
];

#[test]
fn ac1_every_pack_case_runs_or_is_skipped_with_a_reason_exactly_once() {
    // Arrange
    let all = cases();
    // Act
    let packs: Vec<&str> = all
        .iter()
        .filter(|c| c.stage == "pack")
        .map(|c| c.id.as_str())
        .collect();
    let unused_skips: Vec<&str> = SKIPS
        .iter()
        .map(|(id, _)| *id)
        .filter(|id| !packs.contains(id))
        .collect();
    // Assert
    assert!(!packs.is_empty(), "cases.txt holds no pack case");
    assert!(
        unused_skips.is_empty(),
        "skips for ids that are not pack cases of cases.txt: {unused_skips:?}"
    );
    for id in &packs {
        let ran = run(id).is_some();
        let skipped = SKIPS
            .iter()
            .filter(|(s, reason)| s == id && !reason.is_empty())
            .count();
        assert_eq!(
            usize::from(ran) + skipped,
            1,
            "{id} must run or be skipped, once"
        );
    }
}

#[test]
fn ac1_each_pack_case_that_runs_gives_the_answer_of_the_c_plus_plus_table() {
    for c in cases().iter().filter(|c| c.stage == "pack") {
        let Some(got) = run(&c.id) else { continue };
        // Arrange
        let want = expected(&c.id);
        // Assert
        assert_eq!(got, want, "{}", c.id);
        // the file's own column agrees: `bytes` with the hex, or `pack_error`
        match &want {
            Answer::Bytes(hex) => {
                assert_eq!(c.expected, "bytes", "{}", c.id);
                assert_eq!(&c.hex, hex, "{}", c.id);
            }
            Answer::Refused(..) => assert_eq!(c.expected, "pack_error", "{}", c.id),
        }
    }
}

#[test]
fn ac1_a_packet_a_pack_case_returns_unpacks_again() {
    // Arrange
    let fields = nostd_fields(&[Repeat(vec![Flags(vec![Bool, n(U8)])])]);
    let scheme = Scheme::new(1, &fields);
    let bytes = from_hex("01030102020303");
    let mut back = Slots {
        cap: Some(16),
        ..Slots::default()
    };
    // Act
    let used = packbin::nostd::unpack(&scheme, &bytes, &mut back);
    // Assert
    assert_eq!(used, Ok(7));
    assert_eq!(back.count(0), Some(3));
}
