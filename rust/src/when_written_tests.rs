use crate::walk::{pack, unpack};
use crate::{
    bits, eq, flags, group, insert, packed, repeat, sized, times, to_hex, u8, when, BinaryPacker,
    BoundField, MapScheme, PackError, Scheme, SchemeItem, UnpackError, Value, Values,
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

fn bytes_of(raw: &[u8]) -> Value {
    Value::Bytes(raw.to_vec())
}

fn ints(items: &[u8]) -> Value {
    Value::List(items.iter().map(|n| Value::U8(*n)).collect())
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

// AC-1

#[test]
fn ac1_a_when_on_a_skipped_field_does_not_match_on_pack() {
    // Arrange
    let scheme = chain_scheme();
    let row = values(&[("0", Value::U8(1)), ("1", zero()), ("2", Value::U8(4))]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");
    let got = unpack(&scheme, &raw).expect("unpack");

    // Assert
    assert_eq!(to_hex(&raw), "0101");
    assert_eq!(got, values(&[("0", Value::U8(1))]));
}

// AC-2

#[derive(Default, Debug, PartialEq)]
struct Chain {
    p: u8,
    n: Option<u8>,
    v: Option<u8>,
}

fn typed_chain() -> Scheme<Chain> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Chain| r.p, |r: &mut Chain, v| r.p = v).into(),
            SchemeItem::when(
                1,
                eq(0, zero()),
                [BoundField::opt_u8(1, |r: &Chain| r.n, |r: &mut Chain, v| r.n = v).into()],
            ),
            SchemeItem::when(
                2,
                eq(1, zero()),
                [BoundField::opt_u8(2, |r: &Chain| r.v, |r: &mut Chain, v| r.v = v).into()],
            ),
        ],
    )
}

fn typed_unpack(scheme: &Scheme<Chain>, raw: &[u8]) -> Result<Chain, UnpackError> {
    let mut got = Chain::default();
    BinaryPacker::unpack_with(raw, &mut [&mut scheme.on(|row| got = row)])?;
    Ok(got)
}

#[test]
fn ac2_the_typed_scheme_agrees() {
    // Arrange
    let scheme = typed_chain();
    let row = Chain {
        p: 1,
        n: Some(0),
        v: Some(4),
    };

    // Act
    let raw = BinaryPacker::pack(&scheme, &row).expect("pack");
    let got = typed_unpack(&scheme, &raw);

    // Assert
    assert_eq!(to_hex(&raw), "0101");
    assert_eq!(
        got,
        Ok(Chain {
            p: 1,
            n: None,
            v: None
        })
    );
}

// AC-3

/// `flags(0, "f", [group(0, "on", [])]); when(1, eq("on", test), [u8 "1"])`
fn bool_when(test: Value) -> MapScheme {
    MapScheme::new(
        1,
        vec![
            flags(0, "f", vec![group(0, "on", vec![])]),
            when(1, eq("on", test), vec![u8("1")]),
        ],
    )
}

#[test]
fn ac3_eq_false_on_a_clear_bit_does_not_write_its_body() {
    // Arrange
    let scheme = bool_when(zero());
    let clear = values(&[("on", zero()), ("1", Value::U8(7))]);
    let absent = values(&[("1", Value::U8(7))]);

    // Act
    let (with_zero, without) = (hex(&scheme, &clear), hex(&scheme, &absent));

    // Assert
    assert_eq!(with_zero, "0100");
    assert_eq!(without, "0100");
    assert_eq!(unpack(&scheme, &[1, 0]), Ok(values(&[("f", zero())])));
}

#[test]
fn ac3_eq_true_writes_its_body_only_on_a_set_bit() {
    // Arrange
    let scheme = bool_when(Value::U8(1));
    let set = values(&[("on", Value::U8(1)), ("1", Value::U8(7))]);
    let clear = values(&[("on", zero()), ("1", Value::U8(7))]);

    // Act
    let (on, off) = (hex(&scheme, &set), hex(&scheme, &clear));

    // Assert
    assert_eq!(on, "010107");
    assert_eq!(off, "0100");
    assert_eq!(
        unpack(&scheme, &[1, 1, 7]),
        Ok(values(&[
            ("f", Value::U8(1)),
            ("on", Value::U8(1)),
            ("1", Value::U8(7))
        ]))
    );
    assert_eq!(unpack(&scheme, &[1, 0]), Ok(values(&[("f", zero())])));
}

// AC-4

fn skipped_count(count_field: crate::Field) -> MapScheme {
    MapScheme::new(
        1,
        vec![
            u8("0"),
            when(1, eq("0", zero()), vec![u8("1")]),
            count_field,
        ],
    )
}

fn missing_one() -> Result<Vec<u8>, PackError> {
    Err(PackError::Missing("1".to_string()))
}

#[test]
fn ac4_a_sized_count_that_names_a_skipped_field_is_missing() {
    // Arrange
    let scheme = skipped_count(sized("2", "1"));
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(2)),
        ("2", bytes_of(&[0xaa, 0xbb])),
    ]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, missing_one());
}

#[test]
fn ac4_a_sized_count_that_names_a_written_field_packs_as_before() {
    // Arrange
    let scheme = skipped_count(sized("2", "1"));
    let row = values(&[
        ("0", zero()),
        ("1", Value::U8(2)),
        ("2", bytes_of(&[0xaa, 0xbb])),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&raw), "010002aabb");
    assert!(unpack(&scheme, &raw).is_ok());
}

#[test]
fn ac4_a_bits_count_that_names_a_skipped_field_is_missing() {
    // Arrange
    let scheme = skipped_count(bits("2", "1"));
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(2)),
        ("2", ints(&[1, 0])),
    ]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, missing_one());
}

#[test]
fn ac4_a_packed_count_that_names_a_skipped_field_is_missing() {
    // Arrange
    let scheme = skipped_count(packed(2, "2", "1", 0));
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(2)),
        ("2", ints(&[1, 2])),
    ]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, missing_one());
}

#[test]
fn ac4_a_times_count_that_names_a_skipped_field_is_missing() {
    // Arrange
    let scheme = skipped_count(times(2, "1", vec![u8("2")]));
    let row = values(&[
        ("0", Value::U8(1)),
        ("1", Value::U8(2)),
        ("2", ints(&[7, 8])),
    ]);

    // Act
    let result = pack(&scheme, &row);

    // Assert
    assert_eq!(result, missing_one());
}

// AC-5

#[test]
fn ac5_a_repeat_round_decides_from_what_the_round_wrote() {
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
    let row = values(&[(
        "__repeat__",
        rounds(&[&[("0", zero()), ("1", Value::U8(5)), ("2", Value::U8(3))]]),
    )]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");
    let got = unpack(&scheme, &raw).expect("unpack");

    // Assert
    assert_eq!(to_hex(&raw), "0100");
    assert_eq!(got, values(&[("__repeat__", rounds(&[&[("0", zero())]]))]));
}

#[test]
fn ac5_a_times_round_decides_from_what_the_round_wrote() {
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
            rounds(&[&[("1", zero()), ("2", Value::U8(5)), ("3", Value::U8(3))]]),
        ),
    ]);

    // Act
    let raw = pack(&scheme, &row).expect("pack");
    let got = unpack(&scheme, &raw).expect("unpack");

    // Assert
    assert_eq!(to_hex(&raw), "010100");
    assert_eq!(got.get("1"), Some(&Some(ints(&[0]))));
    assert_eq!(got.get("2"), None);
}
