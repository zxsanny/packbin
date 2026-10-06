# Round limits: shared hostile cases, README and security notes

**Task**: AZ-2220_round_limits_hostile_and_docs
**Name**: Hostile `limit` cases, README limits text, security notes
**Description**: Two shared hostile cases (a new `limit` stage) replayed by C#, TypeScript, Java and Rust against a scheme with a low limit; the README says what the defaults are and how a scheme raises them; the security docs record F10 fixed and F11 closed; C++ and Python are recorded as unchanged, with the reason.
**Complexity**: 3 points
**Dependencies**: AZ-2216_csharp_round_limits, AZ-2217_typescript_round_limits, AZ-2218_java_round_limits, AZ-2219_rust_round_limits (the package specs land first: the replays call each package's `WithLimits` / `withLimits` / `with_limits`). Coordinate the case count in `cases.test.sh` with AZ-2194_hostile_pack_stage (it adds five `pack` cases and says 22): whichever lands second adds its own lines to the count. One deviation from "no C++ change": the C++ host replay (`cpp/tests/core/hostile_host_tests.cpp`) needs a one-line skip of the `limit` stage, a test-file-only edit (no C++ product code, header or build file); see Flagged concerns.
**Component**: hostile-fixtures-docs (`fixtures/hostile/`, the four packages' replay files, `README.md`, `_docs/`)
**Tracker**: AZ-2220
**Epic**: AZ-2069

## Problem

Loop 15, finding F10 (round budget on unpack) and F11 (no test bounds unpack cost by packet size), decisions D1 to D7 in `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`. The four package tasks add the limits and their own default-limit size tests; the cross-package pieces are left:

- **No shared case.** `fixtures/hostile/cases.txt` has 17 cases, all stage `unpack` (10) or `construct` (7). A literal 1 MiB packet cannot live in the file, and no replay accepts an `ok` result, so the shared case is a small packet replayed against a scheme with a low limit: the file keeps bytes and outcomes only (ADR-001), the scheme and the limit live in the README section and each package writes them by hand.
- **The format has no place for it.** `check-cases.sh` accepts only the stages `unpack` and `construct` (`check-cases.sh:45`); `cases.test.sh` hardcodes the id list (`cases.test.sh:10-14`) and asserts `hostile cases ok: 17` (`:18`). Each replay maps an id to a hand-written scheme and fails on an id it has no scheme for: C# `HostileVectorTests.cs` (`Cases(stage)`, `Schemes`), TypeScript `hostile.test.ts` (`:64-68` filters by stage) with `support/hostile-cases.ts`, Java `HostileVectorTest.java` (`:27-33` fails on an unknown stage), Rust `hostile_tests.rs` (`:228` panics on an unknown stage; `rust_outcome` panics on an unknown id), C++ `hostile_host_tests.cpp` (`:368` asserts `cases.size() == sizeof(kHandlers)/sizeof(kHandlers[0])` over every line of any stage), Python `test_hostile_vectors.py` and `test_bool_placement.py` (both read only their own stage and four columns).
  - So a new case needs a new stage, not the stage `unpack` (Python would need a scheme it cannot build, C++ a handler it cannot express). Python and TypeScript and C# already ignore a stage they do not run. Java and Rust must learn it (they are in scope). C++ counts every line, so its replay needs a one-line skip of the stage it does not run (a test-file edit; no C++ product code, header or build file changes).
- **Existing vectors stay valid (D5 lazy, owner decision 2026-10-06).** `oversize_count_times` (`01ffffffff00`, accepted terms `short_packet`) still ends in a short read of `v` in every package, because round 1 starts and round 2 never does; the limit is never reached. The first draft of D5 (refuse a `times` count above `maxRounds` up front) made TypeScript's replay classify that packet `bad_value` and fail the line; the lazy check removes the need to widen the line. Checked against scratch prototypes of the four packages: no existing hostile vector result changes.
- **The README states the old rule.** `README.md:1081` (under "Untrusted input", "Limits to keep in mind") says unpack has no packet-size budget and gives per-package peak memory for 1 MB of one-byte rounds (TypeScript about 400 MB, C# about 530 MB, Java about 570 MB, Rust about 310 MB and about 1.4 GB with eight flag bits). The intro of the same section (`README.md:1046`) says unpack "stops within time and memory set by the length of the packet". Both become wrong when the limits land.
- **The security docs carry F10 and F11 as open** (`_docs/05_security/security_report.md:39`, `:42`, `:80`, `:90-91`, `:106`; `_docs/05_security/owasp_review.md:16`).

## Outcome

- `cases.txt` has two new `limit` cases, `check-cases.sh` accepts the stage and its self-test covers it, the hostile README documents the stage and both cases, and C#, TypeScript, Java and Rust replay both against a scheme with `maxRounds` 3.
- The 17 existing vectors, `oversize_count_times` included, give the same results as before in every package.
- The README states the defaults, the refusal, the four ways to raise the limits, the upgrade effect, and why C++ and Python have no code change; the memory figures are re-measured.
- The security docs record F10 as fixed in loop 15 and F11 as closed, with the evidence, and the stale "17 cases" counts are updated.

## Scope

### Included
- `fixtures/hostile/cases.txt`, `README.md` (fixtures), `check-cases.sh`, `cases.test.sh`.
- In each of the four packages' hostile replay files, only the code for the new `limit` stage: C# `HostileVectorTests.cs`, TypeScript `hostile.test.ts` and `support/hostile-cases.ts`, Java `HostileVectorTest.java`, Rust `hostile_tests.rs`. The one-line stage skip in C++ `cpp/tests/core/hostile_host_tests.cpp`.
- Root `README.md`: the two places named in Problem, and one sentence in the Repeat and Times sections that points to the limits.
- `_docs/05_security/security_report.md`, `_docs/05_security/owasp_review.md`, `_docs/02_document/tests/blackbox-tests.md:1589` (count).
- A check that the size tests of the four package specs exist.

### Excluded
- Package code and the size tests themselves (AZ-2216 to AZ-2219).
- Any C++ or Python product code, header, build or test logic other than the C++ one-line skip (below).
- The `pack` stage (AZ-2194), a distinct error kind (C15), the v0.2.2 tag.

## The two cases

| Id | Stage | Expected | Hex | Scheme in the README (limit `maxRounds` 3, `maxSlots` default) |
|----|-------|----------|-----|------------------------------------------------------------------|
| `repeat_rounds_over_limit` | `limit` | `too_many\|bad_value` | `0111223344` | id0 `repeat` anchor 0 { id0 `u8 v` } |
| `times_rounds_over_limit` | `limit` | `too_many\|bad_value` | `010411223344` | id0 `u8 n`; id1 `times` anchor 1, count = id0 { id1 `u8 v` } |

Derived by running the design in each package (a scratch prototype of AZ-2216 to AZ-2219): the first packet holds four one-byte rounds, the fourth is refused when it would start, so every package returns its interim bad-value error with `needed` 0 and `left` 1; the second has count 4 and four round bytes, round 4 is refused when it would start, with `left` 1 (not up front: the count field is not refused). Labels differ by package and are not asserted (C15). Both have a README section `## <id>` with Scheme, Limit, Packet, Expected (outcome term, `needed` 0, `left`), Source, `Run by` (C#, TypeScript, Java, Rust) and `Not run by` (C++, Python, with the reason).

## Acceptance Criteria

**AC-1: The format accepts the `limit` stage**
Given lines `id limit <terms> <hex>` with hex lowercase, even length, starting `01`
When `check-cases.sh` runs on the committed file
Then it prints `hostile cases ok: 19` (17 + 2; add AZ-2194's five if it landed first) and exits 0; the stage message names all three stages.

**AC-2: The format rejects a malformed `limit` line**
Given a `limit` line with hex `-`, one with odd hex, one with a stage typo (`limitt`), one with an unknown term, and a duplicate id
When `cases.test.sh` runs its corruption checks
Then each makes `check-cases.sh` fail and name `<file>:<line>:`; the committed file still passes; `cases.test.sh` lists the two new ids and asserts the new count.

**AC-3: Both cases are documented**
Given `fixtures/hostile/README.md`
When `check-cases.sh` runs
Then it finds a `## repeat_rounds_over_limit` and a `## times_rounds_over_limit` section; the Format and Notation text names the stage `limit` ("build the scheme with the limits the section gives, unpack `hex`"), says each package writes the limit by hand, and says C++ and Python do not run it, with the reason.

**AC-4: Four packages replay both cases**
Given the committed `cases.txt` and each package's own scheme with `maxRounds` 3
When the C#, TypeScript, Java and Rust hostile replays run
Then each case returns an error value (no exception, no hang, handler not called, no row) whose kind is accepted by the line's terms, with `needed` 0 and `left` 1 for both cases; the replay fails on a `limit` id it has no scheme for; the existing 17 cases give the same results as before.

**AC-5: The existing vectors are unchanged**
Given the line `oversize_count_times unpack short_packet 01ffffffff00` and every other existing line, left as written
When the C#, TypeScript, Java, Rust, Python and C++ hostile replays run against the packages with the limits at their defaults
Then every one of the 17 existing cases passes with the same outcome as before; in particular `01ffffffff00` still gives a short read of `v` (`needed` 1), classified `short_packet`. No line of `cases.txt` other than the two new ones is edited.

**AC-6: C++ and Python are unchanged, and recorded**
Given the new lines in `cases.txt`
When the C++ host hostile test and the Python hostile tests run
Then both pass: C++ skips the `limit` stage with a one-line filter in its replay (no product code, header or build file changes) and Python needs no edit. The README (Untrusted input) and `security_report.md` state why neither gets a limit: C++ unpacks into caller-owned `Array<T, N>` storage of capacity at most 65,535 and returns `Error::TooMany` (`cpp/include/packbin/table.hpp:82-90`, `core.hpp:19`), and Python keeps only the values it reads (`python/src/packbin/_unpack.py`, `_append`), so memory stays flat (33 MB in the loop 13 audit).

**AC-7: The size tests of the package tasks exist**
Given the four package tasks have landed
When each language's suite is listed
Then it contains the default-limit tests of its spec: C# `csharp/tests/RoundLimitTests.cs`, TypeScript `typescript/tests/round-limits.test.ts`, Java `java/src/test/java/packbin/RoundLimitsTest.java` (called from `PackbinTest.run`), Rust `rust/tests/round_limits_tests.rs`; each holds a test that a packet of `maxRounds` one-byte rounds is accepted and one of `maxRounds + 1` is refused at the defaults, and a test that a refused 1 MiB packet returns `left` 983,041. The record of the loop names the four test runs.

**AC-8: The README states the new rule**
Given `README.md`
When the "Untrusted input" section is read
Then the intro no longer says memory is set only by the packet length, and the bullet at `:1081` says: the defaults (`maxRounds` 65,535 rounds per `repeat` or `times` field, `maxSlots` 4,194,304 slots per unpack call, a slot being a round times a name the round can hold); that C#, TypeScript, Java and Rust refuse a packet above either with the same bad-value error as any other unreadable value (no row, handler not called); the four ways to raise or lower them (`scheme.WithLimits(maxRounds:, maxSlots:)`, `scheme.withLimits({ maxRounds, maxSlots })`, `scheme.withLimits(maxRounds, maxSlots)`, `scheme.with_limits(max_rounds, max_slots)` on `MapScheme` and typed `Scheme`), that an omitted C# or TypeScript value is the default, and that a value below 1 is refused when the scheme is built; the upgrade effect (a packet with more rounds than the default that unpacked before is refused until the scheme raises the limit); that C++ and Python need no limit and why (AC-6); that a cap on the packet length is still advisable (time grows with the packet length). The memory figures are re-measured at the defaults with the method of the old figures (resident set, 1 MB packet of one-byte rounds, 36-name `when` body; Rust `times`, and Rust with eight flag bits) and replace the old ones; the new text gives the bound under the defaults. The Repeat and Times sections gain one sentence pointing to the limits.

**AC-9: The security docs record the outcome**
Given `_docs/05_security/security_report.md` and `owasp_review.md`
When they are read after this task
Then a "Loop 15" status block says: F10 fixed by AZ-2216 to AZ-2219 (defaults, refusal, the four packages), with the test evidence; F11 closed for C#, TypeScript, Java and Rust by the size tests (AC-7) and the two `limit` cases, with C++ and Python recorded as bounded by design (AC-6) and no size test added for them; the A06 line of `owasp_review.md` no longer lists F10 and F11 as open; the earlier loops' tables are not rewritten. `blackbox-tests.md:1589` says 19 cases (or the count at that time).

## Non-Functional Requirements

**Reliability**
- The `limit` replays return within the existing 1 s guard of the hostile README; the packets are 5 and 6 bytes.
- `cases.test.sh` and `check-cases.sh` keep running in the `scaffold` job of `test.yml` without new tools.

**Compatibility**
- Python, C#, TypeScript loaders keep working on a file with an extra stage (verified by their stage filters); Java and Rust change in this task; C++ gets the one-line skip.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `bash fixtures/hostile/check-cases.sh` | `hostile cases ok: 19` |
| AC-2 | `bash fixtures/hostile/cases.test.sh` with new corruptions (`-` hex, odd hex, `limitt`, unknown term, duplicate id) | each corrupted copy rejected with `<name>.txt:<line>:`; `hostile case tests passed` |
| AC-3 | `check-cases.sh` on a copy without one new README section | fails naming the id |
| AC-4 | C#, TypeScript, Java, Rust replays | both cases pass in each; each replay fails on an unknown `limit` id (temporary extra line) |
| AC-5 | the six hostile replays on the committed file | the 17 old cases unchanged; `git diff` shows no old line edited |
| AC-6 | C++ host test, Python hostile tests with the new lines | pass; no C++ product or Python file in the diff |
| AC-7 | list of test names per suite | the default-limit and 1 MiB tests of each package present |
| AC-8 | read README text; grep for the removed figures | stated rules present; no "set by the length of the packet" and no old MB figures left |
| AC-9 | read the two security docs | Loop 15 block present; A06 line updated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `0111223344` against a `repeat` scheme with `maxRounds` 3 | public unpack of each of four packages | error value, `needed` 0, `left` 1, handler not called | Reliability |
| AC-4 | `010411223344` against a `times` scheme with `maxRounds` 3 | public unpack of each of four packages | error value, `needed` 0, `left` 1 | Reliability |
| AC-5 | `01ffffffff00` against `u32 n; times { u8 v }` at the defaults | unpack in the four packages | short read of `v` (`needed` 1), as before | Compatibility |
| AC-6 | whole `cases.txt` | C++ host replay and Python replay | no failure from the `limit` lines | Compatibility |

## Constraints

- **Owns**: `fixtures/hostile/**`; `README.md`; the replay files of the four packages listed in Scope, for the new `limit` stage only (a package spec must have landed first: the replays call its `WithLimits` / `withLimits` / `with_limits`); `cpp/tests/core/hostile_host_tests.cpp` for the one-line stage skip; `_docs/05_security/security_report.md`, `_docs/05_security/owasp_review.md`, `_docs/02_document/tests/blackbox-tests.md` and notes under `_docs/`. **Forbidden**: any package source or test other than the files listed; workflows; `_docs/02_tasks/_dependencies_table.md`.
- ADR-001: the file holds bytes and outcomes only; each language writes its scheme by hand from the README section.
- Outcome terms: only terms `check-cases.sh` already knows (`too_many`, `bad_value`); until C15 a package without a type for a kind passes with any non-ok, non-exception result and names the kind it returned.
- `.sh` changes follow `bash.md`; under `set -o pipefail` capture command output before `grep -q` (loop 14 lesson).
- `_docs/LESSONS.md` (loop 13): re-derive every hex in the README sections from the real packages; the two packets above were run, not written from the wire rules.

## Risks & Mitigation

**Risk 1: A replay green on the wrong cause**
- *Risk*: a package answers the limit case with a shape error (for example a short read of `v`) and the kind check passes.
- *Mitigation*: AC-4 asserts `needed` 0 and the exact `left`; a short read of `v` has `needed` 1.

**Risk 2: Count collision with AZ-2194**
- *Risk*: two tasks edit the same asserted count and the same format check.
- *Mitigation*: Dependencies line; the second to land rebases the count and the stage list.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D5 (lazy, owner decision 2026-10-06): no existing vector changes, so no widening of `oversize_count_times` and no ordering constraint with AZ-2217 (the first draft needed both) | owner (D5) | resolved | Low |
| Test-file-only deviation: the C++ replay counts every line of `cases.txt` against its handler table, so a new line needs the one-line stage skip in `cpp/tests/core/hostile_host_tests.cpp` (no C++ product code, header or build file). Alternative: put the two cases in a separate file | owner | open | Low |
| Size: raised from 2 to 3 points. Beyond two cases it touches the format check and its self-test, the hostile README, the root README (two places plus Repeat/Times, with re-measured figures), two security docs, a blackbox-tests count, four package replays and a C++ test line; loop 14's lesson sizes such work by the scripts and tests touched, not by AC count. If it still overruns, split the README and security notes from the replays | implementer | accepted-risk | Low |
| F11 is closed for four of six packages; C++ and Python are bounded by design and get no size test, so the finding is closed with a stated limit, not fully | owner | accepted-risk | Low |
| Re-measured README figures depend on host and runtime (resident set, not allocation); record the host and method next to the new figures | implementer | open | Low |
