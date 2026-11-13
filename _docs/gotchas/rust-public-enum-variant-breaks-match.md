---
title: "A new variant on a public Rust enum breaks every exhaustive match: grep and run the full Rust suite before the commit"
applies_when: "adding a variant or field to a public Rust enum (nostd::Error, UnpackError)"
source: "loop 69 (nostd::Error variants), loop 97 (AZ-3511, MixedParity fields)"
---

A new variant on a public enum (`nostd::Error` gained `TagMismatch`, `Duplicate`, `TooOld` in loop 69) breaks every exhaustive `match` on it: `rust/tests/nostd_support/hostile.rs` (the `term` function) failed to compile in the `text,ecc` test targets and only the full `run-suite.sh` list (not a hand-picked set) compiles them; `grep -rn "Error::TooLong =>" rust` before the commit, and run `docker compose -f docker-compose.test.yml run --rm rust`.

`UnpackError::MixedParity` has the two flags `first_percent` and `other_percent` since loop 97 (AZ-3511): a pattern that names `first` and `other` without `..` no longer compiles.
