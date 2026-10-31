# Loop 96 smoke — proposed checks

LOCAL_URL: none (no UI, no local deploy script; the ring builds and starts its eight drivers itself)
Branch: dev

## Perform these checks (shell, repository root)

- [ ] `bash .github/workflows/ring-frame.sh` prints `ring-frame: 30 mac rows and 11 refusal rows`, `ring-frame: 30 verify rows for each of 8 writers, and 7 refusal rows`, 64 `pair ... 56 rows, 0 mismatched` lines, `refusals <lang>: 76 rows, 0 mismatched` for 8 languages, and ends `ring-frame: 64 pairs, mismatched: 0` (AC-3)
- [ ] `bash .github/workflows/ring-frame-drivers.test.sh` ends `all passed (8 languages, 340 checks)` (AC-4)
- [ ] `bash .github/workflows/ring-frame.test.sh` ends `ring-frame.test: all passed`, and its output shows `PASS mac-first-piece-only` and `PASS mac-stops-at-empty-piece` (AC-5)
- [ ] in `.github/workflows/drivers/handoff-go/frame.go` change `mk.Tag(tag, parts...)` to `mk.Tag(tag, parts[0])`, run `RING_FRAME_LANGS="python go" bash .github/workflows/ring-frame.sh`: it exits 1 and names `go: P.two mac gave ...` (AC-5); put the line back afterwards
- [ ] `fixtures/frame/ring-cases.txt` differs from loop 95 only by added rows and two header lines: `git diff 98d2202 -- fixtures/frame/ring-cases.txt | grep '^-' ` shows only the `---` line (AC-6)
- [ ] `fixtures/frame/README.md` gives the field format (pieces joined by `|`, `-` empty) and says a joining driver cannot be found (AC-7)

## Notes
No credentials involved. Do not run these while another session runs the publish gate (it fails when the tree changes).

## Agent walk
Checks 1 to 4 observed in this loop: ring 30 s, 0 mismatched; drivers test 340 checks 0 failed; self-test 45 passed; Go `parts[0]` mutation red with 18 mismatches naming `P.two`, `P.first0`, `P.mid0`, `P.split56`, `P.split64` (file restored, compared with a copy). Checks 5 and 6 read from the commit.
