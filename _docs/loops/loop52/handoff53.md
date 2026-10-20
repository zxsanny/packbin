# Handoff to loop 53

From the loop 52 record (`record52.md`). Nothing here is owner-decided yet unless it says so.

## Candidates (`_docs/02_tasks/todo/`, epic AZ-2750; slices write `rust/src/nostd/**` one after another)

| Row | Work | Points | Depends on |
|-----|------|-------:|------------|
| Wave C | AZ-2756 session (`session` feature: seed, caller nonce, seal and open on caller buffers, same bytes as the std `PackSession`), then AZ-2757 hostile corpus, differential proof, publish check, docs, **a nested-scheme stack probe** | 3 + 3 | done: AZ-2752 to AZ-2755; AZ-2757 needs AZ-2756 |

Suggested: loop 53 = AZ-2756 and AZ-2757 in sequence (the epic closes). AZ-2757 should also: replay `fixtures/hostile/cases.txt` and the fuzz corpora on the core, measure a repeat of long raw strings (the C++ memo of AZ-2742 is not ported, see below), run the nested probe on the device image (strings and dictionaries included), and add the `session` set to `rust/embedded/feature-sets.txt` (the probe's `pb_rs_extra` takes a `session` round trip beside the two present ones).

## New candidate (not a spec yet)

- **C++ `when` of a skipped source** (found in loop 51, still no ticket): the C++ core matches a `when` against a source that sits inside a `when` that does not hold, so it writes a body that its own unpack refuses. Probe: `u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` packs `21 00 05`, unpack `TrailingBytes` (`gcc:16`). Needs a ticket, the C++ fix (the `count_skipped` chain of `pack.cpp` applied to `when` too), a hostile case, and a check of the other six packages.

## Owner input needed

- Size limits for the `text` (24,888 B flash, 1,344 B stack on the probe), `ecc` (17,804 B, 760 B) and `session` feature sets (none yet; the base set is 16,384 B flash and 512 B stack, measured 14,532 B and 456 B).
- CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44 stay yours.

## Risks

- **Stack**: the `text` probe frame is 1,344 B including the probe's 192 B scratch and two message rows; the library part is about 700 B. A device with a small stack sizes the scratch to its longest string (3 words per code point).
- **Raw memo** (security observation O2): a repeat of the same long raw string re-runs the parse each time in the Rust core. CPU on the caller's own row; AZ-2757 measures it and ports the memo only if the figure matters.
- **L52-1** (security Low): `unpack_repair` leaves the repaired bytes in the buffer when the field read then fails.
- **L51-1** (still open): references are resolved where they are used, so CPU grows with the square of the scheme size.

## CI read after the push

- `test.yml` on `dev` and `main` for the loop 52 push: the `embedded-arm` job now runs three Rust sets (base, text, ecc); read the wall time and the figures from the annotations (no token on this host). The rust suite job runs three more `cargo test` lines (text and ecc without default features, the dictionary and differential tests with them).
