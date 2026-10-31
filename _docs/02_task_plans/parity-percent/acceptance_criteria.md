# Acceptance criteria — parity as a percentage of the message

Baseline: project ACs of `message-ecc` (EC-1 to EC-17) stay true for every scheme that declares a fixed count `n`. Words: `p` = the percentage, an integer 0 to 100; `L` = the clear length of one message; `n(p, L)` = its parity count; `N` = the sent length.

## Formula

- **AC-1** `n(p, L) = min(32, ceil(p × L / 100))`, in integer arithmetic `(p × L + 99) div 100`. Eight packages give the same `n` for all 22,752 pairs `(p, L)` with `p` 0 to 100 and `L` from 0 to the largest clear length of that `p` (0 to 254 for `p` 0; `pairs` in the results report). Spot values: p 25, L 40 → 10; p 50, L 40 → 20; p 100, L 3 → 3; p 100, L 222 → 32; p 1, L 3 → 1; any p with L 0 → 0.
- **AC-2** `p` = 0 sends the clear bytes with no parity: the bytes of an unprotected scheme, for every `L`.

## Wire

- **AC-3** A message packed under `p` is exactly `protect(clear, n(p, L))` of the existing code: the same bytes the fixed-count scheme with `n = n(p, L)` writes for that clear message (checked on 8 `L` values for each of `p` 10, 25, 50, 100 against `fixtures/ecc/vectors.txt` bytes). No new code, no new byte on the wire.
- **AC-4** The largest clear message under `p` is: p 1 → 251, p 10 → 230, p 25, 50 and 100 → 222 bytes; `p` 0 has no limit from this feature (a scheme without parity has none today: `lim.n0.255` is `ok`). A longer clear message is refused as `too_long` naming its length and that limit, and writes 0 bytes.

## Unpack

- **AC-5** Unpack gets `n` from the received length `N` alone: the one `L` with `L + n(p, L) = N`. For every `p` and every `L` pack then unpack returns the same row (22,752 round trips per package: pairs of AC-1). Because `L + n(p, L)` is strictly increasing, the `L` is unique.
- **AC-6** An `N` that no `L` gives (for p 100: every odd `N` below 64; 32 of the 255 lengths 0 to 254 are impossible for p 25) is refused as `uncorrectable`, 0 values, no field named. `N` above 254 is `too_long` as today (for `p` 1 to 100; with `p` 0 nothing is checked, as for `n` 0). No new refusal kind in any package.
- **AC-7** Repair works with the count of that message: p 50, L 40 (n = 20) repairs 10 wrong bytes with `t` 10, refuses the seeded 11-byte corruption with `t` 10 and the seeded 20-byte corruption with `t` 0 (a refusal is certain only up to `n - t` wrong bytes; the rows are patterns the reference refuses); p 25, L 40 (n = 10) repairs 5 wrong bytes with `t` 5.
- **AC-8** The correction limit `t` is 0 to 16 for a percentage scheme (below 0 or above 16 is `bad_limit` before any byte is read). A `t` above `n / 2` of this message is lowered to `n / 2`; the repaired count is the real one. (A fixed-count scheme keeps its exact rule: `t` above `n / 2` is `bad_limit`.)

## Setting

- **AC-9** A percentage below 0 or above 100 is refused when the scheme is built, as `bad_parity` (the package's invalid-scheme error naming the percentage and 100). A scheme that declares both a fixed count above 0 and a percentage above 0 is refused the same way. The fixed-count setting is unchanged: `n` 0 to 32, default 0. Setting the percentage on a scheme that has a fixed count replaces the count, and setting a count on a scheme that has a percentage replaces the percentage (the last setter wins); the other limit setters keep whichever one the scheme has.
- **AC-10** Dispatch over handlers needs the same setting on all of them: the same percentage, or the same fixed count. A mix (two percentages, or a percentage with a count) is refused when the call is built, before any byte is read, as today's mix of counts is. The percentage setting has the spelling of that package's other scheme setting (`with_parity_percent(p)`, `withParityPercent`, `ParityPercent`, `parity_percent(scheme, p)` and the like), set beside `with_parity(n)`.

## Compatibility and cost

- **AC-11** Every existing row of `fixtures/ecc/vectors.txt` (enc, fix, bad, lim, par, lmt) and every existing test of the 8 packages passes unchanged; a fixed-count scheme writes the same bytes as in 0.4.0.
- **AC-12** The work bound of unpack is the old bound (about 3 × 255 × 32 field operations) plus at most 255 integer steps to find `L`; the existing timing checks (load-factor helpers) pass unchanged.
- **AC-13** C++ `PACKBIN_NO_ECC` removes the percentage with the rest of the feature (a percentage above 0 is then `SchemeInvalid`). The Cortex-M33F pins (`m33f_*`) hold the 64 KB / 8 KB ceilings; a pin raised for this change is raised by at most 400 B of flash and 64 B of stack, and the measured figures replace these two bounds at implement time (on HEAD, same loop). Cortex-M33F string-free, ECC-free image: no growth.

## Documents

- **AC-14** Contract `message-ecc.md` goes to 1.1.0 with the formula, the unpack rule, the table of AC-4 and the vectors; an ADR (010) records the decision; the README error-correction section shows the percentage in each package's spelling beside `with_parity(n)`, with the rule "25 % of 40 bytes = 10 parity bytes".
- **AC-15** `fixtures/ecc/percent-vectors.txt` holds the new rows (the row words are in the results report) that all 8 packages read, and the reference `scripts/ecc/eccfmt.py` computes them.

## Cross-language

- **AC-16** The ECC ring (`.github/workflows/ring-ecc.sh`) gains rows under a percentage (p 10, 25, 50 and 100; intact, repaired within the message's `n / 2`, and refused beyond it, plus an impossible length). Each of the 8 languages writes them and each of the 8 reads what each wrote: 64 pairs, 0 mismatched, and each language's refusals match the reference.

## Inherited project ACs exercised

| Inherited | Why this feature exercises it |
|---|---|
| EC-1 to EC-17 (`_docs/02_task_plans/message-error-correction/acceptance_criteria.md`) | Every message under a percentage is protected by the same code; AC-3 and AC-11 keep the bytes and the error rules |
| AC-10 of the project (100000 pack-then-unpack round trips in at most 1 s, Python 2 s) | Unpack gains the search for `L` (AC-12); the existing timing check must still pass |
| The "Hostile bytes" rule of `message-ecc.md` (unpack never throws or traps) | The new length rule (AC-6) runs on any received length 0 to 255 and above |

## Out of scope

- A percentage chosen per message at pack time (it is per scheme).
- Choosing the strength from the measured link quality (no feedback channel).
- A percentage as "share of wrong bytes survivable" (owner chose overhead, 2026-10-31).
- A change to the fixed count `n`, to the code, to the 254-byte limit or to the cap of 32.
- Frame sessions (they have no message parity), compact text, erasure decoding.
