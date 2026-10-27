#![cfg(feature = "std")]
use packbin::{BinaryPacker, BoundField, Scheme, UnpackError};
use std::collections::BTreeMap;

// AZ-2713: the typed dict form refuses a key that is not greater than the one before it, by UTF-8 bytes.

#[derive(Default, Debug, PartialEq)]
struct Access {
    rights: BTreeMap<String, Vec<String>>,
}

fn scheme() -> Scheme<Access> {
    Scheme::new(
        1,
        [BoundField::dict_list_utf8(|r: &Access| r.rights.clone(), |r, v| r.rights = v).into()],
    )
}

fn unpack_row(hex: &str) -> Result<Access, UnpackError> {
    let bytes: Vec<u8> = (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect();
    let mut got = None;
    let scheme = scheme();
    BinaryPacker::unpack_with(&bytes, &mut [&mut scheme.on(|row| got = Some(row))])?;
    Ok(got.expect("handler ran"))
}

// Keys in the raw text form (02 10 61 is "a"), each with an empty list (0000).
#[test]
fn typed_dict_keys_ascending_are_accepted() {
    let row = unpack_row("01020002106100000210620000").expect("ascending");
    assert_eq!(row.rights.keys().collect::<Vec<_>>(), ["a", "b"]);
}

#[test]
fn typed_dict_keys_repeated_are_refused() {
    let result = unpack_row("01020002106100000210610000");
    assert!(matches!(result, Err(UnpackError::Short(_))), "{result:?}");
}

#[test]
fn typed_dict_keys_out_of_order_are_refused() {
    let result = unpack_row("01020002106200000210610000");
    assert!(matches!(result, Err(UnpackError::Short(_))), "{result:?}");
}

#[test]
fn typed_dict_keys_u_ff5e_then_u_10000_are_accepted_and_the_reverse_refused() {
    let ascending = unpack_row(concat!("010200", "0410efbd9e", "0000", "0510f0908080", "0000"));
    assert_eq!(ascending.expect("ascending").rights.len(), 2);
    let descending = unpack_row(concat!("010200", "0510f0908080", "0000", "0410efbd9e", "0000"));
    assert!(matches!(descending, Err(UnpackError::Short(_))), "{descending:?}");
}
