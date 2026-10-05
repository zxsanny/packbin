# Ripple log — loop 13

The six packages do not import each other, so a change in one package does not stale another package's modules. Three packages changed in source this loop (`git diff ce85fe0..HEAD`): C#, TypeScript and Rust. Python, C++ and Java have no source change, so their component descriptions are not refreshed. The only consumers outside a package are the drivers under `.github/workflows/drivers/`, which call each package's public API (`csharp/Packbin.cs`, `typescript/src/index.ts`, `rust/src/lib.rs`, `java/.../Packbin.java`, the C++ headers); no public signature changed except the Rust `SchemeItem::times` (the Rust drivers do not use it).

There is no `_docs/02_document/modules/` directory in this repo. The component description is the lowest doc level, so each changed file below maps to its component description.

Direct refresh (the changed files belong to these components):

- `components/01_csharp_package/description.md` — refreshed because `csharp/Packbin.cs` (`SchemeOrder` scope resolution, row-type check, scheme-owned copies), `RoundScopes.cs` (new), `Walker.Rounds.cs` (new), `Scope.cs`, `Walker.cs` (`seen` decides `when`, float compare), `Walker.Counted.cs` (counts read from `seen`), `Walker.Presence.cs` (`RequireValue`), `Field.cs` (`With`, `RowType`) changed. Changed by AZ-2087, AZ-2088, AZ-2175, AZ-2176
- `components/02_typescript_package/description.md` — refreshed because `typescript/src/ref-scope.ts` (new), `member-names.ts` (new), `rounds.ts` (new), `kinds.ts` (range checks, `sameValue`), `fields.ts` (flags flattening, `collectFlagBits`, `nameById` removed), `pack-fields.ts`, `walker.ts`, `index.ts` (constructor runs the new checks) changed. Changed by AZ-2084, AZ-2090, AZ-2091, AZ-2177
- `components/04_rust_package/description.md` — refreshed because `rust/src/field/integrity.rs` (new), `scheme/times.rs` (new), `walk/times.rs` (new), `scheme/mod.rs` (`SchemeItem::times`, shared name counter, `__bound_N`), `field/mod.rs` (`times_name`, `rename_container`), `field/map_scheme.rs`, `field/shape.rs`, `value.rs` (`when_matches`, `same_value`), `walk/pack.rs`, `walk/unpack.rs`, `walk/mod.rs` changed. Changed by AZ-2085, AZ-2086 (AZ-2178 added tests only)

Import-graph ripple (inside the packages, all already in the direct refresh set):

- TypeScript: `index.ts` imports `ref-scope.ts`, `member-names.ts` and `rounds.ts`; `walker.ts` and `pack-fields.ts` import `ref-scope.ts` and `rounds.ts`. All five files belong to the TypeScript component.
- Rust: `field/map_scheme.rs` runs `field/integrity.rs`; `scheme/mod.rs` declares `scheme/times.rs`; `walk/pack.rs` and `walk/unpack.rs` import `walk/times.rs`. All belong to the Rust component. The Rust handoff driver depends on the crate by path (`.github/workflows/drivers/handoff-rust/Cargo.toml`) and does not use `SchemeItem::times`.
- C#: one assembly and one namespace (`Packbin`); the new `RoundScopes.cs` is called from `SchemeOrder.Resolve` in `Packbin.cs`, `Walker.Rounds.cs` is a partial of `Walker`. The C# handoff driver (`drivers/csharp/Handoff.cs`) references `csharp/Packbin.csproj` and calls the public `BinaryPacker.Pack` and `Unpack`; its new round commands use `Pack` only, because no public API reads a round row (AZ-2092).

Cross-cutting refresh (the rule is shared by packages, not owned by one):

- `module-layout.md` — new internal files per component (C#, TypeScript, Rust) and the `language-pair.sh` rings and `drivers/handoff-rust/src/rounds.rs` under workflows. Public API files and Owns lines are unchanged
- `architecture.md` — principle: reference scope, nested rounds refused, aligned rounds; §4 pack refusals (TypeScript range check, C# missing value)
- `system-flows.md` — F1 Pack error table: the "field list refused" row named only Java and Rust for reference scope and nested rounds; added the C# missing-value and the Rust typed `times` rows; TypeScript range wording
- `data_model.md` — Field list constraints: same-scope references and no round inside a round
- `_docs/01_solution/schema.md` — table rows for `when`, `packed`, `times`; new References section; Repeat (aligned rounds, nested rounds); Borrowed count (`times` list length). Reason: reference scope, aligned rounds and the `times` exactness rule moved in loop 13
- `fixtures/hostile/README.md` — the `when_names_outer_field_in_repeat` note: C#, TypeScript, Rust, Java and C++ refuse it; only Python builds it (AZ-2113)
- `_docs/02_tasks/done/AZ-2084`, `AZ-2086`, `AZ-2091` — risk text pointed the release notes at `v0.2.0`; tag `v0.2.1` is out, so the README upgrade block ships with the next release

Checked, not changed:

- `components/03_python_package`, `05_cpp_package`, `06_java_package` — no source change in this loop (the C++ and Java drivers under `.github/workflows/drivers/` changed; they are workflow files, covered by the `module-layout.md` workflows entry)
- `interaction-risks.md` — no seam changed; the packages still meet only at the golden and hostile fixtures and the ring script
- `glossary.md` — its split-form entry still says TypeScript, C#, Java and Rust refuse a bit outside its scope, which is true
- `contracts/library/pack-session.md` — sessions are untouched; a failed session pack leaves the counter alone (pinned by AZ-2175 AC-4, behavior unchanged)
- `tests/*`, `components/*/tests.md` — test specs, not part of this step (test-spec sync is `not_in_plan`)
- `_docs/00_problem/*` — no input parameter, acceptance criterion or restriction changed

Import parse: done with `rg` over `typescript/src`, `rust/src` and `.github/workflows/drivers`; C# was read from the namespace and the `.csproj` files (the only `ProjectReference` edges are from the tests and the drivers to `csharp/Packbin.csproj`; none between packages). No parse failure, so no directory-proximity fallback was used.
