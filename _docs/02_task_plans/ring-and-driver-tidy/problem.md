---
loop: 83
branch: dev
---

# Ring and driver tidy (loop 83)

Source: `_docs/loops/loop82/handoff83.md` (§Candidates) and the owner's pick of three of them on 2026-10-29 ("Split handoff.cpp, Shared ring-wiring module and Ring: wrong-length key + 2nd refusal; you can parallelise if possible"). The hopper was empty. Measurements below were taken on HEAD dbf9a57 in this loop.

## Problem

Three small, independent defects in the cross-language ring and its CI wiring checks:

1. **`.github/workflows/drivers/handoff.cpp` is 639 lines**, over the 500-line cap (`quality-thresholds.md`). It holds four jobs in one file: the element rows (lines 13-300), the ECC driver (`ecc_*`, 308-406), the frame driver (`frame_*`, 408-586) and `main` (588). `ring-lib.sh:46` compiles it, with six `cpp/src/core/*.cpp`, in one command; it is the only file that names `handoff.cpp`.
2. **The two ring-wiring checkers duplicate 52 lines**: `ring-wiring-check.py` (249 lines) and `ring-wiring-swift-check.py` (200) carry 12 identical definitions (`FLAGS`, `CACHE_USES`, `SHA_PIN`, `ASCII_SPACE`, `STRING_ESCAPES`, `to_s`, `inspect`, `first_set`, `dig`, `steps_of`, `code_lines`, `runs`). `violations` and `main` differ and stay. Both already import `scripts/ci/yaml_get.py` through a `sys.path.insert`.
3. **The ring has no row that combines a wrong-length key or msg_id with a second refusal.** `fixtures/frame/ring-cases.txt` has 42 refuse rows (21 refuse-seal, 12 refuse-open, 9 refuse-mac): 12 single key/id rows (AZ-3378), 7 rows of TooLong or BufferFull alone. The reference (`scripts/frame/framefmt.py`) answers `BadValue` for a key that is not 32 bytes (`check_load`) and for a msg_id that is not 8 bytes (`_args`) before `TooLong` (`ad` over 255, body over `MAX_BODY`) and `BufferFull` (`out_len` too small). Nothing pins that order in the 6 packages that take a byte string (C#, TypeScript, Python, Java, Go, Swift). Rust (key, msg_id) and C++ (msg_id) cannot be handed the wrong-length value, so their drivers print `BadValue` by construction (README, as for directions 0 and 4): those two cannot pin the order and the rows do not claim they do.

## Change location

No UI. As the owner named them in the handoff:
- "Splitting `handoff.cpp` (639 lines, over the 500-line cap)" - `.github/workflows/drivers/handoff.cpp` and the compile line `.github/workflows/ring-lib.sh:46`.
- "One shared module for the helpers the two ring-wiring checkers duplicate (about 50 lines), next to `scripts/ci/yaml_get.py`" - `.github/workflows/ring-wiring-check.py`, `.github/workflows/ring-wiring-swift-check.py`, `scripts/ci/`.
- "A ring row that combines a wrong-length key or id with a second refusal, to pin which error comes first in the 8 drivers" - `fixtures/frame/ring-cases.txt` (and what reads it).

## Points the design must settle

- **Three tasks, disjoint write sets, one loop.** Split: `drivers/handoff*.cpp`, `ring-lib.sh`. Module: `scripts/ci/`, the two checkers. Rows: `fixtures/frame/ring-cases.txt` and the readers of the row counts. If the rows task finds it must edit a C++ driver, that edit waits for the split (same file).
- **Split seams** follow the file's own sections (rows, `ecc_*`, `frame_*`); a shared header only for what two parts really share (`parse_hex`, `hex_of`/`frame_hex`, `print`). No new abstraction.
- **Module name and path** next to `yaml_get.py`; the checkers run as `python3 -I`, so the import path is inserted as `yaml_get`'s is.
- **A row whose second refusal fires first in some package is a package finding**, not a row to drop or a driver to bend: stop and report it.

## Out of scope

The setup-python / `RING_PYTHON` fold; multi-part MAC rows (owner-declined, G8m); any change to a package's behaviour; the AVR `chacha20_xor` check; stage stamps on the Mac; every "owner input needed" line of the handoff; `all_kinds.cpp` (560 lines, `cpp/embedded/common/`, not a candidate the owner picked).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The wiring checkers are the net under the CI workflow; a refactor can silently drop a check | their mutation tests (`ring-wiring*.test.sh`) must pass unchanged, with the same label inventory | open | High |
| A package answers `TooLong` or `BufferFull` before `BadValue` for a wrong key or id | stop; report as a package defect; owner decides the fix or the reference | open | Medium |
| Rust and C++ drivers print `BadValue` for these rows by construction, so 2 of 8 languages prove nothing about order | said in the row comment and README as for dirs 0 and 4; not hidden | accepted-risk | Low |
| One C++ translation unit becomes several; a stale `$bin` can stand in for a failed build | `ring-lib.sh` compile keeps `|| return`; new sources join the one compile line | open | Medium |
| `all_kinds.cpp` is also over 500 lines | not picked by the owner; recorded for a later handoff | accepted-risk | Low |
