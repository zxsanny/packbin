# Batch 5 report — loop 26

Task: AZ-2517 (Swift round limits, pack budgets and unpack fuzzing, 3 points; stream A, `swift/**` and `fixtures/hostile/fuzz/**`). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2517 | Done | 3 of 3 ACs; 254 tests in 43 suites (parent re-run: pass in 29 s; strict release build 0 warnings); 60 s fuzz run in debug: 5 523 inputs, 554 802 unpack calls, 0 traps, slowest call 0.07 s (worker); thread sanitizer 254 pass, 0 reports (worker); release: speed typed 0.40 s / map 0.22 s, slowest 1 MiB unpack 0.12 s (worker); 29 of 29 mutation proofs red; the seven TypeScript test files of AC-1 pass at HEAD (122 of 122). |

CI-parity: as batch 2. Parent change to `run-suite.sh` (AZ-2521's file): the release step also runs `FuzzTests/mebibyte` (`--filter '\.SpeedTests/' --filter '\.FuzzTests/mebibyte'`), so the 1 MiB hostile unpack is timed in release, where SW-4's 1 s bound is defined; the same packet takes up to 0.8 s in a debug build under the parallel suite. `run-suite.test.sh` passes with the new expected step.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1, 2 | D3: a nested row in a round charges its own members' width (as TypeScript, Go and assessment 24); list and dict items are not charged to `maxRounds`/`maxSlots` (TypeScript and Go agree) | pinned | clear |
| 3 to 5 | refusing-round name, limit value range and message, unpack refusal kind | `parity_differences.md` | clear |
| 6 | the 1 MiB packets are about 7 times slower in debug: 0.8 s worst under the parallel suite; the test bound is 1 s in release, 3 s in debug, 10 s under the sanitizer | parent: accepted; the release step also runs `FuzzTests/mebibyte` | resolved |
| 7 | sanitizer detection by `dlsym(RTLD_DEFAULT, "__tsan_init")` proven on macOS only; on Linux the 3 s debug bound against about 3.4 s measured here could fail under the sanitizer | first CI sanitizer run decides; loop 27 handoff | unclear |
| 8, 9 | zero-width element still packs and unpack refuses (as TypeScript); a u64 times count above `Int.max` is refused by the count rule with TypeScript's text | pinned | clear |
