#!/usr/bin/env bash
# The structure of publish.yml and test.yml (AZ-2095) and the tag-run flow (precheck, test, publish).
# The checker and the `if:` evaluator are publish-workflow-structure.py (AZ-3383), which reads the YAML through
# scripts/ci/yaml_get.py. Sourced by publish-gate.test.sh, which defines fail, $root and $here.

# shellcheck disable=SC2154,SC2016
# workflow_structure <test.yml> <publish.yml>: one line per error on stdout; exit 0 none, 1 errors, 2 YAML unreadable.
workflow_structure() {
  python3 -I "$here/publish-workflow-structure.py" "$1" "$2"
}

# expect_structure_failure <label> <test.yml> <publish.yml> [text]: exit 1 (errors found), not 2 (YAML unreadable);
# with text, the output must name it.
expect_structure_failure() {
  local label="$1" test_yml="$2" publish_yml="$3" want="${4:-}" out code=0
  out="$(workflow_structure "$test_yml" "$publish_yml")" || code=$?
  if [ "$code" -eq 0 ]; then
    fail "AZ-2095 structure check passed a violating copy: $label"
  elif [ "$code" -ne 1 ]; then
    fail "AZ-2095 structure check exited $code, not a check result: $label ($out)"
  elif [ -n "$want" ] && [[ "$out" != *"$want"* ]]; then
    fail "AZ-3383 structure check did not name [$want]: $label ($out)"
  else
    echo "structure check rejects: $label ($out)"
  fi
}

# flow_mutant <label> <dir> <sed script>: a changed copy of publish.yml must be refused by workflow_structure.
flow_mutant() {
  local label="$1" dir="$2" script="$3" copy
  copy="$dir/flow-$(printf '%s' "$label" | tr -c 'a-z0-9' '-').yml"
  sed "$script" "$root/.github/workflows/publish.yml" > "$copy"
  if cmp -s "$root/.github/workflows/publish.yml" "$copy"; then
    fail "the mutant did not change publish.yml: $label"
    return
  fi
  expect_structure_failure "$label" "$root/.github/workflows/test.yml" "$copy"
}

# flow_if_mutant <label> <dir> <condition> [text]: the same with the publish job's if line replaced.
flow_if_mutant() {
  local label="$1" dir="$2" cond="$3" want="${4:-}" copy
  copy="$dir/flow-$(printf '%s' "$label" | tr -c 'a-z0-9' '-').yml"
  awk -v cond="    if: \${{ $cond }}" '/^    if: \$\{\{ !cancelled\(\)/ { print cond; next } { print }' \
    "$root/.github/workflows/publish.yml" > "$copy"
  if cmp -s "$root/.github/workflows/publish.yml" "$copy"; then
    fail "the mutant did not change publish.yml: $label"
    return
  fi
  expect_structure_failure "$label" "$root/.github/workflows/test.yml" "$copy" "$want"
}

# The evaluator refuses what it does not support before it evaluates anything, and never runs workflow text as code.
evaluator_checks() {
  local dir="$1" copy out py="$here/publish-workflow-structure.py"
  local ok="needs.precheck.result == 'success'"
  flow_if_mutant "if with a call outside the set" "$dir" "!cancelled() && startsWith(github.ref, 'v')" "unsupported term in ["
  flow_if_mutant "if with an unclosed quote" "$dir" "!cancelled() && needs.precheck.result == 'success" "unsupported term in ["
  flow_if_mutant "if with a semicolon" "$dir" "!cancelled() && $ok; true" "unsupported term in ["
  flow_if_mutant "if with a backtick" "$dir" '!cancelled() && `true`' "unsupported term in ["
  flow_if_mutant "if with a command substitution" "$dir" '!cancelled() && $(true)' "unsupported term in ["
  flow_if_mutant "if with an unbalanced parenthesis" "$dir" "!cancelled() && ($ok" "does not evaluate ("
  flow_if_mutant "if with a stray closing parenthesis" "$dir" "!cancelled() && $ok)" "does not evaluate ("
  flow_if_mutant "if with a single ampersand" "$dir" "!cancelled() & $ok" "does not evaluate ("
  flow_if_mutant "if with a chained comparison" "$dir" "!cancelled() && $ok == true == true" "does not evaluate ("
  flow_if_mutant "if with a character refusal before a parse error" "$dir" "!cancelled() && ($ok;" "unsupported term in ["
  flow_if_mutant "if with an unknown needs result" "$dir" "!cancelled() && needs.build.result == 'success'" "unsupported term in ["
  flow_if_mutant "if that does not follow the results" "$dir" "!cancelled() && ''" "publish runs="
  copy="$dir/flow-double-quotes.yml"
  awk '/^    if: \$\{\{ !cancelled\(\)/ { gsub(/\047/, "\""); } { print }' \
    "$root/.github/workflows/publish.yml" > "$copy"
  cmp -s "$root/.github/workflows/publish.yml" "$copy" && fail "AZ-3383 temp copy double-quotes is unchanged"
  if ! out="$(workflow_structure "$root/.github/workflows/test.yml" "$copy")"; then
    fail "AZ-3383 the double-quoted publish if is refused: $out"
  fi
  if grep -Eq '\b(eval|exec|compile)\(' "$py"; then
    fail "AZ-3383 $py calls eval, exec or compile"
  fi
}

workflow_checks() {
  local test_yml="$root/.github/workflows/test.yml"
  local publish_yml="$root/.github/workflows/publish.yml"
  local out
  if ! command -v python3 >/dev/null; then
    fail "AZ-2095 python3 is required to parse the workflow YAML"
    return
  fi
  if ! out="$(workflow_structure "$test_yml" "$publish_yml")"; then
    fail "AZ-2095 workflow structure: $out"
  fi
  grep -q 'set -euo pipefail' "$test_yml" || fail "AC-5 a failing suite does not fail the job"
  grep -q 'docker compose -f docker-compose.test.yml run --rm' "$test_yml" || fail "AC-5 suites"
  bash "$here/publish-jobs.test.sh" || fail "AZ-2564 publish-jobs.test.sh failed"

  local tmp
  tmp="$(mktemp -d)"
  awk '/^  contents: read$/ && !done { print; print "  id-token: write"; done = 1; next } { print }' \
    "$publish_yml" > "$tmp/workflow-id-token.yml"
  awk '/^    uses: .\/.github\/workflows\/test.yml$/ { print; print "    secrets: inherit"; next } { print }' \
    "$publish_yml" > "$tmp/secrets-inherit.yml"
  awk '/^    branches: \["\*\*"\]$/ { print "    tags: [\"v*\"]"; next } { print }' \
    "$test_yml" > "$tmp/test-tags.yml"
  grep -v '^concurrency:$\|^  group: publish-\|^  cancel-in-progress: false$' "$publish_yml" > "$tmp/no-concurrency.yml"
  sed 's/^  cancel-in-progress: false$/  cancel-in-progress: true/' "$publish_yml" > "$tmp/cancel.yml"
  sed 's/^  group: publish-.*$/  group: publish/' "$publish_yml" > "$tmp/group.yml"
  for copy in workflow-id-token secrets-inherit no-concurrency cancel group; do
    cmp -s "$publish_yml" "$tmp/$copy.yml" && fail "AZ-2095 temp copy $copy is unchanged"
  done
  cmp -s "$test_yml" "$tmp/test-tags.yml" && fail "AZ-2095 temp copy test-tags is unchanged"
  expect_structure_failure "id-token at workflow level" "$test_yml" "$tmp/workflow-id-token.yml"
  expect_structure_failure "secrets on the test call" "$test_yml" "$tmp/secrets-inherit.yml"
  expect_structure_failure "test.yml push on tags" "$tmp/test-tags.yml" "$publish_yml"
  expect_structure_failure "no concurrency group" "$test_yml" "$tmp/no-concurrency.yml"
  expect_structure_failure "cancel-in-progress true" "$test_yml" "$tmp/cancel.yml"
  expect_structure_failure "concurrency group not keyed by the ref" "$test_yml" "$tmp/group.yml"

  # the tag-run flow. One mutant per rule of precheck, the test call and the publish condition.
  flow_mutant "publish without needs on test" "$tmp" 's#^    needs: \[precheck, test\]$#    needs: [precheck]#'
  flow_mutant "publish without needs on precheck" "$tmp" 's#^    needs: \[precheck, test\]$#    needs: [test]#'
  flow_mutant "test call without needs on precheck" "$tmp" '/^    needs: precheck$/d'
  flow_mutant "test call always runs" "$tmp" "/^    if: needs.precheck.outputs.green != 'true'\$/d"
  flow_mutant "test call runs only on a green proof" "$tmp" "s#green != 'true'#green == 'true'#"
  flow_mutant "test call if with always()" "$tmp" "s#^    if: needs.precheck.outputs.green != 'true'\$#    if: always() \&\& needs.precheck.outputs.green != 'true'#"
  flow_if_mutant "publish if ignores the test result" "$tmp" "!cancelled() && needs.precheck.result == 'success'"
  flow_if_mutant "publish if accepts a failed test" "$tmp" "!cancelled() && needs.precheck.result == 'success' && needs.test.result != 'cancelled'"
  flow_if_mutant "publish if accepts a skipped test without proof" "$tmp" "!cancelled() && needs.precheck.result == 'success' && (needs.test.result == 'success' || needs.test.result == 'skipped')"
  flow_if_mutant "publish if accepts a proof with a failed test" "$tmp" "!cancelled() && needs.precheck.result == 'success' && (needs.test.result == 'success' || needs.precheck.outputs.green == 'true')"
  flow_if_mutant "publish if ignores the precheck result" "$tmp" "!cancelled() && (needs.test.result == 'success' || (needs.precheck.outputs.green == 'true' && needs.test.result == 'skipped'))"
  flow_if_mutant "publish if without cancelled()" "$tmp" "needs.precheck.result == 'success' && (needs.test.result == 'success' || (needs.precheck.outputs.green == 'true' && needs.test.result == 'skipped'))"
  flow_if_mutant "publish if with success()" "$tmp" "success() && needs.precheck.result == 'success' && needs.test.result == 'success'"
  flow_if_mutant "publish if on another condition" "$tmp" "!cancelled() && github.event_name == 'push'"
  flow_if_mutant "publish if runs when cancelled" "$tmp" "always() && needs.precheck.result == 'success' && needs.test.result == 'success'"
  flow_mutant "precheck with contents write" "$tmp" '/^  precheck:$/,/^  test:$/s#^      contents: read$#      contents: write#'
  flow_mutant "precheck with actions write" "$tmp" 's#^      actions: read$#      actions: write#'
  flow_mutant "precheck without actions read" "$tmp" '/^      actions: read$/d'
  flow_mutant "precheck with id-token write" "$tmp" 's#^      actions: read$#      actions: read\
      id-token: write#'
  flow_mutant "precheck without the green output" "$tmp" '/^      green: /d'
  flow_mutant "precheck step that does not run the script" "$tmp" 's#bash .github/workflows/publish-precheck.sh#echo proof#'
  flow_mutant "precheck step with continue-on-error" "$tmp" 's#^        id: proof$#        id: proof\
        continue-on-error: true#'
  flow_mutant "precheck passes secrets" "$tmp" 's#^    timeout-minutes: 5$#    timeout-minutes: 5\
    secrets: inherit#'
  flow_mutant "precheck without a timeout" "$tmp" '/^    timeout-minutes: 5$/d'
  flow_mutant "no precheck job" "$tmp" '/^  precheck:$/,/^  test:$/{/^  test:$/!d;}'
  evaluator_checks "$tmp"
  bash "$here/publish-precheck.test.sh" || fail "publish-precheck.test.sh failed"
  rm -rf "$tmp"
}
