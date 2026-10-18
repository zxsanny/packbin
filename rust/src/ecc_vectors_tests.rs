use crate::ecc::{append, check_limit, unprotect, MAX_PARITY};
use crate::{u8, MapScheme, PackError, UnpackError};
use std::panic::catch_unwind;

// AZ-2684: every row of fixtures/ecc/vectors.txt (enc, fix, bad, lim, par, lmt) against the codec.

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/ecc/vectors.txt");

fn from_hex(hex: &str) -> Vec<u8> {
    if hex == "-" {
        return Vec::new();
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// The rows of one kind: the fields after the kind, split on spaces.
fn rows(kind: &str) -> Vec<Vec<String>> {
    let text = std::fs::read_to_string(VECTORS).expect("vectors file");
    let found: Vec<Vec<String>> = text
        .lines()
        .filter(|line| line.split(' ').next() == Some(kind))
        .map(|line| line.split(' ').skip(1).map(str::to_string).collect())
        .collect();
    assert!(!found.is_empty(), "no {kind} rows");
    found
}

fn number(field: &str) -> usize {
    field.parse().expect("number")
}

#[test]
fn ec2_every_enc_row_appends_its_parity() {
    // Arrange
    let rows = rows("enc");

    for row in &rows {
        let (id, n, clear, protected) = (&row[0], number(&row[1]), from_hex(&row[2]), &row[3]);
        let mut bytes = clear.clone();

        // Act
        append(&mut bytes, n).expect("append");

        // Assert
        assert_eq!(bytes, from_hex(protected), "{id}");
        assert_eq!(&bytes[..clear.len()], &clear[..], "{id}: clear bytes first");
    }
}

#[test]
fn ec5_every_fix_row_returns_its_clear_bytes_and_count() {
    // Arrange
    let rows = rows("fix");
    assert!(rows.len() >= 100);

    for row in &rows {
        let (id, n, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (received, clear, count) = (from_hex(&row[3]), from_hex(&row[4]), number(&row[5]));

        // Act
        let (got, repaired) = unprotect(&received, n, t).unwrap_or_else(|e| panic!("{id}: {e:?}"));

        // Assert
        assert_eq!(&*got, &clear[..], "{id}");
        assert_eq!(repaired, count, "{id}");
    }
}

#[test]
fn ec6_every_bad_row_is_refused_with_its_kind_and_no_bytes() {
    // Arrange
    let rows = rows("bad");
    let mut kinds = std::collections::BTreeSet::new();

    for row in &rows {
        let (id, n, t) = (&row[0], number(&row[1]), number(&row[2]));
        let (received, kind) = (from_hex(&row[3]), row[4].as_str());
        kinds.insert(kind.to_string());

        // Act
        let result = unprotect(&received, n, t);

        // Assert
        match (kind, result) {
            ("uncorrectable", Err(UnpackError::Uncorrectable)) => {}
            ("short", Err(UnpackError::Short(short))) => {
                assert_eq!(short.field, "parity", "{id}");
                assert_eq!((short.needed, short.left), (n, received.len()), "{id}");
            }
            ("too_long", Err(UnpackError::TooLong { len, limit })) => {
                assert_eq!((len, limit), (received.len(), 254), "{id}");
            }
            (_, other) => panic!(
                "{id}: expected {kind}, got {:?}",
                other.map(|(b, c)| (b.len(), c))
            ),
        }
    }
    assert_eq!(
        kinds.len(),
        3,
        "uncorrectable, short and too_long rows all ran"
    );
}

#[test]
fn ec4_every_lim_row_is_accepted_or_refused_naming_length_and_limit() {
    // Arrange
    let rows = rows("lim");

    for row in &rows {
        let (id, n, len, outcome) = (&row[0], number(&row[1]), number(&row[2]), row[3].as_str());
        let mut bytes = vec![0u8; len];

        // Act
        let result = append(&mut bytes, n);

        // Assert
        match (outcome, result) {
            ("ok", Ok(())) => assert_eq!(bytes.len(), len + n, "{id}"),
            ("too_long", Err(PackError::Type(text))) => {
                let limit = 254 - n;
                assert!(text.contains(&len.to_string()), "{id}: {text}");
                assert!(
                    text.contains(&format!("limit of {limit} bytes")),
                    "{id}: {text}"
                );
                assert_eq!(bytes.len(), len, "{id}: nothing appended");
            }
            (_, other) => panic!("{id}: expected {outcome}, got {other:?}"),
        }
    }
}

#[test]
fn ec3_every_par_row_fails_when_the_scheme_is_built_naming_n_and_32() {
    // Arrange
    let rows = rows("par");

    for row in &rows {
        let (id, n) = (&row[0], number(&row[1]));

        // Act
        let result = catch_unwind(|| MapScheme::new(1, vec![u8("a")]).with_parity(n));

        // Assert
        let payload = result
            .err()
            .unwrap_or_else(|| panic!("{id}: scheme was built"));
        let text = payload
            .downcast_ref::<String>()
            .cloned()
            .unwrap_or_default();
        assert!(text.contains(&n.to_string()), "{id}: {text}");
        assert!(text.contains(&MAX_PARITY.to_string()), "{id}: {text}");
    }
}

#[test]
fn ec8_every_lmt_row_is_refused_before_any_byte_is_read() {
    // Arrange
    let rows = rows("lmt");

    for row in &rows {
        let (id, n, t) = (&row[0], number(&row[1]), number(&row[2]));

        // Act
        let direct = check_limit(n, t);
        let unread = unprotect(&[], n, t).map(|(b, c)| (b.len(), c));

        // Assert
        let expected = UnpackError::BadLimit {
            limit: t,
            max: n / 2,
        };
        assert_eq!(direct, Err(expected.clone()), "{id}");
        assert_eq!(
            unread,
            Err(expected),
            "{id}: refused before the empty buffer"
        );
    }
}
