# Handoff to loop 51

From the loop 50 record (`record50.md`). Nothing here is owner-decided yet.

## Candidates (all in `_docs/02_tasks/todo/`, epic AZ-2750, slices write `rust/src/nostd/**` one after another)

| Row | Work | Points | Depends on |
|-----|------|-------:|------------|
| Wave A | AZ-2752 flags, bits, u2, packed, sized, when; then AZ-2753 repeat, group, times, lists, dicts | 5 + 5 | AZ-2749 (done); AZ-2753 after AZ-2752 |
| Wave B | AZ-2754 compact text (caller scratch, `text` feature) and AZ-2755 ECC (`ecc` feature; makes the std `ecc.rs` algorithm shareable) | 5 + 3 | AZ-2753; AZ-2749 |
| Wave C | AZ-2756 session, then AZ-2757 hostile corpus, differential proof, publish check, docs | 3 + 3 | AZ-2755; all |

Suggested: loop 51 = wave A (10 points), loop 52 = wave B, loop 53 = wave C. AZ-2755 only needs AZ-2749 and may run with wave A if the owner prefers (it touches `ecc.rs`, which wave A does not).

## Owner input needed

- Size limits for the `text`, `ecc` and `session` feature sets (none until you set them; the base set has 8,192 B flash and 512 B stack).
- CS-D5 (retrain the tables on the 100 to 200 real messages) before the first `v*` tag; the first `v*` and `go/v*` tags and F44 stay yours.

## Read after the push

- `test.yml` on `dev` and `main` for the loop 50 push: the `embedded-arm` job now installs Rust 1.98 and runs `rust/embedded/run.sh host`; read its wall time from the annotations (loop 48: wall about 220 s, longest job `embedded-esp-core` 204 s). If `embedded-arm` becomes the longest job, split the Rust steps out (the free plan runs 20 jobs; one must be given up elsewhere).
- If the new steps fail on GitHub, read the job log first (no token on this host: annotations only name the step).

## Small items

- Add to the `Row` rustdoc that a panicking callback is the caller's (O1, AZ-2757).
- `cargo package` reports a missing `readme` in `rust/` (AZ-2757 AC-3).
