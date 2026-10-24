---
loop: 66
branch: dev
---

# Publish gate under load: two checks that fail only when the host is busy (loop 66)

Source: `_docs/loops/loop65/handoff66.md` (candidate "Publish gate under load") and `AGENT_GOTCHAS.md` (loop 65 entry). The hopper was empty; on 2026-10-24 the owner chose this candidate from a three-way question (the option text named both files below).

## Problem

In loop 65 the full `scripts/loop-tests.sh` publish gate (8 shares at once, host load 9 to 22) failed on two checks that each passed alone:

1. **`publish-go.test.sh` AC-3** (`.github/workflows/publish-go.test.sh:185`): `gt_publish never GT_GO_FAILS=999 PACKBIN_GO_PROXY_WINDOW=3` then `[ "$(gt_go_calls)" -ge 2 ]` failed with "the proxy was asked once only: 1" in two of two parallel runs. Cause read from `publish-go.sh` `proxy_check` (lines 98-128): `deadline=$((SECONDS + window))` is set before the loop and the loop breaks after an attempt when `SECONDS >= deadline`. With a 3 s window and `PACKBIN_GO_PROXY_PAUSE=0`, one attempt (the `go` stub plus `python3 -I`) that takes 3 s or more on a loaded host ends the loop after one ask. The test bound is a wall-clock time in a script that wants "at least two asks".
2. **`publish-phases-failures.test.sh` AZ-2096 AC-4** (`ph_pipeline_violations`, line 143 on): the real pipeline for `python` returned 1 in one run because `python3 -m pip install --quiet --only-binary=:all: "build==$build_pin"` (`publish-inside.sh:75`) failed inside the container; the log did not keep pip's own error, so the cause (network, index, load) is unknown.

Both are test or test-support defects found under load; neither is a product defect so far. The second may turn out to be a product-side transient (pip fetching from an index) that a real publish also meets; that is a flagged concern, not assumed.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-24 (option text named the files). No UI.

| Work | Place |
|------|-------|
| 1: Go proxy window | `.github/workflows/publish-go.test.sh` (AC-3, line 185; helper `gt_publish` line 106), `.github/workflows/publish-go.sh` (`proxy_check`, read only unless the loop is shown to need a change) |
| 2: container pip install | `.github/workflows/publish-phases-failures.test.sh` (AZ-2096 AC-4, `ph_pipeline_violations`), `.github/workflows/publish-inside.sh` (line 75), `.github/workflows/publish-build.sh` (`run_inside`), `publish-lib.sh` (`publish_container`) |
| Gate proof | `.github/workflows/publish-gate.test.sh --groups go` (28 s) and `--groups phases` (325 s), `scripts/loop-tests.sh` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The pip failure's cause is unknown; a retry in `publish-inside.sh` would change the real publish path | keep the pip error first; add a retry only if the kept error is a transient network one, and say so to the owner | open | Medium |
| The Go check could be loosened until it proves nothing | the check must still fail on a copy of `proxy_check` that stops after one try (broken copy run) | open | Medium |
| Reproducing load takes host time (phases share 325 s alone) | inject the delay (a slow `go` stub), do not rely on a busy host | open | Low |
| First `v*` and `go/v*` tags, F44, CS-D5, U24 | owner decides separately | accepted-risk | Low |
