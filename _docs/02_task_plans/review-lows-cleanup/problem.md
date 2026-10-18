---
loop: 37
branch: dev
---

# Review Lows cleanup

Loop 37 closes the Low findings carried from the loop 35 total review (`_docs/loops/loop35/review35.md`), owner choice "Review Lows cleanup" (2026-10-18). No wire or API change.

| # | Finding | Decision (owner, 2026-10-18) |
|---|---------|------------------------------|
| 2 | `Scratch<65535>` is a 786 KB object with no guard against a local declaration | Frame-size warning in the C++ build, a header comment, a test with a deliberate local (AZ-2674) |
| 5 | `csharp/tests/CompactTextTests.cs` is 620 lines (cap 500) | Split by responsibility (AZ-2675) |
| 6 | `research/bench.py` is 688 lines and duplicates the parse of `textfmt.py` | Reuse `scripts/text/textfmt.py`, split under 500 lines (AZ-2676) |
| 7 | Unrequested `put_number`/`get_number`/`Field::eq` edits | Accepted: merged, a 196 B flash saving, tests green, margin recorded in `AGENT_GOTCHAS.md`. No code |
| 8 | Refusal kinds are not exposed | Accepted: the contract says every package returns its own error naming the field and the kind only decides whether a row is refused. No code |

## Code sections / UI locations for this loop

Owner choice from the loop 37 question. Code: `cpp/include/packbin/core.hpp` (`Scratch`), the C++ build flags (`cpp/Makefile`, `docker-compose.test.yml`, `scripts/` as found), `cpp/tests`; `csharp/tests/CompactTextTests.cs`; `_docs/02_task_plans/compact-strings/research/bench.py`, `scripts/text/textfmt.py`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The frame-size warning could trip an existing C++ test or the embedded stage that declares large locals | Measure; set the limit above the largest legitimate frame | open | Low |
| Cortex-M4F margins are 60 B flash and 20 B stack: a header comment is free, a code edit in `cpp/include` is not | `AGENT_GOTCHAS.md`; only comments and build flags change | open | Low |
