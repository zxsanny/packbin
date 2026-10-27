//! AZ-2754 AC-5: dictionaries in the heap-free core. Needs the `text` feature.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::{from_hex, Slots};
use packbin::nostd::{
    dict, key, pack_with, u8, unpack, utf8, Error, Field, Num, Row, Scheme, DICT_KEY,
};

const OF_BYTES: [Field; 3] = [dict(0, 2), key(), u8(0)];
const OF_STRINGS: [Field; 3] = [dict(0, 2), key(), utf8(0)];

fn of_bytes() -> Scheme<'static> {
    Scheme::new(1, &OF_BYTES)
}

fn row_of(entries: &[(&[u8], u8)]) -> Slots {
    let mut row = Slots::default();
    let items = entries
        .iter()
        .map(|(k, v)| {
            let mut item = Slots::default();
            item.set_bytes(DICT_KEY, k);
            item.set_num(0, Num::U8(*v));
            item
        })
        .collect();
    nostd_support::random::set_items(&mut row, 0, items);
    row
}

fn pack(scheme: &Scheme<'_>, row: &Slots) -> Result<Vec<u8>, Error> {
    let mut out = vec![0u8; 512];
    let mut scratch = vec![0u32; 3 * 64];
    pack_with(scheme, row, &mut out, &mut scratch)
        .map(|n| out[..n].to_vec())
        .map_err(|f| f.error)
}

#[test]
fn ac5_a_dictionary_packs_in_ascending_key_order_with_the_std_bytes() {
    // Arrange
    let row = row_of(&[(b"a", 1), (b"ab", 2), (b"b", 3)]);
    // Act
    let wire = pack(&of_bytes(), &row).expect("pack");
    // Assert: count 3, then key (raw form "a" is 0210 61) and value
    assert_eq!(wire[..3], [1, 3, 0]);
    let mut back = Slots::default();
    unpack(&of_bytes(), &wire, &mut back).expect("unpack");
    assert_eq!(back.count(0), Some(3));
}

#[test]
fn ac5_keys_not_strictly_ascending_are_refused_on_pack() {
    // Arrange
    let cases: [&[(&[u8], u8)]; 4] = [
        &[(b"b", 1), (b"a", 2)],
        &[(b"a", 1), (b"a", 2)],
        &[(b"ab", 1), (b"a", 2)],
        &[(b"a", 1), (b"c", 2), (b"b", 3)],
    ];
    for entries in cases {
        // Act
        let result = pack(&of_bytes(), &row_of(entries));
        // Assert
        assert_eq!(result, Err(Error::BadValue), "{entries:?}");
    }
}

#[test]
fn ac5_the_hostile_dictionary_packets_are_refused_on_unpack() {
    // Arrange
    let cases = [
        ("invalid_utf8_dict_key", "0101000210ff00"),
        ("dict_keys_out_of_order", "0102000210620002106100"),
        ("dict_keys_repeated", "0102000210610002106100"),
        ("dict_keys_repeated_forms", "0102000210610002c90000"),
        ("dict_keys_prefix_descends", "010200031061620002106100"),
        ("dict_keys_utf16_order", "0102000510f0908080000410efbd9e00"),
    ];
    for (id, hex) in cases {
        // Act
        let fault = unpack(&of_bytes(), &from_hex(hex), &mut Slots::default()).expect_err(id);
        // Assert
        assert!(
            matches!(fault.error, Error::BadValue | Error::ShortPacket),
            "{id}: {fault:?}"
        );
    }
}

#[test]
fn ac5_keys_that_ascend_by_decoded_bytes_are_read_whatever_their_form() {
    // Arrange: "" then "b" raw; "don't" compact (044a8edf64) then "e" raw
    for hex in ["010200000002106200", "010200044a8edf640002106500"] {
        // Act
        let result = unpack(&of_bytes(), &from_hex(hex), &mut Slots::default());
        // Assert
        assert!(result.is_ok(), "{hex}: {result:?}");
    }
}

#[test]
fn ac5_more_entries_than_the_row_stores_is_too_many() {
    // Arrange
    let wire = pack(&of_bytes(), &row_of(&[(b"a", 1), (b"b", 2), (b"c", 3)])).expect("pack");
    let mut small = Slots {
        cap: Some(2),
        ..Slots::default()
    };
    // Act
    let fault = unpack(&of_bytes(), &wire, &mut small).expect_err("three into two");
    // Assert
    assert_eq!(fault.error, Error::TooMany);
}

#[test]
fn ac5_a_key_longer_than_its_storage_is_too_many_with_its_size() {
    // Arrange
    let wire = pack(&of_bytes(), &row_of(&[(b"abcdef", 1)])).expect("pack");
    let mut small = Slots {
        cap: Some(3),
        ..Slots::default()
    };
    // Act
    let fault = unpack(&of_bytes(), &wire, &mut small).expect_err("long key");
    // Assert
    assert_eq!(fault.error, Error::TooMany);
    assert_eq!(fault.needed, 6);
}

#[test]
fn ac5_a_dictionary_of_strings_round_trips() {
    // Arrange
    let scheme = Scheme::new(1, &OF_STRINGS);
    let mut row = Slots::default();
    let items = [("Привіт", "світ"), ("hello", "world")]
        .iter()
        .map(|(k, v)| {
            let mut item = Slots::default();
            item.set_bytes(DICT_KEY, k.as_bytes());
            item.set_bytes(0, v.as_bytes());
            item
        })
        .collect::<Vec<_>>();
    // ascending by bytes: "hello" < "Привіт" (0x68 < 0xD0)
    let items = vec![items[1].clone(), items[0].clone()];
    nostd_support::random::set_items(&mut row, 0, items);
    // Act
    let wire = pack(&scheme, &row).expect("pack");
    let mut back = Slots {
        cap: Some(100),
        ..Slots::default()
    };
    unpack(&scheme, &wire, &mut back).expect("unpack");
    // Assert
    let first = back.item(0, 0).expect("item");
    assert_eq!(first.bytes(DICT_KEY), Some("hello".as_bytes()));
    assert_eq!(first.bytes(0), Some("world".as_bytes()));
}

#[test]
fn ac2_scratch_is_shared_by_every_string_in_a_dictionary_and_a_list() {
    // Arrange: a compact value of 13 characters inside a dictionary item, then inside a list
    const TEXT: &str = "привіт, світе";
    let chars = TEXT.chars().count();
    let mut dict_row = Slots::default();
    let mut item = Slots::default();
    item.set_bytes(DICT_KEY, b"k");
    item.set_bytes(0, TEXT.as_bytes());
    nostd_support::random::set_items(
        &mut dict_row,
        0,
        vec![item.clone(), {
            let mut second = item.clone();
            second.set_bytes(DICT_KEY, b"l");
            second
        }],
    );
    let scheme = Scheme::new(1, &OF_STRINGS);
    let list_fields = [packbin::nostd::list(0, 1), utf8(0)];
    let list_scheme = Scheme::new(1, &list_fields);
    let mut list_row = Slots::default();
    let mut element = Slots::default();
    element.set_bytes(0, TEXT.as_bytes());
    nostd_support::random::set_items(&mut list_row, 0, vec![element.clone(), element]);
    for (name, scheme, row) in [
        ("dict", &scheme, &dict_row),
        ("list", &list_scheme, &list_row),
    ] {
        let mut out = [0u8; 128];
        // Act
        let short = vec![0u32; chars * 3 - 1];
        let exact = vec![0u32; chars * 3];
        let refused = pack_with(scheme, row, &mut out, &mut short.clone()).expect_err(name);
        let packed = pack_with(scheme, row, &mut out, &mut exact.clone());
        // Assert
        assert_eq!(refused.error, Error::ScratchTooSmall, "{name}");
        assert_eq!(refused.needed, chars * 3, "{name}");
        assert!(packed.is_ok(), "{name}: {packed:?}");
    }
}
