---
loop: 80
branch: dev
---

# Frame ring: name the row when the reference refuses a seal or mac row (AZ-3369)

Short loop (owner, 2026-10-28: "accept all recommended"; D5 of `handoff80.md`). Probed on HEAD 69b02b8.

## What and why

`scripts/frame/ring_frame.py` loads the rows of `fixtures/frame/ring-cases.txt` and checks each against the reference codec (`scripts/frame/framefmt.py`) before any driver result is read. The `open`, `verify` and `refuse-*` rows catch `ff.Fault` and name the row. The `seal` row (`ff.seal`, line 131) and the `mac` row (`ff.mac_tag`, line 140) do not: a row the reference refuses ends the script with a Python traceback and exit 1 that does not say which row it was. The reader of a red ring step has to find the row by the line number inside the traceback.

Probe on HEAD 69b02b8 (python 3.14.8): a copy of the cases file with `seal E1` kind 4 changed to 16 gives `framefmt.Fault: BadValue` from `_args`, line 83, and a copy with `mac E4` n 4 changed to 5 gives `framefmt.Fault: BadValue` from `mac_tag`, line 180. Neither names the file, the line or the case.

## Code sections / UI locations for this loop

- `scripts/frame/ring_frame.py`, `Rows._add`: the `seal` branch (line 131) and the `mac` branch (line 140). No UI.
- `.github/workflows/ring-frame.test.sh`: two new cases after `refuse-mac-name-changed` (the `corrupt` helper, line 199 on).

## Acceptance criteria

- AC-1: a `seal` row the reference refuses (`seal E1` with kind 16): `ring-frame.sh` exits 1 and prints `<file>:<line>: E1 the reference refuses the row: BadValue`; the output holds no `Traceback`.
- AC-2: a `mac` row the reference refuses (`mac E4` with n 5): exit 1 and `<file>:<line>: E4 the reference refuses the row: BadValue`; no `Traceback`.
- AC-3: the real rows are unchanged: `ring-frame.test.sh` 34 PASS and 0 FAIL (32 on HEAD, plus the two new cases); `ring-frame.sh` against the 8 real drivers prints `ring-frame: 64 pairs, ... mismatched: 0` and `refusals <lang>: 43 rows, 0 mismatched` for 8 languages.
- AC-4: both new cases fail on HEAD (the script without the two catches), each with the traceback in its output.

- AC-5 (found in this loop; follows from tracking `_docs/_autodev_state.md`): `scripts/loop-tests.sh` writes a stage stamp when the only dirty path is `_docs/_autodev_state.md` (tracked and rewritten at every step), and still writes none when any other path is dirty. `loop-tests.test.sh` has the case and fails on the loop-start script (probed in a scratch copy: `FAIL: execution: the autodev position file blocked the stamp`). Before it, `git status --porcelain` was never empty during a loop once the file was tracked, so step 11 stamped nothing and the next plan ran every stage.

Out of scope: multi-part MAC rows, key and message-id length refusals, the 8 drivers (no driver changes), the wording of any other message.

## Expected input and output

| Row change in a copy of `ring-cases.txt` | `RING_FRAME_CASES=<copy> ring-frame.sh` |
|---|---|
| `seal E1 ... 00301005e8030000 4 ...` becomes `... 00301005e8030000 16 ...` | exit 1, `ring-frame: the row files disagree with the reference codec: <copy>:17: E1 the reference refuses the row: BadValue` |
| `mac E4 ... 6e6574 4 ...` becomes `... 6e6574 5 ...` | exit 1, `... <copy>:41: E4 the reference refuses the row: BadValue` |

## Flagged concerns

None.
