#!/usr/bin/env bash
# AZ-2564, AZ-2600, AZ-2607, AZ-2625 and AZ-2626: the job layout of test.yml. Exactly one job runs each part of the old `scaffold` job:
# the static checks (`scaffold`), the suites (`suites`, a matrix: one job per language, Swift as three parts) and the
# publish gate (the publish-gate-* jobs, each running its share of the groups of publish-gate.test.sh); the embedded
# targets are the embedded-* jobs (each part of cpp/embedded/run.sh in exactly one); they run beside `ring` (no needs,
# no if, no continue-on-error, a timeout), and a gate job pulls exactly the images its groups start, before the gate.
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
# The gate jobs are the jobs named publish-gate-*. The suite images each group starts (traced in the code, AZ-2626): the
# golden gate and the read-only probes run all eight; the nojava gate copy has no java; the phase scenarios, the build of
# readonly-full and the pins build start the five that publish-build.sh runs in containers (cpp builds on the host); the
# other groups start none. A job pulls exactly the union for its groups: a missing image would be pulled on first use,
# inside a timed group, and an extra one costs the pull (swift is 4 GB).
gate_jobs = jobs.keys.select { |n| n.start_with?("publish-gate-") }
built = %w[csharp typescript python rust java]
group_images = { "gate" => languages, "readonly" => languages, "readonly-gate-good" => languages,
                 "readonly-gate-bad" => languages, "readonly-gate-nojava" => languages - ["java"], "phases" => built,
                 "phases-rerun" => built, "readonly-full" => built, "pins" => ["python"] }
pull_line = /\Adocker compose .*docker-compose\.publish\.yml.* pull\b/
errors << "test.yml has no publish-gate-* job" if gate_jobs.empty?
embedded_jobs = jobs.keys.select { |n| n.start_with?("embedded-") }
errors << "test.yml has no embedded-* job" if embedded_jobs.empty?
errors << "a job named embedded is left: the embedded targets are the embedded-* jobs" if jobs.key?("embedded")

(%w[scaffold suites ring] + gate_jobs + embedded_jobs).each do |name|
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
errors << "a job named publish-gate is left: the gate is the publish-gate-* jobs" if jobs.key?("publish-gate")

# The embedded jobs: no job-level if, needs or continue-on-error, a timeout; the only step with an if is the report
# (if: always()), and every part of cpp/embedded/run.sh is called by exactly one job, once.
embedded_jobs.each do |name|
  job = jobs[name]
  next unless job.is_a?(Hash)
  errors << "job #{name} has no timeout-minutes" unless job.key?("timeout-minutes")
  %w[if needs continue-on-error].each { |k| errors << "job #{name} has #{k}, so it does not run beside the others" if job.key?(k) }
  steps_of.call(job).each do |step|
    label = step["name"] || step["uses"] || "unnamed"
    errors << "step '#{label}' of job #{name} has continue-on-error" if step.key?("continue-on-error")
    errors << "step '#{label}' of job #{name} has an if (only the embedded report has if: always())" if step.key?("if") && !(label == "embedded report" && step["if"] == "always()")
  end
end
embedded_cmds = ["bash cpp/embedded/run.sh host arm", "bash cpp/embedded/run.sh host esp core", "bash cpp/embedded/run.sh host esp packages"]
embedded_ran = jobs.keys.flat_map do |name|
  steps_of.call(jobs[name]).flat_map { |s| lines_of.call(s) }.select { |l| l.start_with?("bash cpp/embedded/run.sh") }.map { |l| [name, l] }
end
embedded_cmds.each do |cmd|
  found = embedded_ran.select { |_, l| l == cmd }.map(&:first)
  errors << "the embedded part '#{cmd}' runs in #{found.size} jobs, not exactly one" unless found.size == 1
  errors << "the embedded part '#{cmd}' runs in #{found.first}, which is not an embedded-* job" if found.size == 1 && !embedded_jobs.include?(found.first)
end
embedded_ran.reject { |_, l| embedded_cmds.include?(l) }.each { |n, l| errors << "job #{n} runs #{l}, which is not one of the embedded parts" }
embedded_jobs.each do |name|
  n = embedded_ran.count { |j, _| j == name }
  errors << "job #{name} runs #{n} embedded parts, not one" unless n == 1
end

# The suites: one job per matrix entry; every language once, Swift as its two parts, nothing else.
suites = jobs["suites"]
matrix = suites.is_a?(Hash) && suites["strategy"].is_a?(Hash) ? suites["strategy"]["matrix"] : nil
entries = matrix.is_a?(Hash) && matrix["include"].is_a?(Array) ? matrix["include"] : []
errors << "the suites job has no matrix of included entries" if entries.empty?
errors << "the suites matrix has keys besides include (an exclude or a product would change the set)" if matrix.is_a?(Hash) && matrix.keys != ["include"]
errors << "the suites matrix stops the other suites at the first failure (fail-fast is not false)" unless suites.is_a?(Hash) && suites["strategy"].is_a?(Hash) && suites["strategy"]["fail-fast"] == false
got = entries.map { |e| e.is_a?(Hash) ? [e["lang"], e["part"]] : [nil, nil] }
want = (languages - ["swift"]).map { |l| [l, nil] } + [["swift", "tests"], ["swift", "gates"], ["swift", "speed"]]
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
  pulls = steps.each_with_index.flat_map { |s, i| lines_of.call(s).select { |l| l.match?(pull_line) }.map { |l| [i, l] } }
  want = groups.flat_map { |g| group_images.fetch(g, []) }.uniq
  if want.empty?
    errors << "job #{name} pulls images, but none of its groups starts a container" unless pulls.empty?
    next
  end
  if pulls.size != 1 || pulls.first[0] > gate_at
    errors << "job #{name} runs a group that starts containers without pulling its images once before the gate"
    next
  end
  have = pulls.first[1].split.drop_while { |w| w != "pull" }.drop(1).reject { |w| w.start_with?("-") }
  (want - have).each { |img| errors << "job #{name} does not pull #{img}, which #{groups.select { |g| group_images.fetch(g, []).include?(img) }.join(', ')} starts" }
  (have - want).each { |img| errors << "job #{name} pulls #{img}, which none of its groups (#{groups.join(', ')}) starts" }
end
(all_groups - ran).each { |g| errors << "the gate group #{g} runs in no job" }
(ran - all_groups).uniq.each { |g| errors << "the gate group #{g} is not a group of publish-gate.test.sh" }
ran.group_by { |g| g }.select { |_, v| v.size > 1 }.each_key { |g| errors << "the gate group #{g} runs in more than one job" }
errors << "a job other than the publish-gate-* jobs runs the publish gate" if jobs.keys.any? { |n| !gate_jobs.include?(n) && steps_of.call(jobs[n]).any? { |s| lines_of.call(s).any? { |l| l.include?("publish-gate.test.sh") } } }

static = %w[
  .github/workflows/report-row.test.sh fixtures/hostile/cases.test.sh .github/workflows/run-suite.test.sh
  cpp/embedded/lib.test.sh cpp/embedded/run-parts.test.sh .github/workflows/ring-wiring.test.sh scripts/loop-tests.test.sh
  .github/workflows/ring-wiring-swift.test.sh .github/workflows/ring-prepare.test.sh
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
mutant "matrix without the swift speed part" 'jobs["suites"]["strategy"]["matrix"]["include"].reject! { |e| e["part"] == "speed" }'
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
mutant "readonly-gate-good group dropped" 'gate_step.call("publish-gate-readonly-gate-good")["run"] = "bash .github/workflows/publish-gate.test.sh --groups readonly-gate-bad"; gate_step.call("publish-gate-readonly-gate-bad")["run"] = "bash .github/workflows/publish-gate.test.sh --groups readonly-gate-nojava"'
mutant "readonly-gate-bad also in the good job" 'gate_step.call("publish-gate-readonly-gate-good")["run"] += ",readonly-gate-bad"'
mutant "readonly-gate-nojava job without the pull step" 'jobs["publish-gate-readonly-gate-nojava"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "readonly-gate-good job without the pull step" 'jobs["publish-gate-readonly-gate-good"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "readonly-gate-bad moved to the job without a pull" 'gate_step.call("publish-gate-readonly-gate-bad")["run"] = "bash .github/workflows/publish-gate.test.sh --groups readonly-gate-good"; gate_step.call("publish-gate-swift")["run"] += ",readonly-gate-bad"'
mutant "phases-rerun also in the phases job" 'gate_step.call("publish-gate-phases")["run"] += ",phases-rerun"'
mutant "phases-rerun job without the pull step" 'jobs["publish-gate-phases-rerun"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "phases-rerun dropped" 'gate_step.call("publish-gate-phases-rerun")["run"] = "bash .github/workflows/publish-gate.test.sh --groups phases"'
mutant "pins also in the readonly job" 'gate_step.call("publish-gate-readonly")["run"] += ",pins"'
mutant "pins moved to the job without a pull" 'gate_step.call("publish-gate-rest")["run"] = gate_step.call("publish-gate-rest")["run"].sub(",pins", ""); gate_step.call("publish-gate-swift")["run"] += ",pins"'
mutant "readonly group also in the phases job" 'gate_step.call("publish-gate-phases")["run"] = "bash .github/workflows/publish-gate.test.sh --groups phases,readonly"'
mutant "readonly-full also in the phases job" 'gate_step.call("publish-gate-phases")["run"] += ",readonly-full"'
mutant "swift group also in the rest job" 'gate_step.call("publish-gate-rest")["run"] += ",swift"'
mutant "a container group moved to the job without a pull" 'gate_step.call("publish-gate-readonly")["run"] = "bash .github/workflows/publish-gate.test.sh --groups gate"; gate_step.call("publish-gate-swift")["run"] += ",readonly"'
mutant "rest job (readonly-full) without the pull step" 'jobs["publish-gate-rest"]["steps"].reject! { |s| s["name"] == "pull images" }'
mutant "no gate job at all" 'jobs.keys.select { |n| n.start_with?("publish-gate-") }.each { |n| jobs.delete(n) }'
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
mutant "phases pull without java" 'st = step_named.call("publish-gate-phases", "pull images"); st["run"] = st["run"].sub(" java", "")'
mutant "nojava pull without python" 'st = step_named.call("publish-gate-readonly-gate-nojava", "pull images"); st["run"] = st["run"].sub(" python", "")'
mutant "phases pull with swift" 'step_named.call("publish-gate-phases", "pull images")["run"] += " swift"'
mutant "rest pull with go" 'step_named.call("publish-gate-rest", "pull images")["run"] += " go"'
mutant "nojava pull with java" 'step_named.call("publish-gate-readonly-gate-nojava", "pull images")["run"] += " java"'
mutant "a pull in the swift job, whose group starts no container" 'jobs["publish-gate-swift"]["steps"].insert(1, deep.call(step_named.call("publish-gate-phases", "pull images")))'
mutant "two pull steps in the phases job" 'jobs["publish-gate-phases"]["steps"].insert(1, deep.call(step_named.call("publish-gate-phases", "pull images")))'
mutant "gate step with if" 'gate_step.call("publish-gate-rest")["if"] = "github.ref == %q(refs/heads/main)"'
mutant "gate step continue-on-error" 'gate_step.call("publish-gate-readonly")["continue-on-error"] = true'
mutant "gate job needs scaffold" 'jobs["publish-gate-phases"]["needs"] = "scaffold"'
mutant "gate job continue-on-error" 'jobs["publish-gate-rest"]["continue-on-error"] = true'
mutant "gate job without timeout" 'jobs["publish-gate-readonly"].delete("timeout-minutes")'
mutant "gate job removed" 'jobs.delete("publish-gate-rest")'
gate_mutant "a new group that no job runs" 's/^gate_groups="\(.*\)"$/gate_groups="\1 extra"/'
gate_mutant "a group renamed in the list" 's/^gate_groups="\(.*\) readonly-gate-bad \(.*\)"$/gate_groups="\1 ro-gate-bad \2"/'
gate_mutant "the phases-rerun group left out of the list" 's/^gate_groups="\(.*\) phases-rerun \(.*\)"$/gate_groups="\1 \2"/'
gate_mutant "an old readonly-gate group back in the list" 's/^gate_groups="\(.*\) readonly-full"$/gate_groups="\1 readonly-gate readonly-full"/'
gate_mutant "a read-only group left out of the list" 's/^gate_groups="\(.*\) readonly-full"$/gate_groups="\1"/'
# the embedded jobs
mutant "embedded arm job removed" 'jobs.delete("embedded-arm")'
mutant "embedded packages part runs the core part twice" 'jobs["embedded-esp-packages"]["steps"][1]["run"] = jobs["embedded-esp-core"]["steps"][1]["run"]'
mutant "embedded core job runs the whole ESP stage" 'jobs["embedded-esp-core"]["steps"][1]["run"] = jobs["embedded-esp-core"]["steps"][1]["run"].sub("host esp core", "host esp")'
mutant "embedded part runs in two jobs" 'jobs["embedded-esp-core"]["steps"][1]["run"] += "\nbash cpp/embedded/run.sh host arm"'
mutant "the unsplit embedded job is left" 'jobs["embedded"] = deep.call(jobs["embedded-arm"])'
mutant "an unsplit embedded run in the ring job" 'jobs["ring"]["steps"] << { "name" => "embedded", "run" => "bash cpp/embedded/run.sh" }'
mutant "embedded job with if" 'jobs["embedded-arm"]["if"] = "github.ref == %q(refs/heads/main)"'
mutant "embedded job needs scaffold" 'jobs["embedded-esp-core"]["needs"] = "scaffold"'
mutant "embedded job continue-on-error" 'jobs["embedded-esp-packages"]["continue-on-error"] = true'
mutant "embedded job without timeout" 'jobs["embedded-arm"].delete("timeout-minutes")'
mutant "embedded run step with if" 'jobs["embedded-arm"]["steps"][1]["if"] = "always()"'
mutant "embedded run step continue-on-error" 'jobs["embedded-esp-core"]["steps"][1]["continue-on-error"] = true'
mutant "embedded part misspelled" 'jobs["embedded-esp-packages"]["steps"][1]["run"] = jobs["embedded-esp-packages"]["steps"][1]["run"].sub("packages", "package")'
# the static checks
mutant "scaffold without the embedded parts step" 'jobs["scaffold"]["steps"].reject! { |s| s["name"] == "embedded parts" }'
mutant "scaffold without the report columns step" 'jobs["scaffold"]["steps"].reject! { |s| s["name"] == "report columns" }'
mutant "ring preparation test moved to ring" 'jobs["ring"]["steps"] << jobs["scaffold"]["steps"].find { |s| s["name"] == "ring preparation" }; jobs["scaffold"]["steps"].reject! { |s| s["name"] == "ring preparation" }'
mutant "scaffold static check moved to ring" 'jobs["ring"]["steps"] << jobs["scaffold"]["steps"].find { |s| s["name"] == "suite runner" }; jobs["scaffold"]["steps"].reject! { |s| s["name"] == "suite runner" }'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "job layout checks passed"
