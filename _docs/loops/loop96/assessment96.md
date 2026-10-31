# Feature assessment - loop 96

FEATURE ASSESSMENT loop 96 round 1: COMPLETE - 10 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

Intent: owner picked "multi-part MAC rows in the ring" for loop 96 (the opt-in G8m of loop 77 waited for): the ring sends the MAC-only message in pieces, so the eight languages are compared on that path. Baseline: `_docs/02_task_plans/ring-multipart-mac-rows/` (`problem.md`, `acceptance_criteria.md`, `scenarios.md`), spec `_docs/02_tasks/done/AZ-3495_ring_multipart_mac_rows.md`, batch report `_docs/03_implementation/batch_01_loop96_report.md`.

| id | status | AC | test | code path |
|----|--------|----|------|-----------|
| M1 pieces, tag lengths 4, 8, 16, 32 | covered | AC-1, AC-3 | real ring: 64 pairs x 56 rows, 0 mismatched (`P.two`, `P.n8`, `P.n16`, `P.n32`) | `partsOf` / `parts` in the 8 drivers, `unhex_parts` in `ring_frame.py` |
| M2 single-piece line as before | covered | AC-6 | the 45 old rows per pair still match; old self-test cases pass | same helpers, a one-piece field |
| M3 empty piece first, middle, last, all | covered | AC-1 | `P.first0`, `P.mid0`, `P.last0`, `P.all0`; `P.all0` equals `msg0` | same |
| M4 cuts at the hash block edges, 255 bytes in four pieces | covered | AC-1 | `P.split56`, `P.split64`, `P.n32` | same |
| M5 verify over pieces, bit flip and wrong order | covered | AC-2 | `P.v.bit`, `P.v.order` answer `invalid` in all 8 | `verify` in the 8 drivers |
| M6 refusals with pieces | covered | AC-2 | `R.mac.p.nbad5`, `R.mac.p.label0` answer `BadValue` | `mac` in the 8 drivers |
| M7 bad or empty piece is a malformed line | covered | AC-4 | `ring-frame-drivers.test.sh`: 5 refused lines x 8 languages | piece check in each driver |
| M8 a driver that mishandles pieces turns the ring red | covered | AC-5 | `ring-frame.test.sh` four stand-ins; Go `parts[0]` mutation: 18 mismatches naming `P.two`, `P.mid0` | `check` in `ring_frame.py` |
| D1 join or drop-empty drivers give the same tag | covered | AC-5 (wording corrected) | README and AC-5 say no row can tell it | - |
| D2 empty hex string was accepted before | covered | AC-4 | `piece-empty-*` cases, 8 languages | empty-piece check before each hex reader |
| O1 zero pieces (an empty list) | out-of-scope | - | `scenarios.md` O1: one empty piece is `-`, row `msg0` | - |
| O2 `ring-ecc` and the packages' own tests | out-of-scope | - | `scenarios.md` O2 | - |

No `Discovered during implementation` row is unclear (batch report rows 1 and 2, both clear). `scenarios.md` unchanged.
