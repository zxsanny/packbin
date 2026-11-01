# Acceptance criteria: percentage docs and device run

Feature criteria; project criteria are inherited. Numbers are counts of checks, bytes or machines.

## Docs

- AC-1 `Packbin.md` has a section on the percentage that gives the formula `n = min(32, ceil(p x L / 100))`, the setter `withLimits(parityPercent:)`, the reader `parityPercent`, the 0 to 100 range refused as `.schemeError`, "last one set wins" with a count, the three largest clear sizes (251 at 1 %, 230 at 10 %, 222 from 25 %), and `parityPercent` in the API list; 0 symbols in the page that the package does not define.
- AC-2 `go/doc.go` has the same content with `WithParityPercent(p int) (*Scheme, error)`, `ParityPercent() int` and `MaxParityPercent` (100); `go doc` shows the three names and `go vet ./...` stays clean.
- AC-3 Every number and rule in the two pages equals the README section (0 differences found by reading both side by side).

## Device run

- AC-4 The C++ vector runner on QEMU `mps2-an385` and `mps2-an505` runs a percentage test (at least 12 cases: p = 1, 10, 25, 50, 100 against clear lengths that hit the rounding up and the 32 cap, p = 0 equal to no parity, a pack/damage/repair round trip with the repair limit lowered to n / 2), 0 failures on both, and the per-file site count the harness asserts matches.
- AC-5 The Rust `ecc` probe packs with a percentage, damages bytes and repairs them on the M4F row and the `rust-m33f` row (`mps2-an505`), result 0 on both; the same bytes come out of the M4F and M33F rows.
- AC-6 A mutation of the rounding (floor instead of ceil) in the C++ computation and in the Rust one each turns its QEMU run red; the unmutated tree is green.
- AC-7 Flash and stack stay within every existing pin, or the moved figure is measured, shown, and re-pinned only with the owner's yes (concern 1); 0 images lose a heap or panic check.
- AC-8 The existing embedded stages stay green: M3, M33F and the Rust rows report the same failure count of 0 as before.
