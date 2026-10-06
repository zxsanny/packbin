use crate::walk::{pack, unpack};
use crate::{
    eq, flag_byte, flags, insert, sized, times, to_hex, u8, when, MapScheme, PackError, Value,
    Values,
};

fn values(pairs: &[(&str, Value)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(value.clone()));
    }
    vals
}

fn hex(scheme: &MapScheme, vals: &Values) -> String {
    to_hex(&pack(scheme, vals).expect("pack"))
}

fn zero() -> Value {
    Value::U8(0)
}

// A `when` or a count that names a flags byte or a split flag byte reads the byte pack wrote.

/// `u8 "0"; flags(1, "f", [u8 "1"]); when(2, eq("f", 1), [u8 "2"])`
fn when_on_flags_byte() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            flags(1, "f", vec![u8("1")]),
            when(2, eq("f", Value::U8(1)), vec![u8("2")]),
        ],
    )
}

#[test]
fn a_when_on_a_flags_byte_reads_the_byte_pack_wrote() {
    // Arrange
    let scheme = when_on_flags_byte();
    let row = values(&[
        ("0", Value::U8(5)),
        ("1", Value::U8(7)),
        ("2", Value::U8(9)),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "0105010709");
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn a_when_on_a_flags_byte_ignores_a_value_kept_in_the_row() {
    // Arrange
    let scheme = when_on_flags_byte();
    let row = values(&[
        ("0", Value::U8(5)),
        ("1", Value::U8(7)),
        ("2", Value::U8(9)),
        ("f", Value::U8(0)),
    ]);

    // Act
    let result = hex(&scheme, &row);

    // Assert
    assert_eq!(result, "0105010709");
}

/// `u8 "0"; m.byte(); m.bit(u8 "2"); when(3, eq("m", 1), [u8 "3"])`
fn when_on_split_byte() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("0"),
            m.byte(),
            m.bit(u8("2")),
            when(3, eq("m", Value::U8(1)), vec![u8("3")]),
        ],
    )
}

#[test]
fn a_when_on_a_split_flag_byte_reads_the_byte_pack_wrote() {
    // Arrange
    let scheme = when_on_split_byte();
    let row = values(&[
        ("0", Value::U8(1)),
        ("2", Value::U8(5)),
        ("3", Value::U8(8)),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "0101010508");
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn a_when_on_a_split_flag_byte_with_a_clear_bit_does_not_match() {
    // Arrange
    let scheme = when_on_split_byte();
    let row = values(&[("0", Value::U8(1)), ("3", Value::U8(8))]);

    // Act
    let result = hex(&scheme, &row);

    // Assert
    assert_eq!(result, "010100");
}

#[test]
fn a_count_that_names_a_flags_byte_reads_the_byte_pack_wrote() {
    // Arrange
    let scheme = MapScheme::new(1, vec![flags(0, "f", vec![u8("0")]), sized("1", "f")]);
    let row = values(&[
        ("0", Value::U8(5)),
        ("1", Value::Bytes(vec![0xaa])),
        ("f", Value::U8(3)),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010105aa");
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn a_count_that_names_a_split_flag_byte_reads_the_byte_pack_wrote() {
    // Arrange
    let m = flag_byte("m");
    let scheme = MapScheme::new(1, vec![u8("0"), m.byte(), m.bit(u8("2")), sized("3", "m")]);
    let row = values(&[
        ("0", Value::U8(1)),
        ("2", Value::U8(5)),
        ("3", Value::Bytes(vec![0xaa])),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01010105aa");
    assert!(unpack(&scheme, &raw).is_ok());
}

// A `times` leaves, in the scope around it, one list under each name its rounds wrote, as unpack
// does; a name the scope held before is that list now, so a `when` on it does not match.

/// `u8 "0"; m.byte(); times(2, "0", [m.byte(), u8 "3"]); when(4, eq("m", 0), [u8 "4"])`
fn when_after_times() -> MapScheme {
    let m = flag_byte("m");
    MapScheme::new(
        1,
        vec![
            u8("0"),
            m.byte(),
            times(2, "0", vec![m.byte(), u8("3")]),
            when(4, eq("m", zero()), vec![u8("4")]),
        ],
    )
}

const AFTER_TIMES_HEX: &str = "0101000007";

fn unpacked_after_times() -> Values {
    let scheme = when_after_times();
    unpack(&scheme, &[0x01, 0x01, 0x00, 0x00, 0x07]).expect("unpack")
}

#[test]
fn a_name_a_times_round_wrote_is_a_list_after_it_so_a_when_on_it_does_not_match() {
    // Arrange
    let scheme = when_after_times();
    let row = unpacked_after_times();

    // Act
    let again = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&again), AFTER_TIMES_HEX);
}

#[test]
fn a_body_kept_for_a_when_after_a_times_is_not_written() {
    // Arrange
    let scheme = when_after_times();
    let mut row = unpacked_after_times();
    insert(&mut row, "4", Some(Value::U8(9)));

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), AFTER_TIMES_HEX);
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn the_same_holds_when_the_times_is_packed_from_per_name_lists() {
    // Arrange
    let scheme = when_after_times();
    let mut row = unpacked_after_times();
    row.remove("__times_2");
    insert(&mut row, "4", Some(Value::U8(9)));

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), AFTER_TIMES_HEX);
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn a_times_without_rounds_leaves_the_name_it_did_not_write_as_it_was() {
    // Arrange
    let scheme = when_after_times();
    let row = values(&[("0", zero()), ("4", Value::U8(9))]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result.map(|raw| to_hex(&raw)), Ok("01000009".to_string()));
}

#[test]
fn a_count_after_a_times_that_names_a_round_name_is_not_an_integer() {
    // Arrange
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            m.byte(),
            times(2, "0", vec![m.byte(), u8("3")]),
            sized("4", "m"),
        ],
    );
    let row = values(&[
        ("0", Value::U8(1)),
        ("4", Value::Bytes(vec![])),
        (
            "__times_2",
            Value::Groups(vec![values(&[("3", Value::U8(7))])]),
        ),
    ]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, Err(PackError::Type("m".to_string())));
}
