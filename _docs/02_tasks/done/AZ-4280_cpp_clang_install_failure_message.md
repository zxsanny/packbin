---
loop: 123
branch: dev
---

# CI: a failed clang install in the cpp suite names the pin and the image's Debian release

**Task**: AZ-4280_cpp_clang_install_failure_message
**Description**: entry `cpp-sanitizer-clang-base` of `_docs/02_task_plans/hygiene-loop123/queue_item.md`; its text is the spec.
**Complexity**: 1 point
**Dependencies**: none
**Component**: .github/workflows/
**Tracker**: AZ-4280
**Epic**: AZ-4133

## Problem
`run-suite.sh cpp` installs Debian `clang-<major>` in `gcc:16`, whose tag floats. A rebuild on a Debian without that package fails with apt's `Unable to locate package` and nothing about what to change.

## Acceptance checks
- AC-1: when the install fails, the suite prints one line naming the `clang==<major>` line of `.github/workflows/tool-pins.txt` and the image's `/etc/debian_version`, and fails.
- AC-2: `run-suite.test.sh` covers it with a fake `apt-get` that fails (and the line is absent when the install passes).

## Constraints
No change to the install itself.
