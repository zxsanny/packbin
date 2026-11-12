---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 8)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Python: a `None` item in a list of rows is refused, not a raw `TypeError`

## Problem
`bash scripts/probes/element-row/run.sh python` line `null-item`: a list of element rows that holds `None` escapes pack as `TypeError: 'NoneType' object is not subscriptable` (the element's key accessor `row[key]`, `python/src/packbin/_nodes.py`, called from `_pack_element` in `_pack.py`). TypeScript, Java, Go and Swift refuse it with their own error (Go: `items: an item has no value`).

## Outcome
Pack refuses a `None` item of a list (and a `None` value of a dict) whose element is a row with the package's own error naming the list, as it refuses other bad items; the probe line becomes `refused:`.

## Code sections
`python/src/packbin/_pack.py` (`_pack_list_items`, `_pack_dict_items`, `_pack_element`), Python tests; the probe needs no change.

## Acceptance checks
- `[c1, None]` and `{"a": None}` in an element-row list / dict: pack raises the package's `TypeError` / `ValueError` (the type the package uses for other bad items) naming the field; nothing is returned.
- A list of plain values that holds `None` behaves as today (measure first, keep it).
- The probe's `python null-item` line reads `refused:`; all other Python probe lines unchanged; the Python suite passes.

## Needs
none
