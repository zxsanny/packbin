#!/usr/bin/env bash
# Wiring check for the cross-language ring (AZ-2193 AC-1, AC-6): test.yml must run language-pair.sh from a job that runs
# on every push (except one that touches only _docs/) and pull request, as its own check, and that a failing ring fails. ring-wiring-check.py
# parses the workflow with the shared reader (scripts/ci/yaml_get.py), then runs the same check against copies of test.yml
# that each break one rule: every copy must be rejected (exit status 1, not a reader failure). The checks of language-pair.sh itself (PATH shims, the C# element rings, the Go ring) are in
# ring-wiring-rows.test.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ring-wiring-lib.sh
source "$here/ring-wiring-lib.sh" # tmp, failures, fail
test_yml="$here/test.yml"
compose_yml="$here/../../docker-compose.test.yml"

# Prints the violations of workflow file $1, checked against the suite images in compose file $2 (default: the real
# one); exit status 1 when there are any, 2 when a file cannot be read.
ring_wiring() {
  python3 -I "$here/ring-wiring-check.py" "$1" "${2:-$compose_yml}"
}

# expect_rejected <label> <copy of test.yml> [<copy of the compose file>]: a copy differs from the real
# file and the check rejects the pair.
expect_rejected() {
  local label="$1" copy="$2" compose="${3:-$compose_yml}" out status=0
  if cmp -s "$test_yml" "$copy" && cmp -s "$compose_yml" "$compose"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  out="$(ring_wiring "$copy" "$compose")" || status=$?
  if [ "$status" -eq 0 ]; then
    fail "the wiring check passed a violating copy: $label"
  elif [ "$status" -eq 1 ]; then
    echo "rejects: $label ($out)"
  else
    fail "the wiring check failed with status $status, not a rejection: $label ($out)"
  fi
}

# expect_accepted <label> <copy of test.yml>: the copy differs from the real file and is still accepted.
expect_accepted() {
  local label="$1" copy="$2" out
  if cmp -s "$test_yml" "$copy"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  if out="$(ring_wiring "$copy")"; then
    echo "accepts: $label"
  else
    fail "the wiring check rejected a harmless copy: $label ($out)"
  fi
}

# insert_after <line regex> <new line>: test.yml with <new line> after every matching line.
insert_after() {
  awk -v re="$1" -v add="$2" '{ print } $0 ~ re { print add }' "$test_yml"
}

# replace_line <line regex> <new text>: test.yml with every matching line replaced.
replace_line() {
  awk -v re="$1" -v add="$2" '$0 ~ re { print add; next } { print }' "$test_yml"
}

# drop_step <name>: test.yml without the step "- name: <name>" and its one-line run.
drop_step() {
  awk -v head="      - name: $1" '$0 == head { skip = 1; next } skip { skip = 0; next } { print }' "$test_yml"
}

if ! out="$(ring_wiring "$test_yml")"; then
  fail "test.yml: $out"
else
  sed '/language-pair\.sh/d' "$test_yml" > "$tmp/call-removed.yml"
  sed 's#language-pair\.sh#language-pairs.sh#' "$test_yml" > "$tmp/call-renamed.yml"
  sed 's|run: bash \.github/workflows/language-pair\.sh|run: echo skipped # bash .github/workflows/language-pair.sh|' \
    "$test_yml" > "$tmp/call-commented.yml"
  sed 's#language-pair\.sh$#language-pair.sh || true#' "$test_yml" > "$tmp/call-or-true.yml"
  insert_after '^  push:$' '    paths: ["csharp/**"]' > "$tmp/push-paths.yml"
  sed 's#^    paths-ignore: \["_docs/\*\*"\]$#    paths-ignore: ["_docs/**", "cpp/**"]#' "$test_yml" > "$tmp/push-ignores-cpp.yml"
  sed '/^    paths-ignore: \["_docs\/\*\*"\]$/d' "$test_yml" > "$tmp/push-no-ignore.yml"
  insert_after '^  pull_request:$' '    branches: [main]' > "$tmp/pr-branches.yml"
  insert_after '^  pull_request:$' '    paths-ignore: ["**.md"]' > "$tmp/pr-paths-ignore.yml"
  insert_after '^  pull_request:$' '    types: [opened]' > "$tmp/pr-types.yml"
  sed 's#^    branches: \["\*\*"\]$#    branches: ["main"]#' "$test_yml" > "$tmp/push-main-only.yml"
  insert_after '^  ring:$' "    if: github.ref == 'refs/heads/main'" > "$tmp/job-if.yml"
  insert_after '^  ring:$' '    needs: scaffold' > "$tmp/job-needs.yml"
  insert_after '^  ring:$' '    continue-on-error: true' > "$tmp/job-continue.yml"
  insert_after '^      - name: cross-language ring$' "        if: github.ref == 'refs/heads/main'" > "$tmp/step-if.yml"
  insert_after '^      - name: toolchain versions$' '        continue-on-error: true' > "$tmp/step-continue.yml"
  sed '/^      CXX: /d' "$test_yml" > "$tmp/cxx-removed.yml"
  sed 's#^      CXX: .*#      CXX: g++#' "$test_yml" > "$tmp/cxx-runner-gcc.yml"
  insert_after '^      - name: cross-language ring$' '        env:\n          CXX: g++' > "$tmp/cxx-step-override.yml"
  sed 's#RING_NODE: "24"#RING_NODE: "25"#' "$test_yml" > "$tmp/env-node-bumped.yml"
  sed 's#RING_PYTHON: "3.14"#RING_PYTHON: "3.13"#' "$test_yml" > "$tmp/env-python-bumped.yml"
  sed '/^  scaffold:$/,$ s#python-version: ${{ env.RING_PYTHON }}#python-version: "3.14"#' "$test_yml" > "$tmp/python-hardcoded.yml"
  insert_after '^  scaffold:$' '    env:\n      RING_PYTHON: "3.12"' > "$tmp/python-job-env.yml"
  sed '/^      RING_JDK: /d' "$test_yml" > "$tmp/env-jdk-removed.yml"
  sed 's#node-version: ${{ env.RING_NODE }}#node-version: 22#' "$test_yml" > "$tmp/node-hardcoded.yml"
  sed 's#image: gcc:16#image: gcc:17#' "$compose_yml" > "$tmp/compose-gcc-bumped.yml"
  sed 's#image: golang:1.27#image: golang:1.28#' "$compose_yml" > "$tmp/compose-go-bumped.yml"
  sed 's#RING_GO: "1.27"#RING_GO: "1.28"#' "$test_yml" > "$tmp/env-go-bumped.yml"
  sed '/^      RING_GO: /d' "$test_yml" > "$tmp/env-go-removed.yml"
  sed 's#go-version: ${{ env.RING_GO }}#go-version: 1.26#' "$test_yml" > "$tmp/go-hardcoded.yml"
  sed 's#\(actions/setup-go@\)[0-9a-f]\{40\}.*#\1v7.0.0#' "$test_yml" > "$tmp/go-tag-pinned.yml"
  awk '/^      - uses: actions\/setup-go@/ { skip = 1; next } skip && /^        / { next } { skip = 0; print }' \
    "$test_yml" > "$tmp/no-setup-go.yml"
  sed '/ring-prepare\.sh build /d' "$test_yml" > "$tmp/no-go-build.yml"
  insert_after '^        run: bash \.github/workflows/ring-toolchains\.sh$' \
    '      - name: ring script lint\n        run: |\n          bash -n .github/workflows/language-pair.sh\n          shellcheck .github/workflows/language-pair.sh' \
    > "$tmp/call-mentioned.yml"
  replace_line '^        run: bash \.github/workflows/language-pair\.sh$' \
    '        run: |\n          if false; then\n            bash .github/workflows/language-pair.sh\n          fi' > "$tmp/call-in-if-block.yml"
  replace_line '^        run: bash \.github/workflows/language-pair\.sh$' \
    '        run: if false; then bash .github/workflows/language-pair.sh; fi' > "$tmp/call-in-if-line.yml"
  drop_step "toolchain versions" > "$tmp/no-toolchains.yml"
  insert_after '^      - name: toolchain versions$' "        if: github.ref == 'refs/heads/main'" > "$tmp/toolchains-if.yml"
  insert_after '^      - uses: actions/setup-node@' "        if: github.ref == 'refs/heads/main'" > "$tmp/setup-if.yml"
  drop_step "cross-language ring wiring" > "$tmp/no-wiring-step.yml"
  drop_step "cross-language ring row wiring" > "$tmp/no-rows-step.yml"
  drop_step "embedded harness" > "$tmp/no-harness-step.yml"
  drop_step "CI YAML reader" > "$tmp/no-yaml-reader-step.yml"
  drop_step "CI workflow helpers" > "$tmp/no-workflow-helpers-step.yml"
  expect_accepted "a step that only lints or syntax-checks language-pair.sh" "$tmp/call-mentioned.yml"
  expect_rejected "call under if false in a run block" "$tmp/call-in-if-block.yml"
  expect_rejected "call under if false on one line" "$tmp/call-in-if-line.yml"
  expect_rejected "ring-toolchains.sh not run by the ring job" "$tmp/no-toolchains.yml"
  expect_rejected "if condition on the toolchain versions step" "$tmp/toolchains-if.yml"
  expect_rejected "if condition on a setup step" "$tmp/setup-if.yml"
  expect_rejected "scaffold without the ring wiring step" "$tmp/no-wiring-step.yml"
  expect_rejected "scaffold without the ring row wiring step" "$tmp/no-rows-step.yml"
  expect_rejected "scaffold without the embedded harness step" "$tmp/no-harness-step.yml"
  expect_rejected "scaffold without the CI YAML reader step" "$tmp/no-yaml-reader-step.yml"
  expect_rejected "scaffold without the CI workflow helpers step" "$tmp/no-workflow-helpers-step.yml"
  expect_rejected "RING_NODE differs from the typescript suite image" "$tmp/env-node-bumped.yml"
  expect_rejected "RING_PYTHON differs from the python suite image" "$tmp/env-python-bumped.yml"
  expect_rejected "python-version in scaffold is a literal, not RING_PYTHON" "$tmp/python-hardcoded.yml"
  expect_rejected "RING_PYTHON set in the env of scaffold" "$tmp/python-job-env.yml"
  expect_rejected "RING_JDK removed" "$tmp/env-jdk-removed.yml"
  expect_rejected "node-version no longer comes from RING_NODE" "$tmp/node-hardcoded.yml"
  expect_rejected "the cpp suite image moved to gcc:17" "$test_yml" "$tmp/compose-gcc-bumped.yml"
  expect_rejected "RING_GO differs from the go suite image" "$tmp/env-go-bumped.yml"
  expect_rejected "RING_GO removed" "$tmp/env-go-removed.yml"
  expect_rejected "go-version no longer comes from RING_GO" "$tmp/go-hardcoded.yml"
  expect_rejected "setup-go pinned to a tag, not a commit" "$tmp/go-tag-pinned.yml"
  expect_rejected "no setup-go step" "$tmp/no-setup-go.yml"
  expect_rejected "the Go driver is not built" "$tmp/no-go-build.yml"
  expect_rejected "the go suite image moved to golang:1.28" "$test_yml" "$tmp/compose-go-bumped.yml"
  expect_rejected "call removed" "$tmp/call-removed.yml"
  expect_rejected "call renamed" "$tmp/call-renamed.yml"
  expect_rejected "call turned into a comment" "$tmp/call-commented.yml"
  expect_rejected "call followed by || true" "$tmp/call-or-true.yml"
  expect_rejected "path filter on push" "$tmp/push-paths.yml"
  expect_rejected "push without the _docs paths-ignore (the file before loop 65)" "$tmp/push-no-ignore.yml"
  expect_rejected "paths-ignore on push beyond _docs" "$tmp/push-ignores-cpp.yml"
  expect_rejected "push limited to one branch" "$tmp/push-main-only.yml"
  expect_rejected "branch filter on pull_request" "$tmp/pr-branches.yml"
  expect_rejected "paths-ignore on pull_request" "$tmp/pr-paths-ignore.yml"
  expect_rejected "types filter on pull_request" "$tmp/pr-types.yml"
  expect_rejected "if condition on the job" "$tmp/job-if.yml"
  expect_rejected "needs on the job" "$tmp/job-needs.yml"
  expect_rejected "continue-on-error on the job" "$tmp/job-continue.yml"
  expect_rejected "if condition on the ring step" "$tmp/step-if.yml"
  expect_rejected "continue-on-error on a toolchain step" "$tmp/step-continue.yml"
  expect_rejected "CXX removed" "$tmp/cxx-removed.yml"
  expect_rejected "CXX is the runner's g++" "$tmp/cxx-runner-gcc.yml"
  expect_rejected "the ring step overrides CXX" "$tmp/cxx-step-override.yml"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "ring wiring checks passed"
