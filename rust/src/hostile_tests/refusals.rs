//! The rule each refused hostile case must name (AZ-2392), so a refusal by some other rule fails
//! the test, as TypeScript's `PACK_REFUSAL` does. An entry is a fragment of the refusal text; a
//! fragment that starts with `=` must equal the whole text (Rust's own short messages).

use crate::PackError;

/// What a `construct` case's build panic must contain: the rule that refuses the scheme.
pub(super) const CONSTRUCT_REFUSAL: RuleTable = &[
    ("nine_flag_bits", "flags at id 0 has more than 8 members"),
    ("nine_flag_bits_split", "has more than 8 bits"),
    ("when_names_later_field", "is not yet walked"),
    ("count_names_later_field", "is not yet walked"),
    (
        "when_names_outer_field_in_repeat",
        "is not in the same scope",
    ),
    (
        "bool_outside_flags",
        "a bool or empty group is allowed only directly inside flags or under a flag bit",
    ),
    (
        "empty_group_outside_flags",
        "a bool or empty group is allowed only directly inside flags or under a flag bit",
    ),
    (
        "eq_bool_false",
        "compares bool \"0\" with a value other than true (1)",
    ),
    (
        "eq_out_of_range",
        "which is outside the 0 to 255 that field holds",
    ),
    (
        "construct_empty_times_body",
        "times 1: the body holds no member",
    ),
    (
        "construct_empty_repeat_body",
        "repeat 0: the body holds no member",
    ),
    // The README schemes name a source outside the round, which Rust's scope rule refuses before
    // the empty-body rule is reached; rust/tests/empty_round_body_tests.rs pins that rule for
    // `when` bodies (rows 17 and 18).
    (
        "construct_empty_when_times_body",
        "field id 0 is not in the same scope (the container starts at id 2)",
    ),
    (
        "construct_empty_when_repeat_body",
        "field id 0 is not in the same scope (the container starts at id 1)",
    ),
    (
        "construct_empty_nested_when_body",
        "field id 0 is not in the same scope (the container starts at id 2)",
    ),
];

/// A refusal table: the case id and a fragment of the refusal text it must carry.
pub(super) type RuleTable = &'static [(&'static str, &'static str)];

/// What a `pack_error` case's refusal must contain: the rule that refuses the row.
pub(super) const PACK_REFUSAL: RuleTable = &[
    ("pack_out_of_range_integer", "=int"),
    ("pack_missing_required_value", "=missing value: b"),
    (
        "pack_times_list_too_long",
        "times at id 1: 'x' has 3 items, count is 2",
    ),
    ("pack_times_list_too_short", "=missing value: x"),
    (
        "pack_times_count_over_limit",
        "count 65536 (from 'n') is over the 65535 rounds a scheme allows",
    ),
    (
        "pack_times_zero_with_values",
        "times at id 1: 'x' has 1 items, count is 0",
    ),
    (
        "pack_split_when_source_after_byte",
        "'speed' is given, but its when on 'mode' holds, or is written after the flag byte",
    ),
    (
        "pack_split_times_count_after_byte",
        "'pt' is given, but its times count 'n' is not written where the flag byte is written",
    ),
    (
        "pack_split_times_count_skipped",
        "'pt' is given, but its times count 'n' is not written where the flag byte is written",
    ),
    (
        "pack_lone_bytes_in_round",
        "times at id 1: 'd' is one byte buffer",
    ),
    (
        "pack_lone_utf8_under_times_over_budget",
        "s: the packet would be 16779269 bytes, above the limit of 16777216 bytes",
    ),
    (
        "pack_slots_over_limit",
        "m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots",
    ),
    (
        "pack_repeat_over_limit",
        "k: the repeat count is 65536, above the limit of 65535 rounds",
    ),
    (
        "pack_split_count_zero_after_byte_list",
        "times at id 2: 'pt' has 2 items, count is 0",
    ),
    (
        "pack_flags_skipped_count_with_values",
        "pt: a value is given, but the count of its times is not written, so its bit is clear",
    ),
    (
        "pack_round_slots_over_limit",
        "b: the rounds would hold 4 slots, above the limit of 3 slots",
    ),
    (
        "pack_round_slots_flags_over_limit",
        "on: the rounds would hold 6 slots, above the limit of 4 slots",
    ),
    (
        "pack_count_one_clear_when",
        "pt: the count c is 1 in the row, but no field wrote it",
    ),
    ("pack_bits_count_clear_when", "=missing value: c"),
    ("pack_packed_count_clear_when", "=missing value: c"),
    ("pack_sized_count_clear_when", "=missing value: c"),
    (
        "pack_novalue_count_clear_when_bits",
        "v: the count c is 3 in the row, but no field wrote it",
    ),
    (
        "pack_novalue_count_clear_when_packed",
        "v: the count c is 3 in the row, but no field wrote it",
    ),
    (
        "pack_novalue_count_clear_when_sized",
        "v: the count c is 3 in the row, but no field wrote it",
    ),
];

/// The text of a pack refusal: the message, or `missing value: <name>` for a missing value.
pub(super) fn pack_text(err: &PackError) -> String {
    match err {
        PackError::Type(message) => message.clone(),
        PackError::Missing(name) => format!("missing value: {name}"),
    }
}

fn fragment(table: RuleTable, id: &str) -> &'static str {
    table
        .iter()
        .find(|(entry, _)| *entry == id)
        .map(|(_, fragment)| *fragment)
        .unwrap_or_else(|| panic!("{id}: no refusal rule recorded in refusals.rs"))
}

fn names_rule(text: &str, want: &str) -> bool {
    match want.strip_prefix('=') {
        Some(whole) => text == whole,
        None => text.contains(want),
    }
}

pub(super) fn assert_construct_rule(table: RuleTable, id: &str, panic: &str) {
    let want = fragment(table, id);
    assert!(
        names_rule(panic, want),
        "{id}: refused by another rule; wanted {want:?}, got {panic:?}"
    );
}

pub(super) fn assert_pack_rule(table: RuleTable, id: &str, err: &PackError) {
    let want = fragment(table, id);
    let text = pack_text(err);
    assert!(
        names_rule(&text, want),
        "{id}: refused by another rule; wanted {want:?}, got {text:?}"
    );
}

/// Every refused case has a rule and every rule names a refused case, so a new case or a
/// renamed one cannot go unpinned.
pub(super) fn assert_tables_cover(
    construct_table: RuleTable,
    construct_ids: &[String],
    pack_table: RuleTable,
    pack_ids: &[String],
) {
    for (table, ids, kind) in [
        (construct_table, construct_ids, "construct"),
        (pack_table, pack_ids, "pack"),
    ] {
        for (id, _) in table {
            assert!(
                ids.iter().any(|case| case == id),
                "refusals.rs has a {kind} rule for {id}, which is not a refused {kind} case"
            );
        }
    }
}
