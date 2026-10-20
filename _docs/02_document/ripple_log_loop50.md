# Ripple log — loop 50

Changed source: `rust/Cargo.toml` (features, `exclude`), `rust/src/lib.rs` (cfg gates, `pub mod nostd`), new `rust/src/nostd/**`, `rust/embedded/**`, `.github/workflows/test.yml`, `.github/workflows/run-suite.sh`, `docker-compose.test.yml`, `scripts/loop-tests.sh`.

Importers of the Rust crate found with `rg "packbin::"` and the manifests:

- `.github/workflows/drivers/handoff-rust` (the ring driver) uses the map API with default features: unchanged, not refreshed.
- `rust/tests/*`: map API, default features: unchanged.
- `rust/embedded/probe`: new importer, `nostd` only, documented in `components/04_rust_package/description.md`.

Docs refreshed: `components/04_rust_package/description.md` (new interface section), `architecture.md` (Rust row, embedded image line), `module-layout.md` (done at decompose), `interaction-risks.md` (done at decompose). Not refreshed: `system-flows.md` (no flow or seam changed), `data_model.md` (none).
