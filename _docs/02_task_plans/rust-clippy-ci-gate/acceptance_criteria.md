# Acceptance criteria — Rust clippy gate (loop 89)

## Gate

- **AC-1** The Rust suite in the `rust:1.98` container lints the lib and every test target (`--lib --tests`) of the nine feature sets (`none`, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`, default, all features) and ends green on HEAD with 0 clippy warnings in each (9 of 9 sets checked).
- **AC-2** A change that adds one clippy warning to a test file or the lib (for example `x % 2 == 0` on an unsigned integer) makes the Rust suite fail in the set that builds that file, and the output names the feature set and quotes the warning line. A rustc warning still fails it as before (AZ-3357).
- **AC-3** When the `clippy` component cannot be installed or run, the Rust suite fails with a message naming clippy (0 runs counted as pass).
- **AC-4** The gate adds at most 120 s to the wall time of the Rust CI job, read from the first CI run after the push (the log of that job against the log of the previous green run).

## No regression

- **AC-5** `cargo test` counts in the Rust suite are unchanged (as HEAD) and `.github/workflows/run-suite.test.sh` passes with a case for AC-2 and AC-3.
- **AC-6** Library code (`rust/src`), fixtures and embedded images are unchanged, and no `allow(clippy::...)` is added anywhere.

## Size

- **AC-7** After the change no source or test file it touches is longer than 500 lines (`.github/workflows/run-suite.test.sh` is 470 lines on HEAD; `run-suite.sh` is 461).
