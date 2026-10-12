use packbin::{
    bytes, eq, flag_byte, flags, group, insert, list, pack, repeat, times, to_hex, u32, u8, when,
    BoundField, Field, MapScheme, PackError, Scheme, SchemeItem, Value, Values,
};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::{Duration, Instant};

// AZ-2390 (F33): a `repeat` or `times` whose body holds no member is refused when the scheme is built
// (`_docs/03_implementation/reference_loop21_slots.md` section 2, rows 15 to 26). A member is any
// field but a container that holds none (looking through `when`, groups and flag bits); a zero-width
// `bytes`, a flag byte and a member-less `flags` are members. Rust refuses a scheme it cannot
// round-trip by panicking in `MapScheme::new` (see its doc), so the refusal is a panic carrying
// TypeScript's text.

fn built(fields: Vec<Field>) -> Result<MapScheme, String> {
    catch_unwind(AssertUnwindSafe(|| MapScheme::new(1, fields))).map_err(|panic| {
        match panic.downcast_ref::<String>() {
            Some(text) => text.clone(),
            None => panic
                .downcast_ref::<&str>()
                .map_or_else(String::new, |s| (*s).to_string()),
        }
    })
}

fn empty_body(kind: &str, anchor: u32) -> String {
    format!(
        "{kind} {anchor}: the body holds no member; a round of it would charge no slot and write \
         nothing"
    )
}

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn rounds(rows: &[Values]) -> Values {
    v(&[("__repeat__", Value::Groups(rows.to_vec()))])
}

fn hex_of(result: Result<Vec<u8>, PackError>) -> Result<String, PackError> {
    result.map(|raw| to_hex(&raw))
}

fn n(x: u8) -> Value {
    Value::U8(x)
}

#[test]
fn ac1_row_15_an_empty_repeat_is_refused_naming_it() {
    // Arrange / Act
    let refused = built(vec![repeat(0, vec![])]).err();

    // Assert
    assert_eq!(refused, Some(empty_body("repeat", 0)));
}

#[test]
fn ac1_row_16_an_empty_times_is_refused_naming_it() {
    // Arrange / Act
    let refused = built(vec![u8("0"), times(1, "0", vec![])]).err();

    // Assert
    assert_eq!(refused, Some(empty_body("times", 1)));
}

#[test]
fn ac1_row_17_a_body_of_an_empty_when_holds_no_member() {
    // Arrange / Act
    let refused = built(vec![repeat(
        0,
        vec![when(0, eq("x", n(1)), vec![])],
    )])
    .err();

    // Assert
    assert_eq!(refused, Some(empty_body("repeat", 0)));
}

#[test]
fn ac1_row_18_nested_empty_whens_hold_no_member() {
    // Arrange / Act
    let refused = built(vec![repeat(
        0,
        vec![when(
            0,
            eq("x", n(1)),
            vec![when(0, eq("x", n(2)), vec![])],
        )],
    )])
    .err();

    // Assert
    assert_eq!(refused, Some(empty_body("repeat", 0)));
}

#[test]
fn ac1_row_19_a_lone_empty_group_keeps_its_existing_error() {
    // Arrange / Act
    let refused = built(vec![repeat(0, vec![group(0, "g", vec![])])]).err();

    // Assert: an empty group cannot stand alone, and that is judged first
    let text = refused.expect("refused");
    assert!(text.contains("a bool or empty group is allowed only directly inside flags"), "{text}");
}

#[test]
fn ac2_row_20_the_f33_request_shape_fails_at_build_in_under_one_second() {
    // Arrange: Rust cannot put a group in a list (a list element is one value), so the shape is
    // the `times` with no member that the request carried, at the top level
    let started = Instant::now();

    // Act
    let refused = built(vec![u32("0"), times(1, "0", vec![])]).err();

    // Assert
    assert_eq!(refused, Some(empty_body("times", 1)));
    assert!(started.elapsed() < Duration::from_secs(1));
}

#[test]
fn ac2_row_20_a_typed_scheme_with_an_empty_times_fails_at_build_too() {
    // Arrange
    #[derive(Default)]
    struct Pt;
    #[derive(Default)]
    struct Row {
        n: u32,
        pts: Vec<Pt>,
    }
    let started = Instant::now();

    // Act
    let refused = catch_unwind(AssertUnwindSafe(|| {
        Scheme::new(
            1,
            [
                BoundField::u32(0, |r: &Row| r.n, |r, v| r.n = v).into(),
                SchemeItem::times(1, 0, |r: &Row| &r.pts[..], |r, v| r.pts = v, []),
            ],
        )
    }));

    // Assert
    assert!(refused.is_err());
    assert!(started.elapsed() < Duration::from_secs(1));
    let panic = refused.err().expect("panic");
    let text = panic.downcast_ref::<String>().cloned().unwrap_or_default();
    assert_eq!(text, empty_body("times", 1));
}

#[test]
fn ac2_row_20_the_f33_request_shape_as_a_list_of_groups_fails_at_build_with_the_same_text() {
    // Arrange: `list(items, group(item, [u32 n, times n {}]))`; the empty body is judged before the
    // rule that a list element is one value
    let started = Instant::now();

    // Act
    let refused = built(vec![list(
        "items",
        group(0, "item", vec![u32("0"), times(1, "0", vec![])]),
    )])
    .err();

    // Assert
    assert_eq!(refused, Some(empty_body("times", 1)));
    assert!(started.elapsed() < Duration::from_secs(1));
}

#[test]
fn row_20_a_group_with_members_is_not_a_list_element_in_rust_for_another_reason() {
    // Arrange / Act
    let refused = built(vec![list(
        "items",
        group(0, "item", vec![u32("0"), times(1, "0", vec![u8("1")])]),
    )])
    .err();

    // Assert
    let text = refused.expect("refused");
    assert!(text.contains("cannot carry element"), "{text}");
}

#[test]
fn row_21_a_zero_width_bytes_body_builds_and_pack_is_bounded_by_slots() {
    // Arrange
    let scheme = MapScheme::new(1, vec![u8("n"), times(1, "n", vec![bytes("v", 0)])])
        .with_limits(65_535, 5);
    let mut vals = v(&[("n", n(10))]);
    insert(&mut vals, "v", Some(Value::List(vec![Value::Bytes(vec![]); 10])));

    // Act
    let refused = pack(&scheme, &vals);

    // Assert
    assert_eq!(
        refused,
        Err(PackError::Type(
            "v: the rounds would hold 6 slots, above the limit of 5 slots".to_string()
        ))
    );
}

#[test]
fn row_22_a_flag_byte_is_a_member() {
    // Arrange
    let scheme = MapScheme::new(1, vec![repeat(0, vec![flag_byte("m").byte()])]);

    // Act
    let wire = hex_of(pack(&scheme, &Values::new()));

    // Assert
    assert_eq!(wire, Ok("01".to_string()));
}

#[test]
fn row_23_a_flags_without_members_is_a_member() {
    // Arrange
    let scheme = MapScheme::new(1, vec![repeat(0, vec![flags(0, "f", vec![])])]);

    // Act
    let wire = hex_of(pack(&scheme, &Values::new()));

    // Assert
    assert_eq!(wire, Ok("01".to_string()));
}

#[test]
fn ac3_row_24_a_one_member_body_builds_and_packs_as_before() {
    // Arrange
    let by_repeat = MapScheme::new(1, vec![repeat(0, vec![u8("0")])]);
    let by_times = MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])]);
    let mut counted = v(&[("0", n(2))]);
    insert(&mut counted, "1", Some(Value::List(vec![n(7), n(8)])));

    // Act
    let repeated = hex_of(pack(&by_repeat, &rounds(&[v(&[("0", n(7))]), v(&[("0", n(8))])])));
    let counted_wire = hex_of(pack(&by_times, &counted));

    // Assert
    assert_eq!(repeated, Ok("010708".to_string()));
    assert_eq!(counted_wire, Ok("01020708".to_string()));
}

#[test]
fn row_25_the_same_empty_body_is_refused_wherever_it_stands() {
    // Arrange
    let fb = flag_byte("fb");
    let cases: Vec<(&str, Vec<Field>, String)> = vec![
        (
            "under flags",
            vec![flags(0, "f", vec![repeat(0, vec![])])],
            empty_body("repeat", 0),
        ),
        (
            "under a flag bit",
            vec![fb.byte(), fb.bit(repeat(1, vec![]))],
            empty_body("repeat", 1),
        ),
        (
            "under a when",
            vec![u8("0"), when(1, eq("0", n(1)), vec![repeat(1, vec![])])],
            empty_body("repeat", 1),
        ),
        (
            "under a group",
            vec![group(0, "g", vec![repeat(0, vec![])])],
            empty_body("repeat", 0),
        ),
        (
            "a times inside a repeat",
            vec![repeat(0, vec![u8("0"), times(1, "0", vec![])])],
            empty_body("times", 1),
        ),
    ];

    for (place, fields, expected) in cases {
        // Act
        let refused = built(fields).err();

        // Assert
        assert_eq!(refused, Some(expected), "{place}");
    }
}

#[test]
fn row_26_a_flags_holding_an_empty_group_is_a_member_because_it_writes_a_byte() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![repeat(0, vec![flags(0, "f", vec![group(0, "g", vec![])])])],
    );

    // Act
    let wire = hex_of(pack(&scheme, &rounds(&[v(&[("g", n(1))]), Values::new()])));

    // Assert
    assert_eq!(wire, Ok("010100".to_string()));
}
