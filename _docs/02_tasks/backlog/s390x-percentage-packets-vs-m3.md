---
kind: queue-item
order: 500
source: loop98 record (leftovers: "the s390x stage does not compare its percentage packets with the M3 file"); `cpp/embedded/arm.sh` `target_s390x`
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# C++ big-endian row: compare the percentage packets with the Cortex-M3 file

## Problem
The `cpp-m33f` row compares its `PERCENT_HEX` packets (parity percentage, loop 97) with `m3-percent.hex` written by `cpp-m3-qemu`. The big-endian `cpp-s390x` row compares only the all-kinds packet with `m3-all-kinds.hex`; its percentage packets are printed and not compared.

## Outcome
The s390x row fails when a percentage packet differs from the Cortex-M3 bytes.

## Code sections
`cpp/embedded/arm.sh` (`target_s390x`, `percent_packets`), `cpp/embedded/lib.test.sh`, `cpp/embedded/run-parts.test.sh`.

## Acceptance checks
- `target_s390x` writes its percentage packets with `percent_packets` and compares them with `m3-percent.hex`, as `target_m33f` does; a missing M3 file is reported the way the all-kinds check reports it.
- The stub tests of `lib.test.sh` cover the equal and the differing case.
- `docker compose -f docker-compose.test.yml run --rm cpp-embedded` passes.

## Needs
none

## Constraints
No pin and no core source changes.
