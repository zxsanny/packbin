# Handoff to loop 47

From the loop 46 record (`record46.md`). Nothing here is owner-decided yet except where it says so.

## Candidates (disjoint paths)

| Row | Work | Owns |
|-----|------|------|
| AZ-2742 | C++ shortcut for the repeated text: reuse the previous round's bytes in a times/repeat pack; the C++ test returns to a 1 s bound. Any edit under `cpp/src/core` needs a flash and stack saving first (margins 272 B and 8 B in `AGENT_GOTCHAS.md`); run the arm embedded stage | `cpp/src/core`, `cpp/tests/core/text_repeat_host_tests.cpp` |
| CI-split | Split `language-pair.sh` (545 lines) by responsibility with its exact-line wiring tests; move the all-language session-ecc check out of the Swift wiring test | `.github/workflows/language-pair.sh`, `ring-wiring*.test.sh` |
| TSan | Run `TextConcurrencyTests` in the `swift_sanitized` CI step (three exact-string readers in `run-suite-swift.test.sh`) | `.github/workflows/run-suite.sh`, `run-suite-swift.test.sh` |

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Read after the push

- The CI timing of `test.yml` (the ring job grew by about 5 s locally) and whether the new Python hostile test changed the Python suite time (about 2.5 s locally).
