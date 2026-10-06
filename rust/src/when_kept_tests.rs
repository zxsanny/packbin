use crate::walk::pack;
use crate::{
    eq, flag_byte, flags, insert, repeat, times, to_hex, u2, u8, when, MapScheme, Value, Values,
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

fn rounds(each: &[&[(&str, Value)]]) -> Value {
    Value::Groups(each.iter().map(|round| values(round)).collect())
}

fn zero() -> Value {
    Value::U8(0)
}

/// `u8 "0"; when(1, eq("0", 0), [u8 "1"]); when(2, eq("1", 0), [u8 "2"])`
fn chain_scheme() -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", zero()), vec![u8("1")]),
            when(2, eq("1", zero()), vec![u8("2")]),
        ],
    )
}

// AZ-2237 AC-8: rows whose fields were all written keep the bytes they packed before.

#[test]
fn ac8_a_chain_whose_fields_were_all_written_keeps_its_bytes() {
    // Arrange
    let scheme = chain_scheme();
    let all = values(&[("0", zero()), ("1", zero()), ("2", Value::U8(4))]);
    let one = values(&[("0", zero()), ("1", Value::U8(1)), ("2", Value::U8(4))]);

    // Act
    let (long, short) = (hex(&scheme, &all), hex(&scheme, &one));

    // Assert
    assert_eq!(long, "01000004");
    assert_eq!(short, "010001");
}

#[test]
fn ac8_a_chain_on_integer_values_keeps_its_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", Value::U8(1)), vec![u8("1")]),
            when(2, eq("1", Value::U8(5)), vec![u8("2")]),
        ],
    );
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(5)),
        ("2", Value::U8(9)),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01010509");
}

#[test]
fn ac8_repeat_rounds_that_wrote_their_fields_keep_their_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![repeat(
            0,
            vec![
                u8("0"),
                when(1, eq("0", Value::U8(1)), vec![u8("1")]),
                when(2, eq("1", Value::U8(5)), vec![u8("2")]),
            ],
        )],
    );
    let full = &[
        ("0", Value::U8(1)),
        ("1", Value::U8(5)),
        ("2", Value::U8(3)),
    ][..];
    let bare = &[("0", zero())][..];

    // Act
    let one = hex(&scheme, &values(&[("__repeat__", rounds(&[full]))]));
    let two = hex(&scheme, &values(&[("__repeat__", rounds(&[full, bare]))]));

    // Assert
    assert_eq!(one, "01010503");
    assert_eq!(two, "0101050300");
}

#[test]
fn ac8_a_times_round_that_wrote_its_fields_keeps_its_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u8("0"),
            times(
                1,
                "0",
                vec![
                    u8("1"),
                    when(2, eq("1", Value::U8(1)), vec![u8("2")]),
                    when(3, eq("2", Value::U8(5)), vec![u8("3")]),
                ],
            ),
        ],
    );
    let row = values(&[
        ("0", Value::U8(1)),
        (
            "__times_1",
            rounds(&[&[
                ("1", Value::U8(1)),
                ("2", Value::U8(5)),
                ("3", Value::U8(3)),
            ]]),
        ),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "0101010503");
}

#[test]
fn ac8_a_when_after_a_split_flag_byte_keeps_its_bytes() {
    // Arrange
    let m = flag_byte("m");
    let scheme = MapScheme::new(
        1,
        vec![
            u8("k"),
            m.byte(),
            when(2, eq("k", Value::U8(1)), vec![m.bit(u8("v"))]),
        ],
    );
    let off = values(&[("k", zero()), ("v", Value::U8(5))]);
    let on = values(&[("k", Value::U8(1)), ("v", Value::U8(5))]);

    // Act
    let (skipped, taken) = (hex(&scheme, &off), hex(&scheme, &on));

    // Assert
    assert_eq!(skipped, "010001");
    assert_eq!(taken, "01010105");
}

#[test]
fn ac8_a_when_on_a_u2_slot_keeps_its_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            u2(&["0", "1"]),
            when(2, eq("1", Value::U8(2)), vec![u8("2")]),
        ],
    );
    let hit = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(2)),
        ("2", Value::U8(9)),
    ]);
    let miss = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(1)),
        ("2", Value::U8(9)),
    ]);

    // Act
    let (taken, skipped) = (hex(&scheme, &hit), hex(&scheme, &miss));

    // Assert
    assert_eq!(taken, "010909");
    assert_eq!(skipped, "0105");
}

#[test]
fn ac8_a_when_on_a_flags_byte_keeps_its_bytes() {
    // Arrange
    let scheme = MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![u8("0")]),
            when(1, eq("0", Value::U8(3)), vec![u8("1")]),
        ],
    );
    let row = values(&[("0", Value::U8(3)), ("1", Value::U8(9))]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "01010309");
}
