---
kind: queue-item
order: 500
source: loop99 record (leftovers: owner publishes the first pub.dev version; "After it, edit the two README lines that say Dart is installed from the repository")
origin: operator
depends_on: []
status: blocked
blocked_on: OPERATOR_TODO N1 (the first `dart pub publish`)
created: 2026-11-12
---
# Dart: README install lines after the first pub.dev version

## Problem
`README.md` and `dart/README.md` say Dart is installed with `dart pub add packbin` "once the first version is published, from the repository until then". The first version is published by the owner by hand (N1). After that the two lines are wrong, and the epic AZ-4133 stays open.

## Outcome
Both READMEs name pub.dev only; the next tag run publishes Dart without the skip warning; AZ-4133 is closed.

## Code sections
`README.md` (the Dart line of the install list), `dart/README.md`, `dart/CHANGELOG.md` if the version line needs it.

## Acceptance checks
- `curl -s -o /dev/null -w '%{http_code}' https://pub.dev/api/packages/packbin` prints 200.
- Neither README says "from the repository" for Dart.
- The publish gate tests that read the README pass.

## Needs
N1 of `_docs/OPERATOR_TODO.md`.

## Constraints
No change to the publish workflow in this item.
