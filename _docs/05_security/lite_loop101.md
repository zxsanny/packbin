# Security lite — loop 101 (AZ-4168, TypeScript colliding dictionary keys)

**Date**: 2026-11-11
**Diff**: `git diff e02ddc2..HEAD -- . ':!_docs'` (1 source file, 10 added lines; 1 test file; docs)
**Verdict**: CLEAN

## Triggers

| # | Trigger | Hit |
|---|---------|-----|
| T1 | sensitive path | no (`typescript/src/pack-fields.ts`, `typescript/tests/`, `README.md`) |
| T2 | sensitive content | no (grep of the changed source lines for token, secret, password, jwt, session, innerHTML, eval, exec, http, fs: 0 hits) |
| T3 | size or complexity | no (10 source lines, 1 source file, 2 points) |
| T4 | dependencies | no (`package.json`, lock files unchanged) |
| T5 | carried finding touched | no (F70 to F78 name release, CI and Dart files; none changed) |
| T6 | stale audit | no (full report of loop 99 and the loop 100 pass are from today) |
| T7 | lite concern | no |

## Checks on the changed lines

| Check | Result |
|-------|--------|
| Input limits | The new loop compares each pair of neighbouring keys once after the sort: O(n) comparisons and two `TextEncoder.encode` calls per pair, on a dictionary the caller already holds and that is capped at 65,535 keys; no new allocation grows with a count from the wire. Unpack is unchanged. |
| Behaviour on refusal | A refusal throws before anything is written to the output, so no partial packet leaves `pack`. The message names the dictionary and quotes no key text. |
| Silent data change | Removed: the old code wrote one key twice and the reader refused the packet; the new code refuses at the writer. No dictionary without a collision changes (4 packets equal to the old bytes; 5,000 seeded dictionaries agree with Dart). |
| Outbound, auth, secrets, edge config, blast radius | not touched (`Object.keys` appears once in `typescript/src`, so no other writer changes) |

No finding. Step 14 is done.
