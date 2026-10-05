use packbin::{eq, to_hex, BinaryPacker, BoundField, Scheme, SchemeItem, UnpackError, Value};
use std::time::{Duration, Instant};

fn parse_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

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

fn pt(lat: i32, lon: i32) -> Point {
    Point { lat, lon }
}

#[derive(Default, Debug, PartialEq)]
struct Route {
    sid: u16,
    name: u16,
    unit: Option<u16>,
    straight: Option<bool>,
    route_id: Option<u16>,
    count: u8,
    kinds: Vec<u8>,
    points: Vec<Point>,
    mask: Vec<u8>,
}

fn route_scheme() -> Scheme<Route> {
    Scheme::new(
        0x34,
        [
            BoundField::u16(0, |r: &Route| r.sid, |r, v| r.sid = v).into(),
            BoundField::u16(1, |r: &Route| r.name, |r, v| r.name = v).into(),
            SchemeItem::flags(
                2,
                [
                    BoundField::opt_u16(2, |r: &Route| r.unit, |r, v| r.unit = v).into(),
                    BoundField::bool_flag(3, |r: &Route| r.straight, |r, v| r.straight = v).into(),
                    BoundField::opt_u16(4, |r: &Route| r.route_id, |r, v| r.route_id = v).into(),
                ],
            ),
            BoundField::u8(5, |r: &Route| r.count, |r, v| r.count = v).into(),
            BoundField::packed(2, 6, 5, 0, |r: &Route| r.kinds.clone(), |r, v| r.kinds = v).into(),
            SchemeItem::times(
                7,
                5,
                |r: &Route| &r.points[..],
                |r, v| r.points = v,
                [
                    BoundField::i32(7, |p: &Point| p.lat, |p, v| p.lat = v).into(),
                    BoundField::i32(8, |p: &Point| p.lon, |p, v| p.lon = v).into(),
                ],
            ),
            SchemeItem::when(
                9,
                eq(3, Value::U8(1)),
                [
                    BoundField::packed(1, 9, 5, -1, |r: &Route| r.mask.clone(), |r, v| r.mask = v)
                        .into(),
                ],
            ),
        ],
    )
}

const ROUTE_HEX: &str = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101";

#[test]
fn ac5_typed_route_matches_the_fixture_both_ways() {
    // Arrange
    let scheme = route_scheme();
    let row = Route {
        sid: 16,
        name: 21,
        unit: None,
        straight: Some(true),
        route_id: Some(45),
        count: 2,
        kinds: vec![1, 3],
        points: vec![pt(500000000, 300000000), pt(500010000, 300010000)],
        mask: vec![1],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &parse_hex(ROUTE_HEX)).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), ROUTE_HEX);
    assert_eq!(back, row);
}

fn assert_unpack_fails_fast<T: Default + 'static>(scheme: &Scheme<T>, hex: &str) -> UnpackError {
    let started = Instant::now();
    let result = unpack_row(scheme, &parse_hex(hex));
    assert!(
        started.elapsed() < Duration::from_secs(1),
        "{hex}: too slow"
    );
    result
        .err()
        .unwrap_or_else(|| panic!("{hex}: expected an error"))
}

#[derive(Default)]
struct Wide {
    n: u32,
    bytes: Vec<Byte>,
}

#[derive(Default)]
struct Byte {
    v: u8,
}

#[derive(Default)]
struct Signed {
    n: i8,
    bytes: Vec<Byte>,
}

#[test]
fn ac6_oversize_count_through_a_typed_times_is_short() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::u32(0, |r: &Wide| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Wide| &r.bytes[..],
                |r, v| r.bytes = v,
                [BoundField::u8(1, |b: &Byte| b.v, |b, v| b.v = v).into()],
            ),
        ],
    );

    // Act
    let err = assert_unpack_fails_fast(&scheme, "01ffffffff00");

    // Assert
    assert!(matches!(err, UnpackError::Short(_)), "{err:?}");
}

#[test]
fn ac6_negative_count_through_a_typed_times_is_an_error() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::i8(0, |r: &Signed| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Signed| &r.bytes[..],
                |r, v| r.bytes = v,
                [BoundField::u8(1, |b: &Byte| b.v, |b, v| b.v = v).into()],
            ),
        ],
    );

    // Act
    let err = assert_unpack_fails_fast(&scheme, "01ff");

    // Assert
    assert!(matches!(err, UnpackError::Short(_)), "{err:?}");
}
