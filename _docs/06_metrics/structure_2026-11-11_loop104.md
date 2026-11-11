# Structure snapshot — 2026-11-11, loop 104

Source: `_docs/02_document/module-layout.md`, `_docs/02_document/components/`, `_docs/02_document/contracts/library/`, the committed loop 99 to 103 diffs. Previous snapshot: `structure_2026-10-20_loop50.md` (loops 51 to 98 wrote none).

| Metric | Loop 50 | Loop 104 |
|--------|--------:|---------:|
| Components | 8 | 9 (`dart/`, loop 99) |
| Cross-component import edges | 0 (packages are peers) | 0 (a grep of the library sources of TypeScript, C#, Java and Dart for a path into a sibling package found none; the rings and fixtures are shared data, not imports) |
| Cycles | 0 | 0 |
| New modules since loop 50 | | `dart/` (40 library files, 7,040 lines at loop 99), frame mode in all nine, `cpp/embedded` rows; none in loops 101 to 103 (4 source files edited, none added) |
| Architecture findings (new / resolved) | 0 / 0 | 0 / 0 |
| Contracts | 3 | 3 (`compact-text.md`, `message-ecc.md`, `pack-session.md`); loops 99 to 103 added consumer change-log rows only: no version, byte or rule changed |
| Contract coverage of the public API | not computed | not computed (the contracts name wire rules, not API symbols) |

The wire format and the three contracts did not change in loops 101 to 103; the behaviour changes of the three packages are refusals at pack and the Java replacement character.
