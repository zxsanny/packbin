---
title: "Run make -C cpp clean when switching cpp/build between the host and a container, and clean inside the container, not on the host right before it starts"
applies_when: "switching between host make -C cpp and the gcc:16 container or a compose stage, or deleting a bind-mounted path before a container start"
source: "loop 18 (shared cpp/build), loop 28 (AZ-2565, cpp stage failed 6 of 12 runs), loop 74 (a smoke step on host make after a container stage)"
---

## cpp/build is shared (loops 18, 74)

`cpp/build/` is shared by the host `make` (Mach-O) and the `gcc:16` container (ELF): a binary built by one cannot run in the other (`Syntax error: "(" unexpected` or `cannot execute binary file`). Run `make -C cpp clean` before switching between them.

Host `make -C cpp test` after a container stage fails on the ELF objects it left in the shared `cpp/build`: run `make -C cpp clean` first (a smoke step did not and failed on it; the clean right before a *container* start is the other trap, below).

## Never delete a bind-mounted path on the host right before a container starts (loop 28)

Never delete a bind-mounted path on the host right before a container starts on it: on Docker Desktop the container still sees the old entries for about a second after a host `rm -rf` (loop 28, AZ-2565: the `cpp` stage failed 6 of 12 runs, alone, with `make -C cpp clean` on the host then `docker compose run`); clean inside the container, as `scripts/loop-tests.sh` does for `cpp`.
