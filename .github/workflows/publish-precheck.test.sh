#!/usr/bin/env bash
# publish-precheck.sh decides green=true only for a completed, successful push run of test.yml of this
# repository at the tagged commit. A stub curl serves the runs API answer; the real script must pass every
# scenario and each mutant (one per condition of the lookup) must fail at least one.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
sha="2cade74a9c111422f864e59c5175aac09c6e0bad"
other="51ee43b0000000000000000000000000000000aa"
repo="zxsanny/packbin"

mkdir -p "$work/bin"
cat > "$work/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKBIN_STUB_LOG"
if [ "${PACKBIN_STUB_EXIT:-0}" != 0 ]; then
  echo "curl: (22) The requested URL returned error: 500" >&2
  exit "$PACKBIN_STUB_EXIT"
fi
cat "$PACKBIN_STUB_BODY"
EOF
chmod +x "$work/bin/curl"

# run_case <script> <body file> <curl exit>: prints the output file; the script's own stdout goes to $work/stdout.
run_case() {
  local script="$1" body="$2" code="$3"
  : > "$work/out"
  : > "$work/stdout"
  : > "$work/log"
  PATH="$work/bin:$PATH" PACKBIN_STUB_BODY="$body" PACKBIN_STUB_EXIT="$code" PACKBIN_STUB_LOG="$work/log" \
    PACKBIN_REPO="$repo" PACKBIN_SHA="$sha" GH_TOKEN="tok-secret" GITHUB_OUTPUT="$work/out" \
    bash "$script" > "$work/stdout" 2>&1 < /dev/null
}

# run_json <name> <ruby hash merged over a green push run, or nil for no run>: writes $work/<name>.json.
run_json() {
  ruby -rjson - "$work/$1.json" "$2" <<'RUBY'
run = { "id" => 7, "name" => "test", "path" => ".github/workflows/test.yml", "event" => "push",
        "status" => "completed", "conclusion" => "success", "head_sha" => ENV.fetch("PACKBIN_CASE_SHA"),
        "head_branch" => "dev", "head_repository" => { "full_name" => "zxsanny/packbin" } }
changes = eval(ARGV[1]) # rubocop:disable Security/Eval
runs = changes.nil? ? [] : [run.merge(changes)]
File.write(ARGV[0], JSON.dump({ "total_count" => runs.size, "workflow_runs" => runs }))
RUBY
}

# scenarios <script>: prints one line per scenario that disagrees; returns 1 when there is one.
scenarios() {
  local script="$1" errs=0 name changes expect
  # name | change to the green run ("nil" = no run at all) | wanted green
  while IFS='|' read -r name changes expect; do
    [ -n "$name" ] || continue
    PACKBIN_CASE_SHA="$sha" run_json "$name" "$changes"
    run_case "$script" "$work/$name.json" 0 || { echo "scenario '$name': script exited non-zero"; errs=1; continue; }
    if [ "$(cat "$work/out")" != "green=$expect" ]; then
      echo "scenario '$name': wanted green=$expect, got [$(tr '\n' ' ' < "$work/out")]"
      errs=1
    fi
  done <<EOF
a green push run|{}|true
no run at all|nil|false
a failed run|{"conclusion" => "failure"}|false
a cancelled run|{"conclusion" => "cancelled"}|false
a run still going|{"status" => "in_progress"}|false
a pull request run|{"event" => "pull_request"}|false
another commit|{"head_sha" => "$other"}|false
another workflow file|{"path" => ".github/workflows/publish.yml"}|false
another repository|{"head_repository" => {"full_name" => "someone/packbin"}}|false
a path with a ref suffix|{"path" => ".github/workflows/test.yml@refs/heads/dev"}|true
EOF
  # a failed call, an answer that is not JSON, an answer without workflow_runs
  printf '{}' > "$work/empty.json"
  printf 'not json' > "$work/notjson.json"
  run_case "$script" "$work/empty.json" 22 || { echo "scenario 'curl fails': script exited non-zero"; errs=1; }
  [ "$(cat "$work/out")" = "green=false" ] || { echo "scenario 'curl fails': wanted green=false"; errs=1; }
  grep -q 'runs API call failed' "$work/stdout" || { echo "scenario 'curl fails': the reason is not printed"; errs=1; }
  run_case "$script" "$work/notjson.json" 0 || { echo "scenario 'not json': script exited non-zero"; errs=1; }
  [ "$(cat "$work/out")" = "green=false" ] || { echo "scenario 'not json': wanted green=false"; errs=1; }
  run_case "$script" "$work/empty.json" 0 || { echo "scenario 'no workflow_runs': script exited non-zero"; errs=1; }
  [ "$(cat "$work/out")" = "green=false" ] || { echo "scenario 'no workflow_runs': wanted green=false"; errs=1; }
  # the request names the commit, the push event, the success status and the workflow file; the token is sent, never printed
  PACKBIN_CASE_SHA="$sha" run_json green "{}"
  run_case "$script" "$work/green.json" 0 || errs=1
  for part in "workflows/test.yml/runs" "head_sha=$sha" "event=push" "status=success" "Authorization: Bearer tok-secret"; do
    grep -qF -- "$part" "$work/log" || { echo "request lacks [$part]"; errs=1; }
  done
  if grep -q 'tok-secret' "$work/stdout" "$work/out"; then echo "the token was printed"; errs=1; fi
  # a malformed repository or commit stops the script with exit 2 and writes no output
  for badsha in "" "abc" "2CADE74A9C111422F864E59C5175AAD0E6BAC09D"; do
    : > "$work/out"
    if PACKBIN_REPO="$repo" PACKBIN_SHA="$badsha" GITHUB_OUTPUT="$work/out" bash "$script" > /dev/null 2>&1 < /dev/null; then
      echo "scenario 'bad sha [$badsha]': accepted"; errs=1
    fi
    [ ! -s "$work/out" ] || { echo "scenario 'bad sha [$badsha]': wrote an output"; errs=1; }
  done
  if PACKBIN_REPO="not a repo" PACKBIN_SHA="$sha" GITHUB_OUTPUT="$work/out" bash "$script" > /dev/null 2>&1 < /dev/null; then
    echo "scenario 'bad repo': accepted"; errs=1
  fi
  return "$errs"
}

# mutant <label> <sed expression>: a copy of the script with one condition changed must fail a scenario.
mutant() {
  local label="$1" expr="$2" copy
  copy="$work/mutant.sh"
  sed "$expr" "$here/publish-precheck.sh" > "$copy"
  if cmp -s "$copy" "$here/publish-precheck.sh"; then
    bad "the mutant did not change the script: $label"
  elif out="$(scenarios "$copy")" && [ -z "$out" ]; then
    bad "the precheck tests accepted a mutant: $label"
  else
    echo "precheck tests reject: $label"
  fi
}

# Act and assert: the real script
if out="$(scenarios "$here/publish-precheck.sh")" && [ -z "$out" ]; then
  echo "publish-precheck.sh: all scenarios ok"
else
  bad "publish-precheck.sh: $out"
fi

# Act and assert: one mutant per condition
mutant "head_sha not compared" 's#r\["head_sha"\] == ARGV\[2\] \&\& ##'
mutant "event not compared" 's#r\["event"\] == "push" \&\& ##'
mutant "status not compared" 's#r\["status"\] == "completed" \&\&#true \&\&#'
mutant "conclusion not compared" 's#r\["conclusion"\] == "success" \&\& ##'
mutant "workflow path not compared" 's#r\["path"\].to_s.split("@").first == ".github/workflows/test.yml" \&\&#true \&\&#'
mutant "repository not compared" 's#r.dig("head_repository", "full_name") == ARGV\[1\]#true#'
mutant "no proof writes green=true" 's#echo "green=false"#echo "green=true"#'
mutant "a failed call counts as proof" 's#  no_proof "the runs API call failed"#  echo "green=true" >> "$out"; exit 0#'
mutant "sha filter dropped from the request" 's#head_sha=\$sha\&##'
mutant "sha not validated" 's#\^\[0-9a-f\]{40}\$#^.*$#'
mutant "token not sent" 's#auth=(-H "Authorization: Bearer \$GH_TOKEN")#auth=()#'

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish-precheck checks passed"
