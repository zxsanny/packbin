//! Probe of AZ-4242: a list or dict whose element is a row of required members. It builds each
//! shape of ../README.md, packs the values given there and unpacks its own bytes. One line per
//! shape: package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what
//! happens.
//!
//! The crate has two public APIs with a `list` and a `dict`, so every shape is probed twice: the
//! map form (`map_form.rs`: `MapScheme`, the shapes under their own names) and the heap-free API
//! `packbin::nostd` (`nostd_form.rs`: the same shapes with `-nostd` after the name). The typed
//! `Scheme<T>` has no list or dict of rows (its bound lists hold u16 or utf8 items) and is not
//! probed.
//!
//! `refused:` is an `Err` of the crate's error type, or a panic of `MapScheme::new`, which the
//! crate documents as its refusal of a scheme that cannot round-trip. `threw: panic:` is any other
//! panic (in pack, unpack, or a heap-free build, which promises not to panic).
mod map_form;
mod nostd_form;

use std::any::Any;
use std::cell::Cell;
use std::panic::{self, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};

thread_local! {
    /// True while `caught` runs a step: its panic is a result to print, not a failure of the probe.
    static CATCHING: Cell<bool> = const { Cell::new(false) };
}

/// Set when the probe's own code panicked: the run failed, whatever its lines say.
static FAILED: AtomicBool = AtomicBool::new(false);

fn line(shape: &str, build: &str, pack: &str, unpack: &str) {
    println!("rust\t{shape}\t{build}\t{pack}\t{unpack}");
}

fn na(shape: &str, why: &str) {
    line(shape, &format!("n/a: {why}"), "-", "-");
}

/// Whitespace runs (a tab or a line break too) as one space, so a message stays in its field.
fn one_line(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Runs `step`; a panic comes back as its message.
fn caught<T>(step: impl FnOnce() -> T) -> Result<T, String> {
    CATCHING.with(|catching| catching.set(true));
    let result = panic::catch_unwind(AssertUnwindSafe(step));
    CATCHING.with(|catching| catching.set(false));
    result.map_err(|payload| panic_message(payload.as_ref()))
}

/// The unpack cell for values that came back: `compare` gives `same` or `differs: ...`. That is the
/// probe's own code, not the crate's: if it panics the cell is `-`, the reason goes to stderr, the
/// later shapes still run and the probe exits non-zero after its last line.
fn compared(shape: &str, compare: impl FnOnce() -> String) -> String {
    caught(compare).unwrap_or_else(|message| {
        eprintln!("rust {shape}: the probe panicked on the values that came back: {message}");
        FAILED.store(true, Ordering::Relaxed);
        "-".to_string()
    })
}

fn panic_message(payload: &(dyn Any + Send)) -> String {
    if let Some(text) = payload.downcast_ref::<&str>() {
        one_line(text)
    } else if let Some(text) = payload.downcast_ref::<String>() {
        one_line(text)
    } else {
        "a panic that carries no text".to_string()
    }
}

fn main() {
    // A panic inside `caught` is printed in its line; any other panic keeps the default report.
    let report = panic::take_hook();
    panic::set_hook(Box::new(move |info| {
        if !CATCHING.with(Cell::get) {
            report(info);
        }
    }));
    map_form::run();
    nostd_form::run();
    if FAILED.load(Ordering::Relaxed) {
        std::process::exit(1);
    }
}
