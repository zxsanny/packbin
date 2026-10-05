use packbin::{to_hex, BinaryPacker, BoundField, Scheme, SchemeItem, UnpackError};

fn unpack_row<T: Default + 'static>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
    let mut got = None;
    BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(|row| got = Some(row))])?;
    Ok(got.expect("handler ran"))
}

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| s.to_string()).collect()
}

#[derive(Default, Debug, PartialEq)]
struct Leg {
    l: Vec<u16>,
}

#[derive(Default, Debug, PartialEq)]
struct Trip {
    n: u8,
    l: Vec<u16>,
    legs: Vec<Leg>,
}

fn trip_scheme() -> Scheme<Trip> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |t: &Trip| t.n, |t, v| t.n = v).into(),
            BoundField::list_u16(|t: &Trip| t.l.clone(), |t, v| t.l = v, 0).into(),
            SchemeItem::times(
                1,
                0,
                |t: &Trip| &t.legs[..],
                |t, v| t.legs = v,
                [BoundField::list_u16(|l: &Leg| l.l.clone(), |l, v| l.l = v, 0).into()],
            ),
        ],
    )
}

#[test]
fn parent_list_before_a_times_with_its_own_list_keeps_its_items() {
    // Arrange
    let scheme = trip_scheme();
    let row = Trip {
        n: 2,
        l: vec![7],
        legs: vec![Leg { l: vec![1, 2] }, Leg { l: vec![] }],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "0102010007000200010002000000");
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct Stage {
    f: Option<u8>,
    a: Vec<u16>,
    s: Vec<String>,
}

#[derive(Default, Debug, PartialEq)]
struct Journey {
    n: u8,
    a: Vec<u16>,
    s: Vec<String>,
    stages: Vec<Stage>,
    after: Vec<u16>,
}

fn journey_scheme() -> Scheme<Journey> {
    Scheme::new(
        1,
        [
            BoundField::u8(0, |j: &Journey| j.n, |j, v| j.n = v).into(),
            BoundField::list_u16(|j: &Journey| j.a.clone(), |j, v| j.a = v, 0).into(),
            BoundField::list_utf8(|j: &Journey| j.s.clone(), |j, v| j.s = v).into(),
            SchemeItem::times(
                1,
                0,
                |j: &Journey| &j.stages[..],
                |j, v| j.stages = v,
                [
                    SchemeItem::flags(
                        1,
                        [BoundField::opt_u8(1, |s: &Stage| s.f, |s, v| s.f = v).into()],
                    ),
                    BoundField::list_u16(|s: &Stage| s.a.clone(), |s, v| s.a = v, 0).into(),
                    BoundField::list_utf8(|s: &Stage| s.s.clone(), |s, v| s.s = v).into(),
                ],
            ),
            BoundField::list_u16(|j: &Journey| j.after.clone(), |j, v| j.after = v, 0).into(),
        ],
    )
}

#[test]
fn lists_and_flags_in_the_parent_and_the_element_keep_their_own_content() {
    // Arrange
    let scheme = journey_scheme();
    let row = Journey {
        n: 2,
        a: vec![7],
        s: strings(&["p", "q"]),
        stages: vec![
            Stage {
                f: None,
                a: vec![1],
                s: strings(&["x"]),
            },
            Stage {
                f: Some(5),
                a: vec![],
                s: vec![],
            },
        ],
        after: vec![9],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(
        to_hex(&bytes),
        concat!(
            "0102", "01000700", "0200", "010070", "010071", // parent
            "00", "01000100", "0100", "010078", // round 1
            "0105", "0000", "0000",     // round 2
            "01000900"  // after
        )
    );
    assert_eq!(back, row);
}
