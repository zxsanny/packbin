---
loop: 121
branch: dev
source: _docs/02_task_plans/hygiene-loop121/queue_item.md
---
# Problem: eight small agent-found hygiene entries

One loop for the open hygiene item (work-queue.md §Agent-made work): eight entries found in loops 113 to 119, none above Medium, none changing a packet. Split into five tasks by package group (AZ-4257 Java, AZ-4258 Python, AZ-4259 C# and Go, AZ-4260 Dart, AZ-4261 C++), so workers own disjoint directories. The entries' own Problem, Outcome, Code sections and Acceptance checks are in `queue_item.md` and in each task spec.

## Outcome
Every entry's acceptance checks hold; no packet byte changes; each package suite passes.

## Decisions applied (OPERATOR_TODO D14, D15; reversible)
- D14 Java top-level row class: the no-argument constructor unpack already uses makes the one row the accessors are probed on.
- D15 C++ sanitizer timing: under a sanitizer build the timing checks print and do not assert.

## Constraints
No packet change; plain C++ builds keep every wall-clock bound; the shared hostile cases and every unrelated refusal text stay unchanged.
