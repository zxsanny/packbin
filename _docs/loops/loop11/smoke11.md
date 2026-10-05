# Loop 11 smoke — proposed checks

LOCAL_URL: none (libraries; no UI, no local server)
Branch: dev (no worktree, owner decision)
HEAD: c9c6572 (code), later commits touch `_docs/` only

## Perform these checks in a terminal at the repo root

- [ ] All six CI suites pass in Docker, the same jobs GitHub Actions runs (about 2 minutes):
      `for l in csharp typescript python rust cpp java; do docker compose -f docker-compose.test.yml run --rm $l || break; done`
      Then `cat test-results/report.csv` shows PASS for all six. (AZ-2071..2077, 2107..2111, 2122..2125)
- [ ] Shared hostile vectors still check out: `bash fixtures/hostile/cases.test.sh` ends with "hostile case tests passed".
- [ ] Python never hangs on the zero-progress repeat packet: `/tmp/packbin-pytest/bin/python -m pytest -v python/tests/test_hostile_unpack.py -k zero_progress` passes in well under a second. (AZ-2071 AC-1)
- [ ] A 131 KB list-of-lists packet is an error, not a stall: `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --filter ZeroWidth` passes, including the 131 KB case. (AZ-2109 AC-1)
- [ ] C# no longer throws on the largest 64-bit integers: `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --filter TopRange` passes. (AZ-2123 AC-1)
- [ ] TypeScript keeps `__proto__` as an ordinary key: `cd typescript && node --test tests/value-fidelity.test.ts` passes. (AZ-2122 AC-1)
- [ ] Concurrent sessions never reuse a keystream: `bash java/test.sh` prints "All session tests passed", and the C# `ConcurrentPack` test passes. (AZ-2123/2124)
- [ ] Rust refuses an orphan flag bit when the scheme is built: `cargo test --manifest-path rust/Cargo.toml orphan -- --nocapture` passes. (AZ-2111 AC-5)
- [ ] The README section "Untrusted input" (README.md, near the end) matches what you decided: errors for hostile packets, the two build-time rules, the upgrade breakages, and the limits list.
- [ ] Jira: AZ-2071..2077, AZ-2107..2111 and AZ-2122..2125 are In Testing; AZ-2112..2121 are open follow-ups under AZ-2069.

## Notes

No credentials needed. Docker must be running. After PASS the loop record is written, `dev` is pushed to origin, and `origin/stage` is fast-forwarded to it (`loop_end_merge: stage`). No tag is created, so nothing is published; v0.2.0 still waits for AZ-2094..2097.

## Result

smoke: PASS (owner, 2026-10-05). No agent browser walk: no UI. Each selected test command in the checklist was run by the agent beforehand and passed (C# ZeroWidth 19, TopRange 16, ConcurrentPack 1; TypeScript value-fidelity 9; Rust orphan 3; Python zero_progress 1; six Docker suites PASS).
