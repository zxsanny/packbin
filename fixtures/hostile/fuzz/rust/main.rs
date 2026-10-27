//! packbin hostile-input probe, Rust (AZ-2666, loop 41): the compact text decoder and the message ECC
//! unpack path (plain and dispatch), through the public API only.
//!
//! How to run: `sh run.sh <packbin checkout> <build dir> <debug|release> <command> [args]` (see run.sh).
//! The sources are main.rs and the files it includes (tools, calls, random, perf, edges).
//! The binary takes the checkout first: it reads `fixtures/text/vectors.txt`, `fixtures/ecc/vectors.txt`,
//! `fixtures/hostile/fuzz/corpus.txt` and the frozen code lengths in `rust/src/walk/text_tables.rs`.
//!
//!   random  <seed> <calls>   (a) seeded random and mutated inputs: text unpack (lone string, list, dict),
//!                            ECC unpack (random buffers, code words with k wrong bytes, vector seeds),
//!                            and strings inside protected messages. Prints seed, calls, accepted/refused,
//!                            panics and the slowest call.
//!   ecctime <calls>          (b) repair time at n = 32, N = 254 for the inputs that make the most work.
//!   textamp <case>           (c) decoded bytes per payload byte, time and peak RSS:
//!                            one | list1m | list8m | controls | short
//!   edges                    (d) the AC-1 / AC-2 edge cases a random run is unlikely to reach.
//!
//! Exit status 1 when an invariant is broken (a panic, a call above 1 s, a wrong repair).
use packbin::{
    bytes, dict, insert, list, pack, unpack, unpack_repair, utf8, BinaryPacker, DispatchHandler,
    MapScheme, UnpackError, Value, Values,
};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::{Duration, Instant};

include!("tools.rs");
include!("calls.rs");
include!("random.rs");
include!("perf.rs");
include!("edges.rs");

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: probe <checkout> random <seed> <calls> | ecctime <calls> | textamp <case> | edges");
        std::process::exit(2);
    }
    std::panic::set_hook(Box::new(|info| {
        let msg = info.to_string();
        let short: String = msg.chars().take(300).collect();
        eprintln!("panic: {short}");
    }));
    let checkout = &args[1];
    let ok = match args[2].as_str() {
        "random" => random(
            checkout,
            u64::from_str_radix(args.get(3).map(|s| s.trim_start_matches("0x")).unwrap_or("5eed"), 16).expect("seed (hex)"),
            args.get(4).map(|s| s.parse().expect("calls")).unwrap_or(20_000),
        ),
        "ecctime" => ecctime(args.get(3).map(|s| s.parse().expect("calls")).unwrap_or(20_000)),
        "textamp" => textamp(checkout, args.get(3).map(String::as_str).unwrap_or("one")),
        "edges" => edges(checkout),
        other => panic!("unknown command {other}"),
    };
    std::process::exit(if ok { 0 } else { 1 });
}
