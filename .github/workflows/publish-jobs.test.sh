#!/usr/bin/env bash
# AZ-2564: the job layout of test.yml. Exactly one job runs each part of the old `scaffold` job: the static checks
# (`scaffold`), the eight suites (`suites`) and the publish gate (`publish-gate`); the three run beside `embedded` and
# `ring` (no needs, no if, no continue-on-error, a timeout), and the gate job pulls its own images.
# The real test.yml must pass; each mutant (one per rule) must be refused.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# jobs_layout <test.yml>: prints one line per violation; exit 0 when there is none.
jobs_layout() {
  ruby -ryaml - "$1" <<'RUBY'
errors = []
wf = YAML.safe_load(File.read(ARGV[0]))
jobs = wf["jobs"].is_a?(Hash) ? wf["jobs"] : {}
steps_of = ->(job) { job.is_a?(Hash) && job["steps"].is_a?(Array) ? job["steps"] : [] }
lines_of = ->(step) { step["run"].to_s.lines.map(&:strip).reject(&:empty?) }
runs = lambda do |name, wanted|
  steps_of.call(jobs[name]).select { |s| lines_of.call(s).any? { |l| l == wanted } }
end
all_runs = ->(wanted) { jobs.keys.flat_map { |n| runs.call(n, wanted).map { n } } }

%w[scaffold suites publish-gate embedded ring].each do |name|
  errors << "test.yml has no #{name} job" unless jobs[name].is_a?(Hash)
end
%w[scaffold suites publish-gate].each do |name|
  job = jobs[name]
  next unless job.is_a?(Hash)
  errors << "job #{name} has no timeout-minutes" unless job.key?("timeout-minutes")
  %w[if needs continue-on-error].each { |k| errors << "job #{name} has #{k}, so it does not run beside the others" if job.key?(k) }
  steps_of.call(job).each do |step|
    label = step["name"] || step["uses"] || "unnamed"
    errors << "step '#{label}' of job #{name} has an if or continue-on-error" if step.key?("if") || step.key?("continue-on-error")
  end
end

list = "for lang in csharp typescript python rust cpp java go swift; do"
body = 'docker compose -f docker-compose.test.yml run --rm "$lang"'
loop_jobs = all_runs.call(list)
errors << "the eight suites run in #{loop_jobs.size} jobs (#{loop_jobs.inspect}), not exactly one" unless loop_jobs.size == 1
errors << "the eight suites do not run in the suites job" unless loop_jobs == ["suites"]
errors << "the suites step does not run each language through compose" unless all_runs.call(body) == ["suites"]
suites_step = steps_of.call(jobs["suites"]).find { |st| lines_of.call(st).include?(list) }
errors << "the suites step does not start with set -euo pipefail, so a failing suite can pass" unless suites_step && lines_of.call(suites_step).first == "set -euo pipefail"

gate = "bash .github/workflows/publish-gate.test.sh"
gate_jobs = all_runs.call(gate)
errors << "the publish gate runs in #{gate_jobs.size} jobs (#{gate_jobs.inspect}), not exactly one" unless gate_jobs.size == 1
errors << "the publish gate does not run in the publish-gate job" unless gate_jobs == ["publish-gate"]
steps = steps_of.call(jobs["publish-gate"])
gate_at = steps.index { |s| lines_of.call(s).include?(gate) }
pull_at = steps.index do |s|
  lines_of.call(s).any? { |l| l.match?(/\Adocker compose .*docker-compose\.publish\.yml.* pull\b/) && %w[csharp typescript python rust cpp java go swift].all? { |lang| l.split.include?(lang) } }
end
errors << "the publish-gate job does not pull its own images before the gate" if pull_at.nil? || gate_at.nil? || pull_at > gate_at

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
eval(ARGV[2]) # rubocop:disable Security/Eval
File.write(ARGV[1], YAML.dump(wf))
RUBY
  if out="$(jobs_layout "$copy")"; then
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
mutant "suites list without swift" 'step_named.call("suites", "suites")["run"] = step_named.call("suites", "suites")["run"].sub(" swift;", ";")'
mutant "gate step moved into scaffold" 'g = jobs["publish-gate"]["steps"].pop; jobs["scaffold"]["steps"] << g'
mutant "suites step without set -euo pipefail" 'st = step_named.call("suites", "suites"); st["run"] = st["run"].sub("set -euo pipefail\n", "")'
mutant "gate step removed" 'jobs["publish-gate"]["steps"].pop'
mutant "gate step with if" 'jobs["publish-gate"]["steps"].last["if"] = "github.ref == %q(refs/heads/main)"'
mutant "gate step continue-on-error" 'jobs["publish-gate"]["steps"].last["continue-on-error"] = true'
mutant "suites job needs scaffold" 'jobs["suites"]["needs"] = "scaffold"'
mutant "publish-gate job without timeout" 'jobs["publish-gate"].delete("timeout-minutes")'
mutant "suites job removed" 'jobs.delete("suites")'
mutant "publish-gate job without the pull step" 'jobs["publish-gate"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "pull step after the gate" 'jobs["publish-gate"]["steps"].reverse!'
mutant "suites loop also in scaffold" 'jobs["scaffold"]["steps"] << jobs["suites"]["steps"].last.dup'
mutant "scaffold without the report columns step" 'jobs["scaffold"]["steps"].reject! { |s| s["name"] == "report columns" }'
mutant "scaffold static check moved to ring" 'jobs["ring"]["steps"] << jobs["scaffold"]["steps"].find { |s| s["name"] == "suite runner" }; jobs["scaffold"]["steps"].reject! { |s| s["name"] == "suite runner" }'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "job layout checks passed"
