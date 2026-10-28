# Security lite — loop 78

Diff: `d57e2a3^..HEAD` without `_docs/` (16 files, +913/-345): the 8 frame drivers, `ring_frame.py`, `ring-frame.test.sh`, new `ring-frame-drivers.test.sh`, `test.yml` (one new `run:` step), `publish-jobs.test.sh`, `loop-tests.sh`, `fixtures/frame/`.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/**`: `test.yml` gains one step `bash .github/workflows/ring-frame-drivers.test.sh`; no `uses:`, no `permissions:`, no secret or env added |
| T2 sensitive content | no | only the word `token` (hex token, parse helpers) in comments and variable names |
| T3 size | yes | 16 changed files, 913 added lines |
| T4 dependencies | no | no manifest or lockfile changed |
| T5 carried finding | no | `security_report.md` findings are in package code, not in the ring |
| T6 stale audit | no | not a ship loop |
| T7 lite concern | no | see checks |

Verdict: ESCALATE by T1 and T3, answered with a diff-scoped pass below (the full repository audit of `SKILL.md` is not repeated; the diff touches test drivers and CI scripts only, no product source).

Checks on the changed lines:
- Injection / process args: `ring-frame-drivers.test.sh` uses `eval` on the `run_lang` text cut from `ring-lib.sh` (the same as `ring-frame.sh`; repository file, no external input) and `perl -e 'alarm shift; exec @ARGV' ... bash -c 'run_lang "$@"'` with arguments the script builds itself. No path or word comes from outside the checkout.
- Secrets and logs: none read, written or printed; no network call added; the Go driver still runs in the same container as before.
- Input limits: the new strict parsers reject bad hex, odd length, bad numbers and missing fields with a non-zero exit (C++ `.at`, Rust `Result`, Go `frameFields`, Swift throwing helpers); a huge `out_len` in a test row would abort the driver (C++ `length_error`, Rust and Go allocation) — Low, rows are repository text.
- Blast radius: `scripts/loop-tests.sh` now also runs `ring-frame.sh`, `ring-frame-drivers.test.sh` and `ring-frame.test.sh`; all are repository scripts, run on the developer host as the other stages are.
- Unsafe constructs in drivers: `static_cast<FrameDirection>(uint8)` and Go `FrameDirection(uint8(d))` wrap a direction above 255 (257 reads as Up). No row uses it. Low; left (assessment 78).

Findings: 0 Critical, 0 High, 0 Medium, 2 Low (huge `out_len`, direction above 255 wrap). Step 14 done.
