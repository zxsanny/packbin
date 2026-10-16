#!/usr/bin/env bash
# AZ-2564 and AZ-2600: the job layout of test.yml. Exactly one job runs each part of the old `scaffold` job: the static
# checks (`scaffold`), the suites (`suites`, a matrix: one job per language, Swift as two parts) and the publish gate
# (three jobs, each running its share of the groups of publish-gate.test.sh); they run beside `embedded` and `ring`
# (no needs, no if, no continue-on-error, a timeout), and a gate job that starts containers pulls its images first.
# The real test.yml must pass; each mutant (one per rule) must be refused.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# jobs_layout <test.yml> [<publish-gate.test.sh>]: prints one line per violation; exit 0 when there is none.
jobs_layout() {
  ruby -ryaml - "$1" "${2:-$here/publish-gate.test.sh}" <<'RUBY'
errors = []
wf = YAML.safe_load(File.read(ARGV[0]))
gate_source = File.read(ARGV[1])
jobs = wf["jobs"].is_a?(Hash) ? wf["jobs"] : {}
steps_of = ->(job) { job.is_a?(Hash) && job["steps"].is_a?(Array) ? job["steps"] : [] }
lines_of = ->(step) { step["run"].to_s.lines.map(&:strip).reject(&:empty?) }
runs = lambda do |name, wanted|
  steps_of.call(jobs[name]).select { |s| lines_of.call(s).any? { |l| l == wanted } }
end
all_runs = ->(wanted) { jobs.keys.flat_map { |n| runs.call(n, wanted).map { n } } }
languages = %w[csharp typescript python rust cpp java go swift]
gate_jobs = %w[publish-gate-readonly publish-gate-phases publish-gate-rest]

(%w[scaffold suites embedded ring] + gate_jobs).each do |name|
  errors << "test.yml has no #{name} job" unless jobs[name].is_a?(Hash)
end
(%w[scaffold suites] + gate_jobs).each do |name|
  job = jobs[name]
  next unless job.is_a?(Hash)
  errors << "job #{name} has no timeout-minutes" unless job.key?("timeout-minutes")
  %w[if needs continue-on-error].each { |k| errors << "job #{name} has #{k}, so it does not run beside the others" if job.key?(k) }
  steps_of.call(job).each do |step|
    label = step["name"] || step["uses"] || "unnamed"
    errors << "step '#{label}' of job #{name} has an if or continue-on-error" if step.key?("if") || step.key?("continue-on-error")
  end
end
errors << "a job named publish-gate is left: the gate is the three publish-gate-* jobs" if jobs.key?("publish-gate")

# The suites: one job per matrix entry; every language once, Swift as its two parts, nothing else.
suites = jobs["suites"]
matrix = suites.is_a?(Hash) && suites["strategy"].is_a?(Hash) ? suites["strategy"]["matrix"] : nil
entries = matrix.is_a?(Hash) && matrix["include"].is_a?(Array) ? matrix["include"] : []
errors << "the suites job has no matrix of included entries" if entries.empty?
errors << "the suites matrix has keys besides include (an exclude or a product would change the set)" if matrix.is_a?(Hash) && matrix.keys != ["include"]
errors << "the suites matrix stops the other suites at the first failure (fail-fast is not false)" unless suites.is_a?(Hash) && suites["strategy"].is_a?(Hash) && suites["strategy"]["fail-fast"] == false
got = entries.map { |e| e.is_a?(Hash) ? [e["lang"], e["part"]] : [nil, nil] }
want = (languages - ["swift"]).map { |l| [l, nil] } + [["swift", "tests"], ["swift", "gates"]]
(want - got).each { |e| errors << "the suites matrix has no entry for #{e.compact.join(' ')}" }
(got - want).each { |e| errors << "the suites matrix has an unknown entry #{e.inspect}" }
got.group_by { |e| e }.select { |_, v| v.size > 1 }.each_key { |e| errors << "the suites matrix runs #{e.compact.join(' ')} twice" }
entries.each { |e| errors << "the suites matrix entry #{e.inspect} has keys besides lang and part" if e.is_a?(Hash) && !(e.keys - %w[lang part]).empty? }

body = 'docker compose -f docker-compose.test.yml run --rm -e PACKBIN_SWIFT_PART "$SUITE"'
errors << "the suites run in #{all_runs.call(body).inspect}, not only in the suites job" unless all_runs.call(body) == ["suites"]
errors << "a job other than suites runs a suite through compose" unless jobs.keys.reject { |n| n == "suites" }.none? { |n| steps_of.call(jobs[n]).any? { |s| lines_of.call(s).any? { |l| l.include?("docker-compose.test.yml run") } } }
suites_step = steps_of.call(suites).find { |st| lines_of.call(st).include?(body) }
errors << "the suites step does not start with set -euo pipefail, so a failing suite can pass" unless suites_step && lines_of.call(suites_step).first == "set -euo pipefail"
errors << "the suites step does not take its language from the matrix" unless suites_step && suites_step.dig("env", "SUITE") == "${{ matrix.lang }}"
errors << "the suites step does not take its Swift part from the matrix" unless suites_step && suites_step.dig("env", "PACKBIN_SWIFT_PART") == "${{ matrix.part }}"

# The publish gate: every group of publish-gate.test.sh runs in exactly one job, and no group name is made up.
all_groups = (gate_source[/^gate_groups="([^"]*)"$/, 1] || "").split
errors << "publish-gate.test.sh has no gate_groups list" if all_groups.empty?
gate_cmd = "bash .github/workflows/publish-gate.test.sh"
ran = []
gate_jobs.each do |name|
  mine = steps_of.call(jobs[name]).flat_map { |s| lines_of.call(s) }.select { |l| l.start_with?(gate_cmd) }
  if mine.size != 1
    errors << "job #{name} runs the publish gate #{mine.size} times, not once"
    next
  end
  m = mine.first.match(/\A#{Regexp.escape(gate_cmd)} --groups (\S+)\z/)
  if m.nil?
    errors << "job #{name} does not run the gate with --groups <list>: #{mine.first}"
    next
  end
  groups = m[1].split(",")
  errors << "job #{name} names no group" if groups.empty?
  ran.concat(groups)
  steps = steps_of.call(jobs[name])
  gate_at = steps.index { |s| lines_of.call(s).any? { |l| l.start_with?(gate_cmd) } }
  pull_at = steps.index do |s|
    lines_of.call(s).any? { |l| l.match?(/\Adocker compose .*docker-compose\.publish\.yml.* pull\b/) && languages.all? { |lang| l.split.include?(lang) } }
  end
  # Groups that start containers (the golden gate, the read-only gate, the phases) need their images before the gate.
  if (groups & %w[gate readonly phases]).any? && (pull_at.nil? || pull_at > gate_at)
    errors << "job #{name} runs a group that starts containers without pulling its images before the gate"
  end
end
(all_groups - ran).each { |g| errors << "the gate group #{g} runs in no job" }
(ran - all_groups).uniq.each { |g| errors << "the gate group #{g} is not a group of publish-gate.test.sh" }
ran.group_by { |g| g }.select { |_, v| v.size > 1 }.each_key { |g| errors << "the gate group #{g} runs in more than one job" }
errors << "a job other than the three gate jobs runs the publish gate" if jobs.keys.any? { |n| !gate_jobs.include?(n) && steps_of.call(jobs[n]).any? { |s| lines_of.call(s).any? { |l| l.include?("publish-gate.test.sh") } } }

static = %w[
  .github/workflows/report-row.test.sh fixtures/hostile/cases.test.sh .github/workflows/run-suite.test.sh
  cpp/embedded/lib.test.sh .github/workflows/ring-wiring.test.sh scripts/loop-tests.test.sh
]
static.each do |script|
  found = all_runs.call("bash #{script}")
  errors << "the static check bash #{script} runs in #{found.inspect}, not only in scaffold" unless found == ["scaffold"]
end

errors.each { |e| puts e }
exit(errors.empty? ? 0 : 1)
RUBY
}

# mutant <label> <ruby expression on `wf`, a Hash>: writes a changed copy of test.yml and expects a refusal.
mutant() {
  local label="$1" edit="$2" copy out
  copy="$work/$(printf '%s' "$label" | tr -c 'a-z0-9' '-').yml"
  ruby -ryaml - "$here/test.yml" "$copy" "$edit" <<'RUBY'
wf = YAML.safe_load(File.read(ARGV[0]))
jobs = wf["jobs"]
step_named = ->(job, name) { jobs[job]["steps"].find { |s| s["name"] == name } }
gate_step = ->(job) { step_named.call(job, "publish gate") }
deep = ->(x) { Marshal.load(Marshal.dump(x)) }
eval(ARGV[2]) # rubocop:disable Security/Eval
File.write(ARGV[1], YAML.dump(wf))
RUBY
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

# Act and assert: one mutant per rule. The suites matrix
mutant "matrix without the swift tests part" 'jobs["suites"]["strategy"]["matrix"]["include"].reject! { |e| e["part"] == "tests" }'
mutant "matrix without the swift gates part" 'jobs["suites"]["strategy"]["matrix"]["include"].reject! { |e| e["part"] == "gates" }'
mutant "matrix with swift as one whole entry" 'inc = jobs["suites"]["strategy"]["matrix"]["include"]; inc.reject! { |e| e["lang"] == "swift" }; inc << { "lang" => "swift" }'
mutant "matrix without typescript" 'jobs["suites"]["strategy"]["matrix"]["include"].reject! { |e| e["lang"] == "typescript" }'
mutant "matrix runs go twice" 'jobs["suites"]["strategy"]["matrix"]["include"] << { "lang" => "go" }'
mutant "matrix with a language that has no suite" 'jobs["suites"]["strategy"]["matrix"]["include"] << { "lang" => "ruby" }'
mutant "matrix entry with an extra key" 'jobs["suites"]["strategy"]["matrix"]["include"].first["extra"] = "x"'
mutant "matrix with an exclude" 'jobs["suites"]["strategy"]["matrix"]["exclude"] = [{ "lang" => "cpp" }]'
mutant "matrix without fail-fast false" 'jobs["suites"]["strategy"].delete("fail-fast")'
mutant "matrix with fail-fast true" 'jobs["suites"]["strategy"]["fail-fast"] = true'
mutant "suites job without a matrix" 'jobs["suites"].delete("strategy")'
mutant "suites step without set -euo pipefail" 'st = step_named.call("suites", "suite"); st["run"] = st["run"].sub("set -euo pipefail\n", "")'
mutant "suites step ignores the matrix language" 'step_named.call("suites", "suite")["env"]["SUITE"] = "go"'
mutant "suites step without the swift part" 'step_named.call("suites", "suite")["env"].delete("PACKBIN_SWIFT_PART")'
mutant "suites step without -e PACKBIN_SWIFT_PART" 'st = step_named.call("suites", "suite"); st["run"] = st["run"].sub(" -e PACKBIN_SWIFT_PART", "")'
mutant "suites job needs scaffold" 'jobs["suites"]["needs"] = "scaffold"'
mutant "suites job with if" 'jobs["suites"]["if"] = "github.ref == %q(refs/heads/main)"'
mutant "suites step continue-on-error" 'step_named.call("suites", "suite")["continue-on-error"] = true'
mutant "suites job without timeout" 'jobs["suites"].delete("timeout-minutes")'
mutant "suites job removed" 'jobs.delete("suites")'
mutant "suites step also in scaffold" 'jobs["scaffold"]["steps"] << deep.call(step_named.call("suites", "suite"))'
mutant "a suite run in the ring job" 'jobs["ring"]["steps"] << { "name" => "go", "run" => "docker compose -f docker-compose.test.yml run --rm go" }'
# the publish gate jobs
mutant "phases group dropped" 'gate_step.call("publish-gate-phases")["run"] = "bash .github/workflows/publish-gate.test.sh --groups gate,pins"'
mutant "readonly group also in the phases job" 'gate_step.call("publish-gate-phases")["run"] = "bash .github/workflows/publish-gate.test.sh --groups gate,pins,phases,readonly"'
mutant "a group that does not exist" 'gate_step.call("publish-gate-rest")["run"] += ",bogus"'
mutant "the rest job names no group" 'gate_step.call("publish-gate-rest")["run"] = "bash .github/workflows/publish-gate.test.sh --groups ,"'
mutant "a gate job without --groups" 'gate_step.call("publish-gate-phases")["run"] = "bash .github/workflows/publish-gate.test.sh"'
mutant "a gate job with a flag instead of groups" 'gate_step.call("publish-gate-rest")["run"] = "bash .github/workflows/publish-gate.test.sh --npm"'
mutant "the gate also runs in scaffold" 'jobs["scaffold"]["steps"] << deep.call(gate_step.call("publish-gate-rest"))'
mutant "the whole gate in the readonly job too" 'gate_step.call("publish-gate-readonly")["run"] = "bash .github/workflows/publish-gate.test.sh"'
mutant "the old publish-gate job is left" 'jobs["publish-gate"] = deep.call(jobs["publish-gate-rest"])'
mutant "readonly job without the pull step" 'jobs["publish-gate-readonly"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "phases job without the pull step" 'jobs["publish-gate-phases"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "pull step after the gate" 'jobs["publish-gate-phases"]["steps"].reverse!'
mutant "pull step without swift" 'st = step_named.call("publish-gate-readonly", "pull images"); st["run"] = st["run"].sub(" swift", "")'
mutant "gate step with if" 'gate_step.call("publish-gate-rest")["if"] = "github.ref == %q(refs/heads/main)"'
mutant "gate step continue-on-error" 'gate_step.call("publish-gate-readonly")["continue-on-error"] = true'
mutant "gate job needs scaffold" 'jobs["publish-gate-phases"]["needs"] = "scaffold"'
mutant "gate job continue-on-error" 'jobs["publish-gate-rest"]["continue-on-error"] = true'
mutant "gate job without timeout" 'jobs["publish-gate-readonly"].delete("timeout-minutes")'
mutant "gate job removed" 'jobs.delete("publish-gate-rest")'
gate_mutant "a new group that no job runs" 's/^gate_groups="\(.*\)"$/gate_groups="\1 extra"/'
gate_mutant "a group renamed in the list" 's/^gate_groups="\(.*\) readonly"$/gate_groups="\1 read-only"/'
# the static checks
mutant "scaffold without the report columns step" 'jobs["scaffold"]["steps"].reject! { |s| s["name"] == "report columns" }'
mutant "scaffold static check moved to ring" 'jobs["ring"]["steps"] << jobs["scaffold"]["steps"].find { |s| s["name"] == "suite runner" }; jobs["scaffold"]["steps"].reject! { |s| s["name"] == "suite runner" }'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "job layout checks passed"
