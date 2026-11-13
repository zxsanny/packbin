//! Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of
//! ../README.md, packs each shape's values and unpacks its own bytes. One line per shape:
//! package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//!
//! The crate has three public ways to write S, so every shape is probed three times:
//! - the map form (`map_form.rs`): the lines under the shape names of the README, on stdout;
//! - the heap-free API `packbin::nostd` (`nostd_form.rs`): `-nostd` after the shape name, on stdout,
//!   as in the repeat probe;
//! - the typed `Scheme<T>` (`typed_form.rs`): `-typed` after the shape name, on stdout when its
//!   build, pack or unpack cell differs from the map form's line of the same shape, else on stderr.
mod map_form;
mod nostd_form;
mod typed_form;

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

/// The shapes of the README, in order.
pub const SHAPES: [&str; 4] = ["both", "x-only", "b-only", "none"];

/// The values of a shape: `x` and `b`, `None` for a value the shape leaves out.
pub fn values_of(shape: &str) -> (Option<u8>, Option<bool>) {
    match shape {
        "both" => (Some(9), Some(true)),
        "x-only" => (Some(9), None),
        "b-only" => (None, Some(true)),
        _ => (None, None),
    }
}

/// The build, pack and unpack cells of one line.
pub type Cells = [String; 3];

pub fn line(shape: &str, cells: &Cells) -> String {
    format!("rust\t{shape}\t{}\t{}\t{}", cells[0], cells[1], cells[2])
}

/// Whitespace runs (a tab or a line break too) as one space, so a message stays in its field.
pub fn one_line(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Cells for a step that stopped: `cells` so far, `-` for the rest.
pub fn stopped(cells: &[String]) -> Cells {
    let mut out = [String::from("-"), String::from("-"), String::from("-")];
    for (i, cell) in cells.iter().enumerate() {
        out[i] = cell.clone();
    }
    out
}

/// Runs `step`; a panic comes back as its message. The crate refuses a scheme with a panic.
pub fn caught<T>(step: impl FnOnce() -> T) -> Result<T, String> {
    CATCHING.with(|catching| catching.set(true));
    let result = panic::catch_unwind(AssertUnwindSafe(step));
    CATCHING.with(|catching| catching.set(false));
    result.map_err(|payload| panic_message(payload.as_ref()))
}

/// The unpack cell for values that came back: `compare` gives `same` or `differs: ...`. That is the
/// probe's own code, not the crate's: if it panics the cell is `-`, the reason goes to stderr, the
/// later shapes still run and the probe exits non-zero after its last line.
pub fn compared(shape: &str, compare: impl FnOnce() -> String) -> String {
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
    let mut map_cells = Vec::new();
    for shape in SHAPES {
        let cells = map_form::probe(shape);
        println!("{}", line(shape, &cells));
        map_cells.push(cells);
    }
    for shape in SHAPES {
        println!(
            "{}",
            line(&format!("{shape}-nostd"), &nostd_form::probe(shape))
        );
    }
    for (shape, map) in SHAPES.iter().zip(&map_cells) {
        let cells = typed_form::probe(shape);
        let text = line(&format!("{shape}-typed"), &cells);
        if &cells == map {
            eprintln!("same outcome as the map form, not on stdout: {text}");
        } else {
            println!("{text}");
        }
    }
    if FAILED.load(Ordering::Relaxed) {
        std::process::exit(1);
    }
}
