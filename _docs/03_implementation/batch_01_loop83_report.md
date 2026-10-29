# Batch 1 report - loop 83

Tasks: AZ-3387 (split handoff.cpp), AZ-3388 (shared ring-wiring module), AZ-3389 (ring rows key/id + second refusal). One parallel wave, three workers in separate tree copies, paths disjoint; the parent merged the owned paths and ran the union.

## Task results

| Task | Status | Result |
|------|--------|--------|
| AZ-3387 | Done | `handoff.cpp` 639 -> 320 lines; new `handoff_ecc.cpp` 133, `handoff_frame.cpp` 198, `handoff_common.hpp` 23; `ring-lib.sh` compile line lists the 3 driver sources + 5 core. HEAD binary vs new: 0 differences over 108 invocations; gcc:16 `-Werror` build OK |
| AZ-3388 | Done | `scripts/ci/workflow_yaml.py` (73 lines) holds the 12 definitions; checkers 249 -> 185 and 200 -> 136 lines; 52 compared cases byte-identical; 3 wiring-test logs identical to HEAD; `workflow_yaml.test.sh` added (16 checks; the wiring tests did not catch a broken `inspect`) |
| AZ-3389 | Done | 14 rows (6 seal, 8 open) all `BadValue`; refuse rows 42 -> 56; refusal rows per language 58 -> 72; no package disagrees; Python key check moved after the size checks -> 7 mismatches (ring exit 1) |

## Merge and parent-owned edits

- `ring-frame.test.sh` line 184: needle `go: R.seal.id7 seal gave` -> `go: R.open.id7 open gave TagMismatch` (forced by the new rows: the ring prints 5 of 13 mismatch lines; the check still catches the padded-id lie).
- `test.yml`: step `CI workflow helpers` (`bash scripts/ci/workflow_yaml.test.sh`) in the scaffold job, after `CI YAML reader`.

## Tests (parent, merged tree, host load < 2)

- `ring-frame.sh`: `64 pairs, mismatched: 0`, 45 rows per pair, `refusals <lang>: 72 rows` x 8.
- `language-pair.sh` exit 0; `ring-ecc.sh` 64 pairs, 45440 rows, 0 mismatched; `ring-ecc.test.sh`, `ring-frame.test.sh`, `ring-frame-drivers.test.sh` (276 checks), `ring-lib.test.sh`, `ring-prepare.test.sh` (6 mutants), `ring-wiring*.test.sh` (output identical to HEAD), `publish-pins.test.sh`, `publish-jobs.test.sh`, `publish-workflow.test.sh`, `report-row.test.sh`, `run-suite.test.sh`, `yaml_get.test.sh`, `workflow_yaml.test.sh`: all exit 0.

CI-parity: PASS - the commands of the CI `scaffold` and `ring` jobs that the diff touches (list above) plus `docker gcc:16 g++ -std=c++17 -O2 -Wall -Wextra -Werror` on the merged driver sources.

## Review

PASS_WITH_WARNINGS (5 Low/Medium cleanups, no bug): the scaffold wiring check does not require the new CI step; the `id-padded` needle depends on the 5-line print cap; `kMax` in the shared header; `frame_hex` wraps `hex_of`; copied include lists. Recorded as loop leftovers, not fixed here.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3389 AC-5 | `ring-frame.test.sh` `id-padded` needle went stale with the new rows | applied the one-line needle change above | clear |
| AZ-3388 AC-5 | the three wiring tests do not catch a broken `inspect` quoting | added `workflow_yaml.test.sh` and a CI step | clear |
| AZ-3388 | `SCAFFOLD_SCRIPTS` of `ring-wiring-check.py` does not list `yaml_get.test.sh` or `workflow_yaml.test.sh` | leftover for a later loop (needs wiring-test mutants) | clear |
| AZ-3387 | spec said six core sources on the compile line; the line has five (values, pack, unpack, crypto, frame) | kept the five | clear |

## Commit

`[AZ-3387] [AZ-3388] [AZ-3389] Split handoff.cpp, share the ring-wiring helpers, pin key/id order in the ring`

Next batch: none.
