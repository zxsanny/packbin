# Handoff to loop 54

From the loop 53 record (`record53.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty: all eight slices of epic AZ-2750 are done.

## Epic AZ-2750 is complete

AZ-2749, AZ-2751 to AZ-2757 shipped in loops 50 to 53. Jira: AZ-2756 and AZ-2757 are In Testing like the others; the epic itself is the owner's to close. The Rust crate has `packbin::nostd` with features `text`, `ecc` and `session`, an embedded CI stage, a hostile and differential proof, and documents.

## Owner input needed

- Size limits for the feature sets (now with figures at loop 53 HEAD): `text` 26,632 B flash / 2,760 B stack (the stack figure includes the probe's nested rows, about 1 KB of it), `ecc` 17,980 B / 760 B, `session` 18,404 B / 1,832 B (most of the stack is key derivation at `start`/`join`); base 14,700 B / 456 B against 16,384 / 512.
- CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44 stay yours.
- Whether to close the open row U24 in the C++ package: the Rust core now refuses the three `pack_novalue_count_clear_when_*` cases (a counted `sized`/`bits`/`packed` member whose count is never written), the C++ runner still skips them.

## Candidates (not specs yet)

- **C++ `when` of a skipped source** (found in loop 51, still no ticket): the C++ core matches a `when` against a source that sits inside a `when` that does not hold, so it writes a body that its own unpack refuses. Probe: `u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` packs `21 00 05`, unpack `TrailingBytes` (`gcc:16`). Needs a ticket, the C++ fix, a hostile case, and a check of the other six packages.
- **Session stack**: derive the keys in place (HKDF output straight into the two key arrays, one SHA-256 state reused) to cut the 1,832 B; only worth it once the owner names a limit.
- **`session_core` outside the clippy deny list** (security O3): move the lints to that module's root and replace the two `+=`/`-` shapes.
- **Ring driver for `nostd`** (idea): the ring hands packets between packages; the core has no driver, so a packet from the core is proven only against `std` in-process.

## Risks

- **L52-1** (security Low): `unpack_repair` leaves the repaired bytes in the buffer when the field read then fails.
- **L51-1**: references are resolved where they are used, so CPU grows with the square of the scheme size.
- A session pad is not a MAC and an injected packet shifts the receive position (security O1, O2); frame mode is meshbell PB-04.

## CI read after the push

- **`main` is red on a C# suite** (run 39537652411, job `suites (csharp rust)`, "suites failed: csharp") while the same commit is green on `dev` (run 39537581654). The loop touched no C# file; the rust steps of the red job passed. First action of loop 54: ask the owner to re-run that job on `main` and, if it fails again, read the log for the test name (it needs a token; the annotation does not name it).

- `test.yml` on `dev` and `main` for the loop 53 push: `embedded-arm` now builds four Rust sets (base, text, ecc, session); the rust suite job runs eight lines (two new session runs and the hostile set with `text,ecc`). Read the wall time and the figures from the annotations (no token on this host).
