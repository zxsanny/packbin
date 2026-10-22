//! The scheme and the Rust outcome of each hostile case, written by hand from
//! fixtures/hostile/README.md. They are tables, not `match` expressions, so the loader can name by
//! case id a handler that no case of cases.txt uses (`unused_handlers`).

use crate::{
    bits, dict, eq, flag_byte, flags, group, i8, list, repeat, sized, times, u16, u32, u8, utf8,
    when, MapScheme, Value, DEFAULT_MAX_SLOTS,
};

type Build = fn() -> MapScheme;

fn zero_progress_when() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![u8("1")])]),
        ],
    )
}

fn dict_scheme() -> MapScheme {
    MapScheme::new(1, vec![dict("0", u8("0"))])
}

fn nine_flag_bits_split() -> MapScheme {
    let byte = flag_byte("0");
    let mut fields = vec![byte.byte()];
    fields.extend((1..10).map(|i| byte.bit(u8(i.to_string()))));
    MapScheme::new(1, fields)
}

fn empty_when_times_body() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            u8("1"),
            times(2, "1", vec![when(2, eq("0", Value::U8(1)), vec![])]),
        ],
    )
}

fn empty_nested_when_body() -> MapScheme {
    MapScheme::new(
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
    )
}

/// The scheme each `unpack` and `construct` case names.
const SCHEMES: &[(&[&str], Build)] = &[
    (&["zero_progress_repeat_bool"], || {
        MapScheme::new(1, vec![repeat(0, vec![group(0, "0", vec![])])])
    }),
    (
        &[
            "zero_progress_repeat_when",
            "when_names_outer_field_in_repeat",
        ],
        zero_progress_when,
    ),
    (&["negative_count"], || {
        MapScheme::new(1, vec![i8("0"), sized("1", "0")])
    }),
    (&["oversize_count"], || {
        MapScheme::new(1, vec![u32("0"), sized("1", "0")])
    }),
    (&["oversize_count_times"], || {
        MapScheme::new(1, vec![u32("0"), times(1, "0", vec![u8("1")])])
    }),
    (&["oversize_list_count"], || {
        MapScheme::new(1, vec![list("0", u8("0"))])
    }),
    (&["invalid_utf8"], || MapScheme::new(1, vec![utf8("0")])),
    (
        &[
            "invalid_utf8_dict_key",
            "dict_keys_out_of_order",
            "dict_keys_repeated",
            "dict_keys_repeated_forms",
            "dict_keys_prefix_descends",
            "dict_keys_utf16_order",
        ],
        dict_scheme,
    ),
    (&["count_behind_clear_flag"], || {
        MapScheme::new(1, vec![flags(0, "f", vec![u8("0")]), sized("1", "0")])
    }),
    (&["count_behind_clear_flag_bits"], || {
        MapScheme::new(1, vec![flags(0, "f", vec![u8("0")]), bits("1", "0")])
    }),
    (&["when_names_later_field"], || {
        MapScheme::new(
            1,
            vec![
                u8("0"),
                when(1, eq("2", Value::U8(1)), vec![u8("1")]),
                u8("2"),
            ],
        )
    }),
    (&["count_names_later_field"], || {
        MapScheme::new(1, vec![sized("0", "1"), u16("1")])
    }),
    (&["nine_flag_bits"], || {
        MapScheme::new(
            1,
            vec![flags(0, "f", (0..9).map(|i| u8(i.to_string())).collect())],
        )
    }),
    (&["nine_flag_bits_split"], nine_flag_bits_split),
    (&["construct_empty_times_body"], || {
        MapScheme::new(1, vec![u8("0"), times(1, "0", vec![])])
    }),
    (&["construct_empty_when_times_body"], empty_when_times_body),
    (&["construct_empty_when_repeat_body"], || {
        MapScheme::new(
            1,
            vec![
                u8("0"),
                repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![])]),
            ],
        )
    }),
    (
        &["construct_empty_nested_when_body"],
        empty_nested_when_body,
    ),
    (&["construct_empty_repeat_body"], || {
        MapScheme::new(1, vec![repeat(0, vec![])])
    }),
    (&["empty_group_outside_flags"], || {
        MapScheme::new(1, vec![u8("0"), group(1, "1", vec![])])
    }),
    (&["eq_bool_false"], || {
        MapScheme::new(
            1,
            vec![
                flags(0, "f", vec![group(0, "0", vec![])]),
                when(1, eq("0", Value::U8(0)), vec![u8("1")]),
            ],
        )
    }),
    (&["eq_out_of_range"], || {
        MapScheme::new(
            1,
            vec![u8("a"), when(1, eq("a", Value::U16(300)), vec![u8("v")])],
        )
    }),
];

/// Rounds the scheme of a `limit` case allows; max_slots stays at its default.
const LOW_ROUNDS: usize = 3;

/// The scheme each `limit` case names.
const LIMIT_SCHEMES: &[(&[&str], Build)] = &[
    (&["repeat_rounds_over_limit"], || {
        MapScheme::new(1, vec![repeat(0, vec![u8("0")])]).with_limits(LOW_ROUNDS, DEFAULT_MAX_SLOTS)
    }),
    (&["times_rounds_over_limit"], || {
        MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])
            .with_limits(LOW_ROUNDS, DEFAULT_MAX_SLOTS)
    }),
];

/// What Rust returns for each `unpack` and `construct` case today; the labels are undecided until C15.
const OUTCOMES: &[(&[&str], &str)] = &[
    (
        &[
            "zero_progress_repeat_bool",
            "nine_flag_bits",
            "nine_flag_bits_split",
            "bool_outside_flags",
            "empty_group_outside_flags",
            "eq_bool_false",
            "eq_out_of_range",
            "construct_empty_times_body",
            "construct_empty_repeat_body",
            "construct_empty_when_times_body",
            "construct_empty_when_repeat_body",
            "construct_empty_nested_when_body",
            "zero_progress_repeat_when",
            "when_names_outer_field_in_repeat",
            "when_names_later_field",
            "count_names_later_field",
        ],
        "scheme_error",
    ),
    (
        &[
            "negative_count",
            "oversize_count",
            "oversize_count_times",
            "oversize_list_count",
            "invalid_utf8",
            "invalid_utf8_dict_key",
            "dict_keys_out_of_order",
            "dict_keys_repeated",
            "dict_keys_repeated_forms",
            "dict_keys_prefix_descends",
            "dict_keys_utf16_order",
            "count_behind_clear_flag",
            "count_behind_clear_flag_bits",
        ],
        "Short",
    ),
];

fn find<T: Copy>(table: &[(&[&str], T)], id: &str) -> Option<T> {
    table
        .iter()
        .find(|(ids, _)| ids.contains(&id))
        .map(|(_, value)| *value)
}

pub(super) fn scheme_for(id: &str) -> MapScheme {
    match find(SCHEMES, id) {
        Some(build) => build(),
        None => panic!("no scheme written for hostile case {id}"),
    }
}

pub(super) fn limit_scheme_for(id: &str) -> MapScheme {
    match find(LIMIT_SCHEMES, id) {
        Some(build) => build(),
        None => panic!("no scheme written for hostile limit case {id}"),
    }
}

pub(super) fn rust_outcome(id: &str) -> &'static str {
    match find(OUTCOMES, id) {
        Some(outcome) => outcome,
        None => panic!("no Rust outcome recorded for hostile case {id}"),
    }
}

/// Every id of a table that no case of `cases` (id, stage) of one of `stages` carries, as a message
/// naming the id.
fn ids_without_case<T>(
    table: &[(&[&str], T)],
    what: &str,
    stages: &[&str],
    cases: &[(String, String)],
) -> Vec<String> {
    table
        .iter()
        .flat_map(|(ids, _)| ids.iter())
        .filter(|id| {
            !cases
                .iter()
                .any(|(case, stage)| case == *id && stages.contains(&stage.as_str()))
        })
        .map(|id| {
            format!(
                "{id}: {what} has no {} case in cases.txt",
                stages.join(" or ")
            )
        })
        .collect()
}

/// The handlers of the three tables that no case uses, one message per id (empty when all are used).
pub(super) fn unused_handlers(cases: &[(String, String)]) -> Vec<String> {
    let stages = ["unpack", "construct"];
    let mut unused = ids_without_case(SCHEMES, "scheme handler", &stages, cases);
    unused.extend(ids_without_case(
        LIMIT_SCHEMES,
        "limit scheme handler",
        &["limit"],
        cases,
    ));
    unused.extend(ids_without_case(OUTCOMES, "Rust outcome", &stages, cases));
    unused
}
