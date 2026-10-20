# Handoff to loop 48

From the loop 47 record (`record47.md`). Nothing here is owner-decided yet except where it says so.

## Candidates

| Row | Work | Owns |
|-----|------|------|
| AZ-2742 | C++ shortcut for the repeated text: reuse the previous round's bytes in a times/repeat pack; the C++ test returns to a 1 s bound. Any edit under `cpp/src/core` needs a flash and stack saving first (margins 272 B and 8 B in `AGENT_GOTCHAS.md`); run the arm embedded stage | `cpp/src/core`, `cpp/tests/core/text_repeat_host_tests.cpp` |
| Ring comments | Point the comments that name `language-pair.sh` for the runner at `ring-lib.sh`; split `ring-wiring.test.sh` (exactly 500 lines) before its next edit | `ring-cxx.sh`, `ring-go.sh`, `ring-swift.sh`, `ring-prepare.sh`, `ring-toolchains.sh`, `publish-vcpkg.test.sh`, `ring-wiring.test.sh` |

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Read after the push

- The CI time of the ring job and of the Swift `sanitized` step (AZ-2745 AC-5); the local TSan figure for the text test is 2.7 s.

## CI read after the push (loop 47, `ebce1b6`)

`test.yml` on `dev` (run 39370459426) and on `main` (run 39370461865): both green, 20 jobs, `dev` wall 274 s (queue to done). Longest job `suites (swift, tests)` 272 s (loop 34 median wall was 213.5 s; this part holds the sanitized step and the host-noisy runner was not re-run), then `suites (swift, speed)` 230 s, `suites (swift, gates)` 229 s, `publish-gate-readonly` 218 s; `ring` 143 s (was 209 s at loop 33), `scaffold` 166 s. AZ-2744 AC-3 holds on the runner (the two new wiring steps are inside `scaffold`); AZ-2745 AC-5 added time is not separable from the one run: the Swift `tests` job is the longest, so read a second run before judging.
