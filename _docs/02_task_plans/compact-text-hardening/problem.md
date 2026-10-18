---
loop: 36
branch: dev
---

# Compact text hardening

Loop 36 closes the two Medium findings of the loop 35 total review (`_docs/loops/loop35/review35.md`) and runs the security audit of the new decoder that loop 35 skipped (owner, 2026-10-18).

1. **Encode state belongs to the pack call.** Python (`_text_encode.py` `_last`) and TypeScript (`text.ts` `lastText`/`lastField`, plus the shared scratch arrays) keep the last encoded text in module-level mutable state, so one pack call can see another call's text, a 64 KB text stays alive after the call, and two instances share it. Go, Swift and Rust already keep the cache in the pack call. The cache moves into the pack call object in Python and TypeScript.
2. **The 1 s speed bound (CS-11) is checked in CI.** Rust asserts 1 s only when `debug_assertions` is off and CI runs `cargo test` in debug; Swift's CI speed step filters `\.SpeedTests/` and so never runs `TextSpeedTests`. Both are made to run in the release configuration CI already uses for speed.
3. **Security audit** of the compact text decoder in all eight packages (untrusted bytes), report in `_docs/05_security/`.

## Code sections / UI locations for this loop

Owner: "Security audit + 2 Medium findings" (loop 36 choice, 2026-10-18). Code: `python/src/packbin/_text_encode.py`, `_pack.py` (the two `_text_field` call sites), `typescript/src/text.ts`, `kinds.ts`, `pack-out.ts`; `.github/workflows/run-suite.sh` (the `rust)` branch and `swift_speed`), `run-suite.test.sh` and `run-suite-swift.test.sh`; the decoders of the eight packages for the audit.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A release build of the Rust crate in the `csharp rust` CI job adds minutes to the job | Measure on the first CI run; the wall floor is about 200 s | open | Low |
| `/feature-assess` and the retrospective of loop 35 are owner-run skills | Carried; the owner runs them | open | Low |
