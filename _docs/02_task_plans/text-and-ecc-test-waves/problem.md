---
loop: 46
branch: dev
---

# Text and ECC test waves (loop 46)

Source: `_docs/loops/loop45/handoff46.md`, written from the loop 45 feature assessment (`_docs/loops/loop45/assessment45.md`, round 1, verdict CLARIFY). The owner answered on 2026-10-20: all six recommended answers, and "small items now, tests next loop". The small items shipped as AZ-2733 in loop 45. This loop does the tests, the criteria change and the three documentation leftovers. Hopper was a hit (the loop 45 record holds the leftovers), so there is no new interview: the work and the answers are the owner's decisions of 2026-10-20.

## Problem

The compact string format and the message error correction are built and proven in the eight packages, but the continuous build does not guard four things the acceptance criteria or the assessment name:

1. **Concurrency (CS-S3).** Scenario S3 says two threads pack and unpack at once with no shared mutable state. No package of C#, Java, Rust, Go or Swift has a test of it. Python, TypeScript and C++ have the interleaved or caller-scratch tests only, which is all they can express.
2. **Random and hostile counts (CS-A5, CS-A10).** CS-5 says 100,000 random strings and CS-10 says 100,000 hostile payloads per package; the suites run fewer, and Python, C# and Swift run none for text. The owner chose to change the criteria to what the suites run: 3,000 random strings and 30,000 hostile payloads per package, with the large runs kept as a manual probe before a decoder change.
3. **Repeated text speed (CS-D7).** A 65,535-character text written in 200 rounds of `times`/`repeat` has a 1 s test in Python and TypeScript only. Nobody has run the case in Java, C#, Rust or C++.
4. **Protected session across languages (EC-D2).** The session cross-language check carries no parity bytes, so no test makes one language read another language's protected session payload.

Three leftovers of loop 45 are documentation: old-format hex in five test-spec cases, a traceability matrix over the 500-line soft cap, and a size report whose header is written by hand.

## Code sections / UI locations for this loop

From `handoff46.md` (the owner's "Owns" column of the waves, accepted with the six answers on 2026-10-20). No UI.

| Work | Place |
|------|-------|
| CS-S3 | `csharp/tests`, `java/src/test`, `rust/src`, `go/` (tests), `swift/Tests` |
| CS-A5, CS-A10 | `python/tests`, `csharp/tests`, `swift/Tests`, `go/` (the 20,000 payload test), `_docs/02_task_plans/compact-strings/acceptance_criteria.md` |
| CS-D7 | `java/src/test`, `csharp/tests`, `rust/src`, `cpp/tests` |
| EC-D2 | `.github/workflows/language-pair.sh` and the eight session drivers under `.github/workflows/drivers/` |
| Documents | `_docs/02_document/tests/blackbox-tests-02-strings-lists-dicts.md`, `_docs/02_document/tests/traceability-matrix.md`, `scripts/text/size_report.py`, `_docs/02_task_plans/compact-strings/size_report.md` |

No file under `cpp/src`, `cpp/include` or `cpp/embedded` changes (the Cortex-M4F margins of `_docs/AGENT_GOTCHAS.md`: 272 B flash, 8 B stack). No production code changes unless a new test fails (CS-D7: "Fix the walker only if a test fails").

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The Go hostile-payload test runs 20,000 payloads, below the new 30,000 of CS-10 (the handoff listed Go under "today" without a change) | raise it to 30,000 in this loop; the criteria and the suites must agree | open | Low |
| CS-10 also says "unpack time ≤ 1 ms for 64 KiB"; no package has a test of that bound, loop 41 measured it in probes | owner chose option B (criteria match the suites); the bound stays written as measured by the loop 41 probes, not a suite test | accepted-risk | Low |
| A concurrency test is timing-dependent by nature | a fixed thread count, a result comparison and no sleep; a wall-clock check uses the package's load-aware helper (`AGENT_GOTCHAS.md`) | open | Low |
| EC-D2 adds one row to the slowest CI job group | one payload, both directions as for the unprotected session; the CI median of `test.yml` is re-read after the run | open | Low |
| CS-D7 may show a slow package | add the 1 s test first; fix the walker only if the test fails (owner 2026-10-20) | open | Medium |
| CS-D5 (retrain the tables on the owner's 100 to 200 real messages), the first `v*` and `go/v*` tags and F44 | owner-run, waiting on the owner | accepted-risk | Medium |
