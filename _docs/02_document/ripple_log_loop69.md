# Ripple log — loop 69

Changed source: `rust/src/nostd/session.rs`, `rust/src/nostd/error.rs`, `rust/src/nostd/mod.rs`, `rust/src/session_core/{mod,pad,sha256}.rs`, `rust/Cargo.toml`, `rust/src/lib.rs`, new `rust/src/nostd/frame/`, `rust/src/session_core/{hmac,counters}.rs`.

- docs/components/04_rust_package/description.md — refreshed: the frame feature, its API, sizes and device figures (done in this loop).
- docs/contracts/library/pack-session.md — refreshed: 2.0.0, frame mode and MAC-only (AZ-3200).
- docs/module-layout.md — refreshed: the loop 69 file list.
- docs/adr/ — ADR-008 added; index updated.
- docs/architecture.md — the authentication line (AZ-3200).
- Importers of `nostd::Session` and `nostd::Error`: `rust/embedded/probe` (frame set added; the session set unchanged to the byte), `rust/tests/nostd_session_tests.rs` (unchanged, passes). `Error` gained three kinds: no exhaustive `match` on `Error` exists outside the new tests (the build is clean).
- Other packages (C#, TypeScript, Python, C++, Java, Go, Swift): not touched; their docs are unchanged by design (frame mode is Rust-first; the error kind names are fixed in the contract for them).
