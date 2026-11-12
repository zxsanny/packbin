# Implementation completeness — loop 111

| Task | Outcome / Scope / AC vs code | Scaffold grep | Verdict |
|------|------------------------------|---------------|---------|
| AZ-4205 | AC-1, AC-1b: overloads in `csharp/Field.cs` and `csharp/Fields.cs`, unpack fills arrays, `List<E>`, `Dictionary<string, E>` (existing `CollectionShape`); AC-2, AC-2b: `SchemeOrder` walks nested-row fields and element-row members with their row type (`RequireRow`); AC-3, AC-3b: tests pin TypeScript's bytes; AC-4: whole C# suite 5,384 of 5,384 on both targets; AC-5: README C# List section and refusal bullet | `placeholder|stub|TODO|fake|not implemented` in the four touched sources: 0 hits | PASS |

## System Pipeline Audit

Single component (C# package): scheme build (`Scheme<T>` constructor → `SchemeOrder.Resolve`) → pack / unpack walkers, unchanged. WIRED: the new overloads build the same `Field` tree (`List`/`Dict` over `ElementRow<TChild>`) the walkers already read; the check runs inside `Resolve`, which every `Scheme` constructor calls.
