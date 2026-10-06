use crate::walk::unpack;
use crate::{
    bits, dict, eq, flag_byte, flags, group, i8, list, repeat, sized, times, u16, u32, u8, utf8,
    when, BoundField, MapScheme, Scheme, UnpackError, Value, DEFAULT_MAX_SLOTS,
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
        "invalid_utf8_dict_key" => MapScheme::new(1, vec![dict("0", u8("0"))]),
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
        "empty_group_outside_flags" => MapScheme::new(1, vec![u8("0"), group(1, "1", vec![])]),
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
        | "empty_group_outside_flags" => "scheme_error",
        "zero_progress_repeat_when" | "when_names_outer_field_in_repeat" => "scheme_error",
        "negative_count"
        | "oversize_count"
        | "oversize_count_times"
        | "oversize_list_count"
        | "invalid_utf8"
        | "invalid_utf8_dict_key"
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
        UnpackError::DuplicateType { .. } => "DuplicateType",
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

#[test]
fn hostile_vectors_error_without_panic_or_hang() {
    let text = fs::read_to_string(CASES).expect("fixtures/hostile/cases.txt");
    let mut seen = HashSet::new();
    let mut outcomes = Vec::new();
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
                let id_owned = id.to_string();
                let refusal = within_one_second(id, move || {
                    catch_unwind(AssertUnwindSafe(|| construct(&id_owned)))
                        .err()
                        .map(|panic| panic_text(panic.as_ref()))
                });
                let msg = refusal
                    .unwrap_or_else(|| panic!("{id}: scheme was built, expected scheme_error"));
                assert_refusal_names_the_rule(id, &msg);
                assert_eq!(rust_outcome(id), "scheme_error", "{id}");
                outcomes.push(format!("{id} -> scheme_error"));
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
            other => panic!("{id}: unknown stage {other}"),
        }
    }
    for line in &outcomes {
        println!("hostile {line}");
    }
    assert!(!outcomes.is_empty(), "no hostile cases ran");
}
