#![cfg(feature = "std")]
use packbin::{
    bits, eq, flag_byte, flags, group, insert, pack, packed, sized, times, to_hex, u16, u8, when,
    Field, MapScheme, PackError, Value, Values,
};

// AZ-2386 (rows 44 to 52) and AZ-2387 (rows 53 to 56) of
// `_docs/03_implementation/reference_loop21_slots.md`: a count behind a clear `when`. An error is
// a `PackError`; the texts are Rust's own where it already had one, and TypeScript's where the
// row is new.

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

fn hex_of(scheme: &MapScheme, vals: &Values) -> Result<String, PackError> {
    pack(scheme, vals).map(|raw| to_hex(&raw))
}

fn text(result: Result<String, PackError>) -> String {
    match result {
        Err(PackError::Type(message)) => message,
        other => panic!("expected a type error, got {other:?}"),
    }
}

fn heading_row(extra: &[(&str, Value)]) -> Values {
    let mut vals = v(&[("heading", Value::U16(90))]);
    for (name, value) in extra {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

// ---- AZ-2386: a count above 0 behind a clear when, no rounds (rows 44 to 52) ----

const NOT_WRITTEN: &str = "the when that holds it is clear), so its times reads no round; give the \
                           count 0, leave it out, or make the when hold";

fn unwritten(count: u64) -> String {
    format!("pt: the count c is {count} in the row, but no field wrote it ({NOT_WRITTEN}")
}

/// `u8 mode; when mode == 1 { u8 c }`, the head of every scheme of the section
fn head() -> Vec<Field> {
    vec![u8("mode"), when(1, eq("mode", n(1)), vec![u8("c")])]
}

/// The head, then `flagByte fb; bit { times(c) { u8 pt } }; bit { u16 heading }`
fn split_behind_when() -> MapScheme {
    let fb = flag_byte("fb");
    let mut fields = head();
    fields.extend([
        fb.byte(),
        fb.bit(times(3, "c", vec![u8("pt")])),
        fb.bit(u16("heading")),
    ]);
    MapScheme::new(1, fields)
}

/// The head, then `flags { times(c) { u8 pt }; u16 heading }`
fn combined_behind_when() -> MapScheme {
    let mut fields = head();
    fields.push(flags(
        2,
        "f",
        vec![times(2, "c", vec![u8("pt")]), u16("heading")],
    ));
    MapScheme::new(1, fields)
}

fn mode_row(mode: u8, extra: &[(&str, Value)]) -> Values {
    let mut vals = heading_row(extra);
    insert(&mut vals, "mode", Some(n(mode)));
    vals
}

#[test]
fn az2386_row_44_count_above_zero_behind_a_clear_when_is_refused_at_the_split_bit() {
    // Arrange
    let vals = mode_row(0, &[("c", n(1))]);

    // Act
    let message = text(hex_of(&split_behind_when(), &vals));

    // Assert
    assert_eq!(message, unwritten(1));
}

#[test]
fn az2386_row_45_an_empty_body_list_does_not_change_the_refusal() {
    // Arrange
    let vals = mode_row(0, &[("c", n(1)), ("pt", Value::List(vec![]))]);

    // Act
    let message = text(hex_of(&split_behind_when(), &vals));

    // Assert
    assert_eq!(message, unwritten(1));
}

#[test]
fn az2386_row_46_the_count_is_printed_as_a_number_whatever_its_width() {
    // Arrange
    let vals = mode_row(0, &[("c", Value::U64(3))]);

    // Act
    let message = text(hex_of(&split_behind_when(), &vals));

    // Assert
    assert_eq!(message, unwritten(3));
}

#[test]
fn az2386_ac2_rows_47_and_48_count_zero_and_a_count_left_out_pack_a_clear_bit() {
    // Arrange
    let zero = mode_row(0, &[("c", n(0))]);
    let left_out = mode_row(0, &[]);

    // Act
    let by_zero = hex_of(&split_behind_when(), &zero);
    let by_none = hex_of(&split_behind_when(), &left_out);

    // Assert
    assert_eq!(by_zero, Ok("0100025a00".to_string()));
    assert_eq!(by_none, Ok("0100025a00".to_string()));
}

#[test]
fn az2386_row_49_a_body_given_is_refused_first_by_the_older_rule() {
    // Arrange
    let vals = mode_row(0, &[("c", n(2)), ("pt", Value::List(vec![n(5), n(6)]))]);

    // Act
    let message = text(hex_of(&split_behind_when(), &vals));

    // Assert
    assert_eq!(
        message,
        "'pt' is given, but its times count 'c' is not written where the flag byte is written \
         (skipped or written after it); write 'c' before the flag byte"
    );
}

#[test]
fn az2386_row_50_count_above_zero_behind_a_clear_when_is_refused_in_a_combined_flags() {
    // Arrange
    let vals = mode_row(0, &[("c", n(2))]);

    // Act
    let message = text(hex_of(&combined_behind_when(), &vals));

    // Assert
    assert_eq!(message, unwritten(2));
}

#[test]
fn az2386_ac2_a_combined_flags_with_count_zero_or_left_out_packs_a_clear_bit() {
    // Arrange
    let zero = mode_row(0, &[("c", n(0))]);
    let left_out = mode_row(0, &[]);

    // Act
    let by_zero = hex_of(&combined_behind_when(), &zero);
    let by_none = hex_of(&combined_behind_when(), &left_out);

    // Assert
    assert_eq!(by_zero, Ok("0100025a00".to_string()));
    assert_eq!(by_none, Ok("0100025a00".to_string()));
}

#[test]
fn az2386_row_51_a_holding_when_packs_as_before() {
    // Arrange
    let vals = mode_row(1, &[("c", n(1)), ("pt", Value::List(vec![n(5)]))]);

    // Act
    let split = hex_of(&split_behind_when(), &vals);
    let combined = hex_of(&combined_behind_when(), &vals);

    // Assert
    assert_eq!(split, Ok("01010103055a00".to_string()));
    assert_eq!(combined, Ok("01010103055a00".to_string()));
}

#[test]
fn az2386_row_52_a_plain_times_after_the_when_names_the_missing_count_before_and_after() {
    // Arrange
    let mut fields = head();
    fields.extend([times(2, "c", vec![u8("pt")]), u16("heading")]);
    let scheme = MapScheme::new(1, fields);

    // Act
    let one = hex_of(&scheme, &mode_row(0, &[("c", n(1))]));
    let zero = hex_of(&scheme, &mode_row(0, &[("c", n(0))]));

    // Assert
    assert_eq!(one, Err(PackError::Missing("c".to_string())));
    assert_eq!(zero, Err(PackError::Missing("c".to_string())));
}

#[test]
fn az2386_the_refusal_reaches_a_times_through_a_group_and_a_when_that_holds() {
    // Arrange: the bit holds a group, then a `when` that holds, around the same times
    let fb = flag_byte("fb");
    let by_group = {
        let mut fields = head();
        fields.extend([
            fb.byte(),
            fb.bit(group(3, "g", vec![times(3, "c", vec![u8("pt")])])),
        ]);
        MapScheme::new(1, fields)
    };
    let fb = flag_byte("fb");
    let by_when = {
        let mut fields = head();
        fields.extend([
            fb.byte(),
            fb.bit(when(3, eq("mode", n(0)), vec![times(3, "c", vec![u8("pt")])])),
        ]);
        MapScheme::new(1, fields)
    };
    let vals = mode_row(0, &[("c", n(1))]);

    // Act
    let through_group = text(hex_of(&by_group, &vals));
    let through_when = text(hex_of(&by_when, &vals));

    // Assert
    assert_eq!(through_group, unwritten(1));
    assert_eq!(through_when, unwritten(1));
}

// ---- AZ-2387: bits, packed and sized counts behind a clear when (rows 53 to 56) ----

type Member = fn() -> Field;

fn members() -> Vec<(&'static str, Member)> {
    vec![
        ("bits", || bits("v", "c")),
        ("packed", || packed(1, "v", "c", 0)),
        ("sized", || sized("v", "c")),
    ]
}

/// The head, then the member plain, as a split bit, or in a combined `flags`.
fn placed(position: &str, member: Field) -> MapScheme {
    let mut fields = head();
    match position {
        "plain" => fields.push(member),
        "split" => {
            let fb = flag_byte("fb");
            fields.extend([fb.byte(), fb.bit(member)]);
        }
        _ => fields.push(flags(2, "f", vec![member])),
    }
    MapScheme::new(1, fields)
}

fn counted_value(kind: &str) -> Value {
    if kind == "sized" {
        Value::Bytes(vec![1, 2, 3])
    } else {
        Value::List(vec![n(1), n(0), n(1)])
    }
}

#[test]
fn az2387_row_53_a_count_behind_a_clear_when_is_refused_for_all_three_kinds_in_all_positions() {
    for (kind, member) in members() {
        for position in ["plain", "split", "flags"] {
            // Arrange
            let scheme = placed(position, member());
            let vals = mode_row(0, &[("c", n(3)), ("v", counted_value(kind))]);

            // Act
            let result = pack(&scheme, &vals);

            // Assert: no bytes, and the count is named
            assert_eq!(result, Err(PackError::Missing("c".to_string())), "{kind} {position}");
        }
    }
}

#[test]
fn az2387_rows_54_and_55_a_count_behind_a_set_when_packs() {
    // Arrange
    let expected = |kind: &str, position: &str| match (kind, position) {
        ("sized", "plain") => "010103010203",
        ("sized", _) => "01010301010203",
        (_, "plain") => "01010305",
        _ => "0101030105",
    };

    for (kind, member) in members() {
        for position in ["plain", "split"] {
            // Arrange
            let scheme = placed(position, member());
            let vals = mode_row(1, &[("c", n(3)), ("v", counted_value(kind))]);

            // Act
            let wire = hex_of(&scheme, &vals);

            // Assert
            assert_eq!(wire, Ok(expected(kind, position).to_string()), "{kind} {position}");
        }
    }
}

#[test]
fn az2387_row_56_no_value_behind_a_clear_when_is_refused_since_az_2410() {
    for (kind, member) in members() {
        for position in ["split", "flags"] {
            // Arrange
            let scheme = placed(position, member());
            let vals = mode_row(0, &[("c", n(3))]);

            // Act
            let message = text(hex_of(&scheme, &vals));

            // Assert: loop 22 U11, the same rule as for a `times` (AZ-2386)
            assert_eq!(
                message,
                "v: the count c is 3 in the row, but no field wrote it (the when that holds it is \
                 clear), so the member reads nothing; give the count 0, leave it out, or make the \
                 when hold",
                "{kind} {position}"
            );
        }
    }
}
