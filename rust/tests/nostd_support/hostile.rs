//! The hostile cases for the heap-free core: the case file, the outcome terms, and the scheme each
//! `unpack`, `construct` and `limit` case names (written by hand from `fixtures/hostile/README.md`,
//! as every package does). Needs `std` and `text`.
#![allow(dead_code)]

use super::tree::{nostd_fields, Node};
use packbin::nostd::{Error, Kind, Scheme};

pub const CASES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/hostile/cases.txt");
pub const CORPUS: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../fixtures/hostile/fuzz/corpus.txt"
);

#[derive(Clone, Debug)]
pub struct Case {
    pub id: String,
    pub stage: String,
    pub expected: String,
    pub hex: String,
}

pub fn cases() -> Vec<Case> {
    std::fs::read_to_string(CASES)
        .expect("cases.txt")
        .lines()
        .filter(|l| !l.trim().is_empty() && !l.starts_with('#'))
        .map(|l| {
            let f: Vec<&str> = l.split_whitespace().collect();
            Case {
                id: f[0].to_string(),
                stage: f[1].to_string(),
                expected: f[2].to_string(),
                hex: f[3].to_string(),
            }
        })
        .collect()
}

/// The outcome term of an error, as the case file spells it.
pub fn term(error: Error) -> &'static str {
    match error {
        Error::ShortPacket => "short_packet",
        Error::TrailingBytes => "trailing_bytes",
        Error::TypeMismatch => "type_mismatch",
        Error::BufferFull => "buffer_full",
        Error::TooMany => "too_many",
        Error::BadValue => "bad_value",
        Error::SchemeInvalid => "scheme_error",
        Error::ScratchTooSmall => "scratch_too_small",
        Error::Uncorrectable => "uncorrectable",
        Error::TooLong => "too_long",
        Error::TagMismatch => "tag_mismatch",
        Error::Duplicate => "duplicate",
        Error::TooOld => "too_old",
    }
}

pub fn allows(expected: &str, got: &str) -> bool {
    expected.split('|').any(|alt| alt == got)
}

fn n(kind: Kind) -> Node {
    Node::Num(kind)
}

fn bit(number: u16, inner: Node) -> Node {
    Node::FlagBit(number, Box::new(inner))
}

/// The nodes of a case that names a scheme, the same layout the C++ runner writes (order ids are
/// the C++ ones: a container shares the id of its first member). `None` for a pack case, which
/// `nostd_hostile_pack_tests` holds, and for a case that has no spelling in the core.
pub fn nodes_of(id: &str) -> Option<Vec<Node>> {
    use Kind::*;
    use Node::{Bits, Bool, Dict, Flags, Group, List, Repeat, Sized, Times, Utf8, When};
    let repeat_when = || vec![n(U8), Repeat(vec![When(0, 1, vec![n(U8)])])];
    Some(match id {
        "zero_progress_repeat_bool" => vec![Repeat(vec![Bool])],
        "zero_progress_repeat_when" | "when_names_outer_field_in_repeat" => repeat_when(),
        "negative_count" => vec![n(I8), Sized(0)],
        "oversize_count" => vec![n(U32), Sized(0)],
        "oversize_count_times" => vec![n(U32), Times(0, vec![n(U8)])],
        "oversize_list_count" => vec![List(Box::new(n(U8)))],
        "invalid_utf8" => vec![Utf8],
        "invalid_utf8_dict_key"
        | "dict_keys_out_of_order"
        | "dict_keys_repeated"
        | "dict_keys_repeated_forms"
        | "dict_keys_prefix_descends"
        | "dict_keys_utf16_order" => vec![Dict(Box::new(n(U8)))],
        "count_behind_clear_flag" => vec![Flags(vec![n(U8)]), Sized(0)],
        "count_behind_clear_flag_bits" => vec![Flags(vec![n(U8)]), Bits(0)],
        "nine_flag_bits" => vec![Flags((0..9).map(|_| n(U8)).collect())],
        "nine_flag_bits_split" => {
            let mut nodes = vec![Node::FlagByte(0)];
            nodes.extend((0..9).map(|_| bit(0, n(U8))));
            nodes
        }
        "when_names_later_field" => vec![n(U8), When(2, 1, vec![n(U8)]), n(U8)],
        "count_names_later_field" => vec![Sized(1), n(U16)],
        "bool_outside_flags" => vec![n(U8), Bool],
        "empty_group_outside_flags" => vec![n(U8), Group(vec![])],
        "eq_bool_false" => vec![Flags(vec![Bool]), When(0, 0, vec![n(U8)])],
        "eq_out_of_range" => vec![n(U8), When(0, 300, vec![n(U8)])],
        "construct_empty_times_body" => vec![n(U32), Times(0, vec![])],
        "construct_empty_repeat_body" => vec![Repeat(vec![])],
        "construct_empty_when_times_body" => {
            vec![n(U8), n(U8), Times(1, vec![When(0, 1, vec![])])]
        }
        "construct_empty_when_repeat_body" => vec![n(U8), Repeat(vec![When(0, 1, vec![])])],
        "construct_empty_nested_when_body" => vec![
            n(U8),
            n(U8),
            Times(1, vec![When(0, 1, vec![When(0, 1, vec![])])]),
        ],
        "repeat_rounds_over_limit" => vec![Repeat(vec![n(U8)])],
        "times_rounds_over_limit" => vec![n(U8), Times(0, vec![n(U8)])],
        _ => return None,
    })
}

/// A scheme of type number 1 from the nodes of a case, with the limits its stage names.
pub fn fields_of(id: &str) -> Option<Vec<packbin::nostd::Field>> {
    nodes_of(id).map(|nodes| nostd_fields(&nodes))
}

pub fn scheme_of<'a>(fields: &'a [packbin::nostd::Field], id: &str) -> Scheme<'a> {
    let scheme = Scheme::new(1, fields);
    if id.ends_with("_rounds_over_limit") {
        scheme.with_limits(3, packbin::nostd::DEFAULT_MAX_SLOTS)
    } else {
        scheme
    }
}

pub use super::from_hex;
