# Ripple log — loop 51

Changed: `rust/src/nostd/**` (AZ-2752, AZ-2753). Importers of `packbin::nostd` outside the module:

- `rust/embedded/probe/src/lib.rs` — the embedded probe; it builds flat schemes only and calls `pack`/`unpack` with `&Route`/`&mut Route` (now `&dyn Row`, coerced): no source change; `rust/embedded/limits.txt` changed (owner limit). Docs: `components/04_rust_package/description.md` (embedded stage figures) refreshed.
- `rust/tests/nostd_*` — tests of the module (updated in the batches).

No other component imports it (the map API, the ring drivers and the publish scripts do not).
