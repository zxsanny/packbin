//! The `ecc` feature off (AZ-2755 AC-3): a scheme that declares parity bytes is refused at
//! validate, a scheme with none is the plain scheme.
#![cfg(not(feature = "ecc"))]

mod nostd_support;

use nostd_support::Slots;
use packbin::nostd::{pack, u8, unpack, validate, Error, Scheme};

#[test]
fn ac3_a_scheme_with_parity_is_refused_by_validate_pack_and_unpack() {
    // Arrange
    let fields = [u8(0)];
    let scheme = Scheme::new(1, &fields).with_parity(2);
    let mut out = [0u8; 8];
    // Act
    let checked = validate(&scheme).expect_err("refused");
    let packed = pack(&scheme, &Slots::default(), &mut out).expect_err("refused");
    let read = unpack(&scheme, &[1, 2, 3, 4], &mut Slots::default()).expect_err("refused");
    // Assert
    for fault in [checked, packed, read] {
        assert_eq!(fault.error, Error::SchemeInvalid);
    }
}

#[test]
fn ac3_parity_zero_is_the_plain_scheme() {
    // Arrange
    let fields = [u8(0)];
    let scheme = Scheme::new(1, &fields).with_parity(0);
    // Act and Assert
    assert!(validate(&scheme).is_ok());
}
