---
title: "Install typescript/node_modules with npm ci after a cd, never npm ci --prefix"
applies_when: "publish-position.sh typescript or ring-prepare.sh installing typescript/node_modules"
source: "2026-10-06, loop 16 (AZ-2230 assessment gaps; the bullet names no loop, taken from git history)"
---

`publish-position.sh typescript` without `typescript/node_modules` runs `npm ci` after a `cd`, because `npm ci --prefix` refuses the lock file (`Missing: ... from lock file`) when the path holds a symlink, and macOS temp dirs always do; `publish-position.test.sh` guards it with a symlinked temp path. `.github/workflows/ring-prepare.sh` follows the same rule.
