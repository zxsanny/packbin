# Feature assessment — loop 75

Tasks: AZ-3292 (C++), AZ-3293 (Go), AZ-3294 (Python), AZ-3295 (TypeScript). Commit assessed: 99b7dec (base 88cbb2b).
Assessed by an independent read-only agent from the four specs, the contract (3.0.0), the C# reference and the code.

## Round 1: EXTEND (4 gap-clear, all Low; 0 gap-unclear)

All 24 acceptance criteria (AC-1..AC-6 for each package) are met. AC-6 (suite green) was only partly run by the assessor (no Go, no pytest, no gcc:16 there); the parent re-ran TypeScript (2,533), Python (3,887), Go (`-race`), C++ host and `gcc:16` before the commit, and step 11 runs the total.

| AC | C++ | Go | Python | TypeScript |
|----|-----|----|--------|------------|
| AC-1 frame rows 157 of 157 | met | met | met | met |
| AC-2 crypto rows 27 of 27 | met | met | met | met |
| AC-3 open order and state (4 tests) | met | met | met | met |
| AC-4 D1 names | met | met | met | met |
| AC-5 README example | met | met | met | met |
| AC-6 suite green | met (parent run) | met (parent run) | met (parent run) | met |

Gaps (fixed in the same loop, round 1 fix batch):
1. Python: a negative counter with a window raised `ValueError` where the docstring says `BadValue`.
2. C++: no named test of the tag compare (Go, Python and TypeScript have one).
3. Go: the AC-1 row count was a lower bound (`< 157`), now `!= 157`.
4. Spec bookkeeping: the four Flagged-concerns rows said the plan names the mechanism; the mechanisms are in the component descriptions and doc comments (C++ const reads, Go `RWMutex`, Python and TypeScript the caller's duty); rows closed.

Noted, not gaps (documented differences): C++ `open` reads `body` twice (tag, then decrypt), where C#, Go, Python and TypeScript copy the frame first; C++ `seal` requires `ad`, `clear` and `plain` not to overlap `out`; the C++ default `MsgContext` (all-zero id) is valid because the struct is POD.

Owner decision left open: whether C++ `open` copies the body (255 B of stack, about 255 B on the `cpp-m33f` frame pin of 912 B) so a receive ring written by an ISR or DMA cannot change between the tag check and the decrypt. Loop 75 keeps the documented requirement.
