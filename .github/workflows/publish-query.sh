#!/usr/bin/env bash
# Sourced by publish-upload.sh. Answers "does the registry already hold this version?" for each
# target, with read-only calls. Every public query sends no token; only Maven Central's published
# endpoint needs one, and PlatformIO's owner lookup uses the account the upload would use.
# Answer: return 0 published, 1 not published. A query that fails (transport error, 5xx or 429
# after $PACKBIN_QUERY_ATTEMPTS tries, an unexpected status or body) stops the run: an unknown
# answer is never read as "not published".
#
# These functions run inside `if`, where `set -e` is off, so every failure here is an explicit exit.
# Needs: $version, $artifacts, $work from the caller.

PACKBIN_QUERY_ATTEMPTS="${PACKBIN_QUERY_ATTEMPTS:-3}"
query_agent="packbin-publish (https://github.com/zxsanny/packbin)"

query_fail() {
  echo "cannot tell whether $1 $version is published: $2" >&2
  exit 1
}

# registry_fetch <label> <url> [curl args...]: GET into $work/query.json.
# Returns 0 on 200 and 1 on 404.
registry_fetch() {
  local label="$1" url="$2" attempt code=""
  shift 2
  for attempt in $(seq 1 "$PACKBIN_QUERY_ATTEMPTS"); do
    if code="$(curl --silent --show-error --max-time 20 --connect-timeout 10 \
      -H "User-Agent: $query_agent" "$@" -o "$work/query.json" -w '%{http_code}' "$url")"; then
      if [ "$code" = 200 ]; then
        return 0
      fi
      if [ "$code" = 404 ]; then
        return 1
      fi
      if [ "${code#5}" = "$code" ] && [ "$code" != 429 ]; then
        break
      fi
    fi
    if [ "$attempt" -lt "$PACKBIN_QUERY_ATTEMPTS" ]; then
      sleep "${PACKBIN_QUERY_PAUSE:-3}"
    fi
  done
  query_fail "$label" "$url answered ${code:-nothing}"
}

# answer_is_yes <mode> [file name...]: the saved body says the version is there.
answer_is_yes() {
  local mode="$1" answer
  shift
  answer="$(python3 "$here/publish-published.py" "$mode" "$work/query.json" "$version" "$@")" \
    || query_fail "$mode" "the answer could not be read"
  [ "$answer" = yes ]
}

# The commit a remote ref points at, empty when the ref is absent.
remote_sha() {
  local url="$1" ref="$2" attempt out
  for attempt in $(seq 1 "$PACKBIN_QUERY_ATTEMPTS"); do
    if out="$(GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=30 \
      git ls-remote "$url" "$ref")"; then
      printf '%s\n' "${out%%[[:space:]]*}"
      return 0
    fi
    if [ "$attempt" -lt "$PACKBIN_QUERY_ATTEMPTS" ]; then
      sleep "${PACKBIN_QUERY_PAUSE:-3}"
    fi
  done
  return 1
}

# A git registry already holds this version when its branch is the commit the build prepared
# (no diff, so nothing to push) and, for Arduino, its tag points at that commit too. A tag that
# exists elsewhere is not "published": the push then fails on it.
git_published() {
  local target="$1" reg="$2" url="$3" branch="$4" tag="${5:-}" remote
  remote="$(remote_sha "$url" "refs/heads/$branch")" || query_fail "$target" "git ls-remote $url failed"
  if [ -z "$remote" ] || [ "$remote" != "$(git -C "$reg" rev-parse HEAD)" ]; then
    return 1
  fi
  if [ -n "$tag" ]; then
    remote="$(remote_sha "$url" "refs/tags/$tag")" || query_fail "$target" "git ls-remote $url failed"
    [ "$remote" = "$(git -C "$reg" rev-parse "refs/tags/$tag")" ]
    return
  fi
  return 0
}

platformio_owner() {
  local owner
  pio account show --json-output > "$work/query.json" \
    || query_fail platformio "pio account show failed"
  owner="$(python3 "$here/publish-published.py" pio-owner "$work/query.json" "$version")" \
    || query_fail platformio "the account answer could not be read"
  printf '%s\n' "$owner"
}

# target_published <target>
target_published() {
  local owner
  case "$1" in
    csharp)
      registry_fetch nuget "https://api.nuget.org/v3-flatcontainer/packbin/index.json" \
        && answer_is_yes nuget
      ;;
    typescript) registry_fetch npm "https://registry.npmjs.org/packbin/$version" ;;
    python)
      registry_fetch pypi "https://pypi.org/pypi/packbin/$version/json" \
        && answer_is_yes pypi "$(basename "$artifacts"/python/*.whl)" "$(basename "$artifacts"/python/*.tar.gz)"
      ;;
    rust) registry_fetch crates "https://crates.io/api/v1/crates/packbin/$version" ;;
    java)
      registry_fetch maven \
        "https://central.sonatype.com/api/v1/publisher/published?namespace=io.github.zxsanny&name=packbin&version=$version" \
        -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
        && answer_is_yes maven
      ;;
    vcpkg) git_published vcpkg "$artifacts/vcpkg/reg" "$(vcpkg_url)" vcpkg ;;
    platformio)
      owner="$(platformio_owner)" || exit 1
      registry_fetch platformio "https://api.registry.platformio.org/v3/packages/$owner/library/packbin" \
        && answer_is_yes platformio
      ;;
    esp-idf)
      registry_fetch esp-idf "https://components.espressif.com/api/components/zxsanny/packbin" \
        && answer_is_yes esp-idf
      ;;
    arduino) git_published arduino "$artifacts/arduino/reg" "$(arduino_url)" arduino "arduino-$version" ;;
    *) query_fail "$1" "unknown target" ;;
  esac
}
