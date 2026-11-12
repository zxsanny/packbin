#!/usr/bin/env bash
# TypeScript probe of AZ-4206 (see ../README.md). Node runs the source; nothing is built or written.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$here/probe.ts" </dev/null
