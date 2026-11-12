#!/usr/bin/env bash
# Counts the existing TypeScript schemes the candidate rule of AZ-4206 would refuse (see ../README.md).
# It copies HEAD to a temporary directory, adds a logging call to the Scheme constructor of the copy,
# runs the whole TypeScript suite (the shared hostile cases are part of it) and loads the ring drivers.
# stdout: one line per scheme the rule would refuse, then the totals. The checkout is not changed.
# Exit: 0 the count ran, 1 it could not (no node_modules, the suite failed in the copy, the constructor moved).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

if [ ! -d "$root/typescript/node_modules" ]; then
  echo "rule-count: typescript/node_modules is missing; run 'npm ci' in typescript/ first" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
copy="$work/packbin"
mkdir -p "$copy"
git -C "$root" archive HEAD | tar -x -C "$copy"
ln -s "$root/typescript/node_modules" "$copy/typescript/node_modules"
cp "$here/repeat-last-probe.ts" "$copy/typescript/src/repeat-last-probe.ts"

# The call goes after the last check of the constructor, so a scheme that does not build is never counted.
index="$copy/typescript/src/index.ts"
import_line='import { validateElementKinds } from "./element-kinds.ts"'
call_line='    validateElementKinds(this.fields)'
if [ "$(grep -c -x -F "$import_line" "$index")" -ne 1 ] || [ "$(grep -c -x -F "$call_line" "$index")" -ne 1 ]; then
  echo "rule-count: the Scheme constructor of typescript/src/index.ts no longer has the lines this script patches" >&2
  exit 1
fi
awk -v import_line="$import_line" -v call_line="$call_line" '
  { print }
  $0 == import_line { print "import { reportRepeatNotLast } from \"./repeat-last-probe.ts\"" }
  $0 == call_line { print "    reportRepeatNotLast(this.fields)" }
' "$index" > "$work/index.ts"
mv "$work/index.ts" "$index"

log="$work/rule-log.jsonl"
: > "$log"
export PACKBIN_RULE_LOG="$log"

if ! (cd "$copy/typescript" && node --test tests/*.ts </dev/null > "$work/suite.out" 2>&1); then
  echo "rule-count: the TypeScript suite failed in the copy; its last lines:" >&2
  tail -n 20 "$work/suite.out" >&2
  exit 1
fi
if ! grep -E '^# (tests|pass|fail) ' "$work/suite.out" >&2; then
  echo "rule-count: the suite output has no test summary" >&2
  exit 1
fi

# Loading a driver builds its schemes; the argument is not a command, so handoff.ts exits 2 after that.
for driver in handoff.ts position.ts; do
  status=0
  node "$copy/.github/workflows/drivers/$driver" not-a-command </dev/null > /dev/null 2> "$work/$driver.err" || status=$?
  if [ "$status" -ne 0 ] && [ "$status" -ne 2 ]; then
    echo "rule-count: driver $driver ended with $status:" >&2
    tail -n 5 "$work/$driver.err" >&2
    exit 1
  fi
done

node -e '
  const lines = require("node:fs").readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean)
  let built = 0
  let drivers = 0
  const refused = new Map()
  for (const l of lines) {
    if (l === "t" || l === "d") {
      built++
      if (l === "d") drivers++
      continue
    }
    const o = JSON.parse(l)
    const why = o.found
      .map((f) => (f.kind === "element" ? "inside a list or dict element" : "followed by " + f.followers.map((x) => x.what + (x.excused ? " (excused)" : "")).join(", ")))
      .join("; ")
    refused.set(o.file + "\u0000" + o.scheme, ["refused", o.file, o.scheme, why].join("\t"))
  }
  for (const line of refused.values()) console.log(line)
  console.log(["total", "schemes built " + built, "of them by the ring drivers " + drivers, "the rule would refuse " + refused.size].join("\t"))
' "$log"
