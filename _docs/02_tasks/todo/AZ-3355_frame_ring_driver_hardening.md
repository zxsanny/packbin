---
loop: 78
branch: dev
ticket: AZ-3355
points: 3
---

# Frame ring: strict driver input and writer blame

**Task**: AZ-3355_frame_ring_driver_hardening
**Name**: Frame ring driver hardening
**Description**: The 8 frame drivers refuse malformed lines instead of reading them quietly, and the ring blames a writer that prints a word that is not hex.
**Complexity**: 3 points
**Dependencies**: AZ-3354_frame_ring_refusal_rows (same driver files)
**Component**: CI ring (`.github/workflows`, `scripts/frame`)
**Tracker**: AZ-3355
**Epic**: none

## Problem

L-1: TypeScript (`Buffer.from(token, "hex")`), Swift (`hexBytes(token) ?? []`), C++ (`ecc_bytes`) and Java accept a bad digit or an odd token and run on with other bytes, while Python, C#, Go and Rust stop. L-2: `ring_frame.py open-in` and `verify-in` check only the count of a writer's lines, so a writer that prints `TooLong` for a good row crashes every reader and the message names the readers. L-3: the Go driver discards 12 parse errors (`epoch, _ := strconv.Atoi(...)`) and never reads `scan.Err()`. The Python driver is the only one that raises on `open-skip` / `verify-skip` instead of answering `skip`. (Assessment loop 77, findings L-1 to L-3 and I-1; re-probed on HEAD in the first batch.)

## Outcome

- A malformed line ends a driver with a non-zero exit and a message with the line number, in all 8 languages.
- A writer's bad output is reported on the writer; readers are not reported as failed.

## Scope

### Included
- `scripts/frame/ring_frame.py` first: `open-in` and `verify-in` check that each line of a writer is hex or `-`; a bad writer gets `open-skip` / `verify-skip` lines for the readers and `check` reports `<writer>: <case> seal gave <text>, wanted <hex>`.
- The 8 drivers: a token that is not hex (bad digit, odd length), a missing field, or an unknown word ends the process with a non-zero exit and a stderr message `frame line <n>: ...`.
- Go: check every parse and `scan.Err()` (a line over 1 MiB is an error).
- Python: answer `open-skip` and `verify-skip` with `skip`.
- New `.github/workflows/ring-frame-drivers.test.sh`: runs the real drivers (through `run_lang`) on three malformed lines each and checks the exit code and the message; wired into the `ring` job of `.github/workflows/test.yml` and `scripts/loop-tests.sh`.
- `ring-frame.test.sh`: a case for a writer that prints `TooLong` for its first seal row.

### Excluded
- The refusal rows and `dirs` / `out_len` (AZ-3354); key and msg_id length; the five-line refusal display.

## Acceptance Criteria

**AC-1: A bad writer is blamed, readers are not**
Given a stand-in writer that prints `TooLong` for its first seal row
When the ring runs
Then `check` prints `<writer>: <case> seal gave TooLong`, exits 1, no line says `frame-batch (open) failed`, and the other 7 writers' pairs print `0 mismatched`.

**AC-2: Malformed lines stop every driver**
Given a file with a bad hex digit, one with an odd-length hex token, and one with a missing field
When each of the 8 real drivers runs on it
Then it exits non-zero with a message that holds the line number (24 runs, none exits 0).

**AC-3: Go checks its parses**
Given a Go driver line with a malformed epoch, direction, tag length or kind, and a line over 1 MiB
When the Go driver runs on it
Then it exits non-zero (5 runs), and `grep -c ', _ := strconv' frame.go` gives 0.

**AC-4: Python skip**
Given the lines `open-skip` and `verify-skip`
When each of the 8 drivers answers them
Then each prints `skip` (was 7 of 8).

**AC-5: Wired and green**
Given `ring-frame-drivers.test.sh`, `ring-frame.test.sh` and `ring-frame.sh`
When they run in the CI `ring` job and in `scripts/loop-tests.sh --all`
Then all pass; CI 20 of 20 jobs green on `dev` and `main`.

Inherited project ACs exercised: AZ-3338 AC-1, AC-5.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `ring-frame.test.sh` scenario `writer-prints-word` | exit 1, writer named, no reader failure line |
| AC-4 | `ring-frame-drivers.test.sh` skip lines | `skip` x 8 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-3 | the 8 real drivers | `bash .github/workflows/ring-frame-drivers.test.sh` | 29 runs as listed, all as required | none |
| AC-5 | the real drivers | `ring-frame.sh` | `64 pairs, mismatched: 0` | none |

## Constraints

- Order of work: the `ring_frame.py` change (AC-1) lands before, or with, the first strict driver (fit decision: strict hex makes a bad writer louder).
- An empty token `-` stays valid. Never suppress an error silently (`coderule.mdc`): no `try/catch` that turns a bad parse into 0.
- The driver test script ends on its own: stdin from `/dev/null`, a time limit through the `limit` function as the first word (AGENT_GOTCHAS).
- Run the real drivers on their toolchains before the first push.

## Risks & Mitigation

**Risk 1: Strict parse rejects a row a driver passed before.**
`-` or a trailing field may reach a strict parser.
- *Mitigation*: the existing 64 pairs and AZ-3354 rows run before the push.

**Risk 2: The driver test script is slow (8 toolchains).**
- *Mitigation*: one process per driver per malformed file, in parallel like `phase`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---|---|---|---|
| Strict hex before the writer blame makes failures name the readers | order of work in Constraints | resolved | Medium |
