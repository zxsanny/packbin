---
loop: 122
branch: dev
source: _docs/02_task_plans/hygiene-loop122/queue_item.md
---
# Problem: two small agent-found hygiene entries

One loop for the open hygiene item (work-queue.md §Agent-made work): two entries found in loop 121, none above Medium, none changing a packet. It runs now because nothing else in the queue is ready. Two tasks, one per entry, on disjoint paths: AZ-4277 Dart (the repeat-last cost test that failed once in the pool), AZ-4278 C++ (a CI job for the sanitizer build). The entries' own Problem, Outcome, Code sections and Acceptance checks are in `queue_item.md` and in each task spec.

## Outcome
Every entry's acceptance checks hold; no packet byte changes; each package suite passes; the new CI job passes on `dev`.

## Decisions applied (OPERATOR_TODO D17; reversible)
- D17 the clang of the sanitizer job: Debian's `clang-19` package installed in the `gcc:16` image the C++ suite already uses (a compose service), major version pinned in `tool-pins.txt`; not the runner's own clang, which changes with `ubuntu-latest`.

## Constraints
No packet change; the plain C++ builds and every other CI job stay as they are; the nominal Dart bound stays 300 ms.
