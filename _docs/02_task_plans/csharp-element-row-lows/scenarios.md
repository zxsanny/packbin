# Scenarios — C# element row Lows (loop 111)

Fit and scenario walk (`new-task` Step 4.7), 3 points: cap 8 rows. Probe on HEAD `05bdc52` (loop 111).

## Part A — Fit

| component / flow | today | after | who depends on today | collision |
|------------------|-------|-------|----------------------|-----------|
| C# row form of a list or dict element (`Fields<T>.List/Dict`, `Field.List/Dict` with members) | only a `List<E>` or `Dictionary<string, E>` member | also `E[]`, `IList<E>`, `IDictionary<string, E>` | AZ-4199 callers (`List<E>` member): Archangel AR-967 | none for users; a new overload must not change which overload an existing call picks (build of every test and README example) |
| C# scheme build, members inside an element row or a nested row | not checked: builds, then `Pack` and `Unpack` throw `InvalidCastException` | refused when the scheme is built, naming the member and both types | nobody: such a scheme cannot pack a row (a null nested row or list is refused as "has no value", a non-null one throws) nor unpack one (probe 5: `InvalidCastException` out of `Unpack`) | none |
| `when` / `times` inside an element row | works, no test | pinned by tests to TypeScript's bytes | — | none |

No problem cards: no collision needs an owner decision.

## Part B — Matrix

| # | actor | trigger | state | proposed behavior | status | AC |
|---|-------|---------|-------|-------------------|--------|----|
| 1 | C# scheme author | row form on a `Comment[]` member, 0 / 1 / 3 rows | first use | same hex as the `List<Comment>` form; unpack gives an array of 0 / 1 / 3 equal rows (an empty array for 0, never null) | confirmed | AC-1 |
| 2 | C# scheme author | row form on an `IList<Comment>` member | first use | same hex; unpack gives a `List<Comment>` behind the `IList<Comment>` | confirmed | AC-1 |
| 3 | C# scheme author | row form on an `IDictionary<string, Comment>` member | first use | same hex as the `Dictionary<string, Comment>` form (keys in the existing order); unpack gives a `Dictionary<string, Comment>` | confirmed | AC-1b |
| 4 | C# scheme author | a null array / `IList<E>` / `IDictionary` member | invalid input | the same refusal the `List<E>` form gives today (`'Items' has no value; a field that may be absent belongs in Flags`) | confirmed | AC-1 |
| 5 | C# scheme author | static form with members declared for an unrelated type, in an element row (list and dict) or a nested row | invalid input | `ArgumentException` from the `Scheme` constructor naming the member, its declared type and the row type; no `InvalidCastException` from `Pack` or `Unpack` | confirmed | AC-2, AC-2b |
| 6 | C# scheme author | members declared for a base type of the element or nested row type | existing data | builds and round-trips (same rule as top level) | confirmed | AC-2b |
| 7 | C# scheme author | `when` or `times` inside an element row | existing-feature overlap | TypeScript's bytes `010200010700` / `01020002050600`; unpack equal | confirmed | AC-3, AC-3b |
| 8 | C# scheme author | `repeat` inside an element row | existing-feature overlap | unchanged in this loop: packs `010200010502` and its unpack refuses it, as in TypeScript; the owner's own cross-package task (decision 4) | out of scope | — |

Concurrent use, permission and undo do not apply: a scheme is immutable after build and has no access control.

## Part D — Record

Rows 1 to 7 → ACs of the task spec; row 8 → `### Excluded` and a `todo/` task for the repeat class.
