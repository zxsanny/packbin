# Security Audit Report, loop 100 (Dart aligned with TypeScript, AZ-4153)

**Date**: 2026-11-11
**Mode**: lite escalated to a diff-scoped full pass (`git diff 0a678be HEAD -- dart fixtures README.md`; commits 4993aee and f955079; 12 library files, about 205 changed library lines)
**Scope**: `dart/lib/src/` unpack of text, dictionary keys and rounds; pack of text and dictionary keys; scheme construction of the empty `nested` mark; the ECC pack refusal. No CI, deploy, dependency, crypto or network file changed.
**Verdict**: PASS

## Lite triggers

| # | Trigger | Hit |
|---|---------|-----|
| T1 | sensitive path | no (`dart/lib`, `dart/test`, docs, `fixtures/hostile/README.md`) |
| T2 | sensitive content | no (grep of changed library lines for CSP, CORS, cookie, token, secret, password, session, process and file words: 0 hits) |
| T3 | size or complexity | yes: task complexity 5 and 12 changed source files, so this pass is the full scope below |
| T4 | dependencies | no (`pubspec.yaml`, lock files, images unchanged) |
| T5 | carried finding touched | no (F70 to F77 live in the release and CI files; none changed) |
| T6 | stale audit | no (the loop 99 audit is from today) |

## Checks on the changed lines

| Check | Result |
|-------|--------|
| Untrusted input into unpack | The changes only narrow what unpack returns: a refused text and a bad key order are now a short-read value with `needed` 0, built from numbers (`needed`, `left`), no longer from a message that quoted the key (the loop 99 `reason` held the hostile key text). No new allocation depends on a count from the wire. |
| Exceptions out of unpack | A hostile-bytes run over 14 scheme shapes (text, dict, dict and list of text, the empty-nested mark under flags, a flag bit and a repeat round, 6 zero-round shapes, count and percentage parity) with random and mutated buffers: 3,446,774 inputs, 48,254,836 unpack calls, 0 throws, slowest call 17.6 ms; every returned row packed again without an exception other than a refusal value. The 10 s seeded run of the suite reported 0 failures in each of the 4 runs. |
| Resource use at pack | An unpaired surrogate adds one pass over a key and a `StringBuffer` only when a lone half is present; the dictionary sort and the new adjacent-key comparison are O(n log n) and O(n); a text above 65,535 UTF-8 bytes is still refused before anything is built. The input is the caller's, not the wire's. |
| Silent data change | A lone surrogate is now written as U+FFFD (TypeScript's behaviour, owner decision). Two keys that collide after the swap are refused rather than written, so no packet is produced that the package itself refuses. |
| Information in errors | Pack refusals for a too long message name the length and the limit only; unpack errors for text and keys carry no key text. |
| Blast radius | `replaceLoneSurrogates` and the empty-nested mark are used only in `dart/lib`; no other package or fixture reads them. |

## Findings

| # | Severity | Status | Finding |
|---|----------|--------|---------|
| F78 | Low | fixed in loop 100 before any release | `nested(name, []).bind(...)` in a typed row built as a presence mark and unpack of `010309` threw a cast error out of `unpackRow` (found by an assessment probe; the empty nested had been refused at build before this loop). `NestedField.bind` of an empty nested is refused when the scheme is built; two tests pin it (`empty_nested_test.dart`). The fuzz run above has no throw. |

No Critical, High or Medium finding. Carried: F70 to F77 (loop 99), unchanged.

## Not covered

- The first publish to pub.dev and the OIDC token behaviour stay unproven until the first tag (loop 99 D20), unchanged by this loop.
- The fuzz run is a scratchpad program and is not committed; the committed seeded run covers the Dart schemes of loop 99, not the empty-nested mark in a round (the assessment names this as a Low harness gap).
