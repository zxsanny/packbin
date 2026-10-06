use packbin::{
    eq, to_hex, BinaryPacker, BoundField, PackError, PackSession, Scheme, SchemeItem,
    SessionPackError, UnpackError, Value, NONCE_SIZE, SEED_SIZE,
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

fn pt(lat: i32, lon: i32) -> Point {
    Point { lat, lon }
}

#[derive(Default, Debug, PartialEq)]
struct Twin {
    n: u8,
    first: Vec<Point>,
    second: Vec<Point>,
    tail: u8,
}

fn twin_scheme() -> Scheme<Twin> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Twin| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Twin| &r.first[..],
                |r, v| r.first = v,
                [
                    BoundField::i32(1, |p: &Point| p.lat, |p, v| p.lat = v).into(),
                    BoundField::i32(2, |p: &Point| p.lon, |p, v| p.lon = v).into(),
                ],
            ),
            SchemeItem::times(
                3,
                0,
                |r: &Twin| &r.second[..],
                |r, v| r.second = v,
                [
                    BoundField::i32(3, |p: &Point| p.lat, |p, v| p.lat = v).into(),
                    BoundField::i32(4, |p: &Point| p.lon, |p, v| p.lon = v).into(),
                ],
            ),
            BoundField::u8(5, |r: &Twin| r.tail, |r, v| r.tail = v).into(),
        ],
    )
}

#[test]
fn two_sibling_times_sharing_one_count_each_take_that_many_rounds() {
    // Arrange
    let scheme = twin_scheme();
    let row = Twin {
        n: 2,
        first: vec![pt(1, 2), pt(3, 4)],
        second: vec![pt(5, 6), pt(7, 8)],
        tail: 9,
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(
        to_hex(&bytes),
        "0102010000000200000003000000040000000500000006000000070000000800000009"
    );
    assert_eq!(back, row);
}

#[test]
fn the_second_of_two_sibling_times_must_match_the_shared_count() {
    // Arrange
    let row = Twin {
        n: 2,
        first: vec![pt(1, 2), pt(3, 4)],
        second: vec![pt(5, 6)],
        tail: 9,
    };

    // Act
    let result = BinaryPacker::pack(&twin_scheme(), &row);

    // Assert
    assert!(
        matches!(&result, Err(PackError::Type(name)) if name == "times at id 3: count 2, 1 rounds"),
        "{result:?}"
    );
}

#[derive(Default, Debug, PartialEq)]
struct Reading {
    v: i32,
}

#[derive(Default, Debug, PartialEq)]
struct Guarded {
    kind: u8,
    n: u8,
    readings: Vec<Reading>,
}

fn guarded_scheme() -> Scheme<Guarded> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Guarded| r.kind, |r, v| r.kind = v).into(),
            BoundField::u8(1, |r: &Guarded| r.n, |r, v| r.n = v).into(),
            SchemeItem::when(
                2,
                eq(0, Value::U8(1)),
                [SchemeItem::times(
                    2,
                    1,
                    |r: &Guarded| &r.readings[..],
                    |r, v| r.readings = v,
                    [BoundField::i32(2, |e: &Reading| e.v, |e, v| e.v = v).into()],
                )],
            ),
        ],
    )
}

#[test]
fn times_inside_a_matching_when_body_packs_and_unpacks_its_round() {
    // Arrange
    let scheme = guarded_scheme();
    let row = Guarded {
        kind: 1,
        n: 1,
        readings: vec![Reading { v: 5 }],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "01010105000000");
    assert_eq!(back, row);
}

#[test]
fn times_inside_a_when_body_that_does_not_match_is_skipped_whatever_its_count() {
    // Arrange
    let scheme = guarded_scheme();
    let row = Guarded {
        kind: 2,
        n: 1,
        readings: vec![],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "010201");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Part {
    len: u8,
    data: Vec<u8>,
}

#[derive(Default, Debug, PartialEq)]
struct Parts {
    n: u8,
    parts: Vec<Part>,
}

fn parts_scheme() -> Scheme<Parts> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Parts| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Parts| &r.parts[..],
                |r, v| r.parts = v,
                [
                    BoundField::u8(1, |p: &Part| p.len, |p, v| p.len = v).into(),
                    BoundField::sized(2, 1, |p: &Part| p.data.clone(), |p, v| p.data = v).into(),
                ],
            ),
        ],
    )
}

#[test]
fn sized_with_an_element_local_count_reads_each_rounds_own_length() {
    // Arrange
    let scheme = parts_scheme();
    let row = Parts {
        n: 2,
        parts: vec![
            Part {
                len: 2,
                data: vec![1, 2],
            },
            Part {
                len: 0,
                data: vec![],
            },
        ],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "010202010200");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Byte {
    v: u8,
}

#[derive(Default, Debug, PartialEq)]
struct Wide {
    n: u16,
    bytes: Vec<Byte>,
}

#[test]
fn a_u16_count_of_300_packs_300_rounds_and_round_trips() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::u16(0, |r: &Wide| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Wide| &r.bytes[..],
                |r, v| r.bytes = v,
                [BoundField::u8(1, |b: &Byte| b.v, |b, v| b.v = v).into()],
            ),
        ],
    );
    let row = Wide {
        n: 300,
        bytes: (0..300).map(|i| Byte { v: (i % 251) as u8 }).collect(),
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(bytes.len(), 303);
    assert_eq!(to_hex(&bytes[..5]), "012c010001");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Cell {
    slots: [Option<u8>; 8],
}

#[derive(Default, Debug, PartialEq)]
struct Grid {
    n: u8,
    cells: Vec<Cell>,
}

fn grid_scheme() -> Scheme<Grid> {
    let slots: Vec<SchemeItem<Cell>> = (0..8usize)
        .map(|k| {
            BoundField::opt_u8(
                1 + k as u32,
                move |c: &Cell| c.slots[k],
                move |c, v| c.slots[k] = v,
            )
            .into()
        })
        .collect();
    Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Grid| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Grid| &r.cells[..],
                |r, v| r.cells = v,
                [SchemeItem::flags(1, slots)],
            ),
        ],
    )
}

fn grid_with_bit_pattern_rounds() -> Grid {
    let cells = (0..255u32)
        .map(|round| Cell {
            slots: std::array::from_fn(|k| {
                (round >> k & 1 == 1).then_some(round as u8 ^ (k as u8 + 1))
            }),
        })
        .collect();
    Grid { n: 255, cells }
}

#[test]
fn a_255_round_times_with_an_eight_member_flags_per_round_round_trips() {
    // Arrange
    let scheme = grid_scheme();
    let row = grid_with_bit_pattern_rounds();

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(bytes.len(), 1273);
    assert_eq!(
        bytes[..10],
        [0x01, 0xff, 0x00, 0x01, 0x00, 0x02, 0x00, 0x03, 0x02, 0x01]
    );
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Bytes {
    n: u8,
    items: Vec<u8>,
}

#[test]
fn a_vec_of_u8_elements_packs_the_count_then_the_bytes() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Bytes| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Bytes| &r.items[..],
                |r, v| r.items = v,
                [BoundField::u8(1, |b: &u8| *b, |b, v| *b = v).into()],
            ),
        ],
    );
    let row = Bytes {
        n: 3,
        items: vec![1, 2, 3],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "0103010203");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Pairs {
    n: u8,
    items: Vec<(i32, i32)>,
}

#[test]
fn a_vec_of_i32_tuple_elements_packs_both_members_per_round() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [
            BoundField::u8(0, |r: &Pairs| r.n, |r, v| r.n = v).into(),
            SchemeItem::times(
                1,
                0,
                |r: &Pairs| &r.items[..],
                |r, v| r.items = v,
                [
                    BoundField::i32(1, |t: &(i32, i32)| t.0, |t, v| t.0 = v).into(),
                    BoundField::i32(2, |t: &(i32, i32)| t.1, |t, v| t.1 = v).into(),
                ],
            ),
        ],
    );
    let row = Pairs {
        n: 2,
        items: vec![(3, 4), (5, 6)],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "010203000000040000000500000006000000");
    assert_eq!(back, row);
}

fn seed() -> [u8; SEED_SIZE] {
    std::array::from_fn(|i| i as u8 + 1)
}

fn session_pair() -> (PackSession, PackSession) {
    let mut opener = PackSession::load(&seed()).expect("load opener");
    let mut waiter = PackSession::load(&seed()).expect("load waiter");
    let nonce = opener.start_with(&[7u8; NONCE_SIZE]).expect("start");
    assert!(waiter.join(&nonce));
    (opener, waiter)
}

fn receive(waiter: &mut PackSession, scheme: &Scheme<Twin>, bytes: &[u8]) -> Twin {
    let mut got = None;
    waiter
        .unpack(bytes, &mut [&mut scheme.on(|row| got = Some(row))])
        .expect("unpack");
    got.expect("handler ran")
}

#[test]
fn a_session_peer_reads_the_times_row_the_opener_packed() {
    // Arrange
    let scheme = twin_scheme();
    let (mut opener, mut waiter) = session_pair();
    let row = Twin {
        n: 2,
        first: vec![pt(1, 2), pt(3, 4)],
        second: vec![pt(5, 6), pt(7, 8)],
        tail: 9,
    };

    // Act
    let sealed = opener.pack(&scheme, &row).expect("pack");
    let back = receive(&mut waiter, &scheme, &sealed);

    // Assert
    assert_eq!(back, row);
}

#[test]
fn a_session_pack_that_fails_on_the_count_leaves_the_next_pack_readable() {
    // Arrange
    let scheme = twin_scheme();
    let (mut opener, mut waiter) = session_pair();
    let broken = Twin {
        n: 2,
        first: vec![pt(1, 2), pt(3, 4)],
        second: vec![pt(5, 6)],
        tail: 9,
    };
    let good = Twin {
        n: 1,
        first: vec![pt(1, 2)],
        second: vec![pt(5, 6)],
        tail: 4,
    };

    // Act
    let failed = opener.pack(&scheme, &broken);
    let sealed = opener.pack(&scheme, &good).expect("pack");
    let back = receive(&mut waiter, &scheme, &sealed);

    // Assert
    assert!(matches!(
        failed,
        Err(SessionPackError::Pack(PackError::Type(_)))
    ));
    assert_eq!(back, good);
}
