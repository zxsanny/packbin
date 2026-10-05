use packbin::{to_hex, BinaryPacker, BoundField, Scheme, UnpackError};
use std::collections::BTreeMap;
use std::time::{Duration, Instant};

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| s.to_string()).collect()
}

fn unpack_row<T: Default + 'static>(scheme: &Scheme<T>, bytes: &[u8]) -> Result<T, UnpackError> {
    let mut got = None;
    BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(|row| got = Some(row))])?;
    Ok(got.expect("handler ran"))
}

#[derive(Default, Debug, PartialEq)]
struct TwoLists {
    a: Vec<String>,
    b: Vec<String>,
}

fn two_lists_scheme() -> Scheme<TwoLists> {
    Scheme::new(
        1,
        [
            BoundField::list_utf8(|r: &TwoLists| r.a.clone(), |r, v| r.a = v).into(),
            BoundField::list_utf8(|r: &TwoLists| r.b.clone(), |r, v| r.b = v).into(),
        ],
    )
}

#[test]
fn two_bound_lists_pack_their_own_members() {
    // Arrange
    let row = TwoLists {
        a: strings(&["x"]),
        b: strings(&["yy", "zz"]),
    };

    // Act
    let bytes = BinaryPacker::pack(&two_lists_scheme(), &row).expect("pack");

    // Assert
    assert_eq!(to_hex(&bytes), "01010001007802000200797902007a7a");
}

#[test]
fn two_bound_lists_unpack_into_their_own_members() {
    // Arrange
    let row = TwoLists {
        a: strings(&["x"]),
        b: strings(&["yy", "zz"]),
    };
    let scheme = two_lists_scheme();
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");

    // Act
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct TwoDicts {
    first: BTreeMap<String, Vec<String>>,
    second: BTreeMap<String, Vec<String>>,
}

#[test]
fn two_bound_dicts_round_trip_their_own_content() {
    // Arrange
    let scheme = Scheme::new(
        2,
        [
            BoundField::dict_list_utf8(|r: &TwoDicts| r.first.clone(), |r, v| r.first = v).into(),
            BoundField::dict_list_utf8(|r: &TwoDicts| r.second.clone(), |r, v| r.second = v).into(),
        ],
    );
    let row = TwoDicts {
        first: BTreeMap::from([("map".to_string(), strings(&["read", "edit"]))]),
        second: BTreeMap::from([
            ("store".to_string(), strings(&["write"])),
            ("tile".to_string(), strings(&[])),
        ]),
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct DictAndRows {
    access: BTreeMap<String, Vec<String>>,
    tables: BTreeMap<String, Vec<BTreeMap<String, String>>>,
}

#[test]
fn bound_dict_and_dict_of_rows_round_trip_their_own_content() {
    // Arrange
    let scheme = Scheme::new(
        3,
        [
            BoundField::dict_list_utf8(|r: &DictAndRows| r.access.clone(), |r, v| r.access = v)
                .into(),
            BoundField::dict_list_dict_utf8(
                |r: &DictAndRows| r.tables.clone(),
                |r, v| r.tables = v,
            )
            .into(),
        ],
    );
    let row = DictAndRows {
        access: BTreeMap::from([("map".to_string(), strings(&["read"]))]),
        tables: BTreeMap::from([(
            "users".to_string(),
            vec![BTreeMap::from([("name".to_string(), "ada".to_string())])],
        )]),
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(back, row);
}

#[derive(Default, Debug, PartialEq)]
struct TwoShortLists {
    left: Vec<u16>,
    right: Vec<u16>,
}

#[test]
fn two_bound_u16_lists_round_trip_their_own_content() {
    // Arrange
    let scheme = Scheme::new(
        4,
        [
            BoundField::list_u16(|r: &TwoShortLists| r.left.clone(), |r, v| r.left = v, 0).into(),
            BoundField::list_u16(|r: &TwoShortLists| r.right.clone(), |r, v| r.right = v, 0).into(),
        ],
    );
    let row = TwoShortLists {
        left: vec![1, 2],
        right: vec![300],
    };

    // Act
    let bytes = BinaryPacker::pack(&scheme, &row).expect("pack");
    let back = unpack_row(&scheme, &bytes).expect("unpack");

    // Assert
    assert_eq!(to_hex(&bytes), "0402000100020001002c01");
    assert_eq!(back, row);
}

fn assert_unpack_fails_fast<T: Default + 'static>(scheme: &Scheme<T>, hex: &str) {
    let bytes: Vec<u8> = (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect();
    let started = Instant::now();
    let result = unpack_row(scheme, &bytes);
    assert!(result.is_err(), "{hex}: expected an error");
    assert!(
        started.elapsed() < Duration::from_secs(1),
        "{hex}: too slow"
    );
}

#[derive(Default)]
struct Name {
    name: String,
}

#[test]
fn hostile_invalid_utf8_through_a_typed_utf8_field_is_an_error() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [BoundField::utf8(0, |r: &Name| r.name.clone(), |r, v| r.name = v).into()],
    );

    // Act / Assert
    assert_unpack_fails_fast(&scheme, "010200c328");
}

#[test]
fn hostile_oversize_count_through_a_typed_list_is_an_error() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [BoundField::list_utf8(|r: &TwoLists| r.a.clone(), |r, v| r.a = v).into()],
    );

    // Act / Assert
    assert_unpack_fails_fast(&scheme, "01ffff");
}

#[test]
fn hostile_invalid_utf8_dict_key_through_a_typed_dict_is_an_error() {
    // Arrange
    let scheme = Scheme::new(
        1,
        [BoundField::dict_list_utf8(|r: &TwoDicts| r.first.clone(), |r, v| r.first = v).into()],
    );

    // Act / Assert
    assert_unpack_fails_fast(&scheme, "0101000100ff00");
}
