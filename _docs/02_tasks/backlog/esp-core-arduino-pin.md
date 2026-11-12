---
kind: queue-item
order: 500
source: found in loop113 (AZ-4219 report: "the ESP stage installs the newest Arduino-ESP32 core, 3.3.12 today, unpinned; 525 s")
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# C++: pin the Arduino-ESP32 core of the ESP core stage

## Problem
`bash cpp/embedded/run.sh host esp core` installs the newest Arduino-ESP32 core at run time (3.3.12 on 2026-11-12) and took 525 s on this host in loop 113 (about 3 minutes expected). A new core release can change the build or the time with no change in this repository, and the CI job `embedded-esp-core` has the same exposure.

## Outcome
The core version is pinned in one place that both the Mac run and the CI job read, with a line in `_docs/AGENT_GOTCHAS.md` saying how to move it.

## Code sections
`cpp/embedded/esp.sh`, `cpp/embedded/run.sh`, the Docker image or the PlatformIO / arduino-cli configuration it uses, `.github/workflows/test.yml` job `embedded-esp-core`, `cpp/embedded/*.test.sh`.

## Acceptance checks
- The stage prints the core version it uses and fails if it differs from the pin.
- `bash cpp/embedded/run.sh host esp core` passes with the pinned core; the stub tests of `lib.test.sh` and `run-parts.test.sh` pass.
- The pin and its date are recorded where the other tool pins are (`.github/workflows/tool-pin.sh` if the project keeps tool pins there).

## Needs
none

## Constraints
The source count of the stage (`expected N packbin sources`) does not change.
