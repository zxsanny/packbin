use packbin::{
    eq, to_hex, BinaryPacker, BoundField, PackError, Scheme, SchemeItem, UnpackError, Value,
};

fn unpack_row<T: Default + 'static>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
    let mut got = None;
    BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(|row| got = Some(row))])?;
    Ok(got.expect("handler ran"))
}

#[derive(Default, Debug, PartialEq)]
struct Point {
    lat: i32,
    lon: i32,
}

#[derive(Default, Debug, PartialEq)]
struct Row {
    n: u8,
    points: Vec<Point>,
    tail: u8,
}

fn pt(lat: i32, lon: i32) -> Point {
    Point { lat, lon }
}

fn points_scheme() -> Scheme<Row> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Row| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Row| &r.points[..],
                |r, v| r.points = v,
                [
                    BoundField::i32(1, |p: &Point| p.lat, |p, v| p.lat = v).into(),
                    BoundField::i32(2, |p: &Point| p.lon, |p, v| p.lon = v).into(),
                ],
            ),
            BoundField::u8(3, |r: &Row| r.tail, |r, v| r.tail = v).into(),
        ],
    )
}

#[test]
fn ac1_readme_times_vector_packs_and_unpacks() {
    // Arrange
    let scheme = points_scheme();
    let row = Row {
        n: 2,
        points: vec![pt(10, 20), pt(30, 40)],
        tail: 7,
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "01020a000000140000001e0000002800000007");
    assert_eq!(back, row);
}

#[test]
fn ac1_four_elements_all_round_trip() {
    // Arrange
    let scheme = points_scheme();
    let row = Row {
        n: 4,
        points: vec![pt(1, 2), pt(3, 4), pt(5, 6), pt(7, 8)],
        tail: 9,
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(
        to_hex(&bytes),
        "0104010000000200000003000000040000000500000006000000070000000800000009"
    );
    assert_eq!(back, row);
}

#[derive(Debug, PartialEq)]
struct Seeded {
    n: u8,
    points: Vec<Point>,
}

impl Default for Seeded {
    fn default() -> Self {
        Seeded {
            n: 0,
            points: vec![pt(1, 1)],
        }
    }
}

#[test]
fn count_zero_replaces_a_default_vec_that_is_not_empty() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Seeded| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Seeded| &r.points[..],
                |r, v| r.points = v,
                [
                    BoundField::i32(1, |p: &Point| p.lat, |p, v| p.lat = v).into(),
                    BoundField::i32(2, |p: &Point| p.lon, |p, v| p.lon = v).into(),
                ],
            ),
        ],
    );

    // Act
    let back = unpack_row(&scheme, &[1, 0]).expect("unpack");

    // Assert
    assert_eq!(
        back,
        Seeded {
            n: 0,
            points: vec![]
        }
    );
}

#[test]
fn ac2_count_zero_packs_no_round() {
    // Arrange
    let scheme = points_scheme();
    let row = Row {
        n: 0,
        points: vec![],
        tail: 7,
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "010007");
    assert_eq!(back, row);
}

#[test]
fn ac2_count_one_keeps_the_element() {
    // Arrange
    let scheme = points_scheme();
    let row = Row {
        n: 1,
        points: vec![pt(10, 20)],
        tail: 7,
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "01010a0000001400000007");
    assert_eq!(back, row);
}

#[test]
fn ac3_count_larger_than_the_vec_names_the_times() {
    // Arrange
    let row = Row {
        n: 2,
        points: vec![pt(10, 20)],
        tail: 7,
    };

    // Act
    let result = BinaryPacker::pack(&points_scheme(), &row);

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(name)) if name.starts_with("times")),
        "{result:?}"
    );
}

#[test]
fn ac3_count_smaller_than_the_vec_names_the_times() {
    // Arrange
    let row = Row {
        n: 2,
        points: vec![pt(10, 20), pt(30, 40), pt(50, 60)],
        tail: 7,
    };

    // Act
    let result = BinaryPacker::pack(&points_scheme(), &row);

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(name)) if name.starts_with("times")),
        "{result:?}"
    );
}

#[derive(Default, Debug, PartialEq)]
struct Leg {
    a: Option<u8>,
    b: u8,
}

#[derive(Default, Debug, PartialEq)]
struct Legs {
    n: u8,
    legs: Vec<Leg>,
}

fn legs_scheme() -> Scheme<Legs> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Legs| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Legs| &r.legs[..],
                |r, v| r.legs = v,
                [
                    SchemeItem::flags(
                        1,
                        [BoundField::opt_u8(1, |l: &Leg| l.a, |l, v| l.a = v).into()],
                    ),
                    BoundField::u8(2, |l: &Leg| l.b, |l, v| l.b = v).into(),
                ],
            ),
        ],
    )
}

#[test]
fn ac4_typed_optional_member_keeps_its_round() {
    // Arrange
    let scheme = legs_scheme();
    let row = Legs {
        n: 2,
        legs: vec![Leg { a: None, b: 5 }, Leg { a: Some(9), b: 6 }],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "01020005010906");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Item {
    kind: u8,
    label: String,
    hit: Option<bool>,
}

#[derive(Default, Debug, PartialEq)]
struct Items {
    n: u8,
    items: Vec<Item>,
}

fn items_scheme() -> Scheme<Items> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Items| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Items| &r.items[..],
                |r, v| r.items = v,
                [
                    BoundField::u8(1, |i: &Item| i.kind, |i, v| i.kind = v).into(),
                    SchemeItem::when(
                        2,
                        eq(1, Value::U8(1)),
                        [
                            BoundField::utf8(2, |i: &Item| i.label.clone(), |i, v| i.label = v)
                                .into(),
                        ],
                    ),
                    SchemeItem::flags(
                        3,
                        [BoundField::bool_flag(3, |i: &Item| i.hit, |i, v| i.hit = v).into()],
                    ),
                ],
            ),
        ],
    )
}

#[test]
fn element_when_flags_and_utf8_round_trip_per_round() {
    // Arrange
    let scheme = items_scheme();
    let row = Items {
        n: 2,
        items: vec![
            Item {
                kind: 1,
                label: "ab".into(),
                hit: Some(true),
            },
            Item {
                kind: 2,
                label: String::new(),
                hit: None,
            },
        ],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "01020102006162010200");
    assert_eq!(back, row);
}

#[test]
#[should_panic(expected = "field id 0 is not in the same scope")]
fn element_reference_to_an_outer_field_is_refused() {
    let _ = Scheme::<Items>::new(
        1,
        [
            BoundField::u8(0, |r: &Items| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Items| &r.items[..],
                |r, v| r.items = v,
                [SchemeItem::when(
                    1,
                    eq(0, Value::U8(1)),
                    [BoundField::u8(1, |i: &Item| i.kind, |i, v| i.kind = v).into()],
                )],
            ),
        ],
    );
}

#[test]
#[should_panic(expected = "field id 2 is not the next order 1")]
fn element_ids_must_start_at_the_anchor() {
    let _ = Scheme::<Items>::new(
        1,
        [
            BoundField::u8(0, |r: &Items| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Items| &r.items[..],
                |r, v| r.items = v,
                [BoundField::u8(2, |i: &Item| i.kind, |i, v| i.kind = v).into()],
            ),
        ],
    );
}
