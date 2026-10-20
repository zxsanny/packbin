# Handoff to loop 52

From the loop 51 record (`record51.md`). Nothing here is owner-decided yet unless it says so.

## Candidates (`_docs/02_tasks/todo/`, epic AZ-2750; slices write `rust/src/nostd/**` one after another)

| Row | Work | Points | Depends on |
|-----|------|-------:|------------|
| Wave B | AZ-2754 compact text (caller scratch, `text` feature) **plus dictionaries** (moved from AZ-2753 in loop 51: keys are strings, order compared decoded; spec AC-5); AZ-2755 ECC (`ecc` feature) | 5 + about 2, 3 | done: AZ-2752, AZ-2753 |
| Wave C | AZ-2756 session, then AZ-2757 hostile corpus, differential proof, publish check, docs, **a nested-scheme stack probe** | 3 + 3 | AZ-2755; all |

Suggested: loop 52 = AZ-2754 (re-estimate at intake: with dicts it may pass 5 points) and AZ-2755 if the loop has room; loop 53 = wave C.

## New candidate (not a spec yet)

- **C++ `when` of a skipped source** (found in loop 51, batch 1 discovery 3): the C++ core matches a `when` against a source that sits inside a `when` that does not hold, so it writes a body that its own unpack refuses. Probe: `u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` packs `21 00 05`, unpack `TrailingBytes` (`gcc:16`, loop 51). Std Rust and the new core write `21 00`. Needs a ticket, the C++ fix (the `count_skipped` chain of `pack.cpp` applied to `when` too), a hostile case, and a check of the other six packages.

## Owner input needed

- Size limits for the `text`, `ecc` and `session` feature sets (none yet; the base set is 16,384 B flash and 512 B stack since loop 51).
- CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44 stay yours.

## Risks

- **Stack margin**: the flat probe uses 472 of 512 B (loop 50: 88 B). Nested schemes go deeper. AZ-2757 adds a nested probe; if it passes 512 B, the owner decides the limit or a smaller walk frame (out-of-line helpers did not help, tried in loop 51).
- **CPU per packet** (security Low L51-1): references are resolved where they are used, so cost grows with the square of the scheme size; resolving once at build (Rust 1.83+ const fn, or a generator) is the fix if a real scheme gets large.

## CI read after the push

- `test.yml` on `dev` and `main` for the loop 51 push: the `embedded-arm` job runs the new image (13,724 B flash, 472 B stack); read its wall time from the annotations. No token on this host: annotations only name the step.
