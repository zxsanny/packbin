---
loop: 121
branch: dev
---

# Python hygiene: missing member named, None item in a row list refused

**Task**: AZ-4258_python_hygiene
**Name**: Python hygiene: missing member named, None item in a row list refused
**Description**: entries of the hygiene queue item `_docs/02_task_plans/hygiene-loop121/queue_item.md` (loop 121), below; their text is the spec.
**Complexity**: 2 points
**Dependencies**: none
**Component**: python/ (src/packbin/_pack.py, _nodes.py, tests)
**Tracker**: AZ-4258
**Epic**: AZ-4133

Python parts only.

Each entry below: its Problem, Outcome, Code sections and Acceptance checks are this task's; an acceptance check that names another package belongs to that package's task. Common: no packet change, every refusal text of a path the entry does not name stays the same, the package suite passes.

## Entry: Java and Python: a missing required member is named by its name, not its id

slug `missing-member-message-by-name-java-python`; severity medium; source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 7); created 2026-11-12
### Problem
A row whose required `utf8 text` (id 1) is missing is refused by Java with `1: expected string` and by Python with `1: expected str`; TypeScript, Go and Swift say `missing text`. The id alone does not tell a scheme author which member is missing in a row of several.

### Outcome
Java and Python refuse a missing (null / absent) required member with a message that names the member, as TypeScript, Go and Swift do; a present value of the wrong type keeps its current message.

### Code sections
Java `VarFields.java` (the string getter), the matching paths for other kinds; Python `_pack.py` (the `expected str` check and its siblings); both packages' tests that pin the old text (grep them first).

### Acceptance checks
- Java and Python probe line `null-member` prints a refusal that contains `missing text`.
- A wrong-type value (an int for `text`) keeps its current message.
- Every test or fixture that pins the old text is updated in the same change; both suites pass.

### Needs
none

## Entry: Python: a `None` item in a list of rows is refused, not a raw `TypeError`

slug `python-null-item-in-element-row`; severity medium; source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 8); created 2026-11-12
### Problem
`bash scripts/probes/element-row/run.sh python` line `null-item`: a list of element rows that holds `None` escapes pack as `TypeError: 'NoneType' object is not subscriptable` (the element's key accessor `row[key]`, `python/src/packbin/_nodes.py`, called from `_pack_element` in `_pack.py`). TypeScript, Java, Go and Swift refuse it with their own error (Go: `items: an item has no value`).

### Outcome
Pack refuses a `None` item of a list (and a `None` value of a dict) whose element is a row with the package's own error naming the list, as it refuses other bad items; the probe line becomes `refused:`.

### Code sections
`python/src/packbin/_pack.py` (`_pack_list_items`, `_pack_dict_items`, `_pack_element`), Python tests; the probe needs no change.

### Acceptance checks
- `[c1, None]` and `{"a": None}` in an element-row list / dict: pack raises the package's `TypeError` / `ValueError` (the type the package uses for other bad items) naming the field; nothing is returned.
- A list of plain values that holds `None` behaves as today (measure first, keep it).
- The probe's `python null-item` line reads `refused:`; all other Python probe lines unchanged; the Python suite passes.

### Needs
none

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| agent-found hygiene entries; no operator decision outstanding (D14, D15 applied) | agent | accepted-risk | Low |
