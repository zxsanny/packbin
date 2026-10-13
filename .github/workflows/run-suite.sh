#!/usr/bin/env bash
set -uo pipefail

lang="${1:?language}"
root="${SRC_ROOT:-.}"
fixture="${FIXTURE:-$root/fixtures/golden.hex}"
results="${TEST_RESULTS:-$root/test-results}"
ok=0
started=$(date +%s)

grep -qx '4001000065cd1d00a3e1110100' "$fixture" || ok=1

run() {
  if [ "$ok" -ne 0 ]; then
    return
  fi
  "$@" || ok=1
}

# A suite whose manifest is missing has nothing to run: it fails, as Go always did (AZ-2448 AC-3, AZ-2457), so a
# tree that lost a language cannot turn the check green. Whether a language is published is decided by the
# publish gate (`publish-gate.sh`, AC-15), not by this script.
missing_manifest() {
  printf 'run-suite: %s is missing; the %s suite has nothing to run\n' "$1" "$lang" >&2
  ok=1
}

# Go (golang:1.27): every step runs in the module directory $1 through `go -C`.
go_fmt() {
  local unformatted
  unformatted="$(cd "$1" && gofmt -l .)" || return 1
  if [ -n "$unformatted" ]; then
    printf 'run-suite: gofmt -l lists files that are not gofmt-formatted:\n%s\n' "$unformatted" >&2
    return 1
  fi
}

# The 60 s fuzz run of the package that has the FuzzUnpack target (AZ-2444). Until that target
# exists the step says it is skipped; the line goes away by itself once the target is there.
go_fuzz() {
  local listed pkg
  listed="$(go -C "$1" test -list '^FuzzUnpack$' ./...)" || return 1
  pkg="$(printf '%s\n' "$listed" | awk '$0 == "FuzzUnpack" { found = 1; next } /^ok[ \t]/ { if (found) { print $2; exit } }')"
  if [ -z "$pkg" ]; then
    echo "run-suite: go fuzz step skipped: the package has no FuzzUnpack target yet"
    return 0
  fi
  # -fuzzminimizetime=0: the default minimises every new input for up to 60 s, which left 121k execs in a 60 s run
  # (1.4M without it, AZ-2444 report).
  go -C "$1" test -run='^$' -fuzz='^FuzzUnpack$' -fuzztime=60s -fuzzminimizetime=0 "$pkg"
}

# One dependency at most (GO-11, G-3): go.mod's direct requirements and the modules of every package
# the package and its tests build are the main module and golang.org/x/crypto. `go list -m all` alone
# cannot be the check: it always lists x/crypto's own requirements (x/sys, x/net, x/term, x/text).
go_deps() {
  local main direct built extra
  main="$(go -C "$1" list -m)" || return 1
  direct="$(go -C "$1" list -m -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' all)" || return 1
  built="$(go -C "$1" list -deps -test -f '{{with .Module}}{{.Path}}{{end}}' ./...)" || return 1
  extra="$(printf '%s\n%s\n' "$direct" "$built" | grep -vxF -e '' -e "$main" -e 'golang.org/x/crypto' | sort -u)"
  if [ -n "$extra" ]; then
    printf 'run-suite: go depends on modules other than golang.org/x/crypto:\n%s\n' "$extra" >&2
    return 1
  fi
}

case "$lang" in
  csharp)
    shopt -s nullglob
    projects=("$root"/csharp/*.csproj)
    if [ "${#projects[@]}" -gt 0 ]; then
      run env MSBUILDDISABLENODEREUSE=1 dotnet test "$root/csharp" -v n --nologo
      # The same suite against the netstandard2.0 build of the package.
      run env MSBUILDDISABLENODEREUSE=1 dotnet test "$root/csharp" -v n --nologo -p:PackbinTarget=netstandard2.0
    else
      missing_manifest "$root/csharp/*.csproj"
    fi
    ;;
  typescript)
    if [ -f "$root/typescript/package.json" ]; then
      run bash -lc "cd '$root/typescript' && if [ ! -f node_modules/typescript/lib/tsc.js ]; then npm ci; fi && npm test"
    else
      missing_manifest "$root/typescript/package.json"
    fi
    ;;
  python)
    if [ -f "$root/python/pyproject.toml" ]; then
      venv="${PACKBIN_PYTEST_VENV:-/tmp/packbin-pytest}"
      if [ ! -x "$venv/bin/pytest" ]; then
        if pytest_pin="$(bash "$root/.github/workflows/tool-pin.sh" pytest)"; then
          # --clear empties the directory, so only a missing, empty or venv directory may be rebuilt,
          # and never through a symlink (it would empty the target).
          if [ -L "$venv" ]; then
            printf 'run-suite: %q is a symlink; not rebuilding through it\n' "$venv" >&2
            ok=1
          elif [ -e "$venv" ] && [ ! -f "$venv/pyvenv.cfg" ] && [ -n "$(ls -A "$venv" 2>/dev/null)" ]; then
            printf 'run-suite: %q exists, is not empty and is not a python venv; not overwriting it\n' "$venv" >&2
            ok=1
          elif python -m venv --clear "$venv" </dev/null; then
            "$venv/bin/pip" install --only-binary=:all: "pytest==$pytest_pin" || ok=1
          else
            printf "run-suite: cannot create the python venv %q (is 'python' on PATH?)\n" "$venv" >&2
            ok=1
          fi
        else
          ok=1
        fi
      fi
      if [ "$ok" -eq 0 ] && ! "$venv/bin/python" -c 'import pytest' </dev/null >/dev/null 2>&1; then
        printf 'run-suite: python venv %q is unusable: its interpreter or pytest does not start.\n' "$venv" >&2
        printf 'run-suite: remove it and run again so it is rebuilt: rm -rf %q\n' "$venv" >&2
        ok=1
      fi
      run "$venv/bin/python" -m pytest -v --tb=short "$root/python/tests"
    else
      missing_manifest "$root/python/pyproject.toml"
    fi
    ;;
  rust)
    if [ -f "$root/rust/Cargo.toml" ]; then
      run cargo test --manifest-path "$root/rust/Cargo.toml" -- --nocapture
    else
      missing_manifest "$root/rust/Cargo.toml"
    fi
    ;;
  cpp)
    if [ -f "$root/cpp/Makefile" ]; then
      run make -C "$root/cpp" test
    else
      missing_manifest "$root/cpp/Makefile"
    fi
    ;;
  java)
    if [ -x "$root/java/test.sh" ] || [ -f "$root/java/test.sh" ]; then
      run bash "$root/java/test.sh"
    else
      missing_manifest "$root/java/test.sh"
    fi
    ;;
  go)
    # In the CI container Go runs as root on a checkout owned by the runner user, so git refuses it
    # ("dubious ownership") and `go list -test` stops with "error obtaining VCS status" (CI run 38422313279).
    # No step needs the VCS stamp, so every go command here runs with -buildvcs=false.
    export GOFLAGS="${GOFLAGS:+$GOFLAGS }-buildvcs=false"
    # A missing manifest fails: a Go suite that runs nothing must not pass (AZ-2448 AC-3).
    if [ -f "$root/go/go.mod" ]; then
      run go_fmt "$root/go"
      run go -C "$root/go" vet ./...
      run go -C "$root/go" test -race -count=1 -v ./...
      # AC-10 (1 s for 100 000 round trips) is a bound on the production build: the race detector costs about 5x,
      # so TestAC7SpeedRoundTrips asserts it only without -race and this step runs it there.
      run go -C "$root/go" test -run='^TestAC7SpeedRoundTrips$' -count=1 -v ./...
      run go_fuzz "$root/go"
      run go_deps "$root/go"
    else
      missing_manifest "$root/go/go.mod"
    fi
    ;;
  *)
    echo "unknown language: $lang" >&2
    ok=1
    ;;
esac

elapsed_ms=$(( ($(date +%s) - started) * 1000 ))
if [ "$ok" -eq 0 ]; then
  result=PASS
  message=
else
  result=FAIL
  message="suite failed"
fi
TEST_RESULTS="$results" SRC_ROOT="$root" bash "$root/.github/workflows/report-row.sh" \
  "$lang" "$lang suite" "$elapsed_ms" "$result" "$message"
exit "$ok"
