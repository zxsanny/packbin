//! AZ-2757 AC-1: the hostile corpus on the heap-free core. Every `unpack`, `construct` and `limit`
//! case of `fixtures/hostile/cases.txt` returns an outcome its row allows, a case the C++ runner skips
//! is skipped with the same reason, and the fuzz corpus (and mutations of it) reads as the body of a
//! packet of every case scheme without a panic. Needs `std` and `text`.
#![cfg(all(feature = "std", feature = "text"))]

mod nostd_support;

use nostd_support::hostile::{allows, cases, fields_of, scheme_of, term, CORPUS};
use nostd_support::{from_hex, Slots};
use packbin::nostd::{unpack, validate};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

/// A case with no spelling in the core, and why (the C++ runner skips it for the same reason).
const SKIPS: [(&str, &str); 1] = [(
    "construct_empty_round_body_list_element",
    "a list element holds one field and no times, so the shape has no spelling; the plain empty times of construct_empty_times_body covers the same refusal",
)];

/// Runs `job` on its own thread; a case that does not return in 20 s is a hang (the nominal bound
/// is 1 s, so this holds on a loaded host).
fn within<R: Send + 'static>(what: &str, job: impl FnOnce() -> R + Send + 'static) -> R {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let _ = tx.send(job());
    });
    match rx.recv_timeout(Duration::from_secs(20)) {
        Ok(result) => result,
        Err(_) => panic!("{what}: no result within 20 s (a hang or a panic)"),
    }
}

fn read(id: &str, bytes: &[u8]) -> &'static str {
    let fields = fields_of(id).expect("a scheme");
    let scheme = scheme_of(&fields, id);
    let mut row = Slots::default();
    match unpack(&scheme, bytes, &mut row) {
        Ok(_) => "ok",
        Err(fault) => term(fault.error),
    }
}

fn construct(id: &str) -> &'static str {
    let fields = fields_of(id).expect("a scheme");
    match validate(&scheme_of(&fields, id)) {
        Ok(()) => "ok",
        Err(fault) => term(fault.error),
    }
}

#[test]
fn ac1_the_skipped_cases_are_exactly_the_stated_skips() {
    // Arrange
    let all = cases();
    let expected: Vec<&str> = SKIPS.iter().map(|(id, _)| *id).collect();
    // Act
    let skipped: Vec<&str> = all
        .iter()
        .filter(|c| c.stage != "pack" && fields_of(&c.id).is_none())
        .map(|c| c.id.as_str())
        .collect();
    let moved_to_skip: Vec<&str> = skipped
        .iter()
        .copied()
        .filter(|id| !expected.contains(id))
        .collect();
    let moved_to_run: Vec<&str> = expected
        .iter()
        .copied()
        .filter(|id| !skipped.contains(id) && all.iter().any(|c| c.id == *id))
        .collect();
    let unused_skips: Vec<&str> = expected
        .iter()
        .copied()
        .filter(|id| !all.iter().any(|c| c.id == *id))
        .collect();
    // Assert
    assert!(
        moved_to_skip.is_empty(),
        "cases with neither a scheme nor a stated skip (moved from run to skip): {moved_to_skip:?}"
    );
    assert!(
        moved_to_run.is_empty(),
        "stated skips that now have a scheme (moved from skip to run): {moved_to_run:?}"
    );
    assert!(
        unused_skips.is_empty(),
        "skips for ids that are not cases of cases.txt: {unused_skips:?}"
    );
    assert!(SKIPS.iter().all(|(_, reason)| !reason.is_empty()));
    assert!(
        all.iter().any(|c| c.stage != "pack"),
        "cases.txt holds no case but pack cases"
    );
}

#[test]
fn ac1_each_unpack_and_limit_case_returns_an_outcome_its_row_allows() {
    // Arrange
    let mut ran = 0;
    for c in cases()
        .iter()
        .filter(|c| c.stage == "unpack" || c.stage == "limit")
    {
        let (id, bytes) = (c.id.clone(), from_hex(&c.hex));
        // Act
        let got = within(&c.id, move || read(&id, &bytes));
        // Assert
        assert!(
            allows(&c.expected, got),
            "{}: got {got}, allowed {}",
            c.id,
            c.expected
        );
        ran += 1;
    }
    assert!(ran > 0, "cases.txt holds no unpack or limit case");
}

#[test]
fn ac1_each_construct_case_is_a_scheme_error() {
    // Arrange
    let mut ran = 0;
    for c in cases().iter().filter(|c| c.stage == "construct") {
        if SKIPS.iter().any(|(id, _)| *id == c.id) {
            continue;
        }
        let id = c.id.clone();
        // Act
        let got = within(&c.id, move || construct(&id));
        // Assert
        assert!(
            allows(&c.expected, got),
            "{}: got {got}, allowed {}",
            c.id,
            c.expected
        );
        ran += 1;
    }
    assert!(ran > 0, "cases.txt holds no construct case to run");
}

#[test]
fn ac1_a_limit_case_stops_at_the_round_it_would_start() {
    // Arrange
    let case = cases()
        .into_iter()
        .find(|c| c.id == "repeat_rounds_over_limit")
        .expect("case");
    let fields = fields_of(&case.id).expect("scheme");
    let scheme = scheme_of(&fields, &case.id);
    let mut row = Slots::default();
    // Act
    let fault = unpack(&scheme, &from_hex(&case.hex), &mut row).expect_err("refused");
    // Assert
    assert!(matches!(term(fault.error), "too_many" | "bad_value"));
    assert_eq!(fault.needed, 3, "the limit is named, not a short read");
}

/// The fuzz corpus: (name, kind, bytes).
fn corpus() -> Vec<(String, String, Vec<u8>)> {
    std::fs::read_to_string(CORPUS)
        .expect("corpus.txt")
        .lines()
        .filter(|l| !l.trim().is_empty() && !l.starts_with('#'))
        .map(|l| {
            let f: Vec<&str> = l.split_whitespace().collect();
            (f[0].to_string(), f[1].to_string(), from_hex(f[2]))
        })
        .collect()
}

/// The inputs corpus.txt lists, counted by the README rule and not by the loader's filter: an input
/// is `name kind hex`, name and kind only `[a-z0-9_]`, hex lowercase, so a comment never counts,
/// whatever it ends with.
fn listed_inputs() -> usize {
    let word = |s: &str| {
        s.bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_')
    };
    std::fs::read_to_string(CORPUS)
        .expect("corpus.txt")
        .lines()
        .filter(|l| {
            let mut f = l.split_whitespace();
            match (f.next(), f.next(), f.next(), f.next()) {
                (Some(name), Some(kind), Some(hex), None) => {
                    word(name)
                        && word(kind)
                        && hex
                            .bytes()
                            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
                }
                _ => false,
            }
        })
        .count()
}

/// Every scheme a corpus input is read with: the case schemes (type number 1).
fn scheme_ids() -> Vec<String> {
    cases()
        .into_iter()
        .filter(|c| c.stage != "pack" && fields_of(&c.id).is_some())
        .map(|c| c.id)
        .collect()
}

/// Reads `bytes` with every scheme, as a packet and as the body of a packet of each scheme.
fn read_with_every_scheme(ids: &[String], bytes: &[u8]) {
    for id in ids {
        let fields = fields_of(id).expect("scheme");
        if validate(&scheme_of(&fields, id)).is_err() {
            continue;
        }
        let scheme = scheme_of(&fields, id);
        let mut packet = vec![1u8];
        packet.extend_from_slice(bytes.get(1..).unwrap_or(&[]));
        let mut body = vec![1u8];
        body.extend_from_slice(bytes);
        for candidate in [bytes, packet.as_slice(), body.as_slice()] {
            let mut row = Slots {
                cap: Some(256),
                ..Slots::default()
            };
            let _ = unpack(&scheme, candidate, &mut row);
        }
    }
}

#[test]
fn ac1_the_fuzz_corpus_reads_without_a_panic_and_its_hostile_inputs_keep_their_outcome() {
    // Arrange
    let inputs = corpus();
    let ids = scheme_ids();
    let by_case = cases();
    // Act
    let (ids2, inputs2) = (ids.clone(), inputs.clone());
    within("corpus", move || {
        for (_, _, bytes) in &inputs2 {
            read_with_every_scheme(&ids2, bytes);
        }
    });
    // Assert
    let listed = listed_inputs();
    assert_eq!(
        inputs.len(),
        listed,
        "corpus.txt lists {listed} inputs, the loader read {}",
        inputs.len()
    );
    assert!(listed > 0, "corpus.txt holds no input");
    for c in by_case
        .iter()
        .filter(|c| c.stage == "unpack" || c.stage == "limit")
    {
        let name = format!("hostile_{}", c.id);
        let packet = from_hex(&c.hex);
        assert!(
            inputs
                .iter()
                .any(|(n, kind, bytes)| *n == name && *kind == c.id && *bytes == packet),
            "case {} has no input {name} in the fuzz corpus",
            c.id
        );
    }
    for (name, kind, bytes) in &inputs {
        let Some(case) = by_case.iter().find(|c| &c.id == kind) else {
            assert!(
                !name.starts_with("hostile_"),
                "corpus input {name} names {kind}, which is not a case of cases.txt"
            );
            continue;
        };
        assert!(name.starts_with("hostile_"), "{name}");
        let got = read(&case.id, bytes);
        assert!(
            allows(&case.expected, got),
            "{name}: got {got}, allowed {}",
            case.expected
        );
    }
}

#[test]
fn ac1_mutated_corpus_inputs_never_panic_on_any_case_scheme() {
    // Arrange
    let inputs = corpus();
    let ids = scheme_ids();
    let mut state = 0x9E37_79B9_7F4A_7C15u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    let mut mutated = Vec::new();
    for (_, _, bytes) in &inputs {
        for _ in 0..40 {
            let mut m = bytes.clone();
            match next() % 4 {
                0 if !m.is_empty() => {
                    let at = (next() as usize) % m.len();
                    m[at] ^= (next() as u8) | 1;
                }
                1 if !m.is_empty() => m.truncate((next() as usize) % m.len()),
                2 => m.extend((0..(next() % 8)).map(|_| next() as u8)),
                _ => {
                    let at = (next() as usize) % (m.len() + 1);
                    m.insert(at, next() as u8);
                }
            }
            mutated.push(m);
        }
    }
    // Act
    within("mutations", move || {
        for bytes in &mutated {
            read_with_every_scheme(&ids, bytes);
        }
    });
    // Assert: reaching this line is the property (no panic, no hang)
}
