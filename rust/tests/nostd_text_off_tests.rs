//! The `text` feature off (AZ-2754 AC-3): a wire string is forwarded, a decoded one is refused at
//! validate.
#![cfg(not(feature = "text"))]

mod nostd_support;

use nostd_support::Slots;
use packbin::nostd::{dict, key, list, pack, u8, unpack, utf8, utf8_wire, validate, Error, Scheme};

#[test]
fn ac3_a_utf8_member_is_refused_at_validate_and_by_pack_and_unpack() {
    // Arrange
    let fields = [utf8(0)];
    let scheme = Scheme::new(1, &fields);
    let mut out = [0u8; 8];
    // Act
    let checked = validate(&scheme).expect_err("refused");
    let packed = pack(&scheme, &Slots::default(), &mut out).expect_err("refused");
    let unpacked = unpack(&scheme, &[1, 0], &mut Slots::default()).expect_err("refused");
    // Assert
    for fault in [checked, packed, unpacked] {
        assert_eq!(fault.error, Error::SchemeInvalid);
    }
}

#[test]
fn ac3_a_dict_and_a_list_of_strings_are_refused_at_validate() {
    // Arrange
    let dict_fields = [dict(0, 3), key(), u8(0)];
    let list_fields = [list(0, 2), utf8(0)];
    let dict_scheme = Scheme::new(1, &dict_fields);
    let list_scheme = Scheme::new(1, &list_fields);
    // Act and Assert
    assert_eq!(
        validate(&dict_scheme).expect_err("dict").error,
        Error::SchemeInvalid
    );
    assert_eq!(
        validate(&list_scheme).expect_err("list").error,
        Error::SchemeInvalid
    );
}

#[test]
fn ac3_a_wire_string_is_forwarded_unchanged() {
    // Arrange
    let fields = [utf8_wire(0), u8(1)];
    let scheme = Scheme::new(1, &fields);
    let packet = [1, 2, 0x10, 0x41, 0x07];
    let mut row = Slots::default();
    // Act
    unpack(&scheme, &packet, &mut row).expect("unpack");
    let mut out = [0u8; 16];
    let n = pack(&scheme, &row, &mut out).expect("pack");
    // Assert
    assert_eq!(&out[..n], &packet);
}
