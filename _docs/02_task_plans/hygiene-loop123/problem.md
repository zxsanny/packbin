---
loop: 123
branch: dev
source: _docs/02_task_plans/hygiene-loop123/queue_item.md
---
# Problem: two Low entries left by loop 122

One loop for the hygiene item (work-queue.md §Agent-made work), run because nothing else in the queue is ready; agent-made loop 3 of 3 in a row, so the queue stops for agent-made work after it. AZ-4279: a group of 255+ members does not compile with upstream clang (fold nesting limit). AZ-4280: a failed clang install in the cpp suite should say what to change. The retrospective of loops 119 to 123 is due in this loop.

## Outcome
Both entries' acceptance checks hold; no packet byte, flash or stack figure changes; each suite passes.

## Constraints
The C++ change is compile-time only: the `cpp-m33f` pins and the embedded rows stay as they are.
