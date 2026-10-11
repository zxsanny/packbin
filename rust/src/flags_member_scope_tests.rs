use crate::walk::{pack, unpack};
use crate::{flag_byte, flags, group, insert, to_hex, u8, MapScheme, Value, Values};

// AZ-2333: each member of one `flags` is a flag-byte scope of its own, as in C++, TypeScript and
// Java: a byte read in one member is not seen by a bit in the next, so a bit after the `flags`
// or in a sibling member binds to the byte read before the `flags`, and with none it is refused.
// The hex strings are the bytes TypeScript gives for the same scheme and rows (S1), and those of
// the C++ `flag_scope_host_tests.cpp` table for the single-member scheme.

fn row(pairs: &[(&str, u8)]) -> Values {
    let mut vals = Values::new();
    for (name, value) in pairs {
        insert(&mut vals, name, Some(Value::U8(*value)));
    }
    vals
}

fn bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// S1: `flagbyte fb; flags { group g1 { u8 v; flagbyte fb; bit fb { u8 x } }, group g2 { bit fb { u8 y } } }; bit fb { u8 b }`
fn siblings_with_an_outer_byte() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![
            fb.byte(),
            flags(
                1,
                "f",
                vec![
                    group(1, "g1", vec![u8("v"), fb.byte(), fb.bit(u8("x"))]),
                    group(4, "g2", vec![fb.bit(u8("y"))]),
                ],
            ),
            fb.bit(u8("b")),
        ],
    )
}

/// The C++ `outer_then_member` scheme: one `flags` member with a byte of its own.
fn one_member_with_an_outer_byte() -> MapScheme {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![
            fb.byte(),
            flags(
                1,
                "f",
                vec![group(1, "g1", vec![u8("v"), fb.byte(), fb.bit(u8("x"))])],
            ),
            fb.bit(u8("b")),
        ],
    )
}

fn check_rows(scheme: &MapScheme, rows: &[(&[(&str, u8)], &str)]) {
    for (pairs, expected) in rows {
        // Act
        let wire = to_hex(&pack(scheme, &row(pairs)).expect("pack"));
        let back = unpack(scheme, &bytes(expected)).expect("unpack");
        let again = to_hex(&pack(scheme, &back).expect("repack"));

        // Assert
        assert_eq!(&wire, expected, "{pairs:?}");
        assert_eq!(&again, expected, "repack of {pairs:?}");
    }
}

#[test]
fn ac1_sibling_members_each_have_their_own_byte_scope() {
    // Arrange: a bit in the second member binds to the outer byte, not to the first member's
    let rows: &[(&[(&str, u8)], &str)] = &[
        (
            &[("v", 3), ("x", 5), ("y", 6), ("b", 7)],
            "0103030301050607",
        ),
        (&[("v", 3), ("x", 5)], "010001030105"),
        (&[("y", 6)], "01010206"),
        (&[("b", 7)], "01020007"),
        (&[("v", 3), ("y", 6)], "010103030006"),
        (&[], "010000"),
    ];

    // Act and assert
    check_rows(&siblings_with_an_outer_byte(), rows);
}

#[test]
#[should_panic(expected = "flag bit \"y\" of flag byte \"fb\" is not in the same scope")]
fn ac1_a_bit_in_a_sibling_member_cannot_use_the_byte_of_the_member_before() {
    let fb = flag_byte("fb");
    MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![
                group(0, "g1", vec![u8("v"), fb.byte(), fb.bit(u8("x"))]),
                group(3, "g2", vec![fb.bit(u8("y"))]),
            ],
        )],
    );
}

#[test]
#[should_panic(expected = "flag bit \"y\" of flag byte \"fb\" is not in the same scope")]
fn ac1_a_byte_that_is_itself_a_flags_member_is_not_seen_by_the_next_member() {
    let fb = flag_byte("fb");
    MapScheme::new(1, vec![flags(0, "f", vec![fb.byte(), fb.bit(u8("y"))])]);
}

#[test]
fn ac2_one_member_with_a_byte_of_its_own_is_unchanged() {
    // Arrange: the rows of the C++ table
    let rows: &[(&[(&str, u8)], &str)] = &[
        (&[("b", 7)], "01010007"),
        (&[("v", 3), ("b", 7)], "010101030007"),
        (&[("v", 3), ("x", 5), ("b", 7)], "01010103010507"),
        (&[("v", 3), ("x", 5)], "010001030105"),
        (&[("v", 3)], "0100010300"),
        (&[], "010000"),
    ];

    // Act and assert
    check_rows(&one_member_with_an_outer_byte(), rows);
}

#[test]
fn ac2_a_byte_and_its_bits_inside_one_member_still_build_and_round_trip() {
    // Arrange
    let fb = flag_byte("fb");
    let scheme = MapScheme::new(
        1,
        vec![flags(
            0,
            "f",
            vec![group(0, "g1", vec![u8("v"), fb.byte(), fb.bit(u8("x"))])],
        )],
    );
    let rows: &[(&[(&str, u8)], &str)] = &[
        (&[("v", 3), ("x", 5)], "0101030105"),
        (&[("v", 3)], "01010300"),
        (&[], "0100"),
    ];

    // Act and assert
    check_rows(&scheme, rows);
}
