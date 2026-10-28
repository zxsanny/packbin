# Security lite — loop 79

Diff: `cb6759b..692edcc` without `_docs/` (23 files, +474/-169): the 8 frame drivers, `scripts/frame/ring_frame.py`, `ring-frame.test.sh`, `ring-frame-drivers.test.sh`, `fixtures/frame/`, `run-suite.sh`, `run-suite.test.sh`, 4 Rust sources (cfg attributes on test-only helpers), 3 Rust tests and their support module (imports).

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/**`: `run-suite.sh` (Rust branch), two ring test scripts, the drivers; `test.yml` unchanged; no `uses:`, `permissions:`, secret or env added |
| T2 sensitive content | no | only `token` (parse helper variables) and `FrameSession` (the type the drivers call) in test drivers |
| T3 size | yes | 23 changed files |
| T4 dependencies | no | no manifest or lockfile changed |
| T5 carried finding | no | open findings of `security_report.md` are in package code |
| T6 stale audit | no | not a ship loop, 5 points |
| T7 lite concern | no | see checks |

Verdict: ESCALATE by T1 and T3, answered with a diff-scoped pass below (as in loop 78: test drivers and CI scripts only, no product code path changed).

Checks on the changed lines:
- Injection / process args: `rust_test_build` passes a set name from a fixed list in the script into `--features "$set"`; no outside input. The drivers read only the lines the ring writes.
- Input limits: every number on a driver line is now bounded before use (AZ-3356), so a row can no longer make a driver allocate more than 64 KiB (`out_len`, `clear_len` at most 65,535) or wrap a value; this closes the two Lows of loop 78 (huge `out_len`, direction wrap). The C++ MAC buffer was 32 bytes under a span of up to `n` bytes; `n` is now at most 255 and the buffer 255 bytes (the C++ package refuses any `n` other than 4, 8, 16, 32, so the overflow was not reachable).
- Secrets and logs: none read, written or printed; no network call added.
- Library code: the Rust changes are `cfg` attributes on test-only helpers (`counters`, `hmac_sha256_of`, `block_of`, the frame test impl) and test imports; no item of the shipped crate changed (`cargo check --tests` of all 9 sets clean).
- Blast radius: `run-suite.sh` is shared by the CI `suites` jobs and the compose services of step 11; the change is in the Rust branch only; the Swift CI cache key hashes `run-suite.sh`, so the first CI run misses that cache once.

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new; loop 78 Lows L1 (huge `out_len`) and L2 (direction above 255 wraps) resolved. Info: a `seal` or `mac` ring row that the reference refuses crashes the loader without naming the row (before this loop; leftover). Step 14 done.
