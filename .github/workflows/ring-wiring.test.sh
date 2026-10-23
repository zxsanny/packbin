#!/usr/bin/env bash
# Wiring check for the cross-language ring (AZ-2193 AC-1, AC-6): test.yml must run language-pair.sh from a job that runs
# on every push (except one that touches only _docs/) and pull request, as its own check, and that a failing ring fails. It parses the workflow with Ruby yaml
# like the publish gate does, then runs the same check against copies of test.yml that each break one rule: every copy
# must be rejected. The checks of language-pair.sh itself (PATH shims, the C# element rings, the Go ring) are in
# ring-wiring-rows.test.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ring-wiring-lib.sh
source "$here/ring-wiring-lib.sh" # tmp, failures, fail
test_yml="$here/test.yml"
compose_yml="$here/../../docker-compose.test.yml"

# Prints the violations of workflow file $1, checked against the suite images in compose file $2 (default: the real
# one); exit status 1 when there are any.
ring_wiring() {
  ruby -ryaml - "$1" "${2:-$compose_yml}" <<'RUBY'
workflow = YAML.safe_load(File.read(ARGV.fetch(0)))
compose = YAML.safe_load(File.read(ARGV.fetch(1)))
errors = []
as_list = ->(v) { v.is_a?(Array) ? v : [v].compact }
steps_of = ->(job) { job.is_a?(Hash) && job["steps"].is_a?(Array) ? job["steps"] : [] }
code_lines = ->(step) { step["run"].to_s.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") } }
# The exact call, the script as the command word in any other form (|| true, a pipe, &), a set line.
call = %r{\A(?:bash )?(?:\./)?\.github/workflows/language-pair\.sh\z}
invokes = %r{\A(?:(?:bash|sh) )?(?:\./)?\.github/workflows/language-pair\.sh\b}
toolchains = %r{\A(?:bash )?(?:\./)?\.github/workflows/ring-toolchains\.sh\z}
shell_options = /\Aset -[euo]+( pipefail)?\z/
wrapper = %r{/\.github/workflows/ring-cxx\.sh\z}
# The job env versions and the suite images they copy (docker-compose.test.yml service => RING_ variable).
suites = { "RING_DOTNET" => "csharp", "RING_NODE" => "typescript", "RING_PYTHON" => "python",
           "RING_RUST" => "rust", "RING_GCC" => "cpp", "RING_JDK" => "java", "RING_GO" => "go" }

on = workflow.key?("on") ? workflow["on"] : workflow[true]
if on.is_a?(Hash) && on.key?("push") && on.key?("pull_request")
  push = on["push"]
  if push.is_a?(Hash)
    push.each_key do |key|
      errors << "push has the filter #{key}" unless %w[branches paths-ignore].include?(key)
    end
    # The one filter the owner allows (2026-10-23): a push that touches only _docs/ starts no run.
    if as_list.call(push["paths-ignore"]) != ["_docs/**"]
      errors << "push ignores the paths #{as_list.call(push['paths-ignore']).inspect}, not exactly _docs/**"
    end
    if push.key?("branches") && as_list.call(push["branches"]) != ["**"]
      errors << "push is limited to the branches #{as_list.call(push['branches']).inspect}"
    end
  end
  if on["pull_request"].is_a?(Hash)
    on["pull_request"].each_key { |key| errors << "pull_request has the filter #{key}" }
  end
else
  errors << "test.yml does not run on both push and pull_request"
end

jobs = workflow["jobs"].is_a?(Hash) ? workflow["jobs"] : {}
callers = {}
jobs.each do |name, job|
  steps_of.call(job).each do |step|
    lines = code_lines.call(step)
    if lines.any? { |l| l.match?(call) }
      (callers[name] ||= []) << step
      lines.each do |l|
        next if l.match?(call) || l.match?(shell_options)
        errors << "the ring step of job #{name} runs more than the call, which can skip it: #{l}"
      end
    else
      lines.each do |l|
        errors << "job #{name} runs language-pair.sh in a form that can hide its failure: #{l}" if l.match?(invokes)
      end
    end
  end
end
errors << "test.yml has no job that runs .github/workflows/language-pair.sh" if callers.empty?
callers.each do |name, ring_steps|
  job = jobs[name]
  steps = steps_of.call(job)
  errors << "job #{name} has an if condition" if job.key?("if")
  errors << "job #{name} needs another job, so it does not run in parallel" if job.key?("needs")
  errors << "job #{name} has no timeout-minutes" unless job.key?("timeout-minutes")
  errors << "job #{name} has continue-on-error" if job.key?("continue-on-error")
  checks_at = steps.index { |s| code_lines.call(s).any? { |l| l.match?(toolchains) } }
  ring_at = steps.index { |s| ring_steps.include?(s) }
  if checks_at.nil? || checks_at > ring_at
    errors << "job #{name} does not run ring-toolchains.sh before the ring"
  end
  steps.each do |step|
    label = step["name"] || step["uses"] || "unnamed"
    errors << "step '#{label}' of job #{name} has continue-on-error" if step.key?("continue-on-error")
    errors << "step '#{label}' of job #{name} has an if condition" if step.key?("if") && !step["uses"].to_s.match?(/\Aactions\/cache@\h{40}\z/) # a cache step runs no check (AZ-2627)
    # The ring and the version check must both compile through the gcc image, not the runner's GCC.
    next unless ring_steps.include?(step) || code_lines.call(step).any? { |l| l.match?(toolchains) }
    env = [job["env"], step["env"]].select { |e| e.is_a?(Hash) }.reduce({}) { |all, e| all.merge(e) }
    unless env["CXX"].to_s.match?(wrapper)
      errors << "step '#{label}' of job #{name} does not compile through ring-cxx.sh (CXX is '#{env['CXX']}')"
    end
  end
  # Go: setup-go pinned to a commit SHA at RING_GO; the driver built by ring-go.sh or ring-prepare.sh build (calls it).
  setup_go = steps.find { |s| s["uses"].to_s.start_with?("actions/setup-go@") }
  if setup_go.nil?
    errors << "job #{name} has no actions/setup-go step"
  else
    errors << "the setup-go step of job #{name} is not pinned to a commit SHA" unless setup_go["uses"].match?(/@[0-9a-f]{40}\z/)
    errors << "the setup-go step of job #{name} does not take go-version from RING_GO" unless setup_go.dig("with", "go-version").to_s == "${{ env.RING_GO }}"
  end
  go_build = %r{\Abash \.github/workflows/ring-(?:go\.sh|prepare\.sh build) \S+\z}
  errors << "job #{name} does not build the Go driver through ring-go.sh" unless steps.any? { |s| code_lines.call(s).any? { |l| l.match?(go_build) } }
  services = compose.is_a?(Hash) && compose["services"].is_a?(Hash) ? compose["services"] : {}
  used = steps.map { |s| [s["with"], s["run"]].to_s }.join("\n")
  suites.each do |key, service|
    image = services.dig(service, "image").to_s
    version = image.split(":", 2)[1].to_s.sub(/-jdk\z/, "")
    have = job["env"].is_a?(Hash) ? job["env"][key].to_s : ""
    if version.empty? || have != version
      errors << "#{key} is '#{have}' in job #{name}, the #{service} suite image '#{image}' has the version '#{version}'"
    end
    errors << "#{key} is not used by any step of job #{name}" unless used.include?(key)
  end
end

scaffold = jobs["scaffold"]
{ "cpp/embedded/lib.test.sh" => "the embedded harness self-test",
  ".github/workflows/ring-wiring.test.sh" => "the ring wiring check",
  ".github/workflows/ring-wiring-rows.test.sh" => "the ring row wiring check" }.each do |script, what|
  step = steps_of.call(scaffold).find { |s| code_lines.call(s).any? { |l| l == "bash #{script}" } }
  if step.nil?
    errors << "scaffold does not run #{what} (bash #{script})"
  elsif step.key?("if") || step.key?("continue-on-error")
    errors << "the scaffold step for #{script} has an if or continue-on-error"
  end
end

errors.each { |e| puts e }
exit(errors.empty? ? 0 : 1)
RUBY
}

# expect_rejected <label> <copy of test.yml> [<copy of the compose file>]: a copy differs from the real
# file and the check rejects the pair.
expect_rejected() {
  local label="$1" copy="$2" compose="${3:-$compose_yml}" out
  if cmp -s "$test_yml" "$copy" && cmp -s "$compose_yml" "$compose"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  if out="$(ring_wiring "$copy" "$compose")"; then
    fail "the wiring check passed a violating copy: $label"
  else
    echo "rejects: $label ($out)"
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

if ! command -v ruby > /dev/null; then
  fail "ruby is required to parse the workflow YAML"
elif ! out="$(ring_wiring "$test_yml")"; then
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
  expect_accepted "a step that only lints or syntax-checks language-pair.sh" "$tmp/call-mentioned.yml"
  expect_rejected "call under if false in a run block" "$tmp/call-in-if-block.yml"
  expect_rejected "call under if false on one line" "$tmp/call-in-if-line.yml"
  expect_rejected "ring-toolchains.sh not run by the ring job" "$tmp/no-toolchains.yml"
  expect_rejected "if condition on the toolchain versions step" "$tmp/toolchains-if.yml"
  expect_rejected "if condition on a setup step" "$tmp/setup-if.yml"
  expect_rejected "scaffold without the ring wiring step" "$tmp/no-wiring-step.yml"
  expect_rejected "scaffold without the ring row wiring step" "$tmp/no-rows-step.yml"
  expect_rejected "scaffold without the embedded harness step" "$tmp/no-harness-step.yml"
  expect_rejected "RING_NODE differs from the typescript suite image" "$tmp/env-node-bumped.yml"
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
