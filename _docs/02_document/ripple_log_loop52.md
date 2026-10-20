# Ripple log — loop 52

Changed: `rust/src/nostd/**` (AZ-2754, AZ-2755), `rust/src/ecc.rs` (now on `rust/src/ecc_core.rs`), `rust/src/lib.rs`. Importers:

- `rust/src/ecc.rs` importers (`walk/mod.rs`, `scheme/mod.rs`, `session/mod.rs`, `field/map_scheme.rs`): the functions they call (`append`, `check_len`, `push_parity`, `unprotect`, `check_limit`, `shared_parity`, `MAX_PARITY`) keep their signatures; the 22 std ECC lib tests, `ecc_scheme_tests`, `ecc_session_dispatch_tests` and the 1,339 vector rows pass unchanged.
- `rust/embedded/**` — probe, `main.cpp`, `target.sh`, `feature-sets.txt`, `limits.txt` changed (sets `text` and `ecc`, weak `pb_rs_extra`).
- `.github/workflows/run-suite.sh` and `run-suite.test.sh` — three more `cargo test` runs for the feature parts.
- `walk/text_tables.rs` (generated, unedited) is also read by `nostd/text/mod.rs`.

No other component imports `nostd`.
