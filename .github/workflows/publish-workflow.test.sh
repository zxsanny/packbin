#!/usr/bin/env bash
# The structure of publish.yml and test.yml (AZ-2095) and the tag-run flow (precheck, test, publish).
# Sourced by publish-gate.test.sh, which defines fail, $root and $here.

# shellcheck disable=SC2154,SC2016
workflow_structure() {
  ruby -ryaml - "$1" "$2" <<'RUBY'
test_path, publish_path = ARGV
errors = []
load_yaml = ->(path) { YAML.safe_load(File.read(path)) }
triggers = ->(wf) { wf.key?("on") ? wf["on"] : wf[true] }
as_list = ->(v) { v.is_a?(Array) ? v : [v].compact }
read_only = { "contents" => "read" }
test_wf = load_yaml.call(test_path)
publish_wf = load_yaml.call(publish_path)

on = triggers.call(test_wf)
errors << "test.yml has no workflow_call" unless on.is_a?(Hash) && on.key?("workflow_call")
errors << "test.yml has no pull_request" unless on.is_a?(Hash) && on.key?("pull_request")
push = on.is_a?(Hash) ? on["push"] : nil
unless push.is_a?(Hash) && !as_list.call(push["branches"]).empty? &&
       !push.key?("tags") && !push.key?("tags-ignore")
  errors << "test.yml push is not limited to branches"
end
errors << "test.yml permissions are not contents: read" unless test_wf["permissions"] == read_only
%w[scaffold suites publish-gate embedded].each do |name|
  job = test_wf["jobs"][name]
  errors << "test.yml has no #{name} job" if job.nil?
  errors << "test.yml #{name} has no timeout-minutes" if job && !job.key?("timeout-minutes")
end

on = triggers.call(publish_wf)
tags = on.is_a?(Hash) && on["push"].is_a?(Hash) ? as_list.call(on["push"]["tags"]) : []
errors << "publish.yml does not trigger on v* tags" unless tags.include?("v*")
if on.is_a?(Hash) && on["push"].is_a?(Hash) && on["push"].key?("branches")
  errors << "publish.yml triggers on branches"
end
errors << "publish.yml workflow permissions are not contents: read" unless publish_wf["permissions"] == read_only
jobs = publish_wf["jobs"]
test_ids = jobs.select { |_, j| j["uses"] == "./.github/workflows/test.yml" }.keys
errors << "publish.yml must call ./.github/workflows/test.yml exactly once" unless test_ids.size == 1
test_job = jobs[test_ids.first]
if test_job
  errors << "test call permissions are not contents: read" unless test_job["permissions"] == read_only
  errors << "test call passes secrets" if test_job.key?("secrets")
  errors << "the test call does not need precheck" unless as_list.call(test_job["needs"]).include?("precheck")
end

# `if` expressions are checked by their truth table over every result a needed job can have, not by their text.
# vars: needs.<job>.result, needs.<job>.outputs.<name>, cancelled(), always(); anything else is refused.
results = %w[success failure cancelled skipped]
greens = ["true", "false", ""]
evaluate = lambda do |expr, vars|
  e = expr.to_s.strip
  e = e[3..-3].strip if e.start_with?("${{") && e.end_with?("}}")
  return [nil, "no if expression"] if e.empty?
  ruby = e.gsub(/needs\.([A-Za-z_-]+)\.outputs\.([A-Za-z_-]+)/) { vars["needs.#{$1}.outputs.#{$2}"].inspect }
          .gsub(/needs\.([A-Za-z_-]+)\.result/) { vars["needs.#{$1}.result"].inspect }
          .gsub("cancelled()", vars["cancelled"].inspect).gsub("always()", "true")
  rest = ruby.gsub(/'[^']*'|"[^"]*"/, "").gsub(/\b(true|false)\b/, "")
  return [nil, "unsupported term in [#{e}]"] unless rest.match?(/\A[\s()!=&|]*\z/)
  begin
    [eval(ruby) ? true : false, nil] # rubocop:disable Security/Eval
  rescue SyntaxError, StandardError => ex
    [nil, "[#{e}] does not evaluate (#{ex.class})"]
  end
end
precheck = jobs["precheck"]
if precheck.nil?
  errors << "publish.yml has no precheck job"
else
  errors << "precheck permissions are not exactly contents: read and actions: read" unless precheck["permissions"] == { "contents" => "read", "actions" => "read" }
  errors << "precheck passes secrets" if precheck.key?("secrets")
  errors << "precheck has no timeout-minutes" unless precheck.key?("timeout-minutes")
  errors << "precheck has no green output" unless precheck["outputs"].is_a?(Hash) && precheck["outputs"]["green"].to_s.include?("steps.proof.outputs.green")
  proof = (precheck["steps"] || []).find { |s| s["id"] == "proof" }
  errors << "precheck has no proof step that runs publish-precheck.sh" unless proof && proof["run"].to_s.lines.map(&:strip).include?("bash .github/workflows/publish-precheck.sh")
  errors << "the proof step has an if or continue-on-error" if proof && (proof.key?("if") || proof.key?("continue-on-error"))
end
if test_job
  greens.each do |green|
    vars = { "needs.precheck.result" => "success", "needs.precheck.outputs.green" => green, "cancelled" => false }
    runs, why = evaluate.call(test_job["if"], vars)
    if runs.nil?
      errors << "test call if: #{why}"
      break
    end
    next if runs == (green != "true")
    errors << "test call runs=#{runs} for green [#{green}]; it must run exactly when there is no green proof"
  end
  errors << "the test call if has a status function" if test_job["if"].to_s.match?(/always\(\)|cancelled\(\)|failure\(\)|success\(\)/)
end
publish = jobs["publish"]
if publish.nil?
  errors << "publish.yml has no publish job"
else
  errors << "publish does not need the test call" unless (test_ids - as_list.call(publish["needs"])).empty?
  errors << "publish does not need precheck" unless as_list.call(publish["needs"]).include?("precheck")
  if publish["if"].to_s.match?(/\b(cancelled|always)\(\)/)
    results.product(results, greens, [true, false]).each do |pre, tst, green, cancelled|
      vars = { "needs.precheck.result" => pre, "needs.test.result" => tst, "needs.precheck.outputs.green" => green, "cancelled" => cancelled }
      runs, why = evaluate.call(publish["if"], vars)
      if runs.nil?
        errors << "publish if: #{why}" unless errors.include?("publish if: #{why}")
        next
      end
      wanted = !cancelled && pre == "success" && (tst == "success" || (green == "true" && tst == "skipped"))
      next if runs == wanted
      errors << "publish runs=#{runs} for precheck #{pre}, test #{tst}, green [#{green}], cancelled #{cancelled}; wanted #{wanted}"
      break
    end
  else
    errors << "publish has no cancelled() or always() in its if, so a skipped test would skip the publish"
  end
  expected = { "contents" => "write", "id-token" => "write" }
  errors << "publish permissions are not contents: write and id-token: write" unless publish["permissions"] == expected
  errors << "publish has no timeout-minutes" unless publish.key?("timeout-minutes")
end
concurrency = publish_wf["concurrency"] || (publish && publish["concurrency"])
if concurrency.is_a?(Hash)
  errors << "publish concurrency group is not keyed by the ref" unless concurrency["group"].to_s.include?("github.ref")
  errors << "publish concurrency cancels a run in progress" if concurrency["cancel-in-progress"]
else
  errors << "publish.yml has no concurrency group"
end
jobs.each do |name, job|
  next if name == "publish"
  if (job["permissions"] || {}).values.include?("write")
    errors << "#{name} holds a write permission"
  end
end

errors.each { |e| puts e }
exit(errors.empty? ? 0 : 1)
RUBY
}

expect_structure_failure() {
  local label="$1" test_yml="$2" publish_yml="$3" out
  if out="$(workflow_structure "$test_yml" "$publish_yml")"; then
    fail "AZ-2095 structure check passed a violating copy: $label"
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

# flow_if_mutant <label> <dir> <condition>: the same with the publish job's if line replaced.
flow_if_mutant() {
  local label="$1" dir="$2" cond="$3" copy
  copy="$dir/flow-$(printf '%s' "$label" | tr -c 'a-z0-9' '-').yml"
  awk -v cond="    if: \${{ $cond }}" '/^    if: \$\{\{ !cancelled\(\)/ { print cond; next } { print }' \
    "$root/.github/workflows/publish.yml" > "$copy"
  if cmp -s "$root/.github/workflows/publish.yml" "$copy"; then
    fail "the mutant did not change publish.yml: $label"
    return
  fi
  expect_structure_failure "$label" "$root/.github/workflows/test.yml" "$copy"
}

workflow_checks() {
  local test_yml="$root/.github/workflows/test.yml"
  local publish_yml="$root/.github/workflows/publish.yml"
  local out
  if ! command -v ruby >/dev/null 2>&1; then
    fail "AZ-2095 ruby is required to parse the workflow YAML"
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
  bash "$here/publish-precheck.test.sh" || fail "publish-precheck.test.sh failed"
  rm -rf "$tmp"
}
