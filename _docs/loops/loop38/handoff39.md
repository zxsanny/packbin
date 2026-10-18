# Loop 39 handoff (written 2026-10-18 at the close of loop 38)

Read `_docs/loops/loop38/record38.md` and `_docs/loops/loop37/record37.md`.

## State
- Loops 35 to 38 are on `origin/dev`; `main` is not pushed and no tag exists. Message error correction (epic AZ-2677, tasks AZ-2678 to AZ-2690) is in all eight packages; contract `message-ecc.md` 1.0.0, ADR 007.
- Owner-run and still open: `/feature-assess`, `/security` (AZ-2666), the retrospective, F44, the first tags.

## Candidate work
- Owner decision: the default correction limit (now 0, detect only) and the 254-byte limit.
- Review cleanups of loop 38 (record38 leftovers): one dispatch/duplicate-type order, a distinct `TooLong` in Go, Swift and C++, the Rust trait default, the re-verify test, the stale C++ description numbers. About 5 points, short loop.
- A CI run to measure the `test.yml` median (AZ-2689 AC-3), ESP32 and Pico builds with ECC on.
- Real messages (D5): retraining is a wire break, free until the first `v*` tag; needs 100 to 200 messages from the owner.
- AZ-2068 (AVR build, stretch) is the only unclaimed spec in `todo/`.
