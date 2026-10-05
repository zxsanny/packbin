#!/usr/bin/env bash
# Re-run and registry-policy scenarios (AZ-2097). Sourced by publish-gate.test.sh after
# publish-phases.test.sh, whose ph_* helpers, stubs and bare repositories it reuses.
#
# The curl, dotnet, npm, twine, cargo and pio stubs answer from $ph_scenario, one line each:
#   published <target>   the registry already holds this version (csharp typescript python rust java
#                        platformio esp-idf; vcpkg and arduino are published when the bare repo holds the commit)
#   partial python       with `published python`: only the wheel is on PyPI
#   fail <tool>          the tool exits 1 after logging its call (dotnet npm twine cargo pio)
#   503 <target>         the registry query always answers 503
#   503-once <target>    the first query answers 503
#   maven-exists         Central reports the deployment FAILED because the component already exists

RR_UPLOADS='^[0-9]+ (dotnet nuget push|npm publish|twine upload|cargo publish|pio pkg publish|compote component upload) |^[0-9]+ curl .*publisher/upload|git-push'
RR_REQUIRED="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY"

rr_uploads() {
  grep -Ec "$RR_UPLOADS" "$1" || true
}

rr_commits() {
  git --git-dir="$1" rev-list --count --all
}

# ph_creds without the variable $1.
rr_creds_without() {
  local var="$1" item
  rr_kept=()
  for item in "${ph_creds[@]}"; do
    if [ "${item%%=*}" != "$var" ]; then
      rr_kept+=("$item")
    fi
  done
}

rr_scenario() {
  : > "$ph_scenario"
  local line
  for line in "$@"; do
    printf '%s\n' "$line" >> "$ph_scenario"
  done
  rm -f "$ph_scenario".*.seen
}

# The target table and the credential check, on a matrix of environments, without any build.
rr_credential_unit() {
  local script expected out
  script='source "$1"
for t in csharp typescript python rust java vcpkg platformio esp-idf arduino; do
  printf "%s:%s:%s\n" "$t" "$(target_tier "$t")" "$(missing_credentials "$t")"
done'
  expected="csharp:required:NUGET_TOKEN
typescript:required:NPM_TOKEN or ACTIONS_ID_TOKEN_REQUEST_URL
python:required:PYPI_TOKEN or ACTIONS_ID_TOKEN_REQUEST_URL
rust:required:CARGO_REGISTRY_TOKEN
java:required:MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY
vcpkg:required:GITHUB_TOKEN
platformio:optional:PLATFORMIO_AUTH_TOKEN
esp-idf:optional:IDF_COMPONENT_API_TOKEN
arduino:optional:GITHUB_TOKEN"
  # shellcheck disable=SC2086
  out="$(env -u VCPKG_REGISTRY_URL -u ARDUINO_REGISTRY_URL $(for v in $PH_CREDENTIALS; do printf -- '-u %s ' "$v"; done) \
    bash -c "$script" _ "$here/publish-lib.sh")"
  assert_eq "$out" "$expected" "AZ-2097 target table with no credential"

  out="$(env NUGET_TOKEN=n NPM_TOKEN=n PYPI_TOKEN=p CARGO_REGISTRY_TOKEN=c MAVEN_CENTRAL_TOKEN=m \
    MAVEN_GPG_PRIVATE_KEY=k PLATFORMIO_AUTH_TOKEN=x IDF_COMPONENT_API_TOKEN=y GITHUB_TOKEN=g \
    bash -c "$script" _ "$here/publish-lib.sh" | awk -F: '$3 != ""')"
  assert_eq "$out" "" "AZ-2097 target table with every credential"

  out="$(env -u NPM_TOKEN -u PYPI_TOKEN -u MAVEN_GPG_PRIVATE_KEY -u GITHUB_TOKEN \
    ACTIONS_ID_TOKEN_REQUEST_URL=https://oidc.example MAVEN_CENTRAL_TOKEN=m \
    VCPKG_REGISTRY_URL=/srv/vcpkg.git ARDUINO_REGISTRY_URL=/srv/arduino.git \
    bash -c "$script" _ "$here/publish-lib.sh" | awk -F: '$1 == "typescript" || $1 == "python" || $1 == "vcpkg" || $1 == "arduino" || $1 == "java"')"
  expected="typescript:required:
python:required:
java:required:MAVEN_GPG_PRIVATE_KEY
vcpkg:required:
arduino:optional:"
  assert_eq "$out" "$expected" "AZ-2097 OIDC, a non-GitHub registry and one Maven variable"
}

# AC-1 and AC-3: each required credential unset in turn fails before any write and names itself.
rr_credential_matrix() {
  local var url=""
  ph_set_credentials
  for var in $RR_REQUIRED GITHUB_TOKEN; do
    rr_creds_without "$var"
    ph_bares "matrix-$var"
    url="$ph_vcpkg"
    if [ "$var" = "GITHUB_TOKEN" ]; then
      url="https://github.com/zxsanny/packbin.git"
    fi
    ph_publish "matrix-$var" - "${rr_kept[@]}" "VCPKG_REGISTRY_URL=$url"
    [ "$ph_code" -ne 0 ] || fail "AZ-2097 AC-1 publish passed without $var"
    grep -q "$var" "$ph_dir/matrix-$var.out" || fail "AZ-2097 AC-1 $var is not named: $(cat "$ph_dir/matrix-$var.out")"
    [ ! -s "$ph_log" ] || fail "AZ-2097 AC-1 a tool ran without $var: $(head -n 3 "$ph_log")"
    ph_no_refs "AZ-2097 AC-1 $var"
    [ ! -e "$ph_out/artifacts" ] || fail "AZ-2097 AC-1 a build started without $var"
  done
  echo "credential matrix: 7 runs rejected before any build or write"

  ph_bares matrix-all
  ph_publish matrix-all - "VCPKG_REGISTRY_URL=https://github.com/zxsanny/packbin.git"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 AC-1 publish passed with no credential"
  for var in $RR_REQUIRED GITHUB_TOKEN; do
    grep -q "$var" "$ph_dir/matrix-all.out" || fail "AZ-2097 AC-1 $var is not named when every credential is missing"
  done
  [ ! -s "$ph_log" ] || fail "AZ-2097 AC-1 a tool ran with no credential"
  ph_no_refs "AZ-2097 AC-1 all"

  printf 'python\n' > "$ph_plan"
  rr_creds_without PYPI_TOKEN
  ph_publish matrix-python - "${rr_kept[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 AC-3 a python-only plan without PYPI_TOKEN did not fail"
  grep -q 'PYPI_TOKEN' "$ph_dir/matrix-python.out" || fail "AZ-2097 AC-3 python skip is silent"
  if grep -q '^skip python' "$ph_dir/matrix-python.out"; then
    fail "AZ-2097 AC-3 python was dropped with a skip line"
  fi
  printf 'rust\n' > "$ph_plan"
  rr_creds_without CARGO_REGISTRY_TOKEN
  ph_publish matrix-rust - "${rr_kept[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 AC-3 a rust-only plan without CARGO_REGISTRY_TOKEN did not fail"
  grep -q 'CARGO_REGISTRY_TOKEN' "$ph_dir/matrix-rust.out" || fail "AZ-2097 AC-3 rust skip is silent"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}

# AC-2: optional credentials unset warn and skip; the required targets are uploaded.
rr_optional_warnings() {
  local summary="$ph_dir/summary.md" name
  ph_set_credentials
  rr_creds_without PLATFORMIO_AUTH_TOKEN
  ph_creds=("${rr_kept[@]}")
  rr_creds_without IDF_COMPONENT_API_TOKEN
  rr_scenario
  : > "$summary"
  ph_bares optional
  ph_publish optional - "${rr_kept[@]}" "ARDUINO_REGISTRY_URL=" "GITHUB_STEP_SUMMARY=$summary"
  assert_eq "$ph_code" "0" "AZ-2097 AC-2 exit code"
  assert_eq "$(grep -c '^::warning::' "$ph_dir/optional.out")" "3" "AZ-2097 AC-2 warning lines"
  grep -q '^::warning::.*platformio.*PLATFORMIO_AUTH_TOKEN' "$ph_dir/optional.out" || fail "AZ-2097 AC-2 platformio warning"
  grep -q '^::warning::.*esp-idf.*IDF_COMPONENT_API_TOKEN' "$ph_dir/optional.out" || fail "AZ-2097 AC-2 esp-idf warning"
  grep -q '^::warning::.*arduino.*GITHUB_TOKEN' "$ph_dir/optional.out" || fail "AZ-2097 AC-2 arduino warning"
  assert_eq "$(wc -l < "$summary" | tr -d ' ')" "3" "AZ-2097 AC-2 summary lines"
  for name in platformio:PLATFORMIO_AUTH_TOKEN esp-idf:IDF_COMPONENT_API_TOKEN arduino:GITHUB_TOKEN; do
    grep -q "${name%%:*}.*${name##*:}" "$summary" || fail "AZ-2097 AC-2 summary lacks ${name%%:*}"
  done
  for name in '^[0-9]+ dotnet nuget push ' '^[0-9]+ npm publish ' '^[0-9]+ twine upload ' '^[0-9]+ cargo publish ' \
    '^[0-9]+ curl .*publisher/upload' '^[0-9]+ git-push optional-vcpkg.git$'; do
    grep -Eq "$name" "$ph_log" || fail "AZ-2097 AC-2 required upload missing: $name"
  done
  if grep -Eq 'pio pkg publish|compote component upload|git-push optional-arduino' "$ph_log"; then
    fail "AZ-2097 AC-2 an optional target without a credential was uploaded"
  fi
  assert_eq "$(grep -c '^build ok ' "$ph_dir/optional.out")" "6" "AZ-2097 AC-2 only the credentialed targets build"
}

# A query line that is not Maven's must carry no token.
rr_queries_carry_no_token() {
  local label="$1" line
  if ! grep -q 'curl .*registry.npmjs.org' "$ph_log"; then
    fail "AZ-2097 $label no npm query was logged"
  fi
  while IFS= read -r line; do
    case "$line" in
      *publisher/published*)
        case "$line" in *"Authorization: Bearer m"*) ;; *) fail "AZ-2097 $label Central query lacks its token" ;; esac
        ;;
      *)
        case "$line" in *Authorization*|*Bearer*|*token*) fail "AZ-2097 $label a public query carries a token: $line" ;; esac
        ;;
    esac
  done < <(grep -E ' curl .*(registry.npmjs.org|pypi.org/pypi|crates.io/api|api.nuget.org|api.registry.platformio.org|components.espressif.com|publisher/published)' "$ph_log")
}

# AC-4 first run fails at crates.io, AC-5 re-run finishes the rest, AC-6 re-run of a complete publish is a no-op.
rr_rerun_chain() {
  local line commits_vcpkg commits_arduino target
  ph_set_credentials
  ph_bares chain

  rr_scenario "fail cargo"
  ph_publish chain-1 - "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 AC-4 a failed crates.io upload did not fail the run"
  assert_eq "$(grep -c '^build ok ' "$ph_dir/chain-1.out")" "9" "AZ-2097 AC-4 builds before the failed upload"
  for line in '^[0-9]+ dotnet nuget push ' '^[0-9]+ npm publish ' '^[0-9]+ twine upload ' '^[0-9]+ cargo publish '; do
    grep -Eq "$line" "$ph_log" || fail "AZ-2097 AC-5 first run did not reach: $line"
  done
  if grep -Eq 'publisher/upload|git-push|pkg publish|component upload' "$ph_log"; then
    fail "AZ-2097 AC-4 an upload ran after the failed required upload: $(grep -E 'publisher/upload|git-push|pkg publish|component upload' "$ph_log" | head -n 2)"
  fi
  ph_no_refs "AZ-2097 AC-4"

  rr_scenario "published csharp" "published typescript" "published python"
  ph_publish chain-2 - "${ph_creds[@]}"
  assert_eq "$ph_code" "0" "AZ-2097 AC-5 re-run exit code"
  for target in csharp typescript python; do
    grep -qx "already published $target 0.1.9" "$ph_dir/chain-2.out" || fail "AZ-2097 AC-5 no already-published line for $target"
  done
  if grep -Eq '^[0-9]+ (dotnet nuget push|npm publish|twine upload) ' "$ph_log"; then
    fail "AZ-2097 AC-5 an already published target was uploaded again"
  fi
  for line in '^[0-9]+ cargo publish ' '^[0-9]+ curl .*publisher/upload' '^[0-9]+ pio pkg publish ' \
    '^[0-9]+ compote component upload ' '^[0-9]+ git-push chain-vcpkg.git$' '^[0-9]+ git-push chain-arduino.git$'; do
    grep -Eq "$line" "$ph_log" || fail "AZ-2097 AC-5 the re-run did not upload: $line"
  done
  git --git-dir="$ph_vcpkg" show vcpkg:ports/packbin/vcpkg.json | grep -q '"version": "0.1.9"' || fail "AZ-2097 AC-5 vcpkg after the re-run"
  git --git-dir="$ph_arduino" show arduino-0.1.9:library.properties | grep -qx 'version=0.1.9' || fail "AZ-2097 AC-5 arduino after the re-run"
  rr_queries_carry_no_token "AC-5"

  commits_vcpkg="$(rr_commits "$ph_vcpkg")"
  commits_arduino="$(rr_commits "$ph_arduino")"
  rr_scenario "published csharp" "published typescript" "published python" "published rust" \
    "published java" "published platformio" "published esp-idf"
  ph_publish chain-3 - "${ph_creds[@]}"
  assert_eq "$ph_code" "0" "AZ-2097 AC-6 no-op re-run exit code"
  assert_eq "$(grep -c '^already published ' "$ph_dir/chain-3.out")" "9" "AZ-2097 AC-6 already-published lines"
  assert_eq "$(rr_uploads "$ph_log")" "0" "AZ-2097 AC-6 upload commands in a complete re-run"
  assert_eq "$(rr_commits "$ph_vcpkg")" "$commits_vcpkg" "AZ-2097 AC-6 vcpkg commits"
  assert_eq "$(rr_commits "$ph_arduino")" "$commits_arduino" "AZ-2097 AC-6 arduino commits"
  if grep -q '^upload ' "$ph_dir/chain-3.out"; then
    fail "AZ-2097 AC-6 an upload line was printed in a complete re-run"
  fi
}

# PyPI holding only the wheel is not "published"; Central's duplicate rejection is.
rr_partial_python_and_maven() {
  printf 'python\njava\n' > "$ph_plan"
  ph_set_credentials
  ph_bares partial
  rr_scenario "published python" "partial python" "maven-exists"
  ph_publish partial - "${ph_creds[@]}"
  assert_eq "$ph_code" "0" "AZ-2097 partial python and Central rejection exit code"
  grep -Eq "^[0-9]+ twine upload .*--skip-existing " "$ph_log" || fail "AZ-2097 PyPI with one file missing was not completed: $(grep twine "$ph_log")"
  if grep -qx 'already published python 0.1.9' "$ph_dir/partial.out"; then
    fail "AZ-2097 PyPI with one file missing was read as published"
  fi
  grep -Eq '^[0-9]+ curl .*publisher/upload' "$ph_log" || fail "AZ-2097 Central upload was not attempted"
  grep -qx 'already published java 0.1.9' "$ph_dir/partial.out" || fail "AZ-2097 Central 'already exists' was not read as published"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}

# Optional upload failure with a credential present, Arduino tag conflict and the query rules, on the cpp targets.
rr_embedded_failures() {
  local other="$ph_dir/other-content" before
  printf 'cpp\n' > "$ph_plan"
  ph_set_credentials

  ph_bares optional-fails
  rr_scenario "fail pio"
  ph_publish optional-fails - "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 a failed optional upload with its credential present did not fail the run"
  grep -Eq '^[0-9]+ git-push optional-fails-vcpkg.git$' "$ph_log" || fail "AZ-2097 the required vcpkg push did not run before the optional failure"
  grep -Eq '^[0-9]+ pio pkg publish ' "$ph_log" || fail "AZ-2097 the failing optional upload did not run"

  ph_bares tag-conflict
  git init -q -b main "$other"
  git -C "$other" config user.email t@example.invalid
  git -C "$other" config user.name t
  printf 'different\n' > "$other/file"
  git -C "$other" add file
  git -C "$other" commit -q -m different
  mv "$ph_arduino/hooks/pre-receive" "$ph_arduino/hooks/pre-receive.off"
  git -C "$other" push -q "$ph_arduino" HEAD:refs/tags/arduino-0.1.9
  mv "$ph_arduino/hooks/pre-receive.off" "$ph_arduino/hooks/pre-receive"
  before="$(git --git-dir="$ph_arduino" rev-parse arduino-0.1.9)"
  rr_scenario
  ph_publish tag-conflict - "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 an arduino tag that points at other content did not fail the run"
  assert_eq "$(git --git-dir="$ph_arduino" rev-parse arduino-0.1.9)" "$before" "AZ-2097 the existing arduino tag moved"
  if git --git-dir="$ph_arduino" rev-parse --verify --quiet refs/heads/arduino >/dev/null; then
    fail "AZ-2097 the arduino branch moved although its tag was refused"
  fi

  ph_bares query-503
  rr_scenario "503 esp-idf" "503-once platformio"
  ph_publish query-503 - "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2097 a registry query that kept failing did not fail the run"
  grep -q 'cannot tell whether esp-idf 0.1.9 is published' "$ph_dir/query-503.out" || fail "AZ-2097 failed query message: $(tail -n 3 "$ph_dir/query-503.out")"
  assert_eq "$(grep -c 'curl .*components.espressif.com' "$ph_log")" "3" "AZ-2097 query attempts"
  assert_eq "$(grep -c 'curl .*api.registry.platformio.org' "$ph_log")" "2" "AZ-2097 one transient 503 is retried"
  grep -Eq '^[0-9]+ pio pkg publish ' "$ph_log" || fail "AZ-2097 the retried query did not lead to the upload"
  if grep -Eq 'compote component upload|git-push query-503-arduino' "$ph_log"; then
    fail "AZ-2097 a target whose query failed was uploaded"
  fi
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}

ph_rerun_checks() {
  rr_credential_unit
  rr_credential_matrix
  rr_embedded_failures
  rr_partial_python_and_maven
  rr_optional_warnings
  rr_rerun_chain
}
