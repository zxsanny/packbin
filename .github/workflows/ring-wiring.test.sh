#!/usr/bin/env bash
# Wiring check for the cross-language ring (AZ-2193 AC-1, AC-6): test.yml must run language-pair.sh from a
# job that runs on every push and pull request, as its own check, and that a failing ring fails. It parses
# the workflow with Ruby yaml like the publish gate does, then runs the same check against copies of
# test.yml that each break one rule: every copy must be rejected. It also runs language-pair.sh against PATH
# shims for its toolchains (consumer_failure_checks), to check the line a failing pair prints.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_yml="$here/test.yml"
compose_yml="$here/../../docker-compose.test.yml"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# Prints the violations of workflow file $1, checked against the suite images in compose file $2 (default:
# the real one); exit status 1 when there are any.
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
           "RING_RUST" => "rust", "RING_GCC" => "cpp", "RING_JDK" => "java" }

on = workflow.key?("on") ? workflow["on"] : workflow[true]
if on.is_a?(Hash) && on.key?("push") && on.key?("pull_request")
  push = on["push"]
  if push.is_a?(Hash)
    push.each_key do |key|
      errors << "push has the filter #{key}" unless key == "branches"
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
    errors << "step '#{label}' of job #{name} has an if condition" if step.key?("if")
    # The ring and the version check must both compile through the gcc image, not the runner's GCC.
    next unless ring_steps.include?(step) || code_lines.call(step).any? { |l| l.match?(toolchains) }
    env = [job["env"], step["env"]].select { |e| e.is_a?(Hash) }.reduce({}) { |all, e| all.merge(e) }
    unless env["CXX"].to_s.match?(wrapper)
      errors << "step '#{label}' of job #{name} does not compile through ring-cxx.sh (CXX is '#{env['CXX']}')"
    end
  end
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
  ".github/workflows/ring-wiring.test.sh" => "the ring wiring check" }.each do |script, what|
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

# write_shim <dir> <tool> <pack output> <pack exit status> <unpack exit status>: a stand-in for the toolchain
# command <tool> that language-pair.sh runs. A pack-* driver command prints <pack output> and exits with the
# pack status, an unpack-* command exits with the unpack status; every call is logged to $SHIM_LOG.
write_shim() {
  cat > "$1/$2" <<SHIM
#!/bin/sh
echo "$2 \$*" >> "\$SHIM_LOG"
for arg in "\$@"; do
  case "\$arg" in
    pack-*) printf '%s\n' '$3'; exit $4 ;;
    unpack-*) exit $5 ;;
  esac
done
SHIM
  chmod +x "$1/$2"
}

# expect_ring <label> <expected output> <expected exit status>: runs language-pair.sh from the temp tree
# with the shims first on PATH; stdout and stderr together must be exactly the expected text.
expect_ring() {
  local label="$1" want="$2" want_rc="$3" out rc=0
  : > "$shim_log"
  out="$(PATH="$shims:$PATH" SHIM_LOG="$shim_log" bash "$ring_tree/.github/workflows/language-pair.sh" 2>&1)" || rc=$?
  if [ "$out" != "$want" ] || [ "$rc" -ne "$want_rc" ]; then
    fail "$label: exit $rc, output [$out], expected exit $want_rc, output [$want]"
  else
    echo "names the pair: $label ($out)"
  fi
}

# AZ-2238 AC-4, AC-5: a pair that fails ends the script with exit 1 and one line that names it. The first
# pair is csharp -> typescript, the second typescript -> python; the script stops at the first failure.
consumer_failure_checks() {
  # expect_ring reads these three (bash scopes a local to the functions it calls).
  local user_hex shim_log="$tmp/shim.log" shims="$tmp/shims" ring_tree="$tmp/ring-tree"
  user_hex="$(sed -n 's/^user_hex="\([0-9a-f]*\)"$/\1/p' "$here/language-pair.sh")"
  if [ -z "$user_hex" ]; then
    fail "language-pair.sh has no user_hex line to feed the shims"
    return
  fi
  mkdir -p "$shims" "$ring_tree/.github/workflows"
  cp "$here/language-pair.sh" "$ring_tree/.github/workflows/language-pair.sh"

  write_shim "$shims" dotnet "$user_hex" 0 0
  write_shim "$shims" python3 "$user_hex" 0 0
  write_shim "$shims" node "$user_hex" 0 1
  expect_ring "the node consumer fails" "typescript unpack-user failed on the bytes packed by csharp" 1

  write_shim "$shims" node "$user_hex" 0 0
  write_shim "$shims" python3 "$user_hex" 0 1
  expect_ring "the python consumer fails after a passing node" \
    "python unpack-user failed on the bytes packed by typescript" 1

  write_shim "$shims" python3 "$user_hex" 0 0
  write_shim "$shims" dotnet 00 0 0
  expect_ring "the csharp producer prints other bytes" "csharp pack-user mismatch" 1
  if grep -q 'unpack' "$shim_log"; then
    fail "a consumer ran after a producer mismatch: $(cat "$shim_log")"
  fi

  write_shim "$shims" dotnet "$user_hex" 1 0
  expect_ring "the csharp producer exits 1 while packing" "csharp pack-user failed" 1
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
  drop_step "embedded harness" > "$tmp/no-harness-step.yml"
  expect_accepted "a step that only lints or syntax-checks language-pair.sh" "$tmp/call-mentioned.yml"
  expect_rejected "call under if false in a run block" "$tmp/call-in-if-block.yml"
  expect_rejected "call under if false on one line" "$tmp/call-in-if-line.yml"
  expect_rejected "ring-toolchains.sh not run by the ring job" "$tmp/no-toolchains.yml"
  expect_rejected "if condition on the toolchain versions step" "$tmp/toolchains-if.yml"
  expect_rejected "if condition on a setup step" "$tmp/setup-if.yml"
  expect_rejected "scaffold without the ring wiring step" "$tmp/no-wiring-step.yml"
  expect_rejected "scaffold without the embedded harness step" "$tmp/no-harness-step.yml"
  expect_rejected "RING_NODE differs from the typescript suite image" "$tmp/env-node-bumped.yml"
  expect_rejected "RING_JDK removed" "$tmp/env-jdk-removed.yml"
  expect_rejected "node-version no longer comes from RING_NODE" "$tmp/node-hardcoded.yml"
  expect_rejected "the cpp suite image moved to gcc:17" "$test_yml" "$tmp/compose-gcc-bumped.yml"
  expect_rejected "call removed" "$tmp/call-removed.yml"
  expect_rejected "call renamed" "$tmp/call-renamed.yml"
  expect_rejected "call turned into a comment" "$tmp/call-commented.yml"
  expect_rejected "call followed by || true" "$tmp/call-or-true.yml"
  expect_rejected "path filter on push" "$tmp/push-paths.yml"
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

consumer_failure_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "ring wiring checks passed"
