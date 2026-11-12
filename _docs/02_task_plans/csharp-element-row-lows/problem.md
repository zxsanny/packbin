---
loop: 111
branch: dev
---
# Loop 111 — the three review Lows of the C# element row (AZ-4199)

Loop: 111 (on `dev`, no worktree). Owner choice 2026-11-12 for the empty hopper: "AZ-4199 Lows in C#". Source: `_docs/03_implementation/batch_AZ-4199_report.md` (review PASS_WITH_WARNINGS, 3 Low, none applied) and `_docs/loops/loop109/record109.md` leftovers.

## What

AZ-4199 (loop 109) let a C# `List` or `Dict` element be a row of required members with no flag byte: `f.List(x => x.Items, e => [e.U8(0, m => m.Id), e.U8(1, m => m.N)])`. Its review left three Lows. A probe on HEAD `05bdc52` (scratch console project against `csharp/Packbin.csproj`, and the same shapes in TypeScript) measured what each one is today:

1. **Collection types.** The row form takes only a `List<E>` member (list) or a `Dictionary<string, E>` member (dict). The other collection members C# accepts for a list or dict field (`E[]`, `IList<E>`; `IDictionary<string, E>`) cannot use it: there is no overload, so such a member needs a wrapper or a flags element (1 byte more per element).
2. **Row type of the members.** A member declared for another row type inside an element row builds and then `Pack` throws a raw `InvalidCastException`:
   - element row: `Field.List<Marked, Mark>(x => x.Items, Field.U8<Other>(0, o => o.Id), Field.U8<Other>(1, o => o.Z))` → built, then `InvalidCastException: Unable to cast object of type 'Mark' to type 'Other'.`
   - nested row (a `Group` without anchor), same hole: `Field.Group<Nest, Mark?>(x => x.M, Field.U8<Other>(0, o => o.Z))` → built, then the same `InvalidCastException`.
   - for comparison, a top-level member is refused when the scheme is built: `'Z' is declared for row type Other, but this scheme is for Mark`; a flags element is refused at build too (`element type Mark is too narrow or of another kind`).
   Cause: `SchemeOrder.WalkFromZero` walks the children of a nested row, list element and dict element with `row: null`, so `RequireRow` checks nothing there.
3. **Rounds and `when` inside an element row** had no test. Probe: they work and C# writes TypeScript's bytes:
   - `when`: element row `(u8 mode, when(mode == 1, u8 speed))`, items `{1, 7}`, `{0}` → C# `010200010700`, TypeScript `010200010700`; both unpack to the same rows.
   - `times`: element row `(u8 c, times(1, c, u8 v))`, items `{2, [5, 6]}`, `{0, []}` → C# `01020002050600`, TypeScript `01020002050600`; both round-trip.
   - `repeat`: element row `(u8 mode, repeat(1, u8 v))`, items `{1, [5]}`, `{2, []}` → C# and TypeScript both pack `010200010502` and both refuse it on unpack (`ShortPacket` / `field mode, needed 1, left 0`): a repeat reads to the end of the buffer. A top-level `repeat(0, u8 v), u8 x` does the same in TypeScript (`01050609`, then `field x, needed 1, left 0`). This is a cross-package class, not a C# Low.

## Who

C# users of Packbin who bind typed rows (Archangel's marker frame is the first, AR-967), and the package owner.

## In scope (owner decision 2026-11-12, "accept all recommended")

- (1) The row form also for an `E[]` and an `IList<E>` list member and an `IDictionary<string, E>` dict member, in `Fields<T>` and the static `Field`, with the same bytes as the `List<E>` / `Dictionary<string, E>` form.
- (2) A member declared for a row type that is not the element row's (or the nested row's) type, nor a base type of it, is refused when the scheme is built, with the message top-level members already get, instead of an `InvalidCastException` at `Pack`. Element rows **and** nested rows.
- (3) Tests for `when` and `times` inside an element row, pinned to the TypeScript bytes above.

## Out of scope

- (4) The repeat class (a repeat inside a list or dict element, or any field after a repeat, packs bytes its own unpack refuses, in C# and TypeScript at least): its own cross-package task in `_docs/02_tasks/todo/` for a later loop (probe all nine packages, one rule for the owner), not fixed here.
- Optional members in an element row (the flags element stays the form for that; AZ-4199 Excluded).
- A non-generic `IList` / `IDictionary` member for the row form (no element type to bind the row to).
- Other packages' element rows and fixtures.
- The `dotnet test csharp` hang without a console logger (separate leftover).

## Code sections / UI locations for this loop

Owner's words (option picked 2026-11-12): `csharp/Field.cs`, `csharp/Fields.cs`, `csharp/FieldAccess.cs`; the scope question named `csharp/SchemeOrder.cs` (the row check), `csharp/tests/ElementRowTests.cs` and the README C# List section, and the owner accepted it. Exact places: `Field.List<T, TChild>` / `Field.Dict<T, TChild>` / `ElementRow<TChild>` (`csharp/Field.cs` about lines 287 to 304), the `List` / `Dict` member-row overloads of `Fields<T>` (`csharp/Fields.cs` about lines 69 to 74), `SchemeOrder.Walk` / `WalkFromZero` / `RequireRow` (`csharp/SchemeOrder.cs` lines 26 to 112), C# tests under `csharp/tests/`, `README.md` the paragraph after "A C# `List` or `Dict` element can also be a row of several required members" (about line 1895). No UI.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| New overloads for `E[]` and `IList<E>` beside `List<E>` may make an existing call ambiguous (CS0121) or pick another overload | build every C# test and README example; the whole C# suite on both target frameworks | open | Medium |
| The build-time check in nested rows refuses a scheme that builds today (members of an unrelated type); such a scheme throws at every pack of a non-null nested row, so only a scheme that never packs one would break | owner accepted nested rows in scope (2026-11-12) | accepted-risk | Low |
| The repeat class stays unfixed in this loop | owner decision (4): own task for a later loop | accepted-risk | Medium |
