#![cfg(feature = "std")]
use packbin::{
    eq, flag_byte, flags, insert, pack, repeat, times, to_hex, u8, when, MapScheme, PackError,
    Value, Values,
};

// AZ-2433 (owner decision U22 of loop 23, review22 finding 5, security F37): the map form of a
// `repeat` dropped given values in two shapes. (a) A value kept beside `__repeat__` groups under a
// name of the body must be what the rounds hold, as `check_lists` asks of a `times` (a non-list
// counts as a list of one item); a value the rounds do not hold is refused naming it. (b) Without
// groups, the names of a `times` nested in the repeat body are refused like the body's own names
// (U13). Rows with groups only, with values that agree with the groups, or with no extra names
// pack as at HEAD (b8b2809). A `repeat` cannot sit in a round, so a repeat nested in a repeat
// body cannot be spelled (construction panics: "a round keeps no inner repeat rounds").
// Follow-up (review Low 4, assessment G5, G6): the own name of a `flags` in the body and the
// `__times_<anchor>` key of a nested `times` are refused the same way.

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|x| n(*x)).collect())
}

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn rounds(items: Vec<Values>) -> Value {
    Value::Groups(items)
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn text(result: Result<String, PackError>) -> String {
    match result {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

fn disagrees(id: u32, name: &str) -> String {
    format!("repeat at id {id}: list for '{name}' disagrees with its rounds")
}

fn without_groups(id: u32, name: &str) -> String {
    format!(
        "repeat at id {id}: '{name}' is given without '__repeat__' groups; give the rounds of a \
         repeat as '__repeat__' groups, one per round"
    )
}

/// `repeat { u8 n; u8 x }`
fn plain() -> MapScheme {
    MapScheme::new(1, vec![repeat(0, vec![u8("n"), u8("x")])])
}

fn one_round() -> Value {
    rounds(vec![row(&[("n", n(1)), ("x", n(5))])])
}

fn two_rounds() -> Value {
    rounds(vec![
        row(&[("n", n(1)), ("x", n(5))]),
        row(&[("n", n(2)), ("x", n(6))]),
    ])
}

/// `repeat { u8 n; times(n) { u8 w } }`
fn nested_times() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(0, vec![u8("n"), times(1, "n", vec![u8("w")])])],
    )
}

/// `repeat { u8 n; when n == 1 { times(n) { u8 w } } }`
fn nested_times_under_when() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![
                u8("n"),
                when(1, eq("n", n(1)), vec![times(1, "n", vec![u8("w")])]),
            ],
        )],
    )
}

/// `flags { repeat { u8 n; times(n) { u8 w } }; u8 z }`
fn nested_times_in_flags() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![
                repeat(0, vec![u8("n"), times(1, "n", vec![u8("w")])]),
                u8("z"),
            ],
        )],
    )
}

/// `flagByte fb; bit { repeat { u8 n; times(n) { u8 w } } }`
fn nested_times_in_split_bit() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![
            fb.byte(),
            fb.bit(repeat(1, vec![u8("n"), times(2, "n", vec![u8("w")])])),
        ],
    )
}

/// `flags { repeat { u8 n }; u8 z }`
fn repeat_in_flags() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(0, "f", vec![repeat(0, vec![u8("n")]), u8("z")])],
    )
}

/// `flagByte fb; bit { repeat { u8 n } }`
fn repeat_in_split_bit() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(1, vec![fb.byte(), fb.bit(repeat(1, vec![u8("n")]))])
}

// ---- AC-1: a value beside groups that the rounds do not hold ----

#[test]
fn ac1_a_list_beside_groups_that_disagrees_is_refused_naming_it() {
    // Arrange
    let vals = row(&[("__repeat__", one_round()), ("n", ints(&[2]))]);

    // Act
    let message = text(hex_of(&plain(), &vals));

    // Assert: HEAD packed `010105` and dropped `n`
    assert_eq!(message, disagrees(0, "n"));
}

#[test]
fn ac1_a_shorter_list_and_a_lone_value_beside_groups_are_refused() {
    // Arrange
    let shorter = row(&[("__repeat__", two_rounds()), ("x", ints(&[5]))]);
    let lone = row(&[("__repeat__", one_round()), ("x", n(6))]);
    let empty = row(&[("__repeat__", one_round()), ("x", ints(&[]))]);

    // Act
    let messages = [
        text(hex_of(&plain(), &shorter)),
        text(hex_of(&plain(), &lone)),
        text(hex_of(&plain(), &empty)),
    ];

    // Assert: HEAD packed `0101050206`, `010105`, `010105`; an empty list beside groups that hold
    // the name disagrees with them, as for a `times`
    assert_eq!(
        messages,
        [disagrees(0, "x"), disagrees(0, "x"), disagrees(0, "x")]
    );
}

#[test]
fn ac1_two_disagreeing_names_name_the_first_in_name_order() {
    // Arrange
    let vals = row(&[
        ("__repeat__", two_rounds()),
        ("x", ints(&[9])),
        ("n", ints(&[9])),
    ]);

    // Act
    let message = text(hex_of(&plain(), &vals));

    // Assert
    assert_eq!(message, disagrees(0, "n"));
}

#[test]
fn ac1_a_list_beside_groups_of_a_repeat_under_flags_or_a_split_bit_is_refused() {
    for (label, scheme, id) in [
        ("flags", repeat_in_flags(), 0),
        ("split", repeat_in_split_bit(), 1),
    ] {
        // Arrange: the second row's round holds no value, so the bit is clear
        let set = row(&[
            ("__repeat__", rounds(vec![row(&[("n", n(1))])])),
            ("n", ints(&[3])),
        ]);
        let clear = row(&[
            ("__repeat__", rounds(vec![Values::new()])),
            ("n", ints(&[1])),
        ]);

        // Act
        let messages = [text(hex_of(&scheme, &set)), text(hex_of(&scheme, &clear))];

        // Assert: HEAD packed `010101` and `0100`
        assert_eq!(
            messages,
            [disagrees(id, "n"), disagrees(id, "n")],
            "{label}"
        );
    }
}

#[test]
fn ac1_a_name_of_a_nested_times_beside_groups_is_refused() {
    // Arrange: the rounds hold `w` as the nested times' list; one kept at the top is dropped
    let vals = row(&[
        (
            "__repeat__",
            rounds(vec![row(&[("n", n(1)), ("w", ints(&[7]))])]),
        ),
        ("w", ints(&[7])),
    ]);

    // Act
    let message = text(hex_of(&nested_times(), &vals));

    // Assert: HEAD packed `010107`
    assert_eq!(message, disagrees(0, "w"));
}

// ---- AC-2: names of a times nested in the body, given without groups ----

#[test]
fn ac2_a_name_of_a_nested_times_without_groups_is_refused_naming_it() {
    // Arrange
    let list = row(&[("w", ints(&[1]))]);
    let lone = row(&[("w", n(1))]);

    // Act
    let messages = [
        text(hex_of(&nested_times(), &list)),
        text(hex_of(&nested_times(), &lone)),
        text(hex_of(&nested_times_under_when(), &list)),
    ];

    // Assert: HEAD packed `01` for all three
    assert_eq!(
        messages,
        [
            without_groups(0, "w"),
            without_groups(0, "w"),
            without_groups(0, "w")
        ]
    );
}

#[test]
fn ac2_a_nested_name_of_a_repeat_under_flags_or_a_split_bit_is_refused() {
    // Arrange
    let vals = row(&[("w", ints(&[1]))]);

    // Act
    let messages = [
        text(hex_of(&nested_times_in_flags(), &vals)),
        text(hex_of(&nested_times_in_split_bit(), &vals)),
    ];

    // Assert: HEAD packed `0100` for both
    assert_eq!(messages, [without_groups(0, "w"), without_groups(1, "w")]);
}

// ---- AC-3: rows with groups only, agreeing values or no extra names (hex as at b8b2809) ----

#[test]
fn ac3_values_beside_groups_that_agree_with_them_pack_the_groups() {
    // Arrange: the review's AC-1 row `{__repeat__: [{n:1,x:5}], n: [1]}` agrees with its round,
    // so it packs (nothing is dropped), as the same row through a `times` does
    let literal = row(&[("__repeat__", one_round()), ("n", ints(&[1]))]);
    let lone = row(&[("__repeat__", one_round()), ("x", n(5))]);
    let same = row(&[
        ("__repeat__", two_rounds()),
        ("n", ints(&[1, 2])),
        ("x", ints(&[5, 6])),
    ]);
    let mut none_beside = row(&[("__repeat__", one_round())]);
    insert(&mut none_beside, "n", None);

    // Act
    let bytes = [
        hex_of(&plain(), &literal),
        hex_of(&plain(), &lone),
        hex_of(&plain(), &same),
        hex_of(&plain(), &none_beside),
    ];

    // Assert
    let ok = |hex: &str| Ok(hex.to_string());
    assert_eq!(
        bytes,
        [ok("010105"), ok("010105"), ok("0101050206"), ok("010105")]
    );
}

#[test]
fn ac3_groups_only_and_nothing_given_pack_as_at_head() {
    // Arrange
    let nested_groups = row(&[(
        "__repeat__",
        rounds(vec![
            row(&[("n", n(2)), ("w", ints(&[3, 4]))]),
            row(&[
                ("n", n(1)),
                ("__times_1", rounds(vec![row(&[("w", n(9))])])),
            ]),
        ]),
    )]);
    let count_zero = row(&[("__repeat__", rounds(vec![row(&[("n", n(0))])]))]);
    let under_when = row(&[(
        "__repeat__",
        rounds(vec![
            row(&[("n", n(1)), ("w", ints(&[5]))]),
            row(&[("n", n(2))]),
        ]),
    )]);
    let one_w = row(&[(
        "__repeat__",
        rounds(vec![row(&[("n", n(1)), ("w", ints(&[3]))])]),
    )]);
    let empty_list = row(&[("w", ints(&[]))]);

    // Act
    let bytes = [
        hex_of(&nested_times(), &nested_groups),
        hex_of(&nested_times(), &count_zero),
        hex_of(&nested_times(), &Values::new()),
        hex_of(&nested_times(), &empty_list),
        hex_of(&nested_times_under_when(), &under_when),
        hex_of(&nested_times_in_flags(), &one_w),
        hex_of(&nested_times_in_flags(), &Values::new()),
        hex_of(&nested_times_in_split_bit(), &one_w),
        hex_of(&nested_times_in_split_bit(), &Values::new()),
    ];

    // Assert
    let ok = |hex: &str| Ok(hex.to_string());
    assert_eq!(
        bytes,
        [
            ok("010203040109"),
            ok("0100"),
            ok("01"),
            ok("01"),
            ok("01010502"),
            ok("01010103"),
            ok("0100"),
            ok("01010103"),
            ok("0100"),
        ]
    );
}

// ---- G5: the own name of a flags in the body; G6: the key of a nested times ----

/// `repeat { u8 n; flags fl { u8 a } }`
fn flags_in_body() -> MapScheme {
    MapScheme::new(
        1,
        vec![repeat(0, vec![u8("n"), flags(1, "fl", vec![u8("a")])])],
    )
}

fn nested_key(w: u8) -> Value {
    rounds(vec![row(&[("w", n(w))])])
}

#[test]
fn g5_a_flags_name_without_groups_or_beside_groups_is_refused() {
    // Arrange
    let fb = flag_byte("fb");
    let split = MapScheme::new(
        1,
        vec![
            fb.byte(),
            fb.bit(repeat(1, vec![u8("n"), flags(2, "fl", vec![u8("a")])])),
        ],
    );
    let lone = row(&[("fl", n(5))]);
    let beside = row(&[
        ("__repeat__", rounds(vec![row(&[("n", n(1)), ("a", n(2))])])),
        ("fl", n(5)),
    ]);

    // Act
    let messages = [
        text(hex_of(&flags_in_body(), &lone)),
        text(hex_of(&flags_in_body(), &row(&[("fl", ints(&[5]))]))),
        text(hex_of(&split, &lone)),
        text(hex_of(&flags_in_body(), &beside)),
    ];

    // Assert: HEAD packed `01`, `01`, `0100`, `01010102`
    assert_eq!(
        messages,
        [
            without_groups(0, "fl"),
            without_groups(0, "fl"),
            without_groups(1, "fl"),
            disagrees(0, "fl"),
        ]
    );
}

#[test]
fn g6_a_nested_times_key_without_groups_or_beside_groups_is_refused() {
    // Arrange
    let lone = row(&[("__times_1", nested_key(9))]);
    let beside = row(&[
        (
            "__repeat__",
            rounds(vec![row(&[("n", n(1)), ("w", ints(&[9]))])]),
        ),
        ("__times_1", nested_key(9)),
    ]);

    // Act
    let messages = [
        text(hex_of(&nested_times(), &lone)),
        text(hex_of(&nested_times_in_flags(), &lone)),
        text(hex_of(&nested_times(), &beside)),
    ];

    // Assert: HEAD packed `01`, `0100`, `010109`
    assert_eq!(
        messages,
        [
            without_groups(0, "__times_1"),
            without_groups(0, "__times_1"),
            disagrees(0, "__times_1"),
        ]
    );
}

#[test]
fn g5_g6_groups_only_empty_values_and_a_key_the_rounds_hold_pack_as_at_head() {
    // Arrange: a key kept beside groups whose round holds the same key agrees with them
    let groups_only = row(&[(
        "__repeat__",
        rounds(vec![row(&[("n", n(1)), ("a", n(2))]), row(&[("n", n(3))])]),
    )]);
    let held_key = row(&[
        (
            "__repeat__",
            rounds(vec![row(&[("n", n(1)), ("__times_1", nested_key(9))])]),
        ),
        ("__times_1", nested_key(9)),
    ]);

    // Act
    let bytes = [
        hex_of(&flags_in_body(), &groups_only),
        hex_of(&flags_in_body(), &row(&[("fl", ints(&[]))])),
        hex_of(&nested_times(), &row(&[("__times_1", rounds(Vec::new()))])),
        hex_of(&nested_times(), &held_key),
    ];

    // Assert
    let ok = |hex: &str| Ok(hex.to_string());
    assert_eq!(
        bytes,
        [ok("010101020300"), ok("01"), ok("01"), ok("010109")]
    );
}
