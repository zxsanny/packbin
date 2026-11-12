# Operator to-do

What waits for the operator. The agent writes the rows, re-checks the needs itself and closes them. No secret values in this file.

## Needs

| id | need | why / blocks | how to provide | verify (the agent runs it) | since | status |
|----|------|--------------|----------------|----------------------------|-------|--------|
| N1 | The first pub.dev version of `packbin`, published by hand, then automated publishing switched on | Until then every tag run skips Dart with a warning. Blocks the queue item `dart-readme-install-lines-after-first-publish` and the epic AZ-4133 | `cd dart && dart pub publish` from your pub.dev account. Then on pub.dev: package `packbin`, Admin tab, Automated publishing, enable for the GitHub repository `zxsanny/packbin` with tag pattern `v{{version}}`; do not require a GitHub environment | `curl -s -o /dev/null -w '%{http_code}' https://pub.dev/api/packages/packbin` prints 200 (2026-11-12: 404) | 2026-11-11 (loop 99) | open |
| N2 | The `vcpkg` tool on this Mac | The vcpkg `supports` check and the consumer check of `publish-vcpkg.test.sh` print NOT RUN in every total run since loop 76; NOT RUN is not a pass. Blocks nothing else | `brew install vcpkg`, or say that the agent may install it | `command -v vcpkg` prints a path | 2026-10-27 (loop 76) | open |
| N4 | A one-sentence fix in the autodev skill, outside this repository | `~/.claude/skills/autodev/protocols/worktree-isolation.md` §Loop close, step 2, says the `dev` push "is the `dev` CI trigger". In this repository a push that changes only `_docs/**` starts no run. Blocks nothing | Edit the sentence in the skill source (for example: "This push starts CI when it changes a path the workflow watches"), then re-sync the rules | `grep -n 'CI trigger' ~/.claude/skills/autodev/protocols/worktree-isolation.md` shows the new sentence | 2026-11-11 (loop 105) | open |

## Decisions

| id | question | options | default | blocks | since | status |
|----|----------|---------|---------|--------|-------|--------|
| D1 | Should Java and C++ also refuse, when the scheme is built, a `repeat` inside a `repeat` or `times` round (contract case R9)? Today both build it; Java then refuses some rows at pack and the README warns that the rest reads back differently. | A: refuse at build, as the other seven packages do / B: keep building it in Java and C++ | A, because the owner's rule of 2026-11-12 is "a repeat is the last thing a packet reads" and the next round follows an inner repeat; reversible until the next release tag | nothing (AZ-4214 AC-5 and AZ-4219 AC-5 are built with A) | 2026-11-12 | applied 2026-11-12 |
| D2 | U24: a C++ unbound `bits` / `packed` / `sized` member behind a clear `when`. Option B (README text only) was chosen on 2026-10-13 and shipped as AZ-2479. Is anything still open, for example option A (the core refuses it)? | A: the core refuses it / B: keep the README text only | B, your choice of 2026-10-13; nothing more is planned | nothing | 2026-10-13 | applied 2026-11-12 |
| D3 | Should the vcpkg port drop `supports: linux \| osx`? | A: keep the line / B: drop it after a Windows build and test of the C++ package | A: no Windows build exists, and the line is true today | nothing | 2026-10-27 (loop 76) | applied 2026-11-12 |
| D4 | The Dart API choices of loop 99 that were kept as built: a lone surrogate in text is refused; `short_packet` as a seventh frame refusal; the names `flagBool`, `groupOf`, `utf8Field`, `nested`, `rowScheme`, `bind`; `eq(u64, -1)` builds; zero rounds are empty lists; `tooLong` for an oversized message; `bad_value` for repeated dictionary keys and text refusals; `bits` / `packed` as `Uint8List`; the frame direction as an `int` wrapper; `PACKBIN_DART_STRICT` default 0. Change any before the first pub.dev version? | A: keep all as built / B: name the ones to change | A: they match TypeScript where it has the same choice (loop 100), and a rename after the first publish is a new version, not a break of anything published today | nothing; it is cheapest to change before N1 | 2026-11-11 (loop 99) | applied 2026-11-12 |
| D5 | Build a public-key pairing step for frame mode (a candidate since loop 74)? | A: yes, and say which key agreement / B: not now | none (scope) | nothing | 2026-10-27 (loop 74) | open |
| D6 | Jira: the tickets whose change is in a published release stay In Testing (AZ-4134 to AZ-4149, AZ-4153, AZ-4168, AZ-4169, AZ-4191, AZ-4196, AZ-4198, AZ-4199). Move them to Done? | A: the agent moves a ticket to Done when its change is in a published tag / B: they stay In Testing until you move them | none (your tracker workflow) | nothing | 2026-11-11 (loop 105) | open |
| D7 | The Java error text for a `repeat` inside a round. The contract of loop 112 reused the sentence of the other seven packages, "a round cannot hold another repeat or times", which is false in Java (a round can hold a `times`). | A: `repeat <anchor> is inside a repeat or times round; a repeat reads to the end of the packet, so another round cannot follow it; use times` / B: the old sentence | A: an error text must be true; it has the shape of the other two texts of the rule (contract 1.0.1) | nothing | 2026-11-12 | applied 2026-11-12 |

Status values: `open`, `done <date>` (needs), `applied <date>` (default applied, may be overturned), `decided <date>: <answer>`.

## Closed

| id | what | closed | how |
|----|------|--------|-----|
| N3 | Archangel's schemes checked against the rule of epic AZ-4209 (a repeat must be last) | done 2026-11-12 | The agent found the repository itself (`/Users/zxsanny/dev/bellator/archangel`, branch `dev`; read only). `git grep -n -E 'Field\.Repeat'` gives nine schemes, all in `src/backend/Archangel.MapService/LivePackets.cs` (Track, MarkerPath, TripCrew, RouteRoad, PrivateRoute, TripCargo, DambaEnter, Proximity, RouteDanger): in each the repeat is the last field, none sits inside a list or dict element or a round. No `repeat(` in its TypeScript, Dart or Kotlin files. `meshbell` (Rust, frame mode) builds no repeat. Nothing stops building after the upgrade. |
