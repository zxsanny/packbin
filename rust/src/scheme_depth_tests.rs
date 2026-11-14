//! AZ-4302: a scheme nested deeper than 256 levels is refused when it is built, first and without
//! recursion, in the map form and the typed form; 256 levels still build, pack and unpack. Every
//! chain is built by a loop, innermost first. The 256-level pack and unpack need the stack of a
//! release build or of a debug build with `RUST_MIN_STACK` of 8 MiB (`walk_fits_stack`); where it
//! is missing the test says so and returns.

use crate::hostile_tests::{panic_text, walk_fits_stack, within_one_second};
use crate::walk::{pack, unpack};
use crate::{
    dict, eq, flags, group, insert, list, times, to_hex, u8, when, BoundField, Field, MapScheme,
    Scheme, SchemeItem, Value, Values,
};
use std::panic::{catch_unwind, AssertUnwindSafe};

const TEXT: &str = "scheme nested too deep: more than 256 levels; the limit is 256";

fn when_chain(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("1")];
    for _ in 0..depth {
        inner = vec![when(1, eq("0", Value::U8(1)), inner)];
    }
    let mut fields = vec![u8("0")];
    fields.extend(inner);
    fields
}

fn group_chain(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("b")];
    for level in (0..depth).rev() {
        inner = vec![group(0, format!("g{level}"), inner)];
    }
    inner
}

fn flags_chain(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("b")];
    for level in (0..depth).rev() {
        inner = vec![flags(0, format!("f{level}"), inner)];
    }
    inner
}

fn list_chain(depth: usize) -> Vec<Field> {
    let mut inner = u8("0");
    for _ in 0..depth {
        inner = list("0", inner);
    }
    vec![inner]
}

fn dict_chain(depth: usize) -> Vec<Field> {
    let mut inner = u8("0");
    for _ in 0..depth {
        inner = dict("0", inner);
    }
    vec![inner]
}

/// `u8 "0"`, then `depth` nested `times` over it (a `times` in a `times` round is a shape error of
/// its own, which the depth rule must come before).
fn times_chain(depth: usize) -> Vec<Field> {
    let mut inner = vec![u8("x")];
    for _ in 0..depth {
        inner = vec![times(1, "0", inner)];
    }
    let mut fields = vec![u8("0")];
    fields.extend(inner);
    fields
}

type Chain = fn(usize) -> Vec<Field>;

const KINDS: [(&str, Chain); 5] = [
    ("when", when_chain),
    ("group", group_chain),
    ("flags", flags_chain),
    ("list", list_chain),
    ("dict", dict_chain),
];

/// The build panic of `fields`, or a failure when the scheme was built.
fn refusal(fields: Vec<Field>) -> String {
    let built = catch_unwind(AssertUnwindSafe(|| MapScheme::new(1, fields)));
    match built {
        Ok(_) => panic!("the scheme was built, expected a refusal"),
        Err(panic) => panic_text(panic.as_ref()),
    }
}

fn row(pairs: &[(&str, Value)]) -> Values {
    let mut values = Values::new();
    for (name, value) in pairs {
        insert(&mut values, name, Some(value.clone()));
    }
    values
}

fn round_trip(scheme: &MapScheme, given: &Values, hex: &str, what: &str) {
    let packed = pack(scheme, given).unwrap_or_else(|e| panic!("{what}: {e:?}"));
    assert_eq!(to_hex(&packed), hex, "{what}");
    assert_eq!(unpack(scheme, &packed).as_ref(), Ok(given), "{what}");
}

#[test]
fn every_kind_over_256_levels_is_refused_with_the_contract_text() {
    // AC-1: 257, 1,000 and 50,000 levels of each kind, quickly and with no stack error
    for (kind, chain) in KINDS {
        for depth in [257, 1_000, 50_000] {
            // Arrange and Act (the chain is built on the timed thread: names are not `Send`)
            let text = within_one_second(&format!("{kind} {depth}"), move || refusal(chain(depth)));

            // Assert
            assert_eq!(text, TEXT, "{kind} {depth}");
        }
    }
}

#[test]
fn the_depth_rule_comes_before_the_shape_rules() {
    // AC-1: 257 `times` inside each other break the no-times-in-times rule too, and the depth
    // refusal is the one given
    // Arrange
    let fields = times_chain(257);

    // Act
    let text = refusal(fields);

    // Assert
    assert_eq!(text, TEXT);
}

#[test]
fn every_kind_builds_at_256_levels() {
    // AC-1 boundary: 256 builds, 257 is refused
    for (kind, chain) in KINDS {
        // Arrange
        let ok = chain(256);
        let over = chain(257);

        // Act
        let built = MapScheme::new(1, ok);
        let text = refusal(over);

        // Assert
        assert_eq!(built.type_number(), 1, "{kind}");
        assert_eq!(text, TEXT, "{kind}");
    }
}

/// `wrap` groups around `core`, anchored at 0 (the id of the first member of each).
fn wrapped(wrap: usize, core: Vec<Field>) -> Vec<Field> {
    let mut fields = core;
    for level in 0..wrap {
        fields = vec![group(0, format!("w{level}"), fields)];
    }
    fields
}

#[test]
fn a_list_counts_one_level_and_its_element_its_own_kind() {
    // AC-1, contract 1.0.1: `list(list(u8))` is two levels, so 254 groups around it are 256 and 255
    // are 257
    // Arrange
    let core = || vec![list("l", list("l", u8("0")))];

    // Act
    let at_limit = catch_unwind(AssertUnwindSafe(|| MapScheme::new(1, wrapped(254, core()))));
    let over = refusal(wrapped(255, core()));

    // Assert
    assert!(at_limit.is_ok());
    assert_eq!(over, TEXT);
}

#[test]
fn a_flag_bit_adds_no_level() {
    // AC-1, contract 1.0.1: two flag bits and the two groups under them are two levels, not four:
    // 254 groups around them build and 255 are refused
    // Arrange
    let byte = crate::flag_byte("m");
    let core = || {
        let inner = byte.bit(group(1, "c1", vec![u8("b")]));
        vec![byte.byte(), byte.bit(group(1, "c0", vec![inner]))]
    };

    // Act
    let at_limit = catch_unwind(AssertUnwindSafe(|| MapScheme::new(1, wrapped(254, core()))));
    let over = refusal(wrapped(255, core()));

    // Assert
    assert!(at_limit.is_ok());
    assert_eq!(over, TEXT);
}

#[test]
fn a_when_chain_of_256_packs_and_unpacks() {
    // AC-2
    if !walk_fits_stack() {
        eprintln!(
            "skipped: the debug test thread is too small for 256 levels of pack; run --release"
        );
        return;
    }
    // Arrange
    let scheme = MapScheme::new(1, when_chain(256));
    let given = row(&[("0", Value::U8(1)), ("1", Value::U8(7))]);

    // Act and Assert
    round_trip(&scheme, &given, "010107", "when");
}

#[test]
fn a_group_chain_of_256_packs_and_unpacks() {
    // AC-2
    if !walk_fits_stack() {
        eprintln!(
            "skipped: the debug test thread is too small for 256 levels of pack; run --release"
        );
        return;
    }
    // Arrange
    let scheme = MapScheme::new(1, group_chain(256));
    let given = row(&[("b", Value::U8(7))]);

    // Act and Assert
    round_trip(&scheme, &given, "0107", "group");
}

#[test]
fn a_flags_chain_of_256_packs_and_unpacks() {
    // AC-2: one presence byte per level, the member last
    if !walk_fits_stack() {
        eprintln!(
            "skipped: the debug test thread is too small for 256 levels of pack; run --release"
        );
        return;
    }
    // Arrange
    let scheme = MapScheme::new(1, flags_chain(256));
    let given = row(&[("b", Value::U8(7))]);
    let hex = format!("01{}07", "01".repeat(256));

    // Act
    let packed = pack(&scheme, &given).expect("pack");
    let unpacked = unpack(&scheme, &packed).expect("unpack");

    // Assert (unpack also reports the presence of each `flags`)
    assert_eq!(to_hex(&packed), hex);
    assert_eq!(unpacked.get("b"), Some(&Some(Value::U8(7))));
}

#[test]
fn a_list_chain_of_256_packs_and_unpacks() {
    // AC-2: a list in a list 256 times: a u16 count per level, the number last
    if !walk_fits_stack() {
        eprintln!(
            "skipped: the debug test thread is too small for 256 levels of pack; run --release"
        );
        return;
    }
    // Arrange
    let scheme = MapScheme::new(1, list_chain(256));
    let mut value = Value::U8(7);
    for _ in 0..256 {
        value = Value::List(vec![value]);
    }
    let given = row(&[("0", value)]);
    let hex = format!("01{}07", "0100".repeat(256));

    // Act and Assert
    round_trip(&scheme, &given, &hex, "list");
}

#[derive(Default)]
struct Row {
    a: u8,
    b: u8,
}

/// `u8 0`, then `depth` typed `when`s inside each other, the innermost holding `u8 1`.
fn typed_when(depth: usize) -> Vec<SchemeItem<Row>> {
    let mut inner: Vec<SchemeItem<Row>> =
        vec![BoundField::u8(1, |r: &Row| r.b, |r: &mut Row, v| r.b = v).into()];
    for _ in 0..depth {
        inner = vec![SchemeItem::when(1, eq(0u32, Value::U8(1)), inner)];
    }
    let mut items: Vec<SchemeItem<Row>> =
        vec![BoundField::u8(0, |r: &Row| r.a, |r: &mut Row, v| r.a = v).into()];
    items.extend(inner);
    items
}

#[test]
fn a_typed_when_chain_over_256_levels_is_refused() {
    // AC-1: the typed form compiles its items recursively, so it is checked before that
    for depth in [257, 1_000, 50_000] {
        // Arrange and Act (the items are built on the timed thread: they are not `Send`)
        let text = within_one_second(&format!("typed when {depth}"), move || {
            let items = typed_when(depth);
            let built = catch_unwind(AssertUnwindSafe(|| Scheme::new(1, items)));
            built.err().map(|panic| panic_text(panic.as_ref()))
        });

        // Assert
        assert_eq!(text.as_deref(), Some(TEXT), "typed when {depth}");
    }
}

#[test]
fn a_typed_when_chain_of_256_builds_packs_and_unpacks() {
    // AC-2
    // Arrange
    let scheme = Scheme::new(1, typed_when(256));
    if !walk_fits_stack() {
        eprintln!(
            "skipped: the debug test thread is too small for 256 levels of pack; run --release"
        );
        return;
    }
    let given = Row { a: 1, b: 7 };

    // Act
    let packed = crate::BinaryPacker::pack(&scheme, &given).expect("pack");
    let mut got = None;
    let mut handler = scheme.on(|row| got = Some(row));
    let outcome = crate::BinaryPacker::unpack_with(&packed, &mut [&mut handler]);

    // Assert
    assert_eq!(to_hex(&packed), "010107");
    assert!(outcome.is_ok());
    let got = got.expect("handled");
    assert_eq!((got.a, got.b), (1, 7));
}

#[derive(Default)]
struct Round {
    x: u8,
    y: u8,
}

#[derive(Default)]
struct Rounds {
    n: u8,
    rounds: Vec<Round>,
}

/// `u8 0` (the count), then a typed `times` over `Round` whose members are `u8 1`, then `depth`
/// `when`s on it, the innermost holding `u8 2`.
fn typed_times(depth: usize) -> Vec<SchemeItem<Rounds>> {
    let mut inner: Vec<SchemeItem<Round>> =
        vec![BoundField::u8(2, |r: &Round| r.y, |r: &mut Round, v| r.y = v).into()];
    for _ in 0..depth {
        inner = vec![SchemeItem::when(2, eq(1u32, Value::U8(1)), inner)];
    }
    let mut members: Vec<SchemeItem<Round>> =
        vec![BoundField::u8(1, |r: &Round| r.x, |r: &mut Round, v| r.x = v).into()];
    members.extend(inner);
    vec![
        BoundField::u8(0, |r: &Rounds| r.n, |r: &mut Rounds, v| r.n = v).into(),
        SchemeItem::times(
            1,
            0,
            |r: &Rounds| r.rounds.as_slice(),
            |r: &mut Rounds, v| r.rounds = v,
            members,
        ),
    ]
}

#[test]
fn a_typed_times_is_a_level_and_counts_its_elements() {
    // AC-1: a `times` holding 255 `when`s is 256 levels and builds; 256 `when`s are 257 and are
    // refused
    // Arrange
    let at_limit = typed_times(255);
    let over = typed_times(256);

    // Act
    let built = catch_unwind(AssertUnwindSafe(|| Scheme::new(1, at_limit)));
    let refused = catch_unwind(AssertUnwindSafe(|| Scheme::new(1, over)));

    // Assert
    assert!(built.is_ok());
    assert_eq!(panic_text(refused.err().expect("refused").as_ref()), TEXT);
}

#[test]
fn a_typed_times_with_a_deep_element_chain_is_refused_quickly() {
    // AC-1: the depth of the elements is measured when the item is built, with no recursion
    // Arrange and Act (the items are built on the timed thread: they are not `Send`)
    let text = within_one_second("typed times 5000", move || {
        let items = typed_times(5_000);
        catch_unwind(AssertUnwindSafe(|| Scheme::new(1, items)))
            .err()
            .map(|panic| panic_text(panic.as_ref()))
    });

    // Assert
    assert_eq!(text.as_deref(), Some(TEXT));
}
