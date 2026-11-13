---
title: "A new line in tool-pins.txt also goes into PINS_NAMES of publish-pins.test.sh; running that file alone tests nothing"
applies_when: "adding or renaming a tool pin in .github/workflows/tool-pins.txt"
source: "loop 122 (AZ-4278: clang==19)"
---

`.github/workflows/publish-pins.test.sh` allows exactly the names in its `PINS_NAMES` list: a pin line with any other name fails the publish gate's `pins` group with `unexpected tool: <name>` (share `readonly-full,…,pins` of step 11 and CI job `publish-gate-rest`). Add the name there in the same change.

The file is a fragment sourced by `publish-gate.test.sh` (it uses `fail`, `$here`, `$root` from there): `bash publish-pins.test.sh` alone defines functions and exits 0 without checking anything (loop 122 read that as a pass). Check a pin change with the gate: `bash scripts/loop-tests.sh --all --only publish-gate`, or `bash .github/workflows/publish-gate.test.sh --groups pins`.
