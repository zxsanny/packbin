---
title: "A worker in the shared tree writes no git index or state and runs no formatter or linter on files it does not own"
applies_when: "writing a worker or reviewer prompt for parallel workers in the shared tree"
source: "loop 15 (AZ-2214 worker stash), loop 17 (git rm --cached), loop 20 (cargo fmt on the whole crate)"
---

## No git state commands (loop 15)

A worker in the shared tree never runs `git stash`, `git checkout`, `git reset` or `git clean`: in loop 15 the AZ-2214 worker stashed and popped once for a shellcheck baseline while three other workers were writing (the tree survived, by luck). Use `git worktree` or a tree copy under the scratchpad for baselines.

## No index writes either (loop 17)

A worker prompt forbids every index write, not only `git stash`, `checkout`, `reset` and `clean`: in loop 17 a worker ran `git rm --cached` on a deleted file (it undid it); say "no `git add`, `git rm`, `git mv`, `git restore --staged`" and check `git diff --cached` after each stage.

## No formatter or linter write on files you do not own (loop 20)

A worker prompt also says "no formatter or linter write on files you do not own": in loop 20 a Rust worker ran `cargo fmt` on the whole crate and had to restore 11 files from `git show HEAD:path`; the crate is not rustfmt-clean at HEAD and CI runs no clippy.
