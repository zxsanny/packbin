# Autodev loop record — loop 79

loop: 79
branch: dev
plan_artifact: _docs/loops/loop79/plan79.md
tasks_shipped: [AZ-3356_frame_ring_number_ranges, AZ-3357_rust_test_build_warnings]
decisions:
  - owner (2026-10-28, intake): pick "Ring + test-build fixes" (recommended) over the AVR chacha20 check, the public-key pairing step and multi-part MAC rows
  - owner (2026-10-28, intake): bundle "accept all recommended": one range rule in all 8 drivers (dir, tag_len, kind, n 0 to 255; epoch 0 to 4294967295; out_len 0 to 65535; digits only; out of range is a malformed line), the loader refuses such rows, `... and N more` after 5 lines, Rust helpers with their callers' cfg and a warning-free build of every test target of 9 feature sets
  - owner (2026-10-28, assessment round 1): "accept all recommended": U2 keep the Java driver's own `BadValue` for an epoch above `Integer.MAX_VALUE` (the Java package's epoch is an `int`, as U1 of loop 78); D3 keep `cargo check --tests` over `cargo test --no-run`
  - agent: `clear_len` takes the range of `out_len` (new-task Step 5, auto-applied)
  - agent: two tasks (3 + 2 points), no epic, two workers at once (disjoint files)
  - agent: `#[cfg(feature = "frame")]` on `counters::take` (outside the worker's list; the default set warned there, not about `from_hex` as the intake probe said)
  - agent: security lite escalated by T1 (`.github/workflows/**`) and T3 (23 files), answered with a diff-scoped pass (`_docs/05_security/lite_loop79.md`): 0 Critical/High/Medium/Low new; the 2 Lows of loop 78 resolved
  - agent: no per-batch review (owner preference); the assessment was done by the parent
measurements:
  - probe ring on cb6759b (extra rows in a scratch cases file): direction 257/258 sealed and opened by C#, C++, Go; tag length 260 and kind 256/260 by C++; epoch 4294967297 by Go (seal and MAC); `out_len` 2147483647 ran C# and Java out of memory, 1099511627776 got Python and Swift killed (`Killed: 9`)
  - real ring after AZ-3356 (fresh work dir): `refusals <lang>: 43 rows, 0 mismatched` x 8, `64 pairs, mismatched: 0`; driver script 132 of 132 (was 44); the cb6759b drivers fail 54 of the 132 cases
  - Rust 1.98: 0 `warning:` lines in all 9 sets (was 3 in `frame`, 3 in `text,ecc,frame`, 1 in default, 1 in all-features)
  - Rust suite cold on 4 CPUs (`docker run --cpus 4 rust:1.98`, fresh target): HEAD 185 s; with `cargo test --no-run` for the 9 sets 249 s; with `cargo check --tests` 193 s; 96 `test result` lines identical, 0 failed
  - step 11 `scripts/loop-tests.sh --all` at 692edcc, host load 4 to 35: typescript 31 s, csharp 60 s, go 176 s, python 155 s, java 14 s, cpp 95 s, rust 253 s (the 9 checks 94 s: the first build after the cfg edits, cold, inside the 3-suite pool), scaffold 304 s, swift 447 s, cpp-embedded-arm 16 s, rust-embedded 5 s, ring 58 s (was 54 s), ac10 5 s, publish-gate 331 s: 14 passed, 0 failed, 1,052 s; two vcpkg checks NOT RUN on the Mac (CI runs them)
  - rust stage alone afterwards, warm: 77 s (the 9 checks 0 s); the worker's HEAD baseline of the same compose run: 77 s
  - loop AC-12 (rust stage at most +60 s): +8 s cold on 4 CPUs (the CI shape) and +0 s warm; not met in the step 11 pool run (+117 s over loop 78's 136 s, of which 94 s the cold checks); the CI job time is read in loop 80
  - smoke `smoke79.sh` 10 of 10 on the first trial (113 s)
  - local CI parity: `g++ -std=c++17 -O2 -Wall -Wextra -Werror` in `gcc:16`, `gofmt` and `go vet` in `golang:1.27`, Swift driver in `swift:6.3.3` `--static-swift-stdlib` (49 s), `shellcheck -S warning` on the changed scripts
review: "no per-batch code review (owner preference); feature assessment by the parent: round 1 CLARIFY (U2, D3) answered the same turn, final COMPLETE 13 covered / 2 out-of-scope (assessment79.md)"
retro: done (loops 75 to 79, `_docs/06_metrics/retro_2026-10-28_loop79.md`; LESSONS trimmed to 15, the 14 oldest dropped, each kept in its source retro or record)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`; a public-key pairing step
  - owner (new): `_docs/_autodev_state.md` is in `.gitignore` since the scaffold commit; the autodev protocol wants it tracked
  - D5: a `seal` or `mac` ring row that the reference refuses crashes `ring_frame.py` without naming the row (before this loop)
  - ring, open: multi-part MAC messages (a new driver line format); key and msg_id length refusals (U1 of loop 77)
  - candidates from loop 76 still open: the AVR runtime check of `chacha20_xor`
  - open: L76-1 (timing-selftest flake cause unproven); Go intermittent failure L74-3 did not show in step 11
  - Jira: AZ-3356 and AZ-3357 In Testing (read back); AZ-3354, AZ-3355, AZ-3338, AZ-3341 and earlier In Testing
lessons:
  - Measure a new CI step cold with the runner's CPU count and name the job it lands on before agreeing the command with the owner.
  - An intake probe builds every configuration the ACs will name, not a sample.
  - A handoff line names one instance of a defect class, not the class: probe every field at its edge.
smoke: PASS
smoke_artifact: _docs/loops/loop79/smoke79.md
assessment_artifact: _docs/loops/loop79/assessment79.md
loop_end_merge: main
