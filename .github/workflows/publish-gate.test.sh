#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
expected="4001000065cd1d00a3e1110100"
failures=0
# Checks that could not run here (a missing tool outside GitHub Actions): named in the last line, never counted as passed.
not_run=""

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_eq() {
  if [ "$1" != "$2" ]; then
    fail "$3: expected [$2] got [$1]"
  fi
}

static_checks() {
  local test_yml="$root/.github/workflows/test.yml"
  local publish_yml="$root/.github/workflows/publish.yml"
  local registries="$root/.github/workflows/publish-registries.sh"
  for token in NPM_TOKEN NUGET_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN \
    MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN; do
    if grep -q "$token" "$test_yml"; then
      fail "test workflow contains $token"
    fi
  done
  if grep -q 'microsoft/vcpkg' "$registries" || grep -q 'gh pr' "$registries"; then
    fail "cpp publish is not a git push of this registry"
  fi
  local gate_line publish_line
  gate_line="$(grep -n 'publish-gate.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  publish_line="$(grep -n 'publish-registries.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  if [ -z "$gate_line" ] || [ -z "$publish_line" ] || [ "$gate_line" -ge "$publish_line" ]; then
    fail "registries run before the golden gate"
  fi
}

registry_checks() {
  local tmp plan log bin
  tmp="$(mktemp -d)"
  plan="$tmp/plan.txt"
  log="$tmp/log.txt"
  bin="$tmp/bin"
  mkdir -p "$bin"
  cat > "$bin/dotnet" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKBIN_PUBLISH_LOG"
exit 0
EOF
  cat > "$bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKBIN_PUBLISH_LOG"
exit 0
EOF
  chmod +x "$bin/dotnet" "$bin/curl"

  printf 'csharp\n' > "$plan"
  set +e
  PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$plan" PACKBIN_OUT="$tmp" \
    PACKBIN_PUBLISH_LOG="$log" PATH="$bin:$PATH" \
    bash "$here/publish-registries.sh" >"$tmp/out.txt" 2>"$tmp/err.txt"
  local code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "csharp publish ran without NUGET_TOKEN"
  fi
  if [ -s "$log" ]; then
    fail "a registry write ran before the token check"
  fi

  : > "$log"
  printf 'cpp\n' > "$plan"
  local bare="$tmp/vcpkg.git"
  git init --bare "$bare" >/dev/null
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN \
    PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$plan" PACKBIN_VERSION=0.1.0 \
    PACKBIN_OUT="$tmp/cpp-out" VCPKG_REGISTRY_URL="$bare" \
    bash "$here/publish-registries.sh" | tee "$tmp/cpp.txt"
  for skipped in "platformio: PLATFORMIO_AUTH_TOKEN" "esp-idf: IDF_COMPONENT_API_TOKEN" "arduino: GITHUB_TOKEN"; do
    grep -qx "::warning::skipping optional target $skipped is not set" "$tmp/cpp.txt" \
      || fail "embedded publish without a token: $skipped"
  done

  local arduino="$tmp/arduino.git"
  git init --bare "$arduino" >/dev/null
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN \
    PACKBIN_PUBLISH=1 PACKBIN_PLAN="$plan" PACKBIN_VERSION=0.1.0 PACKBIN_OUT="$tmp/cpp-out2" \
    VCPKG_REGISTRY_URL="$bare" ARDUINO_REGISTRY_URL="$arduino" \
    bash "$here/publish-registries.sh"
  git --git-dir="$arduino" show arduino:library.properties | grep -qx 'version=0.1.0' \
    || fail "arduino library version"
  git --git-dir="$arduino" show arduino-0.1.0:src/packbin.h >/dev/null \
    || fail "arduino tag layout"
  git --git-dir="$bare" show vcpkg:ports/packbin/vcpkg.json | grep -q '"name": "packbin"' \
    || fail "vcpkg port name"
  git --git-dir="$bare" show vcpkg:ports/packbin/vcpkg.json | grep -q '"license": "MIT"' \
    || fail "vcpkg license"
  git --git-dir="$bare" rev-parse --verify vcpkg >/dev/null || fail "vcpkg ref missing"
}

copy_tree() {
  local dest="$1"
  mkdir -p "$dest"
  tar -C "$root" \
    --exclude .git \
    --exclude test-results \
    --exclude .github/workflows/out \
    --exclude rust/target \
    --exclude .cache \
    --exclude cpp/build \
    -cf - . | tar -C "$dest" -xf -
}

gate_checks() {
  local out plan
  out="$(mktemp -d)"
  PACKBIN_OUT="$out" bash "$here/publish-gate.sh" >"$out/log.txt"
  plan="$out/publish-plan.txt"
  local order
  order="$(paste -sd ' ' "$plan")"
  assert_eq "$order" "csharp typescript python rust cpp java" "AC-1 call list"
  local count
  count="$(grep -c '^pack ' "$out/log.txt" || true)"
  assert_eq "$count" "6" "AC-1 pack calls"
  while read -r _ lang hex; do
    assert_eq "$hex" "$expected" "AC-1 $lang hex"
  done < <(grep '^pack ' "$out/log.txt")
  assert_eq "$(grep '^mismatch ' "$out/log.txt" | awk '{print $2}')" "0" "AC-5 mismatch"

  local bad
  bad="$(mktemp -d)"
  copy_tree "$bad"
  printf '00\n' > "$bad/fixtures/golden.hex"
  local bad_out="$bad/.github/workflows/out"
  set +e
  SRC_ROOT="$bad" PACKBIN_OUT="$bad_out" bash "$bad/.github/workflows/publish-gate.sh" >"$bad/log.txt"
  local code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "AC-3 mismatch still published"
  fi
  if [ -s "$bad_out/publish-plan.txt" ]; then
    fail "AC-3 plan was not empty"
  fi
  local packed
  packed="$(grep '^pack csharp ' "$bad/log.txt" | awk '{print $3}')"
  assert_eq "$packed" "$expected" "AC-3 pack ignored the bad fixture"

  local missing
  missing="$(mktemp -d)"
  copy_tree "$missing"
  rm -rf "$missing/java"
  local miss_out="$missing/.github/workflows/out"
  SRC_ROOT="$missing" PACKBIN_OUT="$miss_out" bash "$missing/.github/workflows/publish-gate.sh" >"$missing/log.txt"
  if grep -qx java "$miss_out/publish-plan.txt"; then
    fail "AC-4 java was published"
  fi
  if ! grep -q '^absent java$' "$missing/log.txt"; then
    fail "AC-4 java was not absent"
  fi
  assert_eq "$(wc -l < "$miss_out/publish-plan.txt" | tr -d ' ')" "5" "AC-4 five languages"
}

manifest_checks() {
  grep -q 'PackageLicenseExpression>MIT' "$root/csharp/Packbin.csproj" || fail "csharp license"
  grep -q '"license": "MIT"' "$root/typescript/package.json" || fail "typescript license"
  grep -q 'text = "MIT"' "$root/python/pyproject.toml" || fail "python license"
  grep -q 'license = "MIT"' "$root/rust/Cargo.toml" || fail "rust license"
  grep -q '<name>MIT</name>' "$root/.github/workflows/publish-inside.sh" || fail "java license"
  grep -q 'PackageReadmeFile' "$root/csharp/Packbin.csproj" || fail "nuget readme"
  grep -q '"README.md"' "$root/typescript/package.json" || fail "npm readme"
  grep -q 'readme = "README.md"' "$root/rust/Cargo.toml" || fail "crates readme"
  grep -q 'typescript/README.md' "$root/.github/workflows/publish-inside.sh" || fail "npm readme copy"
  grep -q 'cp "$root/README.md" "$stage/README.md"' "$root/.github/workflows/publish-inside.sh" || fail "crates readme copy"
  grep -q 'readme = "README.md"' "$root/python/pyproject.toml" || fail "pypi readme"
  grep -q 'python/README.md' "$root/.github/workflows/publish-inside.sh" || fail "pypi readme copy"
  grep -q 'oidc/mint-token' "$root/.github/workflows/publish-upload.sh" || fail "pypi trusted publisher"
}

crates_token_checks() {
  local publish_yml="$root/.github/workflows/publish.yml"
  local exchange_line publish_line revoke_line
  if grep -q 'crates-io-auth-action' "$publish_yml"; then
    fail "publish workflow still uses crates-io-auth-action"
  fi
  if grep -q 'continue-on-error' "$publish_yml"; then
    fail "publish workflow uses continue-on-error"
  fi
  exchange_line="$(grep -n 'crates-token.sh exchange' "$publish_yml" | head -n 1 | cut -d: -f1)"
  publish_line="$(grep -n 'publish-registries.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  revoke_line="$(grep -n 'crates-token.sh revoke' "$publish_yml" | head -n 1 | cut -d: -f1)"
  if [ -z "$exchange_line" ] || [ -z "$publish_line" ] || [ -z "$revoke_line" ]; then
    fail "crates token steps are missing"
  elif [ "$exchange_line" -ge "$publish_line" ] || [ "$publish_line" -ge "$revoke_line" ]; then
    fail "crates token exchange, publish, and revoke are out of order"
  fi

  local tmp out code
  tmp="$(mktemp -d)"
  set +e
  env -u ACTIONS_ID_TOKEN_REQUEST_URL -u ACTIONS_ID_TOKEN_REQUEST_TOKEN \
    bash "$here/crates-token.sh" exchange >"$tmp/no-oidc.out" 2>"$tmp/no-oidc.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "crates token exchange succeeded without an OIDC token"
  fi

  local bin count
  bin="$tmp/bin"
  count="$tmp/count"
  mkdir -p "$bin"
  cat > "$bin/curl" <<'EOF'
#!/bin/bash
nfile="${PACKBIN_CURL_COUNT:?}"
n=0
[ -f "$nfile" ] && n="$(cat "$nfile")"
n=$((n + 1))
printf '%s\n' "$n" > "$nfile"
mode="${PACKBIN_CURL_MODE:?}"
outfile=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    outfile="$arg"
  fi
  prev="$arg"
done
case "$mode" in
  exchange-ok)
    if [ "$n" -eq 1 ]; then
      printf '%s\n' '{"value":"oidc-jwt"}'
      exit 0
    fi
    printf '%s\n' '{"token":"cio-secret"}' > "$outfile"
    printf '%s' "200"
    ;;
  exchange-denied)
    if [ "$n" -eq 1 ]; then
      printf '%s\n' '{"value":"oidc-jwt"}'
      exit 0
    fi
    printf '%s\n' '{"errors":[{"detail":"denied"}]}' > "$outfile"
    printf '%s' "403"
    ;;
  revoke-503)
    printf '%s' "503"
    ;;
  revoke-200)
    printf '%s' "200"
    ;;
esac
EOF
  chmod +x "$bin/curl"

  out="$tmp/exchange-out"
  : > "$count"
  GITHUB_OUTPUT="$out" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="exchange-ok" \
    ACTIONS_ID_TOKEN_REQUEST_URL="https://token.actions.githubusercontent.com/req?x=1" \
    ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" exchange >"$tmp/exchange.log"
  grep -q '^token=cio-secret$' "$out" || fail "crates token was not written"
  grep -q '^::add-mask::cio-secret$' "$tmp/exchange.log" || fail "crates token was not masked"
  if grep -v '^::add-mask::' "$tmp/exchange.log" | grep -q 'cio-secret'; then
    fail "crates token was printed"
  fi

  : > "$count"
  set +e
  GITHUB_OUTPUT="$tmp/denied-out" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="exchange-denied" \
    ACTIONS_ID_TOKEN_REQUEST_URL="https://token.actions.githubusercontent.com/req?x=1" \
    ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" exchange >"$tmp/denied.log" 2>"$tmp/denied.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "denied crates token exchange succeeded"
  fi
  if [ -s "$tmp/denied-out" ]; then
    fail "denied crates token exchange wrote an output"
  fi

  : > "$count"
  CARGO_REGISTRY_TOKEN="cio-secret" PACKBIN_CRATES_REVOKE_PAUSE=0 \
    PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="revoke-503" PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" revoke >"$tmp/revoke503.log"
  assert_eq "$(grep -c 'revoke returned 503' "$tmp/revoke503.log")" "5" "crates revoke retries"
  grep -q 'revoke still unavailable' "$tmp/revoke503.log" || fail "crates revoke 503 failed the step"

  : > "$count"
  CARGO_REGISTRY_TOKEN="cio-secret" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="revoke-200" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" revoke >"$tmp/revoke200.log"
  grep -q 'token revoked' "$tmp/revoke200.log" || fail "crates revoke 200"
}

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
%w[scaffold embedded].each do |name|
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
end
publish = jobs["publish"]
if publish.nil?
  errors << "publish.yml has no publish job"
else
  errors << "publish does not need the test call" unless (test_ids - as_list.call(publish["needs"])).empty?
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

  local tmp
  tmp="$(mktemp -d)"
  grep -v '^    needs: test$' "$publish_yml" > "$tmp/no-needs.yml"
  awk '/^  contents: read$/ && !done { print; print "  id-token: write"; done = 1; next } { print }' \
    "$publish_yml" > "$tmp/workflow-id-token.yml"
  awk '/^    uses: .\/.github\/workflows\/test.yml$/ { print; print "    secrets: inherit"; next } { print }' \
    "$publish_yml" > "$tmp/secrets-inherit.yml"
  awk '/^    branches: \["\*\*"\]$/ { print "    tags: [\"v*\"]"; next } { print }' \
    "$test_yml" > "$tmp/test-tags.yml"
  grep -v '^concurrency:$\|^  group: publish-\|^  cancel-in-progress: false$' "$publish_yml" > "$tmp/no-concurrency.yml"
  sed 's/^  cancel-in-progress: false$/  cancel-in-progress: true/' "$publish_yml" > "$tmp/cancel.yml"
  sed 's/^  group: publish-.*$/  group: publish/' "$publish_yml" > "$tmp/group.yml"
  for copy in no-needs workflow-id-token secrets-inherit no-concurrency cancel group; do
    cmp -s "$publish_yml" "$tmp/$copy.yml" && fail "AZ-2095 temp copy $copy is unchanged"
  done
  cmp -s "$test_yml" "$tmp/test-tags.yml" && fail "AZ-2095 temp copy test-tags is unchanged"
  expect_structure_failure "publish without needs" "$test_yml" "$tmp/no-needs.yml"
  expect_structure_failure "id-token at workflow level" "$test_yml" "$tmp/workflow-id-token.yml"
  expect_structure_failure "secrets on the test call" "$test_yml" "$tmp/secrets-inherit.yml"
  expect_structure_failure "test.yml push on tags" "$tmp/test-tags.yml" "$publish_yml"
  expect_structure_failure "no concurrency group" "$test_yml" "$tmp/no-concurrency.yml"
  expect_structure_failure "cancel-in-progress true" "$test_yml" "$tmp/cancel.yml"
  expect_structure_failure "concurrency group not keyed by the ref" "$test_yml" "$tmp/group.yml"
  rm -rf "$tmp"
}

# shellcheck source=publish-npm.test.sh
source "$here/publish-npm.test.sh"
# shellcheck source=publish-vcpkg.test.sh
source "$here/publish-vcpkg.test.sh"

if [ "${1:-}" = "--npm" ]; then
  npm_dist_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "npm dist checks passed"
  exit 0
fi

if [ "${1:-}" = "--crates" ]; then
  crates_token_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "crates token checks passed"
  exit 0
fi

if [ "${1:-}" = "--vcpkg" ]; then
  vcpkg_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  if [ -n "$not_run" ]; then
    echo "vcpkg port checks: no failures, NOT RUN: $not_run"
  else
    echo "vcpkg port checks passed"
  fi
  exit 0
fi

# shellcheck source=publish-phases.test.sh
source "$here/publish-phases.test.sh"
# shellcheck source=publish-rerun.test.sh
source "$here/publish-rerun.test.sh"
# shellcheck source=publish-pins.test.sh
source "$here/publish-pins.test.sh"
# shellcheck source=publish-readonly.test.sh
source "$here/publish-readonly.test.sh"

static_checks
crates_token_checks
registry_checks
vcpkg_checks
gate_checks
manifest_checks
npm_dist_checks
workflow_checks
pins_checks
phase_checks
readonly_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
# A run with a check that did not run must not read like a pass (smoke scripts grep for the phrase).
if [ -n "$not_run" ]; then
  echo "publish gate: no failures, NOT RUN: $not_run"
else
  echo "publish gate tests passed"
fi
