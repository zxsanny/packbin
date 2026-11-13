---
title: "A Rust test file that uses the std API carries `#![cfg(feature = \"std\")]`; build the 8 feature sets with --no-run"
applies_when: "adding a Rust test file in rust/tests/ or a library test module in session_core/"
source: "loop 76 (AZ-3331)"
---

A Rust test file in `rust/tests/` that uses the std API (`MapScheme`, `Values`, `pack`, `unpack`) carries an inner `#![cfg(feature = "std")]` (loop 76, AZ-3331): without it `cargo test --no-default-features [--features <set>]` fails to compile, and the CI suite never shows it because `run-suite.sh` names each no-std target with `--test <name>`.

Library test modules of `session_core/` need `use std::{format, string::String}` under `cfg(not(feature = "std"))` and `extern crate std` under `cfg(all(test, not(feature = "std")))` in `lib.rs`.

After adding a test file, build the 8 sets with `--no-run` (`smoke76.sh` step 5); at test time none 19, alloc 20, text 28, ecc 29, text+ecc 38, text+ecc+frame 45 passed.
