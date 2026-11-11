# Scenarios — csharp-list-element-row

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.
Description source: the spec written from Archangel AR-967 (2026-11-11); reused, not re-interviewed.

## Fit analysis

| Component / flow | Today | After | Who depends on today | Collision |
|------------------|-------|-------|----------------------|-----------|
| C# `Fields<T>.List` / `.Dict` (`Fields.cs`, `Field.cs`) | An element is one field. A multi-member element row can only be a flags container (1 flag byte per element) or a nested-row group that reads its members from a wrapper property of the element row. A plain row of required members has no spelling. | A second spelling takes the members of the element row itself and writes them back to back with no flag byte. | Existing schemes and tests that use a leaf, flags or wrapper-group element (`GroupElementTests`, `FlagsElementTests`, README C# examples); Archangel (writes `0x0f` flag byte per comment today). | none: the new spelling is additive; the old spellings keep their bytes. One thing to keep unambiguous: a lambda that returns one field and a lambda that returns a list of fields must not make existing calls ambiguous. |
| Element scope numbering (`SchemeOrder.cs`) | Members of a list element are numbered from 0 in a scope of their own; a nested-row group is a scope of its own. | The members of the new row form are numbered the same way (from 0, own scope, may repeat a name of the row around it). | Reference checks (`when`, counts) inside elements. | none |
| Walker pack/unpack of list and dict elements | A nested-row group element packs its members from the inner row and unpacks to a row of the members by name. | The new form reuses that behavior; unpack gives one row per item. | Map rows (dictionary results) and typed rows. | none |
| TypeScript and Dart | Both already write a list of nested rows as the members back to back: `010701000102` for one row of two `u8` (pinned in their duplicate-names tests). | unchanged | — | none (closes the open concern: both express and pin the plain form) |

No problem card: nothing collides. Contracts: C# public surface gains one overload; no component contract file exists for the C# package (`contracts/` holds loop contracts), so none is produced. ADR scan: no ADR on element rows; ADR-006/007 untouched.

## Matrix (cap 8 for 3 points)

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | Scheme author packs a list member holding 0 rows | confirmed | Packs `00 00`; unpack gives an empty list; the field after it still reads. | AC-1 | intake |
| S2 | Author packs 1 row and 3 rows of four required members (text, text, u32, text) | confirmed | Bytes hold the count then each row's members back to back, no flag byte; unpack returns equal rows. | AC-1 | intake |
| S3 | Author packs a dictionary whose values are such rows | confirmed | Keys in the package's existing key order, each value's members back to back with no flag byte; round-trips. | AC-1 | intake |
| S4 | A row misses a required member (null text) or a list item is null | confirmed | Pack fails naming the member (or the element); nothing is written for it, as for a required nested-row member today. | AC-2 (see spec) | intake |
| S5 | Existing flags-element scheme and existing golden bytes | confirmed | Same bytes as before; the flags form still works and writes its flag byte (1 byte per element). | AC-4 | intake |
| S6 | Same entity packed by C#, TypeScript and Dart | confirmed | One hex in all three; each unpacks the others' bytes. | AC-3 | intake |
| S7 | Element row written without a public parameterless constructor / used in a map row | confirmed | Typed row: scheme build refuses with the existing message for row types (unpack creates them). Map row: items are dictionaries by member name, as for group elements today. | AC-5 | intake |
| S8 | Members of the element row use a name the outer row also uses; element holds a nested list or a `when` | confirmed | Own scope as for a nested row: repeated names allowed, references resolve inside the element. | AC-5 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none | — | — |

## Not walked

- Element row holding a flags container with optional members (covered by the nested-row rules, not new).
- Items over the 65,535 limit (unchanged limit, existing tests).
