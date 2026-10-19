//! Load-aware wall-clock bounds (AZ-2723). A test bound is `nominal * load_factor()`: the factor is how many
//! times slower than an idle host a fixed CPU-bound reference loop runs right now, measured in this process,
//! never below 1 and never above 8. An idle host keeps the nominal bound; a host loaded by other work gets
//! more time; a slowdown of 8 times or more in the code under test still fails everywhere.
//!
//! The file is a `#[cfg(test)]` module of the library and is pulled into each integration test with
//! `#[path = "../src/timing_support.rs"] mod timing_support;`, so there is one copy.
#![allow(dead_code)]

use std::hint::black_box;
use std::sync::Mutex;
use std::time::Instant;

/// The smallest of 90 runs of `reference_run` per profile, taken on 2026-10-19 on the 10-core Mac (a loaded host only adds time), in seconds.
const REFERENCE_SECONDS_DEBUG: f64 = 0.0284;
const REFERENCE_SECONDS_RELEASE: f64 = 0.0263;
const MAX_FACTOR: f64 = 8.0;
/// A factor measured less than this long ago is reused by loops that call `recent_load_factor`.
const FRESH_SECONDS: f64 = 1.0;

fn reference_seconds() -> f64 {
    if cfg!(debug_assertions) {
        REFERENCE_SECONDS_DEBUG
    } else {
        REFERENCE_SECONDS_RELEASE
    }
}

/// Integer work the optimizer cannot remove: a table walk with a data-dependent index and a multiply chain.
pub fn reference_run() -> f64 {
    let rounds: u32 = if cfg!(debug_assertions) { 5_000_000 } else { 8_000_000 };
    let mut table = [0u32; 1024];
    for (i, slot) in table.iter_mut().enumerate() {
        *slot = (i as u32).wrapping_mul(2_654_435_761);
    }
    let table = black_box(table);
    let started = Instant::now();
    let mut state = black_box(0x9E37_79B9u32);
    for _ in 0..rounds {
        let slot = table[(state >> 22) as usize & 1023];
        state = (state ^ slot).wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
    }
    black_box(state);
    started.elapsed().as_secs_f64()
}

fn reference_best_of(runs: usize) -> f64 {
    (0..runs).map(|_| reference_run()).fold(f64::MAX, f64::min)
}

/// The smallest of 3 reference runs over the idle-host time, clamped to [1, 8].
pub fn load_factor() -> f64 {
    (reference_best_of(3) / reference_seconds()).clamp(1.0, MAX_FACTOR)
}

/// `load_factor`, reused for `FRESH_SECONDS`: for guards inside loops that run the same bound many times.
pub fn recent_load_factor() -> f64 {
    static LAST: Mutex<Option<(Instant, f64)>> = Mutex::new(None);
    let mut last = LAST.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    if let Some((at, factor)) = *last {
        if at.elapsed().as_secs_f64() < FRESH_SECONDS {
            return factor;
        }
    }
    let factor = load_factor();
    *last = Some((Instant::now(), factor));
    factor
}

/// `nominal_seconds` scaled by the load factor measured now: call it right before the timed section.
pub fn bound(nominal_seconds: f64) -> f64 {
    nominal_seconds * load_factor()
}

/// The same bound from `recent_load_factor`.
pub fn recent_bound(nominal_seconds: f64) -> f64 {
    nominal_seconds * recent_load_factor()
}

/// The mean of back-to-back reference runs over `window_seconds`, over the idle-host time, clamped to
/// [1, 8]. Unlike `load_factor` (the smallest of 3 short runs, which a scheduler serves ahead of a section that
/// has been running for seconds) it measures the throughput this process gets over a stretch as long as the
/// section that just ran, so it is taken only to confirm a failure, right after the section.
pub fn sustained_load_factor(window_seconds: f64) -> f64 {
    let started = Instant::now();
    let mut runs = 0u32;
    while runs == 0 || started.elapsed().as_secs_f64() < window_seconds.min(10.0) {
        reference_run();
        runs += 1;
    }
    (started.elapsed().as_secs_f64() / f64::from(runs) / reference_seconds()).clamp(1.0, MAX_FACTOR)
}

/// Panics, naming the nominal bound, the factor and the elapsed time, when `elapsed_seconds` is over the
/// load-aware bound. `factor_before` is the value `load_factor()` returned before the timed section. The first
/// check uses it alone; when that fails, the bound is scaled by the largest of it, a fresh `load_factor()` and
/// the sustained factor over a window as long as the section, because the load that slows a section of a
/// second or more can start after the first measurement and is not seen by a 90 ms sample.
pub fn assert_within(what: &str, elapsed_seconds: f64, nominal_seconds: f64, factor_before: f64) {
    if elapsed_seconds <= nominal_seconds * factor_before {
        return;
    }
    let sustained = sustained_load_factor(elapsed_seconds);
    let factor = factor_before.max(load_factor()).max(sustained);
    assert!(
        elapsed_seconds <= nominal_seconds * factor,
        "{what}: took {elapsed_seconds:.3} s, over the nominal bound {nominal_seconds} s x load factor {factor:.2} (before {factor_before:.2}, sustained {sustained:.2}) = {:.3} s",
        nominal_seconds * factor
    );
}
