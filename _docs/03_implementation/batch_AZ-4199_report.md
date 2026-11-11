# Batch report: AZ-4199 (C# element row without flag byte)

Run outside the loop plan on the owner's direct `/implement az-4199` (2026-11-11); spec was written from Archangel AR-967.

| Task | Status | Tests |
|------|--------|-------|
| AZ-4199 | Done | C# `ElementRowTests` 13 tests; whole C# suite 5363 of 5363 on net10.0 and netstandard2.0; TypeScript 4 and Dart 4 fixture tests pass with the same hex |

Review: PASS_WITH_WARNINGS (3 Low: array members not accepted, declared row type of members not checked inside elements, no test for rounds or `when` inside an element row). None applied; all match existing flags-element behavior.

## Discovered during implementation

| Spec ref | Observation | Proposed handling | Clear? |
|----------|-------------|-------------------|--------|
| Scope | `dotnet test csharp` without a console logger hung twice (test host idle) while the same suite with `--logger "console;verbosity=normal"` finished in 11 s | Run the C# suite with the logger; look into the hang separately | unclear |
| Scope | The old workaround was an anchored `Field.Group(0, ...)` element with a dummy accessor; it already wrote the same bytes | None; the new form replaces the need for the dummy member | clear |
