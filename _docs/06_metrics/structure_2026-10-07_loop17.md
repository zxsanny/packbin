# Structure — 2026-10-07 loop 17

| Metric | Value | Versus 2026-10-06 loop 15 |
|--------|-------|---------------------------|
| Components | 6 (the six language packages, peers) | 0 |
| Cross-component imports | 0 | 0 |
| Cycles | 0 | 0 |
| Contracts | the existing library contracts and the session contract | 0 |
| `shared/` | none | 0 |

Loop 17 changed only the C# component. Source files added: `csharp/RowBinding.cs` (214 lines), `FieldBinding.cs` (93), `Bound.cs` (14), `Walker.Elements.cs` (13), `Walker.Numbers.cs` (79); removed: `ObjectValues.cs` (162). Largest C# source file `Walker.Counted.cs` 470 lines (cap 500). Inside the C# component the typed binding now has three owners: `FieldAccess.cs` (compiled member accessors), `FieldBinding.cs` (collection shapes, constructors), `RowBinding.cs` (row to values and back); the walker (`Walker*.cs`) reads and writes values only, and tells a typed row from a dictionary row by the type of the values map (review R5). Tests added (16 files): `TypedParityTests`, `TypedBindingTests`, `NestedRowFlagByteTests`, `SplitBitOrderTests`, `FlagGroupPresenceTests`, `FlagGroupCopyTests`, `CountKindTests`, `CountOverflowTests`, `LoneRoundValueTests`, `GroupElementTests`, `StrictNumberTests`, `U2PresenceTests`, `HostileSessionTests`, `SplitFormReferenceTests`, `FlagScopeContainerTests`, `SessionPrivates`; `csharp/tests/LayoutTests.cs` stays at 517 lines (before the loop, not touched). Architecture compliance baseline: no new violation, none resolved (the architecture document names the six packages as independent walkers, ADR-001; C# did not import from another package).
