mod pack_cases;
mod refusals;

use crate::walk::unpack;
use crate::{
    bits, dict, eq, flag_byte, flags, group, i8, list, repeat, sized, times, to_hex, u16, u32, u8,
    utf8, when, BoundField, MapScheme, Scheme, UnpackError, Value, DEFAULT_MAX_SLOTS,
};
use pack_cases::{pack_case, PACK_NOT_RUN};
use refusals::{
    assert_construct_rule, assert_pack_rule, assert_tables_cover, RuleTable, CONSTRUCT_REFUSAL,
    PACK_REFUSAL,
};
use std::collections::HashSet;
use std::fs;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

const CASES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/hostile/cases.txt");

/// Runs `job` on its own thread and fails the test when it does not finish in one second.
pub(crate) fn within_one_second<R: Send + 'static>(
    what: &str,
    job: impl FnOnce() -> R + Send + 'static,
) -> R {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        // The receiver is gone once the 1 s timeout has fired; nobody is left to tell.
        let _ = tx.send(catch_unwind(AssertUnwindSafe(job)));
    });
    match rx.recv_timeout(Duration::from_secs(1)) {
        Ok(Ok(result)) => result,
        Ok(Err(panic)) => std::panic::resume_unwind(panic),
        Err(_) => panic!("{what}: no result within 1 s (unpack hangs)"),
    }
}

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn zero_progress_when() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![u8("1")])]),
        ],
    )
}

/// The scheme each case names, written by hand from fixtures/hostile/README.md.
fn scheme_for(id: &str) -> MapScheme {
    match id {
        "zero_progress_repeat_bool" => {
            MapScheme::new(1, vec![repeat(0, vec![group(0, "0", vec![])])])
        }
        "zero_progress_repeat_when" | "when_names_outer_field_in_repeat" => zero_progress_when(),
        "negative_count" => MapScheme::new(1, vec![i8("0"), sized("1", "0")]),
        "oversize_count" => MapScheme::new(1, vec![u32("0"), sized("1", "0")]),
        "oversize_count_times" => MapScheme::new(1, vec![u32("0"), times(1, "0", vec![u8("1")])]),
        "oversize_list_count" => MapScheme::new(1, vec![list("0", u8("0"))]),
        "invalid_utf8" => MapScheme::new(1, vec![utf8("0")]),
        "invalid_utf8_dict_key"
        | "dict_keys_out_of_order"
        | "dict_keys_repeated"
        | "dict_keys_repeated_forms"
        | "dict_keys_prefix_descends"
        | "dict_keys_utf16_order" => MapScheme::new(1, vec![dict("0", u8("0"))]),
        "count_behind_clear_flag" => {
            MapScheme::new(1, vec![flags(0, "f", vec![u8("0")]), sized("1", "0")])
        }
        "count_behind_clear_flag_bits" => {
            MapScheme::new(1, vec![flags(0, "f", vec![u8("0")]), bits("1", "0")])
        }
        "when_names_later_field" => MapScheme::new(
            1,
            vec![
                u8("0"),
                when(1, eq("2", Value::U8(1)), vec![u8("1")]),
                u8("2"),
            ],
        ),
        "count_names_later_field" => MapScheme::new(1, vec![sized("0", "1"), u16("1")]),
        "nine_flag_bits" => MapScheme::new(
            1,
            vec![flags(0, "f", (0..9).map(|i| u8(i.to_string())).collect())],
        ),
        "nine_flag_bits_split" => {
            let byte = flag_byte("0");
            let mut fields = vec![byte.byte()];
            fields.extend((1..10).map(|i| byte.bit(u8(i.to_string()))));
            MapScheme::new(1, fields)
        }
        "construct_empty_times_body" => MapScheme::new(1, vec![u8("0"), times(1, "0", vec![])]),
        "construct_empty_when_times_body" => MapScheme::new(
            1,
            vec![
                u8("0"),
                u8("1"),
                times(2, "1", vec![when(2, eq("0", Value::U8(1)), vec![])]),
            ],
        ),
        "construct_empty_when_repeat_body" => MapScheme::new(
            1,
            vec![
                u8("0"),
                repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![])]),
            ],
        ),
        "construct_empty_nested_when_body" => MapScheme::new(
            1,
            vec![
                u8("0"),
                u8("1"),
                times(
                    2,
                    "1",
                    vec![when(
                        2,
                        eq("0", Value::U8(1)),
                        vec![when(2, eq("0", Value::U8(1)), vec![])],
                    )],
                ),
            ],
        ),
        "construct_empty_repeat_body" => MapScheme::new(1, vec![repeat(0, vec![])]),
        "empty_group_outside_flags" => MapScheme::new(1, vec![u8("0"), group(1, "1", vec![])]),
        "eq_bool_false" => MapScheme::new(
            1,
            vec![
                flags(0, "f", vec![group(0, "0", vec![])]),
                when(1, eq("0", Value::U8(0)), vec![u8("1")]),
            ],
        ),
        "eq_out_of_range" => MapScheme::new(
            1,
            vec![u8("a"), when(1, eq("a", Value::U16(300)), vec![u8("v")])],
        ),
        other => panic!("no scheme written for hostile case {other}"),
    }
}

/// Rounds the scheme of a `limit` case allows; max_slots stays at its default.
const LOW_ROUNDS: usize = 3;

/// The scheme a `limit` case names: written by hand from fixtures/hostile/README.md.
fn limit_scheme_for(id: &str) -> MapScheme {
    match id {
        "repeat_rounds_over_limit" => MapScheme::new(1, vec![repeat(0, vec![u8("0")])])
            .with_limits(LOW_ROUNDS, DEFAULT_MAX_SLOTS),
        "times_rounds_over_limit" => MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])
            .with_limits(LOW_ROUNDS, DEFAULT_MAX_SLOTS),
        other => panic!("no scheme written for hostile limit case {other}"),
    }
}

/// Construct cases a Rust scheme cannot spell, with the reason (the README "Expected" line of each).
const CONSTRUCT_NOT_RUN: &[(&str, &str)] = &[(
    "construct_empty_round_body_list_element",
    "a list element cannot hold a `times`; construct_empty_times_body covers the same refusal",
)];

#[derive(Default)]
struct BoolRow {
    a: u8,
    on: Option<bool>,
}

/// Builds the scheme of a `construct` case. The Rust `bool` is the typed `bool_flag`.
fn construct(id: &str) {
    if id == "bool_outside_flags" {
        let _ = Scheme::<BoolRow>::new(
            1,
            [
                BoundField::u8(0, |r: &BoolRow| r.a, |r: &mut BoolRow, v| r.a = v).into(),
                BoundField::bool_flag(1, |r: &BoolRow| r.on, |r: &mut BoolRow, v| r.on = v).into(),
            ],
        );
    } else {
        let _ = scheme_for(id);
    }
}

/// A refusal must come from a scheme rule, not from a malformed hand-written scheme.
fn assert_refusal_names_the_rule(id: &str, msg: &str) {
    let rules = [
        "same scope",
        "next order",
        "not yet walked",
        "more than 8",
        "allowed only directly inside flags",
        "value other than true",
        "which is outside",
        "the body holds no member",
    ];
    assert!(
        rules.iter().any(|rule| msg.contains(rule)),
        "{id}: construction panic does not name the scope/order rule: {msg:?}"
    );
}

fn panic_text(panic: &(dyn std::any::Any + Send)) -> String {
    if let Some(s) = panic.downcast_ref::<String>() {
        s.clone()
    } else if let Some(s) = panic.downcast_ref::<&str>() {
        (*s).to_string()
    } else {
        String::new()
    }
}

/// What Rust returns for each case today; the labels are undecided until C15.
fn rust_outcome(id: &str) -> &'static str {
    match id {
        "zero_progress_repeat_bool"
        | "nine_flag_bits"
        | "nine_flag_bits_split"
        | "bool_outside_flags"
        | "empty_group_outside_flags"
        | "eq_bool_false"
        | "eq_out_of_range"
        | "construct_empty_times_body"
        | "construct_empty_repeat_body"
        | "construct_empty_when_times_body"
        | "construct_empty_when_repeat_body"
        | "construct_empty_nested_when_body" => "scheme_error",
        "zero_progress_repeat_when" | "when_names_outer_field_in_repeat" => "scheme_error",
        "negative_count"
        | "oversize_count"
        | "oversize_count_times"
        | "oversize_list_count"
        | "invalid_utf8"
        | "invalid_utf8_dict_key"
        | "dict_keys_out_of_order"
        | "dict_keys_repeated"
        | "dict_keys_repeated_forms"
        | "dict_keys_prefix_descends"
        | "dict_keys_utf16_order"
        | "count_behind_clear_flag"
        | "count_behind_clear_flag_bits" => "Short",
        "when_names_later_field" | "count_names_later_field" => "scheme_error",
        other => panic!("no Rust outcome recorded for hostile case {other}"),
    }
}

fn variant(err: &UnpackError) -> &'static str {
    match err {
        UnpackError::Short(_) => "Short",
        UnpackError::Trailing { .. } => "Trailing",
        UnpackError::Type { .. } => "Type",
        UnpackError::NoHandlers => "NoHandlers",
        UnpackError::DuplicateType { .. } => "DuplicateType",
        UnpackError::Uncorrectable => "Uncorrectable",
        UnpackError::TooLong { .. } => "TooLong",
        UnpackError::BadLimit { .. } => "BadLimit",
        UnpackError::BadParity { .. } => "BadParity",
        UnpackError::MixedParity { .. } => "MixedParity",
    }
}

/// Builds the case scheme and unpacks `hex`. `Err(text)` is a construction failure.
fn run_unpack(id: &str, hex: &str) -> Result<Result<(), UnpackError>, String> {
    run_with(id, hex, scheme_for)
}

fn run_with(
    id: &str,
    hex: &str,
    build: fn(&str) -> MapScheme,
) -> Result<Result<(), UnpackError>, String> {
    let id = id.to_string();
    let bytes = parse_hex(hex);
    within_one_second(&id.clone(), move || {
        let scheme = match catch_unwind(AssertUnwindSafe(|| build(&id))) {
            Ok(scheme) => scheme,
            Err(panic) => return Err(panic_text(panic.as_ref())),
        };
        // A hostile packet must come back as an error value; a panic out of unpack fails the case.
        Ok(unpack(&scheme, &bytes).map(|_| ()))
    })
}

/// The README expectation of `pack_late_when_in_bit_body` (AZ-2385): another member (`d`) sets the
/// bit, so the late `when` body is written.
#[test]
fn late_when_in_bit_body_packs_the_readme_bytes() {
    let packed = pack_case("pack_late_when_in_bit_body").map(|raw| to_hex(&raw));
    assert_eq!(packed, Ok("0101010509".to_string()));
}

#[test]
fn hostile_vectors_error_without_panic_or_hang() {
    run_all_cases(CONSTRUCT_REFUSAL, PACK_REFUSAL);
}

/// AZ-2418 AC-1: the loader fails, naming the case, when a rule entry is wrong. The wrong entry is
/// built here; the real tables are not touched.
fn wrong_entry(table: RuleTable, id: &str) -> Vec<(&'static str, &'static str)> {
    let mut entries = table.to_vec();
    let entry = entries
        .iter_mut()
        .find(|(case, _)| *case == id)
        .unwrap_or_else(|| panic!("{id}: no rule entry to make wrong"));
    entry.1 = "a rule this refusal never names";
    entries
}

fn loader_failure(construct_rules: RuleTable, pack_rules: RuleTable) -> String {
    let panic = catch_unwind(|| run_all_cases(construct_rules, pack_rules))
        .expect_err("the loader accepted a wrong rule table");
    panic_text(panic.as_ref())
}

#[test]
fn a_wrong_pack_rule_entry_fails_the_loader_naming_the_case() {
    // Arrange: one pack entry that names the wrong rule
    let rules = wrong_entry(PACK_REFUSAL, "pack_times_list_too_long").leak();

    // Act
    let failure = loader_failure(CONSTRUCT_REFUSAL, rules);

    // Assert
    assert!(
        failure.contains("pack_times_list_too_long: refused by another rule"),
        "{failure}"
    );
}

#[test]
fn a_wrong_construct_rule_entry_fails_the_loader_naming_the_case() {
    // Arrange: one construct entry that names the wrong rule
    let rules = wrong_entry(CONSTRUCT_REFUSAL, "nine_flag_bits").leak();

    // Act
    let failure = loader_failure(rules, PACK_REFUSAL);

    // Assert
    assert!(
        failure.contains("nine_flag_bits: refused by another rule"),
        "{failure}"
    );
}

#[test]
fn a_rule_entry_for_a_case_that_is_not_refused_fails_the_loader() {
    // Arrange: an entry for a pack case that packs bytes
    let mut entries = PACK_REFUSAL.to_vec();
    entries.push(("pack_late_when_in_bit_body", "a refusal it never gives"));
    let rules: RuleTable = entries.leak();

    // Act
    let failure = loader_failure(CONSTRUCT_REFUSAL, rules);

    // Assert
    assert!(
        failure.contains("pack rule for pack_late_when_in_bit_body"),
        "{failure}"
    );
}

#[test]
fn a_refused_case_without_a_rule_entry_fails_the_loader() {
    // Arrange: the table without the entry of one refused case
    let rules: RuleTable = PACK_REFUSAL
        .iter()
        .copied()
        .filter(|(case, _)| *case != "pack_repeat_over_limit")
        .collect::<Vec<_>>()
        .leak();

    // Act
    let failure = loader_failure(CONSTRUCT_REFUSAL, rules);

    // Assert
    assert!(
        failure.contains("pack_repeat_over_limit: no refusal rule recorded"),
        "{failure}"
    );
}

fn run_all_cases(construct_rules: RuleTable, pack_rules: RuleTable) {
    let text = fs::read_to_string(CASES).expect("fixtures/hostile/cases.txt");
    let mut seen = HashSet::new();
    let mut outcomes = Vec::new();
    let (mut construct_refused, mut pack_refused) = (Vec::new(), Vec::new());
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let cols: Vec<&str> = line.split_whitespace().collect();
        assert_eq!(cols.len(), 4, "bad case line: {line}");
        let (id, stage, expected, hex) = (cols[0], cols[1], cols[2], cols[3]);
        assert!(seen.insert(id.to_string()), "duplicate case {id}");
        let allows_scheme_error = expected.split('|').any(|t| t == "scheme_error");
        match stage {
            "construct" => {
                if let Some((_, reason)) =
                    CONSTRUCT_NOT_RUN.iter().find(|(skipped, _)| *skipped == id)
                {
                    outcomes.push(format!("{id} -> skipped: {reason}"));
                    continue;
                }
                let id_owned = id.to_string();
                let refusal = within_one_second(id, move || {
                    catch_unwind(AssertUnwindSafe(|| construct(&id_owned)))
                        .err()
                        .map(|panic| panic_text(panic.as_ref()))
                });
                let msg = refusal
                    .unwrap_or_else(|| panic!("{id}: scheme was built, expected scheme_error"));
                assert_construct_rule(construct_rules, id, &msg);
                assert_eq!(rust_outcome(id), "scheme_error", "{id}");
                construct_refused.push(id.to_string());
                outcomes.push(format!("{id} -> scheme_error ({msg})"));
            }
            "unpack" => match run_unpack(id, hex) {
                Err(msg) => {
                    assert_refusal_names_the_rule(id, &msg);
                    assert!(
                        allows_scheme_error,
                        "{id}: construction failed ({msg}) but {expected} was expected"
                    );
                    assert_eq!(rust_outcome(id), "scheme_error", "{id}");
                    outcomes.push(format!("{id} -> scheme_error ({msg})"));
                }
                Ok(Ok(())) => panic!("{id}: unpack returned a value, expected {expected}"),
                Ok(Err(err)) => {
                    assert_eq!(rust_outcome(id), variant(&err), "{id}: {err:?}");
                    outcomes.push(format!("{id} -> {} {err:?}", variant(&err)));
                }
            },
            // The round that would start is refused: no bytes needed, the one byte of that round left.
            "limit" => match run_with(id, hex, limit_scheme_for) {
                Err(msg) => panic!("{id}: the limit scheme was refused at construction: {msg}"),
                Ok(Ok(())) => panic!("{id}: unpack returned a value, expected {expected}"),
                Ok(Err(UnpackError::Short(short))) => {
                    assert_eq!((short.needed, short.left), (0, 1), "{id}: {short:?}");
                    outcomes.push(format!("{id} -> Short {short:?}"));
                }
                Ok(Err(err)) => panic!("{id}: expected the interim bad-value error, got {err:?}"),
            },
            "pack" => {
                if let Some((_, reason)) = PACK_NOT_RUN.iter().find(|(skipped, _)| *skipped == id) {
                    outcomes.push(format!("{id} -> skipped: {reason}"));
                    continue;
                }
                let bytes = pack_case(id).map(|raw| to_hex(&raw));
                match (expected, hex) {
                    ("bytes", _) => assert_eq!(bytes, Ok(hex.to_string()), "{id}"),
                    ("pack_error", "-") => {
                        let err = bytes
                            .as_ref()
                            .expect_err(&format!("{id}: packed {bytes:?}, expected pack_error"));
                        assert_pack_rule(pack_rules, id, err);
                        pack_refused.push(id.to_string());
                    }
                    other => panic!("{id}: malformed pack line {other:?}"),
                }
                outcomes.push(format!("{id} -> {expected} {bytes:?}"));
            }
            other => panic!("{id}: unknown stage {other}"),
        }
    }
    assert_tables_cover(
        construct_rules,
        &construct_refused,
        pack_rules,
        &pack_refused,
    );
    for line in &outcomes {
        println!("hostile {line}");
    }
    assert!(!outcomes.is_empty(), "no hostile cases ran");
}
