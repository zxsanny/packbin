---
loop: 101
branch: dev
---

# Loop 101 — TypeScript refuses dictionary keys that collide after U+FFFD

Loop 101 (on `dev`; no worktree). Intake: the owner's "Yes, loop 101" (2026-11-11) to the question "Start loop 101 with the TypeScript colliding-key fix?", the open TypeScript item of `_docs/loops/loop100/record100.md` (leftovers, first line).

## What and why

TypeScript `pack` writes a packet its own `unpack` refuses. A text key with an unpaired UTF-16 surrogate is written as U+FFFD (what `TextEncoder` does), so two keys that differ only in lone halves, or a lone half and a real U+FFFD, are one key on the wire. TypeScript writes both pairs, and its own unpack then refuses the dictionary as a repeated key (a short packet with `needed` 0). Dart refuses such a dictionary at pack since loop 100 (owner decision 2026-11-11). The owner asked for TypeScript to do the same, so the reference package never writes a packet it cannot read. Observed on HEAD e02ddc2 by running TypeScript (`results_report.md`).

After this loop: `pack` of a dictionary whose keys collide after the swap throws a `RangeError` that names the dictionary and writes nothing; every other dictionary packs the same bytes as before.

Not in this loop: the other six packages (their handling of a lone surrogate in a key differs by language and was not measured here: listed as a leftover), and any release or version change of the npm package.

## Code sections / UI locations for this loop

Owner (2026-11-11): the TypeScript package, `pack` of a `dict` field (the colliding-key fix named in the question and in the loop 100 record). Found by `git grep`: the one place that sorts and writes dictionary keys is `typescript/src/pack-fields.ts` (the `dict` case of `packFields`, lines 264 to 285 at e02ddc2); a dictionary as a list or dict element goes through the same case (`Object.keys` appears only there). Tests go beside `typescript/tests/dict-key-order.test.ts`. Docs that say TypeScript writes the unreadable packet: `README.md` (the loop 100 Dart note at line 2415 and the Dart Dictionaries paragraph at 1000), `_docs/02_task_plans/dart-package/parity_differences.md` row 43, `_docs/02_document/tests/traceability-matrix-loop-100.md` row AL-3, and the TypeScript component doc.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| a dictionary that packed before (two colliding keys) now throws: a behaviour change of a published npm package (0.4.0) | owner asked for it (2026-11-11); the old packet was refused by every unpack, so no reader could use it | accepted-risk | Low |
| the other six packages may write the same unreadable packet for a lone surrogate in a key (C# and Java encoders replace a lone half; Go refuses a string that is not valid UTF-8) | not measured; recorded as a leftover for a later loop | open | Low |
