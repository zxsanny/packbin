---
loop: 78
branch: dev
ticket: AZ-3354
points: 5
---

# Frame ring: refusal rows by name

**Task**: AZ-3354_frame_ring_refusal_rows
**Name**: Frame ring refusal rows by name
**Description**: The frame ring also sends the refusals that name an error (`TooLong`, `BadValue`, `BufferFull`, a direction that is 0, 4 or not loaded, a bad MAC label or `n`), so a driver or package that answers another name, or aborts, turns the ring red.
**Complexity**: 5 points
**Dependencies**: AZ-3338_frame_ring, AZ-3341_frame_ring_tamper_wide (done)
**Component**: CI ring (`.github/workflows`, `scripts/frame`, `fixtures/frame`)
**Tracker**: AZ-3354
**Epic**: none (as AZ-3338, AZ-3341)

## Problem

The ring refuses only tampered `open` and `verify` rows (16 per language). The refusals by name were deferred on 2026-10-27 (G2, G3): the row syntax has no `dirs` and `out_len`, and every driver aborts or throws on a direction outside 1 to 3 (Java and C# throw, Go, Rust and Swift abort, Python raises for 0, C++ maps it to Up) and uses a fixed 300-byte buffer, so `BufferFull` cannot be reached. `framefmt.py` already takes `dirs` and `out_len`. `vectors.txt` holds the 22 cases (`refuse.seal.*` 11, `refuse.open.*` 6, `mac.label0/33`, `mac.nbad0/2/5`) and each package reads them; the ring adds the driver line and the proof that no driver aborts.

## Outcome

- The ring holds the 22 cases as explicit rows with the reference name checked on load; refusal rows per language 38 (was 16).
- Every driver prints the reference name for them and goes on to the next line.

## Scope

### Included
- `fixtures/frame/ring-cases.txt`: row kinds `refuse-seal` and `refuse-open` (the seal and open fields plus `dirs` and `out_len` and the expected name) and `refuse-mac` (the mac fields plus the expected name); the 22 cases as explicit hex; the header comment and `fixtures/frame/README.md` row-syntax note.
- `scripts/frame/ring_frame.py`: read the three kinds, derive each expected name with `framefmt.py` (`dirs`, `out_len`), send them to every reader once after the existing refusal lines, compare, and count them in the `refusals <lang>: N rows` line.
- The seal and open driver lines get optional trailing `dirs` (digits, default `123`) and `out_len` (default 300) fields; a mac refusal reuses the `mac` line and reads `BadValue` from the driver.
- The 8 drivers: a direction outside 1 to 3 or not in `dirs` gives `BadValue` and the next line is answered; the output buffer has `out_len` bytes (a buffer of 0 is legal).
- `ring-frame.test.sh` stand-in `fake.py` learns the two fields; two new cases: a driver that opens with a direction not loaded, and one that aborts on `dir=0` (exit 1, names the row).

### Excluded
- Key or msg_id length refusals (U1), multi-part MAC messages (G8m), the five-line refusal display.
- Strict hex, Go parse checks, writer blame, the Python `skip` answer: AZ-3355.
- Any change to a package source or to `vectors.txt`.

## Acceptance Criteria

**AC-1: The 22 cases are ring rows**
Given `vectors.txt` cases `refuse.seal.*` (11), `refuse.open.*` (6), `mac.label0`, `mac.label33`, `mac.nbad0`, `mac.nbad2`, `mac.nbad5`
When `ring-cases.txt` is loaded
Then it holds each as a row, the total refusal rows per language are 38, every name of `TooLong`, `BadValue`, `BufferFull` and `ShortPacket` is the expected value of at least 3 rows, and direction 0, 4 and not-loaded each have a seal row and an open row.

**AC-2: The reference confirms every row**
Given a refusal row edited to expect `TooLong` where `framefmt.py` says `BadValue`
When the ring loads it
Then it exits 1 naming the row and reads no driver output.

**AC-3: Bad directions do not abort**
Given a seal or open line with direction 0, 4, or a direction that is not in `dirs`
When each of the 8 drivers reads it
Then it prints `BadValue`, exits 0 at the end of the file and answers the line after it. C#, C++, Go, Python and TypeScript hand the number to the package; Java passes `null` and Swift calls `FrameDirection(number:)`, and the package answers `BadValue`; Rust has no enum value for 0 or 4, so its driver prints `BadValue` where its `direction()` has none (the same step as `rust/tests/frame_vectors_tests.rs`, owner to confirm in the batch report).

**AC-4: The buffer comes from the row**
Given a refuse-seal row with `out_len` one byte below the body size and a refuse-open row likewise, and two `seal` rows (`fit.tag4`, `fit.clear`) with `out_len` equal to the body, which the ring also opens into a buffer of exactly the plaintext
When each driver runs them
Then the first prints `BufferFull` and the second prints the body (or plaintext), for two rows per language.

**AC-5: Old lines are unchanged**
Given seal and open lines without `dirs` and `out_len`
When each driver runs them
Then the answers are those of loop 77 and `ring-frame.sh` prints `64 pairs, mismatched: 0`.

**AC-6: The ring passes for real and the self-test catches a bad driver**
Given the 8 real drivers built as the CI `ring` job builds them
When `ring-frame.sh` runs on the Mac and in CI
Then it exits 0 and prints `refusals <lang>: 38 rows, 0 mismatched` for each of the 8 languages; and `ring-frame.test.sh` with the two bad stand-ins ends in exit 1 naming the row (`<lang>: <row> open gave ..., wanted BadValue`).

**AC-7: Size and time**
Given the loop 77 figure of 51 s for `ring-frame.sh` (re-read in the first batch at the same load)
When the ring runs after the change
Then the time grows by at most 20 %, and no touched source file ends above 500 lines unless it was above before.

Inherited project ACs exercised: AZ-3338 AC-1, AC-4, AC-5, AC-8; AZ-3341 AC-8, AC-12.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | the loader on the new kinds, a corrupted row, a file without refusal rows | exit 1 naming the row; the three kinds counted |
| AC-3, AC-6 | `ring-frame.test.sh` scenarios `unloaded-direction-accepted` and `dir0-aborts`; the honest run | exit 1 naming the row; eight clean `refusals` lines |
| AC-5 | the existing self-test scenarios | still pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3, AC-4, AC-5, AC-6 | the 8 real drivers | `bash .github/workflows/ring-frame.sh` | `64 pairs, mismatched: 0`, `refusals <lang>: 38 rows, 0 mismatched` x 8, exit 0 | AC-7 time |

## Constraints

- Rows keep the style of the file: explicit hex, validated by the reference on load; no generator, no second source of truth.
- A driver reports the package's own answer; it never decides a refusal itself (`meta-rule.mdc`, Real Results).
- Defaults keep old lines valid (fit decision, `feature-description.md`).
- `ring-frame: 64 pairs, mismatched: 0` keeps its shape.
- Run the real ring and every `test.yml` ring step before the first push; read CI on `dev` before `main` (LESSONS, loop 77).

## Risks & Mitigation

**Risk 1: A package refuses with another name than the reference for one of the 22 cases.**
vectors.txt passes in each package, so the names agree; the driver mapping may not (loop 77: TypeScript `ShortPacket`).
- *Mitigation*: the first real run names the row; fix the driver, not the row.

**Risk 2: Eight drivers change at once and CI goes red (loop 77: six defects).**
- *Mitigation*: build and run every driver on its toolchain (Go in `golang:1.27`, C++ in `gcc:16`) before the first push.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---|---|---|---|
| Cases also checked per package by vectors.txt | owner 2026-10-28, accepted | accepted-risk | Low |
| Eight drivers change in one batch | real run before push | open | Medium |
