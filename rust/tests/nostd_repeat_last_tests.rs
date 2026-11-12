//! AZ-4218: a `repeat` must be the last thing its packet reads, in the heap-free API. The rule, the
//! refused cases R1 to R9 and the cases K1 to K5 that keep building are the contract
//! `_docs/02_document/contracts/library/repeat-last.md`. `validate` is where a heap-free scheme is
//! built (`pack` and `unpack` call it first); it answers `SchemeInvalid` with the order id of the
//! first field that follows the repeat (`Fault::offset` is its index in the table). The map form
//! is in `repeat_last_tests.rs`. Runs with and without default features.

mod nostd_support;

use nostd_support::{from_hex, Slots};
#[cfg(feature = "text")]
use packbin::nostd::utf8;
use packbin::nostd::{
    boolean, bytes, dict, flag_bit, flag_byte, flags, group, key, list, pack, repeat, sized, times,
    u2, u8, unpack, utf8_wire, validate, when, Error, Fault, Field, Num, Row, Scheme,
};

/// `SchemeInvalid` naming the entry at `index` of the table, whose order id is `id`.
fn invalid(index: usize, id: i32) -> Result<(), Fault> {
    Err(Fault {
        error: Error::SchemeInvalid,
        offset: index,
        field: id,
        needed: 0,
    })
}

fn check(fields: &[Field]) -> Result<(), Fault> {
    validate(&Scheme::new(1, fields))
}

/// A row of `u8` numbers by id.
fn row(nums: &[(u16, u8)]) -> Slots {
    let nums: Vec<(u16, Num)> = nums.iter().map(|(id, x)| (*id, Num::U8(*x))).collect();
    Slots::with(&nums, &[])
}

/// `row` with one round per item under the container `id`, each holding `v` under `member`.
fn with_rounds(mut row: Slots, id: u16, member: u16, items: &[u8]) -> Slots {
    let at = usize::from(id);
    if row.items.len() <= at {
        row.items.resize(at + 1, None);
    }
    row.items[at] = Some(items.iter().map(|x| self::row(&[(member, *x)])).collect());
    row
}

/// The packet of `given` as hex and the row its own unpack fills.
fn round_trip(fields: &[Field], given: &Slots) -> (String, Slots) {
    let scheme = Scheme::new(1, fields);
    let mut out = [0u8; 16];
    let n = pack(&scheme, given, &mut out).expect("pack");
    let packet = out.get(..n).expect("the packed length");
    let mut back = Slots::default();
    let read = unpack(&scheme, packet, &mut back).expect("unpack");
    assert_eq!(read, n, "unpack read the whole packet");
    let hex = packet.iter().map(|b| format!("{b:02x}")).collect();
    (hex, back)
}

/// The `v` of each round of the container `id`, read under `member`.
fn round_values(row: &Slots, id: u16, member: u16) -> Vec<Option<Num>> {
    let count = row.count(id).expect("rounds");
    (0..count)
        .map(|k| row.item(id, k).and_then(|round| round.num(member)))
        .collect()
}

const FIVE_SIX: [Option<Num>; 2] = [Some(Num::U8(5)), Some(Num::U8(6))];

// AC-1: the refused cases, each with the status, the table index and the order id

#[test]
fn ac1_r1_a_field_after_a_repeat_at_the_top_level_is_scheme_invalid_naming_it() {
    // Arrange (AC-1): repeat { u8 v (id 0) }, u8 x (id 1)
    let fields = [repeat(0, 1), u8(0), u8(1)];

    // Act
    let checked = check(&fields);

    // Assert
    assert_eq!(checked, invalid(2, 1));
}

#[test]
fn ac1_a_refused_scheme_packs_and_unpacks_nothing() {
    // Arrange (AC-1): R1 with the values the probe gave it; the buffer is marked to show any write
    let fields = [repeat(0, 1), u8(0), u8(1)];
    let scheme = Scheme::new(1, &fields);
    let given = with_rounds(row(&[(1, 9)]), 0, 0, &[5, 6]);
    let mut out = [0xEEu8; 8];
    let mut back = Slots::default();

    // Act
    let packed = pack(&scheme, &given, &mut out);
    let unpacked = unpack(&scheme, &from_hex("01050609"), &mut back);

    // Assert
    assert_eq!(packed.map(|_| ()), invalid(2, 1));
    assert_eq!(out, [0xEEu8; 8]);
    assert_eq!(unpacked.map(|_| ()), invalid(2, 1));
    assert_eq!(back, Slots::default());
}

#[test]
fn ac1_r2_a_field_after_the_when_that_holds_the_repeat_is_scheme_invalid() {
    // Arrange (AC-1): u8 k (id 0), when k == 1 { repeat { u8 v (id 1) } }, u8 x (id 2)
    let fields = [u8(0), when(1, 0, 1, 2), repeat(1, 1), u8(1), u8(2)];

    // Act
    let checked = check(&fields);

    // Assert
    assert_eq!(checked, invalid(4, 2));
}

#[test]
fn ac1_r3_a_field_after_the_flags_that_holds_the_repeat_is_scheme_invalid() {
    // Arrange (AC-1): flags { repeat { u8 v (id 0) } }, u8 x (id 1)
    let fields = [flags(0, 2), repeat(0, 1), u8(0), u8(1)];

    // Act
    let checked = check(&fields);

    // Assert
    assert_eq!(checked, invalid(3, 1));
}

#[test]
fn ac1_r4_a_field_after_the_group_that_holds_the_repeat_is_scheme_invalid() {
    // Arrange (AC-1): group { repeat { u8 v (id 0) } }, u8 x (id 1); a group shares its row's ids
    let fields = [group(0, 2), repeat(0, 1), u8(0), u8(1)];

    // Act
    let checked = check(&fields);

    // Assert
    assert_eq!(checked, invalid(3, 1));
}

#[test]
fn ac1_r5_a_second_repeat_is_scheme_invalid_by_its_first_member() {
    // Arrange (AC-1): repeat { u8 v (id 0) }, repeat { u8 w (id 1) }
    let fields = [repeat(0, 1), u8(0), repeat(1, 1), u8(1)];

    // Act
    let checked = check(&fields);

    // Assert: `w`, at index 3, is the first entry after the first repeat that writes a byte
    assert_eq!(checked, invalid(3, 1));
}

#[test]
fn ac1_r6_a_field_under_a_when_that_excludes_the_repeats_when_is_scheme_invalid_all_the_same() {
    // Arrange (AC-1): u8 k, when k == 1 { repeat { u8 v (id 1) } }, when k == 2 { u8 x (id 2) }
    let fields = [
        u8(0),
        when(1, 0, 1, 2),
        repeat(1, 1),
        u8(1),
        when(2, 0, 2, 1),
        u8(2),
    ];

    // Act
    let checked = check(&fields);

    // Assert
    assert_eq!(checked, invalid(5, 2));
}

#[test]
fn ac1_r7_r8_have_no_spelling_a_list_or_dict_element_is_one_value_never_a_row() {
    // Arrange (AC-1): the nearest tables, a group as the element and the repeat as the element
    let list_of_rows = [list(0, 4), group(0, 3), u8(0), repeat(1, 1), u8(1)];
    let dict_of_rows = [dict(0, 5), key(), group(0, 3), u8(0), repeat(1, 1), u8(1)];
    let list_of_repeat = [list(0, 2), repeat(0, 1), u8(0)];
    let row_without_repeat = [list(0, 3), group(0, 2), u8(0), u8(1)];

    // Act / Assert: the refusal names the list or dict (id 0) and is the same without a repeat
    assert_eq!(check(&list_of_rows), invalid(0, 0));
    assert_eq!(check(&dict_of_rows), invalid(0, 0));
    assert_eq!(check(&list_of_repeat), invalid(0, 0));
    assert_eq!(check(&row_without_repeat), invalid(0, 0));
}

#[test]
fn ac1_r9_a_repeat_inside_a_times_round_keeps_the_nesting_rule() {
    // Arrange (AC-1): u8 k (id 0), times k { repeat { u8 v (id 1) } }
    let fields = [u8(0), times(1, 0, 2), repeat(1, 1), u8(1)];

    // Act
    let checked = check(&fields);

    // Assert: the repeat itself is named, as before
    assert_eq!(checked, invalid(2, 1));
}

/// (what, the table, the index and the order id of the field that follows the repeat)
type Case = (&'static str, Vec<Field>, usize, i32);

/// Every table is refused naming the field that follows its repeat.
fn assert_each_invalid(cases: Vec<Case>) {
    for (what, fields, index, id) in cases {
        // Act
        let checked = check(&fields);

        // Assert
        assert_eq!(checked, invalid(index, id), "{what}");
    }
}

#[test]
fn ac1_a_byte_writing_field_in_any_container_place_after_a_repeat_is_scheme_invalid() {
    // Arrange (AC-1): the places a field can stand in: flags, flag bits, a when, behind a field
    let cases: Vec<Case> = vec![
        (
            "a later member of the same flags",
            vec![flags(0, 3), repeat(0, 1), u8(0), u8(1)],
            3,
            1,
        ),
        (
            "the field of a flag bit",
            vec![flag_byte(0), repeat(0, 1), u8(0), flag_bit(0, 1), u8(1)],
            4,
            1,
        ),
        (
            "a field after the flag bit that holds the repeat",
            vec![flag_byte(0), flag_bit(0, 2), repeat(0, 1), u8(0), u8(1)],
            4,
            1,
        ),
        (
            "a field behind one that writes nothing",
            vec![repeat(0, 1), u8(0), bytes(1, 0), u8(2)],
            3,
            2,
        ),
        (
            "a field in a group in a when",
            vec![
                u8(0),
                repeat(1, 1),
                u8(1),
                when(2, 0, 1, 2),
                group(2, 1),
                u8(2),
            ],
            5,
            2,
        ),
    ];

    // Act / Assert
    assert_each_invalid(cases);
}

#[test]
fn ac1_every_kind_of_field_that_writes_a_byte_after_a_repeat_is_scheme_invalid() {
    // Arrange (AC-1): the kinds of field that write a byte, each right after the repeat
    let cases: Vec<Case> = vec![
        (
            "a flags of one bool: its byte is written",
            vec![repeat(0, 1), u8(0), flags(1, 1), boolean(1)],
            2,
            1,
        ),
        (
            "a flag byte, which has no order id",
            vec![repeat(0, 1), u8(0), flag_byte(0)],
            2,
            -1,
        ),
        ("a list", vec![repeat(0, 1), u8(0), list(1, 1), u8(0)], 2, 1),
        (
            "a wire string",
            vec![repeat(0, 1), u8(0), utf8_wire(1)],
            2,
            1,
        ),
        ("a u2", vec![repeat(0, 1), u8(0), u2(1, 1), u8(1)], 2, 1),
        (
            "a sized, whatever its count",
            vec![u8(0), repeat(1, 1), u8(1), sized(2, 0)],
            3,
            2,
        ),
        (
            "a times whose body can write a byte",
            vec![u8(0), repeat(1, 1), u8(1), times(2, 0, 1), u8(2)],
            4,
            2,
        ),
    ];

    // Act / Assert
    assert_each_invalid(cases);
}

#[cfg(feature = "text")]
#[test]
fn ac1_a_string_or_a_dict_after_a_repeat_is_scheme_invalid() {
    // Arrange (AC-1): the kinds that need the `text` feature, each right after the repeat
    let cases: Vec<Case> = vec![
        ("a string", vec![repeat(0, 1), u8(0), utf8(1)], 2, 1),
        (
            "a dict: the key and the element are its entries",
            vec![repeat(0, 1), u8(0), dict(1, 2), key(), u8(0)],
            2,
            1,
        ),
    ];

    // Act / Assert
    assert_each_invalid(cases);
}

// AC-1: a field after the repeat that cannot write a byte

#[test]
fn ac1_fields_after_a_repeat_that_cannot_write_a_byte_are_valid() {
    // Arrange (AC-1): (what, the table)
    let cases: Vec<(&str, Vec<Field>)> = vec![
        ("a zero-width bytes", vec![repeat(0, 1), u8(0), bytes(1, 0)]),
        (
            "a when that holds nothing that counts",
            vec![u8(0), repeat(1, 1), u8(1), when(2, 0, 1, 1), bytes(2, 0)],
        ),
        (
            "a group that holds nothing that counts",
            vec![repeat(0, 1), u8(0), group(1, 1), bytes(1, 0)],
        ),
        (
            "a times whose body cannot write a byte",
            vec![u8(0), repeat(1, 1), u8(1), times(2, 0, 1), bytes(2, 0)],
        ),
    ];

    for (what, fields) in cases {
        // Act
        let checked = check(&fields);

        // Assert
        assert_eq!(checked, Ok(()), "{what}");
    }
}

#[test]
fn ac1_a_zero_width_bytes_after_a_repeat_reads_back() {
    // Arrange (AC-1): repeat { u8 v (id 0) }, bytes of 0 (id 1)
    let fields = [repeat(0, 1), u8(0), bytes(1, 0)];
    let mut given = with_rounds(Slots::default(), 0, 0, &[5, 6]);
    given.set_bytes(1, &[]);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "010506");
    assert_eq!(round_values(&back, 0, 0), FIVE_SIX);
    assert_eq!(back.bytes(1), Some(&[][..]));
}

// AC-2: a repeat that is last still validates, with the same bytes

#[test]
fn ac2_k1_a_repeat_after_a_field_packs_the_contract_packet_and_reads_back() {
    // Arrange (AC-2): u8 x (id 0), repeat { u8 v (id 1) }
    let fields = [u8(0), repeat(1, 1), u8(1)];
    let given = with_rounds(row(&[(0, 9)]), 1, 1, &[5, 6]);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "01090506");
    assert_eq!(back.num(0), Some(Num::U8(9)));
    assert_eq!(round_values(&back, 1, 1), FIVE_SIX);
}

#[test]
fn ac2_k2_a_repeat_last_in_a_when_that_nothing_follows_packs_and_reads_back() {
    // Arrange (AC-2): u8 k (id 0), when k == 1 { repeat { u8 v (id 1) } }
    let fields = [u8(0), when(1, 0, 1, 2), repeat(1, 1), u8(1)];
    let given = with_rounds(row(&[(0, 1)]), 1, 1, &[5, 6]);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "01010506");
    assert_eq!(back.num(0), Some(Num::U8(1)));
    assert_eq!(round_values(&back, 1, 1), FIVE_SIX);
}

#[test]
fn ac2_k3_a_repeat_as_the_last_member_of_a_flags_packs_and_reads_back() {
    // Arrange (AC-2): flags { u8 x (id 0), repeat { u8 v (id 1) } }
    let fields = [flags(0, 3), u8(0), repeat(1, 1), u8(1)];
    let given = with_rounds(row(&[(0, 9)]), 1, 1, &[5, 6]);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "0103090506");
    assert_eq!(back.num(0), Some(Num::U8(9)));
    assert_eq!(round_values(&back, 1, 1), FIVE_SIX);
}

#[test]
fn ac2_k4_a_times_has_a_count_so_a_field_may_follow_it() {
    // Arrange (AC-2): u8 k (id 0), times k { u8 v (id 1) }, u8 x (id 2)
    let fields = [u8(0), times(1, 0, 1), u8(1), u8(2)];
    let given = with_rounds(row(&[(0, 2), (2, 9)]), 1, 1, &[5, 6]);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "0102050609");
    assert_eq!(back.num(0), Some(Num::U8(2)));
    assert_eq!(round_values(&back, 1, 1), FIVE_SIX);
    assert_eq!(back.num(2), Some(Num::U8(9)));
}

#[test]
fn ac2_k5_a_bool_bit_of_an_earlier_flag_byte_after_the_repeat_is_valid_and_reads_back() {
    // Arrange (AC-2): flag byte 0, bit { u8 x (id 0) }, repeat { u8 v (id 1) }, bit { bool (id 2) }
    let fields = [
        flag_byte(0),
        flag_bit(0, 1),
        u8(0),
        repeat(1, 1),
        u8(1),
        flag_bit(0, 1),
        boolean(2),
    ];
    let mut given = with_rounds(row(&[(0, 9)]), 1, 1, &[5, 6]);
    given.set_flag(2, true);

    // Act
    let (packet, back) = round_trip(&fields, &given);

    // Assert
    assert_eq!(packet, "0103090506");
    assert_eq!(back.num(0), Some(Num::U8(9)));
    assert_eq!(round_values(&back, 1, 1), FIVE_SIX);
    assert!(back.flag(2));
}
