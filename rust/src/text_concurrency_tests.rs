use crate::timing_support::{assert_within, load_factor};
use crate::walk::{decode_text, encode_text, pack, unpack};
use crate::{insert, utf8, MapScheme, Value, Values};
use std::collections::HashSet;
use std::sync::mpsc::{channel, RecvTimeoutError};
use std::sync::{Arc, Barrier};
use std::thread;
use std::time::{Duration, Instant};

// AZ-2735 (CS-S3, TW-1): eight threads pack and unpack different texts at once. The only state the threads share is
// what the codec itself holds: the table set built once per process. A scheme cannot be shared: its names are `Rc<str>`,
// so `MapScheme`, `Field`, `Values` and `Value` are neither `Send` nor `Sync`, and every thread builds its own scheme
// from the same field list. The texts and the reference bytes cross the threads as `String` and `Vec<u8>`.

const VECTORS: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures/text/vectors.txt");
const WORKERS: usize = 8;
const RANDOM_TEXTS: usize = 100;
/// The join limit that turns a hang into a failure; it is not a timing assertion.
const HANG_GUARD_SECONDS: f64 = 30.0;

/// A small deterministic generator, so a failure reproduces.
struct Lcg(u64);

impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.0 >> 33
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

#[derive(Clone)]
struct Case {
    id: String,
    text: String,
    /// The reference field of a vector row. A random text has none: its reference is the codec run alone after the join.
    field: Option<Vec<u8>>,
}

/// The `enc` rows of fixtures/text/vectors.txt: `enc <id> <text hex or -> <field hex>`.
fn vector_cases() -> Vec<Case> {
    let file = std::fs::read_to_string(VECTORS).expect("vectors file");
    file.lines()
        .filter(|line| line.starts_with("enc "))
        .map(|line| {
            let cols: Vec<&str> = line.split(' ').collect();
            let text = if cols[2] == "-" {
                String::new()
            } else {
                String::from_utf8(from_hex(cols[2])).expect("row text is UTF-8")
            };
            Case {
                id: cols[1].to_string(),
                text,
                field: Some(from_hex(cols[3])),
            }
        })
        .collect()
}

/// Every vector row and `RANDOM_TEXTS` other distinct random texts of a seed per worker, in an order that differs per worker.
fn cases_for(worker: usize, vectors: &[Case]) -> Vec<Case> {
    let pool: Vec<char> = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'ёъыэАБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ \
        abcxyzABCXYZ0123456789.,-:;!?()\"%/@+=*#&_$\n\t\u{0}😀🎉中文日本語한국어ß€é\u{301}\u{200d}\u{feff}\u{10ffff}"
        .chars()
        .collect();
    let mut seen: HashSet<String> = vectors.iter().map(|case| case.text.clone()).collect();
    let mut cases = vectors.to_vec();
    let mut rng = Lcg(0x5eed + worker as u64);
    let mut made = 0;
    while made < RANDOM_TEXTS {
        // Every tenth text is long enough (256 UTF-8 bytes or more) for the walker's per-call text memory.
        let len = if made % 10 == 9 {
            200 + rng.below(300)
        } else {
            1 + rng.below(80)
        };
        let text: String = (0..len).map(|_| pool[rng.below(pool.len())]).collect();
        if seen.insert(text.clone()) {
            cases.push(Case {
                id: format!("random.w{worker}.{made}"),
                text,
                field: None,
            });
            made += 1;
        }
    }
    let by = worker * cases.len() / WORKERS;
    cases.rotate_left(by);
    cases
}

#[derive(Default)]
struct Report {
    packed: Vec<Vec<u8>>,
    errors: Vec<String>,
    mismatches: Vec<String>,
}

/// Packs and unpacks each case with a scheme built in this thread and checks what comes back against the case itself.
fn work(cases: &[Case], start: &Barrier) -> Report {
    let scheme = MapScheme::new(1, vec![utf8("s")]);
    let mut report = Report::default();
    start.wait();
    for case in cases {
        let mut values = Values::new();
        insert(&mut values, "s", Some(Value::Str(case.text.clone())));
        let packet = match pack(&scheme, &values) {
            Ok(packet) => packet,
            Err(error) => {
                report.errors.push(format!("{}: pack {error:?}", case.id));
                report.packed.push(Vec::new());
                continue;
            }
        };
        let field = packet[1..].to_vec();
        if packet[0] != 1 || encode_text(&case.text).as_deref() != Some(field.as_slice()) {
            report.mismatches.push(format!(
                "{}: packed field differs from the codec's own",
                case.id
            ));
        }
        match unpack(&scheme, &packet) {
            Ok(mut unpacked) => match unpacked.remove("s") {
                Some(Some(Value::Str(text))) if text == case.text => {}
                other => report
                    .mismatches
                    .push(format!("{}: unpacked {other:?}", case.id)),
            },
            Err(error) => report.errors.push(format!("{}: unpack {error:?}", case.id)),
        }
        match decode_text(&field) {
            Ok((text, used)) if text == case.text && used == field.len() => {}
            _ => report
                .mismatches
                .push(format!("{}: decode_text of the packed field", case.id)),
        }
        report.packed.push(field);
    }
    report
}

struct Run {
    elapsed: f64,
    round_trips: usize,
    mismatches: Vec<String>,
    errors: Vec<String>,
}

/// Starts `WORKERS` threads together, waits for every report within the hang guard and checks the packed fields
/// against the reference bytes of the vector rows and, for the random texts, against the codec run alone.
fn run_workers(vectors: &[Case], factor: f64) -> Run {
    let start = Arc::new(Barrier::new(WORKERS + 1));
    let (sender, receiver) = channel();
    for worker in 0..WORKERS {
        let cases = cases_for(worker, vectors);
        let (start, sender) = (Arc::clone(&start), sender.clone());
        thread::Builder::new()
            .name(format!("text-worker-{worker}"))
            .spawn(move || {
                let report = work(&cases, &start);
                if sender.send((worker, report)).is_err() {
                    eprintln!(
                        "text-worker-{worker}: the test stopped waiting before the report came"
                    );
                }
            })
            .expect("spawn a worker thread");
    }
    drop(sender);
    start.wait();
    let started = Instant::now();
    let deadline = started + Duration::from_secs_f64(HANG_GUARD_SECONDS * factor);
    let mut reports = Vec::new();
    while reports.len() < WORKERS {
        match receiver.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
            Ok(report) => reports.push(report),
            Err(RecvTimeoutError::Timeout) => panic!(
                "{} of {WORKERS} workers reported within {HANG_GUARD_SECONDS} s x load factor {factor:.2}",
                reports.len()
            ),
            Err(RecvTimeoutError::Disconnected) => panic!(
                "a worker ended without a report ({} of {WORKERS} reported): it panicked",
                reports.len()
            ),
        }
    }
    let elapsed = started.elapsed().as_secs_f64();

    let mut run = Run {
        elapsed,
        round_trips: 0,
        mismatches: Vec::new(),
        errors: Vec::new(),
    };
    for (worker, report) in reports {
        let cases = cases_for(worker, vectors);
        run.round_trips += report.packed.len();
        run.errors.extend(report.errors);
        run.mismatches.extend(report.mismatches);
        for (case, packed) in cases.iter().zip(&report.packed) {
            let reference = match &case.field {
                Some(field) => Some(field.clone()),
                None => encode_text(&case.text),
            };
            if reference.as_ref() != Some(packed) && !packed.is_empty() {
                run.mismatches.push(format!(
                    "{}: worker {worker} packed other bytes than the reference",
                    case.id
                ));
            }
        }
    }
    run
}

#[test]
fn tw1_ac1_eight_workers_pack_and_unpack_vector_rows_and_random_texts_to_the_reference_bytes() {
    // Arrange
    let vectors = vector_cases();
    let distinct: HashSet<String> = cases_for(0, &vectors)
        .into_iter()
        .map(|case| case.text)
        .collect();
    let factor = load_factor();

    // Act
    let run = run_workers(&vectors, factor);

    // Assert
    assert!(vectors.len() >= 290, "{} enc rows", vectors.len());
    assert!(
        distinct.len() >= 200,
        "{} distinct texts per worker",
        distinct.len()
    );
    assert_eq!(run.round_trips, WORKERS * (vectors.len() + RANDOM_TEXTS));
    assert!(
        run.mismatches.is_empty(),
        "{} mismatches, first: {:?}",
        run.mismatches.len(),
        &run.mismatches[..run.mismatches.len().min(5)]
    );
    assert!(
        run.errors.is_empty(),
        "{} errors, first: {:?}",
        run.errors.len(),
        &run.errors[..run.errors.len().min(5)]
    );
}

#[test]
fn tw1_ac2_the_eight_workers_finish_within_a_second_nominal_times_the_load_factor() {
    // Arrange
    let vectors = vector_cases();
    let factor = load_factor();

    // Act
    let run = run_workers(&vectors, factor);

    // Assert
    eprintln!(
        "text concurrency: {WORKERS} workers x {} texts in {:.3} s (nominal bound 1 s, load factor {factor:.2})",
        run.round_trips / WORKERS,
        run.elapsed
    );
    assert_within(
        "8 workers packing and unpacking different texts",
        run.elapsed,
        1.0,
        factor,
    );
}
