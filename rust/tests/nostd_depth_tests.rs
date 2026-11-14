//! AZ-4302: the heap-free API refuses a scheme nested deeper than 256 levels, first, without a heap
//! or recursion, measured on the flat table; 256 levels still validate, pack and unpack. A table
//! of 32,769 entries or more is still refused by `MAX_FIELDS` (the API's own refusal). The
//! 256-level pack and unpack run on the default test thread, debug build included.
#![cfg(feature = "std")]

mod nostd_support;

use nostd_support::Slots;
use packbin::nostd::{
    group, list, pack, repeat, times, u8, unpack, validate, when, Error, Field, Num, Scheme,
    MAX_FIELDS,
};
use std::time::{Duration, Instant};

const LIMIT: usize = 256;

/// `u8 0`, then `depth` whens (`0 == 1`), each with the entries below it, then `u8 1`.
fn when_table(depth: usize) -> Vec<Field> {
    let mut table = vec![u8(0)];
    for below in (1..=depth).rev() {
        table.push(when(1, 0, 1, below as u16));
    }
    table.push(u8(1));
    table
}

/// `depth` groups, each with the entries below it, then `u8 0`.
fn group_table(depth: usize) -> Vec<Field> {
    let mut table: Vec<Field> = (1..=depth)
        .rev()
        .map(|below| group(0, below as u16))
        .collect();
    table.push(u8(0));
    table
}

/// `depth` lists, each holding the next as its element, then `u8 0`.
fn list_table(depth: usize) -> Vec<Field> {
    let mut table: Vec<Field> = (1..=depth)
        .rev()
        .map(|below| list(0, below as u16))
        .collect();
    table.push(u8(0));
    table
}

/// `u8 0`, then `depth` `times` on it, each with the entries below it, then `u8 1`.
fn times_table(depth: usize) -> Vec<Field> {
    let mut table = vec![u8(0)];
    for below in (1..=depth).rev() {
        table.push(times(1, 0, below as u16));
    }
    table.push(u8(1));
    table
}

/// `depth` repeats, each with the entries below it, then `u8 0`.
fn repeat_table(depth: usize) -> Vec<Field> {
    let mut table: Vec<Field> = (1..=depth)
        .rev()
        .map(|below| repeat(0, below as u16))
        .collect();
    table.push(u8(0));
    table
}

type Table = fn(usize) -> Vec<Field>;

const KINDS: [(&str, Table); 5] = [
    ("when", when_table),
    ("group", group_table),
    ("list", list_table),
    ("times", times_table),
    ("repeat", repeat_table),
];

fn check(table: &[Field]) -> Result<(), packbin::nostd::Fault> {
    validate(&Scheme::new(1, table))
}

#[test]
fn every_kind_over_256_levels_is_refused_quickly() {
    // AC-1: 257, 1,000 and 5,000 levels, named by the first entry that is the 257th level
    for (kind, table) in KINDS {
        for depth in [257, 1_000, 5_000] {
            // Arrange
            let table = table(depth);
            let started = Instant::now();

            // Act
            let fault = check(&table).expect_err(kind);

            // Assert
            assert_eq!(fault.error, Error::SchemeInvalid, "{kind} {depth}");
            assert_eq!(fault.needed, LIMIT, "{kind} {depth}");
            assert!(started.elapsed() < Duration::from_secs(5), "{kind} {depth}");
        }
    }
}

#[test]
fn the_fault_names_the_257th_level() {
    // AC-1: the fault is the entry that opens level 257, not the end of the table
    // Arrange
    let whens = when_table(300);
    let groups = group_table(300);

    // Act
    let when_fault = check(&whens).expect_err("when");
    let group_fault = check(&groups).expect_err("group");

    // Assert (`u8 0` comes first in the when table; the 257th `when` is entry 257)
    assert_eq!((when_fault.offset, when_fault.field), (257, 1));
    assert_eq!((group_fault.offset, group_fault.field), (256, 0));
}

#[test]
fn a_table_over_max_fields_is_still_refused_by_its_own_limit() {
    // AC-1: 50,000 entries are refused by MAX_FIELDS first; 32,000 by the depth rule
    // Arrange
    let huge = when_table(50_000);
    let large = when_table(32_000);

    // Act
    let by_size = check(&huge).expect_err("50,000");
    let by_depth = check(&large).expect_err("32,000");

    // Assert
    assert_eq!(
        (by_size.error, by_size.needed),
        (Error::SchemeInvalid, MAX_FIELDS)
    );
    assert_eq!(
        (by_depth.error, by_depth.needed),
        (Error::SchemeInvalid, LIMIT)
    );
}

#[test]
fn every_kind_validates_at_256_levels_and_not_at_257() {
    // AC-1 boundary: the depth rule is the only difference between the two tables
    for (kind, table) in KINDS {
        // Arrange
        let at_limit = table(LIMIT);
        let over = table(LIMIT + 1);

        // Act
        let at_limit = check(&at_limit);
        let over = check(&over).expect_err(kind);

        // Assert (`times` and `repeat` inside each other have their own shape refusals past it)
        assert_eq!(over.needed, LIMIT, "{kind}");
        if let Err(fault) = at_limit {
            assert_ne!(
                fault.needed, LIMIT,
                "{kind}: refused by the depth rule at 256"
            );
        }
    }
}

#[test]
fn a_flat_table_with_many_containers_is_not_a_deep_one() {
    // AC-2: 1,000 groups side by side are one level, whatever their number
    // Arrange
    let mut wide: Vec<Field> = Vec::new();
    for id in 0..1_000u16 {
        wide.push(group(id, 1));
        wide.push(u8(id));
    }

    // Act
    let result = check(&wide);

    // Assert
    assert_eq!(result, Ok(()));
}

#[test]
fn a_when_chain_of_256_packs_and_unpacks() {
    // AC-2
    // Arrange
    let table = when_table(LIMIT);
    let scheme = Scheme::new(1, &table);
    let given = Slots::with(&[(0, Num::U8(1)), (1, Num::U8(7))], &[]);
    let mut out = [0u8; 16];

    // Act
    let n = pack(&scheme, &given, &mut out).expect("pack");
    let mut back = Slots::default();
    unpack(&scheme, &out[..n], &mut back).expect("unpack");

    // Assert
    assert_eq!(&out[..n], &[1, 1, 7]);
    assert_eq!(back, given);
}

#[test]
fn a_group_chain_of_256_packs_and_unpacks() {
    // AC-2
    // Arrange
    let table = group_table(LIMIT);
    let scheme = Scheme::new(1, &table);
    let given = Slots::with(&[(0, Num::U8(7))], &[]);
    let mut out = [0u8; 16];

    // Act
    let n = pack(&scheme, &given, &mut out).expect("pack");
    let mut back = Slots::default();
    unpack(&scheme, &out[..n], &mut back).expect("unpack");

    // Assert
    assert_eq!(&out[..n], &[1, 7]);
    assert_eq!(back, given);
}
