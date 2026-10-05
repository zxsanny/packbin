# Ripple log — loop 12

The six packages do not import each other, so a change in one package does not stale another package's modules. All six changed this loop (`git diff 7a5a235..HEAD`), so every component description is refreshed.

Direct refresh (the changed files belong to these components):

- `components/01_csharp_package/description.md` — `csharp/FlagGroup.cs`, `Packbin.cs` (`SchemeOrder` placement walk), `Walker.cs`, `Walker.Presence.cs` (new: bit presence, set-group value check), `Field.cs` (empty group on a non-`bool` member refused). Changed by AZ-2079, AZ-2130
- `components/02_typescript_package/description.md` — `typescript/src/fields.ts`, `flag-scope.ts` (`validatePresenceMarks`), `index.ts` (checks moved into the `Scheme` constructor), `kinds.ts`, `walker.ts`. Changed by AZ-2080, AZ-2129
- `components/03_python_package/description.md` — `python/src/packbin/_nodes.py` (`_validate_order` placement, ninth `flags` child, empty group). Changed by AZ-2083, AZ-2132
- `components/04_rust_package/description.md` — `rust/src/field/shape.rs` (new), `field/map_scheme.rs` (new), `field/mod.rs`, `field/order.rs`, `scheme/mod.rs`, `walk/pack.rs`, `walk/unpack.rs`, `walk/element.rs`, `walk/mod.rs` (public `pack` / `unpack` docs), `lib.rs` (`pub use walk::{pack, unpack}`). Changed by AZ-2082, AZ-2133
- `components/05_cpp_package/description.md` — `cpp/include/packbin/fields_grouped.hpp` (member-less empty group marked invalid), `cpp/embedded/lib.sh`, `examples.sh` (toolchain cache at repo-root `.cache/embedded`). Changed by AZ-2147, AZ-2133 (tests and driver only)
- `components/06_java_package/description.md` — `java/src/main/java/packbin/SchemeOrder.java`, `Walker.java`, `Rounds.java` (new), `Field.java`, `VarFields.java`, `Containers.java`. Changed by AZ-2089, AZ-2131

Cross-cutting refresh (the rule is shared by all six packages, not owned by one):

- `glossary.md` — new entries Bool and Empty group; Flags gains the 8-bit limit
- `architecture.md` — principle: the bool rule, the 8-bit limit and the empty-group refusal, checked when the field list is built; C++ core: member-less `group(id)` is `SchemeInvalid`
- `system-flows.md` — F1 Pack: bool set only for `true`; error rows for a refused field list, a set C# flag group missing a value, and a Rust map bool other than 0 / 1
- `data_model.md` — Field list constraints: bool / empty group placement and the 8-bit limit
- `_docs/00_problem/acceptance_criteria.md` — AC-4 reworded in batch 2 ("when its field is walked", `bitwhen`)

Checked, not changed:

- `module-layout.md` — public API files are unchanged; the new files (`Walker.Presence.cs`, `shape.rs`, `map_scheme.rs`, `Rounds.java`, new tests) are internal and covered by the "everything except the public API file" rule. Rust's `lib.rs` exports `pack` / `unpack` now, but the public API file is the same
- `contracts/library/pack-session.md` — sessions are untouched this loop
- `tests/*`, `components/*/tests.md` — test specs, not part of this step (test-spec sync is `not_in_plan`)

Import parse: the six packages share no source, so no cross-package edge exists. Inside each package only its entry file and walker import the changed modules, all already in the direct refresh set.
