//! The `pack` stage of the shared hostile cases (fixtures/hostile/cases.txt): the scheme and row of
//! each case, written by hand from fixtures/hostile/README.md in Rust's map form.

use crate::walk::pack;
use crate::{
    bits, bytes, eq, flag_byte, flags, group, insert, packed, repeat, sized, times, u16, u32, u8,
    utf8, when, MapScheme, PackError, Value, Values, DEFAULT_MAX_ROUNDS,
};

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

/// One round row per entry; a name a round leaves out is absent there (false for a bool).
fn rounds(rounds: Vec<Vec<(&str, Value)>>) -> Values {
    let groups = rounds.iter().map(|round| row(round)).collect();
    row(&[("__repeat__", Value::Groups(groups))])
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|n| Value::U8(*n)).collect())
}

fn times_scheme() -> MapScheme {
    MapScheme::new(1, vec![u8("a"), times(1, "a", vec![u8("x")])])
}

/// `flagbyte m; u8 mode; bit m { when mode == 1 { u8 speed } }`: the condition follows the byte.
fn split_when_after_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("mode"),
            m.bit(when(2, eq("mode", Value::U8(1)), vec![u8("speed")])),
        ],
    )
}

/// `flagbyte m; u8 n; bit m { times n { u8 pt } }`: the count follows the byte.
fn split_count_after_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![m.byte(), u8("n"), m.bit(times(2, "n", vec![u8("pt")]))],
    )
}

/// `u8 sel; flagbyte m; when sel == 1 { u8 n }; bit m { times n { u8 pt } }`
fn split_count_skipped() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("sel"),
            m.byte(),
            when(2, eq("sel", Value::U8(1)), vec![u8("n")]),
            m.bit(times(3, "n", vec![u8("pt")])),
        ],
    )
}

/// `u8 mode; flagbyte m; bit m { when mode == 1 { u8 speed } }; bit m { u16 heading }`
fn split_false_condition() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("mode"),
            m.byte(),
            m.bit(when(2, eq("mode", Value::U8(1)), vec![u8("speed")])),
            m.bit(u16("heading")),
        ],
    )
}

/// `u8 n; times n { u8 a }; repeat { u8 b }` with 3 slots: each round of either holds one name.
fn slots_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("n"),
            times(1, "n", vec![u8("a")]),
            repeat(2, vec![u8("b")]),
        ],
    )
    .with_limits(DEFAULT_MAX_ROUNDS, 3)
}

fn slots_row(b: &[u8]) -> Values {
    let mut vals = row(&[("n", Value::U8(1)), ("a", ints(&[1]))]);
    let rounds = b.iter().map(|x| row(&[("b", Value::U8(*x))])).collect();
    insert(&mut vals, "__repeat__", Some(Value::Groups(rounds)));
    vals
}

/// `repeat { flags { bool on; u8 v } }` with 4 slots: a round holds the names `on` and `v`.
fn flags_slots_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![flags(0, "f", vec![group(0, "on", vec![]), u8("v")])],
        )],
    )
    .with_limits(DEFAULT_MAX_ROUNDS, 4)
}

fn flags_slots_row(v: &[u8]) -> Values {
    rounds(
        v.iter()
            .map(|x| vec![("on", Value::U8(1)), ("v", Value::U8(*x))])
            .collect(),
    )
}

/// `flagByte m; u8 n; bit m { times n { u8 pt } }; bit m { u16 heading }`: the count follows the byte.
fn split_times_after_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            m.byte(),
            u8("n"),
            m.bit(times(2, "n", vec![u8("pt")])),
            m.bit(u16("heading")),
        ],
    )
}

/// `u8 mode; when mode == 1 { u8 c }; <member counted by c>`, the row `mode 0, c 3, v given`.
fn count_clear_when(member: crate::Field, v: Value) -> Result<Vec<u8>, PackError> {
    pack(
        &MapScheme::new(
            1,
            vec![
                u8("mode"),
                when(1, eq("mode", Value::U8(1)), vec![u8("c")]),
                member,
            ],
        ),
        &row(&[("mode", Value::U8(0)), ("c", Value::U8(3)), ("v", v)]),
    )
}

/// Pack cases a Rust scheme cannot express, with the reason (the README "Not run by" line of each).
pub(super) const PACK_NOT_RUN: &[(&str, &str)] = &[
    (
        "pack_element_times_over_budget",
        "a list element cannot hold a `times`: Rust refuses it at construction",
    ),
    (
        "pack_flags_short_list",
        "a `repeat` takes its rounds as groups, one row per round, so there is no list to be too short",
    ),
];

/// The scheme and row of a `pack` case, written by hand from fixtures/hostile/README.md (map form).
pub(super) fn pack_case(id: &str) -> Result<Vec<u8>, PackError> {
    match id {
        "pack_out_of_range_integer" => pack(
            &MapScheme::new(1, vec![u8("a")]),
            &row(&[("a", Value::U16(300))]),
        ),
        "pack_missing_required_value" => pack(
            &MapScheme::new(1, vec![u8("a"), u8("b")]),
            &row(&[("a", Value::U8(1))]),
        ),
        "pack_times_list_too_long" => pack(
            &times_scheme(),
            &row(&[("a", Value::U8(2)), ("x", ints(&[1, 2, 3]))]),
        ),
        "pack_times_list_too_short" => pack(
            &times_scheme(),
            &row(&[("a", Value::U8(2)), ("x", ints(&[1]))]),
        ),
        "pack_aligned_round_row" => pack(
            &MapScheme::new(
                1,
                vec![repeat(
                    0,
                    vec![flags(0, "f", vec![group(0, "on", vec![]), u8("n")])],
                )],
            ),
            &rounds(vec![
                vec![("on", Value::U8(1)), ("n", Value::U8(1))],
                vec![("n", Value::U8(2))],
                vec![("on", Value::U8(1)), ("n", Value::U8(3))],
            ]),
        ),
        "pack_times_count_over_limit" => pack(
            &MapScheme::new(1, vec![u32("n"), times(1, "n", vec![u8("x")])]),
            &row(&[("n", Value::U32(65_536)), ("x", Value::U8(7))]),
        ),
        "pack_times_zero_with_values" => pack(
            &times_scheme(),
            &row(&[("a", Value::U8(0)), ("x", ints(&[5]))]),
        ),
        "pack_split_when_source_after_byte" => pack(
            &split_when_after_byte(),
            &row(&[("mode", Value::U8(1)), ("speed", Value::U8(7))]),
        ),
        "pack_split_times_count_after_byte" => pack(
            &split_count_after_byte(),
            &row(&[("n", Value::U8(2)), ("pt", ints(&[5, 6]))]),
        ),
        "pack_split_times_count_skipped" => pack(
            &split_count_skipped(),
            &row(&[("sel", Value::U8(0)), ("pt", ints(&[5]))]),
        ),
        "pack_lone_bytes_in_round" => pack(
            &MapScheme::new(1, vec![u8("n"), times(1, "n", vec![bytes("d", 2)])]),
            &row(&[("n", Value::U8(2)), ("d", Value::Bytes(vec![1, 2]))]),
        ),
        "pack_split_false_condition_silent" => pack(
            &split_false_condition(),
            &row(&[
                ("mode", Value::U8(0)),
                ("speed", Value::U8(7)),
                ("heading", Value::U16(90)),
            ]),
        ),
        "pack_lone_utf8_under_times_over_budget" => pack(
            &MapScheme::new(1, vec![u32("n"), times(1, "n", vec![utf8("s")])]),
            &row(&[
                ("n", Value::U32(65_535)),
                ("s", Value::Str("a".repeat(65_535))),
            ]),
        ),
        "pack_slots_over_limit" => {
            let names: Vec<String> = (0..65).map(|i| format!("m{i}")).collect();
            let mut pairs = vec![("n", Value::U32(65_535))];
            pairs.extend(names.iter().map(|name| (name.as_str(), Value::U8(1))));
            pack(
                &MapScheme::new(
                    1,
                    vec![u32("n"), times(1, "n", names.iter().map(u8).collect())],
                ),
                &row(&pairs),
            )
        }
        "pack_repeat_over_limit" => {
            let rounds = (0..65_536)
                .map(|_| row(&[("k", Value::U8(7))]))
                .collect::<Vec<_>>();
            pack(
                &MapScheme::new(1, vec![repeat(0, vec![u8("k")])]),
                &row(&[("__repeat__", Value::Groups(rounds))]),
            )
        }
        "pack_split_count_zero_after_byte_list" => pack(
            &split_count_after_byte(),
            &row(&[("n", Value::U8(0)), ("pt", ints(&[5, 6]))]),
        ),
        "pack_split_count_zero_after_byte_scalar" => pack(
            &split_count_after_byte(),
            &row(&[("n", Value::U8(0)), ("pt", Value::U8(5))]),
        ),
        "pack_flags_skipped_count_with_values" => pack(
            &MapScheme::new(
                1,
                vec![flags(0, "f", vec![u8("n"), times(1, "n", vec![u8("pt")])])],
            ),
            &row(&[("pt", ints(&[5, 6]))]),
        ),
        "pack_round_slots_at_limit" => pack(&slots_scheme(), &slots_row(&[2, 3])),
        "pack_round_slots_over_limit" => pack(&slots_scheme(), &slots_row(&[2, 3, 4])),
        "pack_round_slots_flags_at_limit" => {
            pack(&flags_slots_scheme(), &flags_slots_row(&[5, 6]))
        }
        "pack_round_slots_flags_over_limit" => {
            pack(&flags_slots_scheme(), &flags_slots_row(&[5, 6, 7]))
        }
        "pack_flags_short_list_filled" => pack(
            &MapScheme::new(
                1,
                vec![repeat(0, vec![u8("w"), flags(1, "f", vec![u8("v")])])],
            ),
            &rounds(vec![
                vec![("w", Value::U8(1)), ("v", Value::U8(5))],
                vec![("w", Value::U8(2))],
            ]),
        ),
        "pack_split_times_absent_body" => pack(
            &split_times_after_byte(),
            &row(&[("n", Value::U8(2)), ("heading", Value::U16(90))]),
        ),
        "pack_late_when_in_bit_body" => {
            let m = flag_byte("m");
            pack(
                &MapScheme::new(
                    1,
                    vec![
                        m.byte(),
                        u8("mode"),
                        m.bit(group(
                            2,
                            "g",
                            vec![
                                u8("d"),
                                when(3, eq("mode", Value::U8(1)), vec![u8("a")]),
                                when(4, eq("mode", Value::U8(2)), vec![u8("b")]),
                            ],
                        )),
                    ],
                ),
                &row(&[
                    ("mode", Value::U8(1)),
                    ("d", Value::U8(5)),
                    ("a", Value::U8(9)),
                ]),
            )
        }
        "pack_count_one_clear_when" => {
            let m = flag_byte("m");
            pack(
                &MapScheme::new(
                    1,
                    vec![
                        u8("mode"),
                        when(1, eq("mode", Value::U8(1)), vec![u8("c")]),
                        m.byte(),
                        m.bit(times(3, "c", vec![u8("pt")])),
                        m.bit(u16("heading")),
                    ],
                ),
                &row(&[
                    ("mode", Value::U8(0)),
                    ("c", Value::U8(1)),
                    ("heading", Value::U16(90)),
                ]),
            )
        }
        "pack_bits_count_clear_when" => {
            count_clear_when(bits("v", "c"), ints(&[1, 0, 1]))
        }
        "pack_packed_count_clear_when" => {
            count_clear_when(packed(1, "v", "c", 0), ints(&[1, 0, 1]))
        }
        "pack_sized_count_clear_when" => {
            count_clear_when(sized("v", "c"), Value::Bytes(vec![1, 2, 3]))
        }
        other => panic!("no scheme written for hostile pack case {other}"),
    }
}
