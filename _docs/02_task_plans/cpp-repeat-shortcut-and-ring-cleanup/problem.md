---
loop: 48
branch: dev
---

# Loop 48: C++ repeated-text shortcut and ring cleanup

Source: `_docs/loops/loop47/record47.md` leftovers and `handoff48.md`. Owner 2026-10-20 asked once and chose "accept all recommended".

## In scope
- AZ-2742 (3 points): C++ text, reuse the previous round's encoded bytes in a times/repeat pack; the C++ repeat test returns to a 1 s bound. Flash and stack saving first, arm embedded stage before the commit.
- AZ-2747 (1 point): ring comments point at `ring-lib.sh`; `ring-wiring.test.sh` (exactly 500 lines) split below the cap.
- Push `dev` (with docs commit 284126b) at the loop close; read the second CI run for the loop 47 ring and Swift sanitized timings.

## Out of scope
- CS-D5 retrain, the first `v*` and `go/v*` tags, F44: owner-run.
- Any wire change: every `enc` row of `fixtures/text/vectors.txt` stays byte-identical.

## Work split
Disjoint write sets: AZ-2742 owns `cpp/src/core`, `cpp/tests/core/text_repeat_host_tests.cpp`, `_docs/AGENT_GOTCHAS.md` margins; AZ-2747 owns `.github/workflows` ring scripts and tests.
