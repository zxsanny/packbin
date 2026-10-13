use packbin::{
    eq, flag_byte, flags, group, insert, pack, to_hex, u8, unpack, when, Field, MapScheme,
    PackError, Value, Values,
};

// Loop 25 probes of Rust against TypeScript: D1 (AZ-2476, an anchored empty group beside a `u8`)
// and D7 (AZ-2478, a split flag bit inside a false `when`). The TypeScript hex was produced by
// running the real `typescript/src` on the same rows. Rust names its fields instead of numbering
// them; a mark (an empty `group`) is the value 1 (set) or 0 (clear) or no entry, and a name that is
// a whole number claims that id. Rust counts the flag byte and an empty group as one id each in
// its order check, which TypeScript does not, so an anchor or a numbered name after either of them
// is one higher here (the `differs_from_typescript` tests).

fn n(x: u8) -> Value {
    Value::U8(x)
}

fn v(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex_of(scheme: &MapScheme, vals: &Values) -> String {
    to_hex(&pack(scheme, vals).expect("pack"))
}

fn unpacked(scheme: &MapScheme, raw: &[u8]) -> Values {
    unpack(scheme, raw).expect("unpack")
}

fn value_of<'a>(vals: &'a Values, name: &str) -> Option<&'a Value> {
    vals.get(name).and_then(|slot| slot.as_ref())
}

// ---- D1: `Flags(0, Group(0, "mark"))` ----

fn flags_mark() -> MapScheme {
    MapScheme::new(1, vec![flags(0, "f", vec![group(0, "mark", vec![])])])
}

#[test]
fn d1_empty_group_mark_in_flags_packs_set_clear_and_absent_as_typescript() {
    // Arrange
    let scheme = flags_mark();

    // Act
    let set = hex_of(&scheme, &v(&[("mark", n(1))]));
    let clear = hex_of(&scheme, &v(&[("mark", n(0))]));
    let absent = hex_of(&scheme, &Values::new());

    // Assert: TypeScript {mark: true} 0101, {mark: false} 0100, {} 0100
    assert_eq!([set, clear, absent], ["0101", "0100", "0100"]);
}

#[test]
fn d1_empty_group_mark_in_flags_unpacks_a_set_bit_as_a_mark_and_a_clear_bit_as_none() {
    // Arrange
    let scheme = flags_mark();

    // Act
    let set = unpacked(&scheme, &[1, 1]);
    let clear = unpacked(&scheme, &[1, 0]);

    // Assert: TypeScript unpack 0101 {mark: true}, 0100 {}
    assert_eq!(
        (value_of(&set, "mark"), value_of(&clear, "mark")),
        (Some(&n(1)), None)
    );
}

#[test]
fn d1_empty_group_mark_under_a_split_bit_packs_010303_as_typescript() {
    // Arrange: split byte, bit 0 the mark, bit 1 the u8
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![m.byte(), m.bit(group(1, "mark", vec![])), m.bit(u8("n"))],
    );

    // Act
    let both = hex_of(&scheme, &v(&[("mark", n(1)), ("n", n(3))]));
    let clear_mark = hex_of(&scheme, &v(&[("mark", n(0)), ("n", n(3))]));
    let mark_only = hex_of(&scheme, &v(&[("mark", n(1))]));

    // Assert: TypeScript {mark: true, n: 3} 010303, {mark: false, n: 3} 010203, {mark: true} 0101
    assert_eq!([both, clear_mark, mark_only], ["010303", "010203", "0101"]);
}

#[test]
fn d1_empty_group_mark_under_a_split_bit_unpacks_the_mark_and_the_u8() {
    // Arrange
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![m.byte(), m.bit(group(1, "mark", vec![])), m.bit(u8("n"))],
    );

    // Act
    let got = unpacked(&scheme, &[1, 3, 3]);

    // Assert: TypeScript unpack 010303 {mark: true, n: 3}
    assert_eq!(
        (value_of(&got, "mark"), value_of(&got, "n")),
        (Some(&n(1)), Some(&n(3)))
    );
}

fn mark_then_u8() -> MapScheme {
    MapScheme::new(
        1,
        vec![flags(0, "f", vec![group(0, "mark", vec![])]), u8("n")],
    )
}

#[test]
fn d1_mark_in_flags_then_a_u8_beside_it_packs_as_typescript() {
    // Arrange: the handoff row `Flags(0, Group(0, "mark")), U8(0, "n")`
    let scheme = mark_then_u8();

    // Act
    let both = hex_of(&scheme, &v(&[("mark", n(1)), ("n", n(3))]));
    let n_only = hex_of(&scheme, &v(&[("n", n(1))]));
    let clear_mark = hex_of(&scheme, &v(&[("mark", n(0)), ("n", n(1))]));

    // Assert: TypeScript {mark: true, n: 3} 010103, {n: 1} 010001, {mark: false, n: 1} 010001
    assert_eq!([both, n_only, clear_mark], ["010103", "010001", "010001"]);
}

#[test]
fn d1_mark_in_flags_then_a_u8_beside_it_unpacks_as_typescript() {
    // Arrange
    let scheme = mark_then_u8();

    // Act
    let set = unpacked(&scheme, &[1, 1, 3]);
    let clear = unpacked(&scheme, &[1, 0, 1]);

    // Assert: TypeScript unpack 010103 {mark: true, n: 3}, 010001 {n: 1}
    assert_eq!(
        (
            value_of(&set, "mark"),
            value_of(&set, "n"),
            value_of(&clear, "mark"),
            value_of(&clear, "n")
        ),
        (Some(&n(1)), Some(&n(3)), None, Some(&n(1)))
    );
}

#[test]
fn d1_mark_in_flags_then_a_u8_beside_it_refuses_a_missing_u8_as_typescript() {
    // Arrange
    let scheme = mark_then_u8();

    // Act
    let without_n = pack(&scheme, &v(&[("mark", n(1))]));
    let empty = pack(&scheme, &Values::new());

    // Assert: TypeScript throws "missing n" for both
    assert_eq!(
        (without_n, empty),
        (
            Err(PackError::Missing("n".into())),
            Err(PackError::Missing("n".into()))
        )
    );
}

#[test]
#[should_panic(expected = "field id 0 is not the next order 1")]
fn d1_a_u8_numbered_0_beside_the_mark_is_refused_differs_from_typescript() {
    // Arrange: TypeScript gives the empty group no id, so `U8(0, "n")` builds there and packs the
    // handoff row. Rust gives the mark an id of its own, so the u8 that claims id 0 is out of order.
    let numbered: Vec<Field> = vec![flags(0, "f", vec![group(0, "mark", vec![])]), u8("0")];

    // Act
    let _ = MapScheme::new(1, numbered);

    // Assert: the should_panic message above
}

#[test]
fn d1_a_u8_numbered_1_beside_the_mark_builds_differs_from_typescript() {
    // Arrange: TypeScript refuses `U8(1, "n")` here ("field id: expected 0, got 1")
    let scheme = MapScheme::new(
        1,
        vec![flags(0, "f", vec![group(0, "mark", vec![])]), u8("1")],
    );

    // Act
    let wire = hex_of(&scheme, &v(&[("mark", n(1)), ("1", n(3))]));

    // Assert
    assert_eq!(wire, "010103");
}

#[test]
fn d1_a_when_can_name_the_mark_differs_from_typescript() {
    // Arrange: TypeScript refuses `When(0, Eq(0, true), ...)` after an empty-group mark with
    // "when 0: eq names field id 0, which is not declared earlier in the same scope". Rust builds
    // it: the mark is a value (1 or 0) that a `when` reads by name.
    let scheme = MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![group(0, "mark", vec![])]),
            when(1, eq("mark", n(1)), vec![u8("v")]),
        ],
    );

    // Act
    let set = hex_of(&scheme, &v(&[("mark", n(1)), ("v", n(7))]));
    let clear = hex_of(&scheme, &v(&[("mark", n(0)), ("v", n(7))]));

    // Assert
    assert_eq!([set, clear], ["010107", "0100"]);
}

// ---- D7: a split flag bit inside a `when` that is false ----

/// `u8 k; flag byte m; when (k == 1) { m.bit(u8 a) }; m.bit(u8 b)`. TypeScript and Go number the
/// `when` 1; Rust counts the flag byte as an id, so the `when` is 2.
fn split_bit_in_when() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("k"),
            m.byte(),
            when(2, eq("k", n(1)), vec![m.bit(u8("a"))]),
            m.bit(u8("b")),
        ],
    )
}

#[test]
fn d7_split_bit_inside_a_when_packs_the_payload_only_when_the_when_holds_as_typescript() {
    // Arrange
    let scheme = split_bit_in_when();

    // Act
    let holds = hex_of(&scheme, &v(&[("k", n(1)), ("a", n(5)), ("b", n(6))]));
    let false_with_a = hex_of(&scheme, &v(&[("k", n(0)), ("a", n(5)), ("b", n(6))]));

    // Assert: TypeScript k=1 0101030506; k=0 01000306 (a's bit set, no a byte)
    assert_eq!([holds, false_with_a], ["0101030506", "01000306"]);
}

#[test]
fn d7_split_bit_inside_a_false_when_unpacks_without_the_member_as_typescript() {
    // Arrange
    let scheme = split_bit_in_when();

    // Act
    let got = unpacked(&scheme, &[1, 0, 3, 6]);

    // Assert: TypeScript {k: 0, b: 6}; Rust also keeps the flag byte under its name "m"
    assert_eq!(
        (
            value_of(&got, "k"),
            value_of(&got, "a"),
            value_of(&got, "b")
        ),
        (Some(&n(0)), None, Some(&n(6)))
    );
}

#[test]
fn d7_repacking_the_unpacked_false_when_values_drops_the_bit_as_typescript() {
    // Arrange
    let scheme = split_bit_in_when();
    let got = unpacked(&scheme, &[1, 0, 3, 6]);

    // Act
    let repacked = hex_of(&scheme, &got);
    let from_k_and_b = hex_of(&scheme, &v(&[("k", n(0)), ("b", n(6))]));

    // Assert: TypeScript repack 01000206
    assert_eq!([repacked, from_k_and_b], ["01000206", "01000206"]);
}
