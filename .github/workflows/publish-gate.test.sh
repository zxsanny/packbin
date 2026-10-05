#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
expected="4001000065cd1d00a3e1110100"
failures=0

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
  local inside="$root/.github/workflows/publish-inside.sh"
  for cmd in "dotnet nuget push" "npm publish" "twine upload" "cargo publish" "https://api.nuget.org" "https://central.sonatype.com"; do
    if ! grep -q "$cmd" "$inside" && ! grep -q "$cmd" "$registries"; then
      fail "missing publish command: $cmd"
    fi
  done
  if ! grep -q 'push_branch "$1" "$2" vcpkg' "$registries" ||
    ! grep -q 'git -C "$reg" push' "$here/publish-lib.sh"; then
    fail "cpp publish does not git push"
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

  if grep -q 'MAVEN_GROUP_ID' "$here/publish-registries.sh" || grep -q 'MAVEN_GROUP_ID' "$here/publish-inside.sh"; then
    fail "Java publish still reads MAVEN_GROUP_ID"
  fi
  if ! grep -q '<groupId>io.github.zxsanny</groupId>' "$here/publish-inside.sh"; then
    fail "Java group id is not io.github.zxsanny"
  fi
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
    VCPKG_REGISTRY_URL="$bare" \
    bash "$here/publish-registries.sh" | tee "$tmp/cpp.txt"
  for skipped in "skip platformio" "skip esp-idf component" "skip arduino"; do
    grep -qx "$skipped" "$tmp/cpp.txt" || fail "embedded publish without a token: $skipped"
  done

  local arduino="$tmp/arduino.git"
  git init --bare "$arduino" >/dev/null
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN \
    PACKBIN_PUBLISH=1 PACKBIN_VERSION=0.1.0 ARDUINO_REGISTRY_URL="$arduino" \
    bash "$here/publish-embedded.sh"
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

maven_bundle_checks() {
  if ! grep -q 'publishingType=AUTOMATIC' "$here/publish-registries.sh"; then
    fail "maven upload is not automatic"
  fi
  if grep -q 'maven-bundle.zip" -C' "$here/publish-inside.sh"; then
    fail "maven bundle is still a jar archive"
  fi
  local tree out ring key
  tree="$(mktemp -d)"
  copy_tree "$tree"
  out="$tree/.github/workflows/out"
  mkdir -p "$out"
  docker compose -f "$tree/docker-compose.test.yml" --project-directory "$tree" \
    -p packbin-maven-bundle run -T --rm --no-deps \
    -e SRC_ROOT=/src \
    -e PACKBIN_VERSION=0.1.2 \
    -e PACKBIN_OUT=/src/.github/workflows/out \
    java "exec /src/.github/workflows/publish-inside.sh java"
  local jar_dir=/src/.github/workflows/out/maven/io/github/zxsanny/packbin/0.1.2
  local class_check='
    set -euo pipefail
    jar="'"$jar_dir"'/packbin-0.1.2.jar"
    classes="$(jar tf "$jar" | grep "\.class$" | sed -e "s/\.class$//" -e "s|/|.|g")"
    total="$(printf "%s\n" "$classes" | wc -l)"
    java17="$(javap -v -cp "$jar" $classes | grep -c "major version: 61" || true)"
    printf "%s %s\n" "$total" "$java17"
  '
  local counts total_classes java17_classes
  counts="$(docker compose -f "$tree/docker-compose.test.yml" --project-directory "$tree" \
    -p packbin-maven-bundle run -T --rm --no-deps -e SRC_ROOT=/src java "$class_check")"
  total_classes="${counts% *}"
  java17_classes="${counts#* }"
  if [ "$total_classes" -lt 1 ]; then
    fail "AZ-2094 AC-1 jar holds no classes"
  fi
  assert_eq "$java17_classes" "$total_classes" "AZ-2094 AC-1 classes with major version 61"
  if command -v gpg >/dev/null 2>&1; then
    ring="$(mktemp -d)"
    chmod 700 "$ring"
    GNUPGHOME="$ring" gpg --batch --pinentry-mode loopback --passphrase '' \
      --quick-generate-key "packbin-test" rsa4096 sign 0
    key="$(GNUPGHOME="$ring" gpg --armor --export-secret-keys)"
    PACKBIN_PUBLISH=1 PACKBIN_MAVEN_BUNDLE_ONLY=1 PACKBIN_OUT="$out" \
      MAVEN_GPG_PRIVATE_KEY="$key" \
      bash "$here/publish-registries.sh"
  else
    docker run --rm -v "$tree:/work" -e SRC_ROOT=/work ubuntu:24.04 bash -lc '
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gnupg python3 >/dev/null
      export GNUPGHOME="$(mktemp -d)"
      chmod 700 "$GNUPGHOME"
      gpg --batch --pinentry-mode loopback --passphrase "" \
        --quick-generate-key "packbin-test" rsa4096 sign 0
      export MAVEN_GPG_PRIVATE_KEY="$(gpg --armor --export-secret-keys)"
      export PACKBIN_PUBLISH=1 PACKBIN_MAVEN_BUNDLE_ONLY=1
      export PACKBIN_OUT=/work/.github/workflows/out
      bash /work/.github/workflows/publish-registries.sh
    '
  fi
  python3 - "$out/maven-bundle.zip" <<'PY'
import sys, zipfile
names = zipfile.ZipFile(sys.argv[1]).namelist()
needed = (
    "io/github/zxsanny/packbin/0.1.2/packbin-0.1.2.pom",
    "io/github/zxsanny/packbin/0.1.2/packbin-0.1.2.jar",
    "io/github/zxsanny/packbin/0.1.2/packbin-0.1.2-sources.jar",
    "io/github/zxsanny/packbin/0.1.2/packbin-0.1.2-javadoc.jar",
)
for name in needed:
    for suffix in ("", ".asc", ".md5", ".sha1"):
        if name + suffix not in names:
            raise SystemExit(f"missing {name}{suffix}")
if any(name == "META-INF" or name.startswith("META-INF/") for name in names):
    raise SystemExit("bundle contains META-INF")
PY
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
  grep -q 'rust/README.md' "$root/.github/workflows/publish-inside.sh" || fail "crates readme copy"
  grep -q 'readme = "README.md"' "$root/python/pyproject.toml" || fail "pypi readme"
  grep -q 'python/README.md' "$root/.github/workflows/publish-inside.sh" || fail "pypi readme copy"
  grep -q 'oidc/mint-token' "$root/.github/workflows/publish-registries.sh" || fail "pypi trusted publisher"
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
  for copy in no-needs workflow-id-token secrets-inherit; do
    cmp -s "$publish_yml" "$tmp/$copy.yml" && fail "AZ-2095 temp copy $copy is unchanged"
  done
  cmp -s "$test_yml" "$tmp/test-tags.yml" && fail "AZ-2095 temp copy test-tags is unchanged"
  expect_structure_failure "publish without needs" "$test_yml" "$tmp/no-needs.yml"
  expect_structure_failure "id-token at workflow level" "$test_yml" "$tmp/workflow-id-token.yml"
  expect_structure_failure "secrets on the test call" "$test_yml" "$tmp/secrets-inherit.yml"
  expect_structure_failure "test.yml push on tags" "$tmp/test-tags.yml" "$publish_yml"
  rm -rf "$tmp"
}

if [ "${1:-}" = "--crates" ]; then
  crates_token_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "crates token checks passed"
  exit 0
fi

static_checks
crates_token_checks
registry_checks
gate_checks
maven_bundle_checks
manifest_checks
workflow_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish gate tests passed"
