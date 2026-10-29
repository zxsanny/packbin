#!/usr/bin/env bash
# AZ-2564, AZ-2600, AZ-2607, AZ-2625, AZ-2626 and AZ-2627: the job layout of test.yml. Exactly one job runs each part of
# the old `scaffold` job: the static checks (`scaffold`), the suites (`suites`, a matrix: each language in one entry,
# short suites sharing one, Swift as three parts with their build caches) and the publish gate (the publish-gate-* jobs,
# each running its share of the groups of publish-gate.test.sh); the embedded targets are the embedded-* jobs (each part
# of cpp/embedded/run.sh in exactly one); they run beside `ring` (no needs, no if, no continue-on-error, a timeout; the
# only step with an if is a cache step), the file makes at most 20 jobs, and a gate job pulls exactly the images its
# groups start, before the gate. The real test.yml must pass; each mutant (one per rule) must be refused.
# The rules are publish-jobs-layout.py, the mutant editor publish-jobs-mutate.py and the mutant list
# publish-jobs-mutants.test.sh (sourced below); all run with `python3 -I` and PyYAML through scripts/ci/yaml_get.py.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# jobs_layout <test.yml> [<publish-gate.test.sh>]: prints one line per violation; exit 0 when there is none.
jobs_layout() {
  python3 -I "$here/publish-jobs-layout.py" "$1" "${2:-$here/publish-gate.test.sh}"
}

# mutant <label> <python edit of the loaded workflow>: writes a changed copy of test.yml and expects a refusal. A copy
# that equals test.yml, or an edit that fails, is a failure of the mutant, not a refusal.
mutant() {
  local label="$1" edit="$2" copy
  copy="$work/$(printf '%s' "$label" | tr -c 'a-z0-9' '-').yml"
  if ! python3 -I "$here/publish-jobs-mutate.py" "$here/test.yml" "$copy" "$edit"; then
    bad "the mutant could not be built: $label"
    return
  fi
  refused "$label" "$copy" "$here/publish-gate.test.sh"
}

# gate_mutant <label> <sed script>: a changed copy of publish-gate.test.sh next to the real test.yml.
gate_mutant() {
  local label="$1" script="$2" copy
  copy="$work/gate-$(printf '%s' "$label" | tr -c 'a-z0-9' '-').sh"
  sed "$script" "$here/publish-gate.test.sh" > "$copy"
  if cmp -s "$here/publish-gate.test.sh" "$copy"; then
    bad "the mutant did not change publish-gate.test.sh: $label"
    return
  fi
  refused "$label" "$here/test.yml" "$copy"
}

refused() {
  local label="$1" workflow="$2" gate="$3" out
  if out="$(jobs_layout "$workflow" "$gate")"; then
    bad "the layout check accepted a mutant: $label"
  elif [ -z "$out" ]; then
    bad "the layout check refused a mutant without a message: $label"
  else
    echo "layout check rejects: $label"
  fi
}

# Act and assert: the real file
if out="$(jobs_layout "$here/test.yml")"; then
  echo "job layout of test.yml: ok"
else
  bad "test.yml job layout: $out"
fi

# Act and assert: one mutant per rule
# shellcheck source=publish-jobs-mutants.test.sh
source "$here/publish-jobs-mutants.test.sh"

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "job layout checks passed"
