//! Probe of AZ-4291: what the crate does with a scheme nested very deep. `probe <api> <shape> <depth>` (api: `map` or `nostd`) builds
//! the scheme, packs one row and unpacks its own bytes, and prints one tab-separated line: package,
//! shape-with-depth, build, pack, unpack. It asserts nothing: it prints what happens.
//!
//! Shapes: `when` (`u8 a`, then `depth` nested `when(a == 1, ...)`, the innermost holding `u8 b`;
//! values a = 1, b = 7; bytes 01 01 07) and `group` (`depth` nested groups, the innermost holding
//! `u8 b`; b = 7).
//!
//! Two APIs are probed: the map form (`map_form.rs`, `MapScheme`, package `rust`) and the heap-free
//! `packbin::nostd` (`nostd_form.rs`, shape suffix `-nostd`). `nostd` takes a table of entries built
//! at run time as a `Vec<Field>` (a `Scheme` borrows a slice), so depth is not fixed at compile time;
//! a `when` or `group` entry counts its members in a `u16`, so depth 50000 fits (at most 65535).
//!
//! Form used for `group`: in both APIs the only group is the anchored one, whose members sit on the row
//! around it (the crate has no nested row), so the nesting is a group inside a group, and the values
//! are flat (`b` only). Same form as `scripts/probes/repeat-followed-by-field` shape `d`.
//!
//! The probe builds its scheme iteratively (innermost first) and never recurses itself. A deep value
//! dropped by the crate's own `Drop` could overflow the stack, so the probe never drops the deep scheme:
//! it prints its line and leaves with `process::exit`, which runs no destructors. A scheme the library
//! refuses by panicking is dropped by the unwinding, which is the library's behaviour, not the probe's.
//! The stack is the main thread's default: a stack overflow kills the process, and `case.sh` turns that
//! into a `crashed:` line.
mod map_form;
mod nostd_form;

use std::any::Any;
use std::cell::Cell;
use std::panic::{self, AssertUnwindSafe};

thread_local! {
    /// True while `caught` runs a step: its panic is a result to print, not a failure of the probe.
    static CATCHING: Cell<bool> = const { Cell::new(false) };
}

/// The line of one case: five tab-separated fields.
pub struct Cells {
    pub shape: String,
    pub build: String,
    pub pack: String,
    pub unpack: String,
}

/// Whitespace runs (a tab or a line break too) as one space, a message cut to 120 characters.
pub fn message(text: &str) -> String {
    let one: String = text.split_whitespace().collect::<Vec<_>>().join(" ");
    one.chars().take(120).collect()
}

/// Hex of the bytes, the first 40 characters and the byte count when it is longer than 80.
pub fn hex(bytes: &[u8]) -> String {
    let text: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
    if text.len() > 80 {
        format!("{}...{} bytes", &text[..40], bytes.len())
    } else {
        text
    }
}

/// Runs `step`; a panic comes back as its message. The crate refuses a scheme with a panic.
pub fn caught<T>(step: impl FnOnce() -> T) -> Result<T, String> {
    CATCHING.with(|catching| catching.set(true));
    let result = panic::catch_unwind(AssertUnwindSafe(step));
    CATCHING.with(|catching| catching.set(false));
    result.map_err(|payload| panic_message(payload.as_ref()))
}

fn panic_message(payload: &(dyn Any + Send)) -> String {
    if let Some(text) = payload.downcast_ref::<&str>() {
        message(text)
    } else if let Some(text) = payload.downcast_ref::<String>() {
        message(text)
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
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (api, shape, depth) = match args.as_slice() {
        [api, shape, depth] => match depth.parse::<usize>() {
            Ok(depth) if depth > 0 => (api.as_str(), shape.as_str(), depth),
            _ => usage(),
        },
        _ => usage(),
    };
    if shape != "when" && shape != "group" {
        usage();
    }
    let cells = match api {
        "map" => map_form::run(shape, depth),
        "nostd" => nostd_form::run(shape, depth),
        _ => usage(),
    };
    println!(
        "rust\t{}\t{}\t{}\t{}",
        cells.shape, cells.build, cells.pack, cells.unpack
    );
    // No destructors: the deep scheme is the library's to drop, never the probe's.
    std::process::exit(0);
}

fn usage() -> ! {
    eprintln!("usage: probe <map|nostd> <when|group> <depth>");
    std::process::exit(2);
}
