---
loop: 96
branch: dev
---

# Frame ring: MAC rows over a message in several parts

**Task**: AZ-3495_ring_multipart_mac_rows
**Name**: Frame ring: MAC rows over a message in several parts
**Description**: Let the cross-language frame ring send the MAC-only message in pieces, so the eight languages are compared on the in-parts path.
**Complexity**: 5 points
**Dependencies**: None (AZ-3338, AZ-3341, AZ-3354, AZ-3378 shipped)
**Component**: frame ring harness (`scripts/frame`, `fixtures/frame`, the eight handoff drivers, the ring test scripts)
**Tracker**: AZ-3495
**Epic**: none

## Problem

All eight packages take the MAC-only message in pieces and the README offers it, but the ring (`ring-frame.sh`) hands every package a message of one piece. A package that tags only the first piece, stops at an empty piece or restarts the hash per piece passes the ring. G8m of loop 77 left it out because the driver line carried one message; the owner opted in on 2026-10-31.

## Outcome

- The ring compares the eight languages with the reference on 11 new MAC rows, 2 new tampered verify rows and 2 new refusal rows that carry a message in pieces.
- A driver that mishandles pieces turns the ring red and the rows are named.
- Rows and lines of one piece keep their meaning.

## Scope

### Included
- A message field of pieces joined by `|` (`-` for an empty piece) in the `mac`, `verify` and `refuse-mac` rows and in the driver lines; the reference, the row loader and the line writers follow.
- The eight drivers pass every piece to the package as its own piece, and refuse a piece that is not hex or `-` as a malformed line.
- The new rows, the format text in `fixtures/frame/README.md`, and the cases in `ring-frame.test.sh` and `ring-frame-drivers.test.sh`.
- Keep every touched file under 500 lines (`ring_frame.py` is 462 now: split by responsibility if the change would pass the cap).

### Excluded
- Any change to a package, the wire format or a version; the packages' own tests and `vectors.txt`.
- Zero pieces (an empty list); `seal`, `open` and `refuse-seal` / `refuse-open` rows; `ring-ecc`.

## Acceptance Criteria

Full wording, row names and figures are in `_docs/02_task_plans/ring-multipart-mac-rows/acceptance_criteria.md`; the list below is the task's contract. Project ACs exercised: the frame-ring ACs of AZ-3338 and AZ-3341 (a wrong output of one language fails the ring).

**AC-1: Good rows in pieces**
Given `ring-cases.txt` with 11 new `mac` rows (two to five pieces; empty piece first, in the middle, last and all; cuts at 56|64 and 64|1; five 1-byte pieces; tag lengths 8, 16, 32 incl. a 255-byte message in four pieces)
When the ring loads it
Then the reference confirms every row and the tag of `P.two` equals that of the single-piece row `E4`, and that of `P.all0` equals `msg0`

**AC-2: Tampered and refused rows in pieces**
Given 2 new `verify` rows (flipped tag bit; pieces in the wrong order) and 2 new `refuse-mac` rows (tag length 5; empty label), all in pieces
When the ring runs
Then every language answers `invalid` for the first two and `BadValue` for the others

**AC-3: The real ring agrees**
Given the eight drivers built and started as `ring-frame.sh` does
When the ring runs
Then it prints 30 mac rows and 11 refusal rows, 30 verify rows per writer and 7 refusal rows, 56 rows and 0 mismatched for each of the 64 pairs, 76 refusal rows and 0 mismatched for each language, `ring-frame: 64 pairs, mismatched: 0`, and exits 0 (HEAD: 19 + 9 + 5 rows, 45 rows per pair, 72 refusal rows per language)

**AC-4: Pieces reach the package, bad pieces are refused**
Given a `mac` or `verify` line
When a driver reads it
Then it hands each piece to the package as its own piece, in order, empty ones included; and `ab|zz`, `ab||cd`, `|ab`, `ab|` are malformed lines in all eight drivers (non-zero exit naming `frame line N`, no result)

**AC-5: The rows can fail**
Given a stand-in driver that hands the reference only the first piece, or stops at the first empty piece
When `ring-frame.test.sh` runs it
Then it exits 1 naming `P.two` and `P.mid0` (as writer and as reader); and a one-line mutation of the Go driver (only `parts[0]`) turns the real ring red naming the rows, then is removed. A driver that joins pieces or drops an empty one gives the same tag and cannot be told by any row

**AC-6: Existing rows unchanged**
Given the 19 + 9 + 5 existing rows and the old self-test cases
When the change is applied
Then `ring-cases.txt` differs only by added rows and its header comment, and the old self-test cases pass unchanged

**AC-7: Documented**
Given `fixtures/frame/README.md` and the `ring_frame.py` docstring
When read
Then both give the field format (pieces joined by `|`, `-` empty, any other empty piece malformed) and name the new rows

**AC-8: Harness only**
Given the change
When `git diff --stat` is read
Then it touches only `scripts/frame`, `fixtures/frame`, `.github/workflows` and `_docs`

## Non-Functional Requirements

**Performance**
- The ring stays near its HEAD time (30 s on this host); the added rows add at most 30 s.

**Compatibility**
- Lines of one piece are byte-identical to today's, so the drivers that are not rebuilt keep working on old rows.

**Reliability**
- Run the ring on the unchanged tree first and on the changed tree on one host; an unchanged mismatch count of 0 is the baseline.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Row loader of `ring_frame.py` on the new rows, and on a row the reference refuses | New rows load; a wrong expected tag is a file error naming the row |
| AC-4 | `ring-frame-drivers.test.sh` bad-piece lines for each of the 8 drivers | Each exits non-zero naming `frame line N`, no result |
| AC-5 | `ring-frame.test.sh` with stand-in drivers (first piece only, stops at an empty piece) | Exit 1 naming `P.two` and `P.mid0` |
| AC-6 | `ring-frame.test.sh` old cases | Pass unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-3 | The new `ring-cases.txt`, 8 real drivers | `bash .github/workflows/ring-frame.sh` | The figures of AC-3, exit 0 | Performance |
| AC-5 | A scratch copy with the Go driver passing only `parts[0]` | The same ring | Red, rows named | - |
| AC-6 | Old rows | The same ring | The 45 old rows per pair still match | Compatibility |

## Constraints

- Harness only: no package or wire change.
- The reference (`scripts/frame/framefmt.py`) is the judge; it already takes pieces.
- Figures in the ACs are HEAD 98d2202 readings from this loop; re-read them on the changed tree.

## Risks & Mitigation

**Risk 1: A language's hex reader takes an empty string as zero bytes**
- *Risk*: `ab||cd` is accepted by some drivers and refused by others.
- *Mitigation*: AC-4 pins one rule and the drivers test checks all eight.

**Risk 2: Root-owned build output**
- *Risk*: `csharp/bin`, `cpp/build` and some `rust/target` directories belong to root and cannot be removed without sudo.
- *Mitigation*: the ring passed on HEAD after the removable files were deleted; if a build fails on them, the owner removes them.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Spelling of an empty piece differs by driver | AC-4 pins `-` only | open | Low |
| Root-owned build directories left by container runs | owner (`sudo chown -R` or remove) | accepted-risk | Low |
