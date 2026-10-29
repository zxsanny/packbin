#!/usr/bin/env bash
# run-suite.sh python: fails with a message naming the venv when it cannot import pytest, runs
# `python -m pytest` on a usable venv and passes its exit code on, refuses to clear a directory
# that is not a venv, and builds a missing venv with the pinned pytest. All interpreters are
# fakes that log their arguments, so there is no network and no real pytest.
# run-suite.sh go (AZ-2448): fails without go/go.mod, runs gofmt -l, go vet, go test -race, the
# FuzzUnpack fuzz step (or says it is skipped) and the one-dependency check in that order, and stops
# at the first failing step. `go` and `gofmt` are fakes too.
# run-suite.sh swift (AZ-2521): run-suite-swift.test.sh, sourced at the end.
# The timing notice (AZ-2607 AC-2): on GitHub Actions one notice with every step line and the total line, else none.
# RUN_SUITE_SH runs every row against another copy of run-suite.sh, RUN_SUITE_COMPOSE row N6 against another compose
# file (the mutation proof of a change to them).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
suite_sh="${RUN_SUITE_SH:-$here/run-suite.sh}"
# The CI scaffold job runs this file: no row may write a notice unless it sets GITHUB_ACTIONS itself.
unset GITHUB_ACTIONS
work="$(mktemp -d "${TMPDIR:-/tmp}/run-suite-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fail=0

bad() { echo "FAIL: $1"; fail=1; }

root="$work/src"
mkdir -p "$root/python/tests" "$root/fixtures" "$root/.github/workflows"
: > "$root/python/pyproject.toml"
cp "$repo/fixtures/golden.hex" "$root/fixtures/golden.hex"
cp "$here/tool-pin.sh" "$here/tool-pins.txt" "$root/.github/workflows/"
cat > "$root/.github/workflows/report-row.sh" <<'ROW'
#!/usr/bin/env bash
echo "report-row $*" >> "${TEST_RESULTS}.rows"
ROW

# A fake interpreter: logs its arguments to $log; `-c import pytest` exits $import_exit,
# `-m pytest` exits $pytest_exit, `-m venv --clear DIR` builds a fake venv in DIR.
fake_python() {
  local path="$1" log="$2" import_exit="$3" pytest_exit="$4"
  cat > "$path" <<PY
#!/bin/sh
echo "\$0 \$*" >> "$log"
case "\$1 \$2" in
  "-c import pytest") exit $import_exit ;;
  "-m pytest") exit $pytest_exit ;;
  "-m venv")
    dir="\$4"; mkdir -p "\$dir/bin"; : > "\$dir/pyvenv.cfg"
    cp "$path" "\$dir/bin/python"; printf '#!/bin/sh\necho "pip \$*" >> "$log"\n' > "\$dir/bin/pip"
    printf '#!/bin/sh\nexit 0\n' > "\$dir/bin/pytest"; chmod +x "\$dir/bin/pip" "\$dir/bin/pytest" "\$dir/bin/python"; exit 0 ;;
esac
exit 0
PY
  chmod +x "$path"
}

make_venv() { # dir import_exit pytest_exit
  local dir="$1"
  mkdir -p "$dir/bin"
  : > "$dir/bin/pytest"; chmod +x "$dir/bin/pytest"
  : > "$dir/pyvenv.cfg"
  fake_python "$dir/bin/python" "$dir.log" "$2" "$3"
}

run_suite() { # venv [extra PATH dir]
  SRC_ROOT="$root" FIXTURE="$root/fixtures/golden.hex" TEST_RESULTS="$work/results" \
    PACKBIN_PYTEST_VENV="$1" PATH="${2:+$2:}$PATH" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" python </dev/null 2>&1
}

# 1. a venv that cannot import pytest
make_venv "$work/broken" 127 0
out="$(run_suite "$work/broken")"; code=$?
[ "$code" -ne 0 ] || bad "a broken venv passed"
case "$out" in
  *"$work/broken"*"is unusable"*"rm -rf "*"$work/broken"*) ;;
  *) bad "no message naming the broken venv and the rebuild command: $out" ;;
esac

# 2. a usable venv: pytest is really called with the tests path, and its success is the exit code
make_venv "$work/good" 0 0
out="$(run_suite "$work/good")"; code=$?
[ "$code" -eq 0 ] || bad "a usable venv failed (exit $code): $out"
grep -q -- "-m pytest -v --tb=short $root/python/tests" "$work/good.log" || bad "pytest was not run on the tests path: $(cat "$work/good.log")"

# 3. a failing pytest fails the run
make_venv "$work/red" 0 1
out="$(run_suite "$work/red")"; code=$?
[ "$code" -ne 0 ] || bad "a failing pytest passed"

# 4. a directory that is not a venv is not cleared
mkdir -p "$work/notvenv"; echo keep > "$work/notvenv/precious.txt"
mkdir -p "$work/fakebin"; fake_python "$work/fakebin/python" "$work/fakebin.log" 0 0
out="$(run_suite "$work/notvenv" "$work/fakebin")"; code=$?
[ "$code" -ne 0 ] || bad "a non-venv directory was accepted"
[ -f "$work/notvenv/precious.txt" ] || bad "a non-venv directory was cleared"
case "$out" in *"not a python venv"*) ;; *) bad "no message for a non-venv directory: $out" ;; esac

# 4b. a symlink to a venv-like directory is not cleared
mkdir -p "$work/target"; : > "$work/target/pyvenv.cfg"; ln -s "$work/target" "$work/link"
out="$(run_suite "$work/link" "$work/fakebin")"; code=$?
[ "$code" -ne 0 ] || bad "a symlinked venv path was accepted"
[ -f "$work/target/pyvenv.cfg" ] || bad "a symlink target was cleared"
case "$out" in *"is a symlink"*) ;; *) bad "no message for a symlink: $out" ;; esac

# 5. a missing venv is built with the pinned pytest and then used
out="$(run_suite "$work/fresh" "$work/fakebin")"; code=$?
[ "$code" -eq 0 ] || bad "a missing venv was not built (exit $code): $out"
pin="$(bash "$here/tool-pin.sh" pytest)"
grep -q "pip install --only-binary=:all: pytest==$pin" "$work/fakebin.log" || bad "pytest==$pin was not installed: $(cat "$work/fakebin.log")"

# --- go ---
gobin="$work/gobin"
mkdir -p "$gobin"
# A fake go: logs its arguments to $GO_LOG, fails the step named by $GO_FAIL (vet, test, list, fuzz,
# mods, deps), lists FuzzUnpack when $GO_FUZZ is set, and prints what the real `go list` templates
# print, plus $GO_EXTRA_DIRECT (a direct requirement) and $GO_EXTRA (a built module) when set.
cat > "$gobin/go" <<'GO'
#!/bin/sh
echo "go $*" >> "$GO_LOG"
echo "GOFLAGS=${GOFLAGS:-}" >> "$GO_LOG.env"
if [ "$1" = -C ]; then shift 2; fi
case "$1 $2" in
  "vet ./...") step=vet ;;
  "test -race") step=test ;;
  "test -list") step=list ;;
  "test -run=^TestAC7"*) step=speed ;;
  "test -run="*) step=fuzz ;;
  "list -m") step=mods ;;
  "list -deps") step=deps ;;
  *) echo "fake go: unexpected arguments $*" >&2; exit 2 ;;
esac
if [ "$step" = "${GO_FAIL:-}" ]; then echo "fake go: $step failed" >&2; exit 1; fi
case "$step" in
  list)
    if [ -n "${GO_FUZZ:-}" ]; then echo FuzzUnpack; fi
    printf 'ok  \tmod.example/packbin\t0.001s\n' ;;
  mods)
    if [ "$#" -eq 2 ]; then echo mod.example/packbin; else printf '\ngolang.org/x/crypto\n\n'; fi
    if [ "$#" -gt 2 ] && [ -n "${GO_EXTRA_DIRECT:-}" ]; then echo "$GO_EXTRA_DIRECT"; fi ;;
  deps)
    printf '\nmod.example/packbin\ngolang.org/x/crypto\n'
    if [ -n "${GO_EXTRA:-}" ]; then echo "$GO_EXTRA"; fi ;;
esac
exit 0
GO
cat > "$gobin/gofmt" <<'GOFMT'
#!/bin/sh
echo "gofmt $*" >> "$GO_LOG"
if [ -n "${GOFMT_OUT:-}" ]; then echo "$GOFMT_OUT"; fi
exit 0
GOFMT
chmod +x "$gobin/go" "$gobin/gofmt"

goroot="$work/gosrc"
mkdir -p "$goroot/go" "$goroot/fixtures" "$goroot/.github/workflows"
cp "$repo/fixtures/golden.hex" "$goroot/fixtures/golden.hex"
cp "$root/.github/workflows/report-row.sh" "$goroot/.github/workflows/"
: > "$goroot/go/go.mod"

run_go() { # tree [VAR=value ...]: runs run-suite.sh go with the fakes first on PATH
  local tree="$1"
  shift
  rm -f "$work/go.log" "$work/go.log.env" "$work/goresults.rows"
  : > "$work/go.log"
  env SRC_ROOT="$tree" FIXTURE="${GO_FIXTURE:-$tree/fixtures/golden.hex}" TEST_RESULTS="$work/goresults" \
    GO_LOG="$work/go.log" PATH="$gobin:$PATH" "$@" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" go </dev/null 2>&1
}
row_is() { # result: the one report row of the last run
  grep -Eqx "report-row go go suite [0-9]+ $1" "$work/goresults.rows" \
    || bad "go report row is not '$1': $(cat "$work/goresults.rows" 2>&1)"
}
ran() { grep -qF -- "$1" "$work/go.log"; }

# G1 (AC-3). a tree without go/go.mod fails, names the manifest, writes a FAIL row and runs no go
mkdir -p "$work/nogo/go" "$work/nogo/fixtures" "$work/nogo/.github/workflows"
cp "$goroot/fixtures/golden.hex" "$work/nogo/fixtures/"
cp "$goroot/.github/workflows/report-row.sh" "$work/nogo/.github/workflows/"
out="$(run_go "$work/nogo")"; code=$?
[ "$code" -ne 0 ] || bad "go: a tree without go/go.mod passed"
case "$out" in *"go/go.mod is missing"*) ;; *) bad "go: no message naming the missing go/go.mod: $out" ;; esac
row_is "FAIL suite failed"
[ ! -s "$work/go.log" ] || bad "go: a tool ran without go/go.mod: $(cat "$work/go.log")"

# G2 (AC-2). every gate in order on a clean tree with a FuzzUnpack target; one PASS row
out="$(run_go "$goroot" GO_FUZZ=1)"; code=$?
[ "$code" -eq 0 ] || bad "go: a clean tree failed (exit $code): $out"
row_is "PASS "
expected="gofmt -l .
go -C $goroot/go vet ./...
go -C $goroot/go test -race -count=1 -v ./...
go -C $goroot/go test -run=^TestAC7SpeedRoundTrips$ -count=1 -v ./...
go -C $goroot/go test -list ^FuzzUnpack$ ./...
go -C $goroot/go test -run=^$ -fuzz=^FuzzUnpack$ -fuzztime=60s -fuzzminimizetime=0 mod.example/packbin
go -C $goroot/go list -m
go -C $goroot/go list -m -f {{if not (or .Main .Indirect)}}{{.Path}}{{end}} all
go -C $goroot/go list -deps -test -f {{with .Module}}{{.Path}}{{end}} ./..."
[ "$(cat "$work/go.log")" = "$expected" ] || bad "go: the steps differ from the expected ones: $(cat "$work/go.log")"
case "$out" in *"skipped"*) bad "go: the fuzz skip line shows although FuzzUnpack exists: $out" ;; esac
# G2b. every go command runs with -buildvcs=false (CI run 38422313279: git refuses the runner-owned checkout in the
# container, and `go list -test` stops with "error obtaining VCS status"); a GOFLAGS of the caller is kept
[ "$(wc -l < "$work/go.log.env" | tr -d ' ')" -eq 8 ] || bad "go: expected the 8 go commands to record GOFLAGS: $(cat "$work/go.log.env")"
[ -z "$(grep -vxF 'GOFLAGS=-buildvcs=false' "$work/go.log.env")" ] || bad "go: a go command ran without -buildvcs=false: $(cat "$work/go.log.env")"
run_go "$goroot" GO_FUZZ=1 GOFLAGS=-mod=mod >/dev/null
[ -z "$(grep -vxF 'GOFLAGS=-mod=mod -buildvcs=false' "$work/go.log.env")" ] || bad "go: the caller's GOFLAGS was not kept: $(cat "$work/go.log.env")"
out="$(run_go "$goroot" GO_FUZZ=1)"

# G3. no FuzzUnpack target yet: the step says it is skipped and does not fuzz
out="$(run_go "$goroot")"; code=$?
[ "$code" -eq 0 ] || bad "go: a tree without a fuzz target failed (exit $code): $out"
case "$out" in *"fuzz step skipped"*"no FuzzUnpack target"*) ;; *) bad "go: no skip line without a fuzz target: $out" ;; esac
if ran "-fuzz="; then bad "go: fuzzed without a FuzzUnpack target"; fi

# G4. gofmt lists a file: fail naming it, and nothing after it runs
out="$(run_go "$goroot" GO_FUZZ=1 GOFMT_OUT=pack.go)"; code=$?
[ "$code" -ne 0 ] || bad "go: an unformatted file passed"
case "$out" in *"not gofmt-formatted"*"pack.go"*) ;; *) bad "go: no message naming the unformatted file: $out" ;; esac
if ran " vet "; then bad "go: vet ran after gofmt failed"; fi
row_is "FAIL suite failed"

# G5 to G8. a failing vet, test, fuzz or dependency query fails the run and stops the later steps
for step in vet test speed fuzz deps; do
  out="$(run_go "$goroot" GO_FUZZ=1 GO_FAIL="$step")"; code=$?
  [ "$code" -ne 0 ] || bad "go: a failing $step passed"
  row_is "FAIL suite failed"
done
run_go "$goroot" GO_FUZZ=1 GO_FAIL=vet >/dev/null
if ran "test -race"; then bad "go: tests ran after vet failed"; fi
run_go "$goroot" GO_FUZZ=1 GO_FAIL=test >/dev/null
if ran "-fuzz="; then bad "go: fuzzed after the tests failed"; fi

# G9. a second module, built or required directly, fails and is named; x/crypto alone passes (G2)
out="$(run_go "$goroot" GO_EXTRA=example.org/other)"; code=$?
[ "$code" -ne 0 ] || bad "go: a second built module passed"
case "$out" in *"other than golang.org/x/crypto"*"example.org/other"*) ;; *) bad "go: the extra module is not named: $out" ;; esac
out="$(run_go "$goroot" GO_EXTRA_DIRECT=example.org/direct)"; code=$?
[ "$code" -ne 0 ] || bad "go: a second direct requirement passed"
case "$out" in *"example.org/direct"*) ;; *) bad "go: the extra requirement is not named: $out" ;; esac

# G10. a fixture without the golden row fails before any go step
printf '00\n' > "$work/bad-golden.hex"
out="$(GO_FIXTURE="$work/bad-golden.hex" run_go "$goroot" GO_FUZZ=1)"; code=$?
[ "$code" -ne 0 ] || bad "go: a wrong golden row passed"
[ ! -s "$work/go.log" ] || bad "go: a step ran with a wrong golden row: $(cat "$work/go.log")"

# --- the other six (AZ-2477) ---
# M1. a tree without a language's manifest fails, names the manifest, writes one FAIL row and runs no tool
bare="$work/bare"
mkdir -p "$bare/fixtures" "$bare/.github/workflows"
cp "$goroot/fixtures/golden.hex" "$bare/fixtures/"
cp "$goroot/.github/workflows/report-row.sh" "$bare/.github/workflows/"
run_lang() { # lang tree
  rm -f "$work/bare.rows"
  : > "$work/go.log"
  env SRC_ROOT="$2" FIXTURE="$2/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
    PACKBIN_PYTEST_VENV="$work/bare-venv" PATH="$gobin:$PATH" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" "$1" </dev/null 2>&1
}
for entry in csharp:csharp/*.csproj typescript:typescript/package.json python:python/pyproject.toml \
  rust:rust/Cargo.toml cpp:cpp/Makefile java:java/test.sh; do
  lang="${entry%%:*}"
  manifest="${entry#*:}"
  out="$(run_lang "$lang" "$bare")"; code=$?
  [ "$code" -ne 0 ] || bad "$lang: a tree without $manifest passed"
  case "$out" in *"$bare/$manifest is missing"*"the $lang suite has nothing to run"*) ;; *) bad "$lang: no message naming the missing $manifest: $out" ;; esac
  grep -Eqx "report-row $lang $lang suite [0-9]+ FAIL suite failed" "$work/bare.rows" \
    || bad "$lang: report row is not 'FAIL suite failed': $(cat "$work/bare.rows" 2>&1)"
  [ "$(wc -l < "$work/bare.rows" | tr -d ' ')" -eq 1 ] || bad "$lang: expected exactly one report row: $(cat "$work/bare.rows")"
  [ ! -s "$work/go.log" ] || bad "$lang: a tool ran without its manifest: $(cat "$work/go.log")"
done

# M2. csharp: a directory without a .csproj fails the same way (the glob matches nothing)
mkdir -p "$bare/csharp"
out="$(run_lang csharp "$bare")"; code=$?
[ "$code" -ne 0 ] || bad "csharp: an empty csharp directory passed"
rmdir "$bare/csharp"

# M3. the manifest present: the suite runs its tool and its exit code is the result (fake tools on PATH)
present="$work/present"
mkdir -p "$present/fixtures" "$present/.github/workflows" "$present/csharp" "$present/rust" "$present/cpp" "$present/java"
cp "$goroot/fixtures/golden.hex" "$present/fixtures/"
cp "$goroot/.github/workflows/report-row.sh" "$present/.github/workflows/"
: > "$present/csharp/Packbin.csproj"; : > "$present/rust/Cargo.toml"; : > "$present/cpp/Makefile"
printf '#!/bin/sh\nexit 0\n' > "$present/java/test.sh"
toolbin="$work/toolbin"
mkdir -p "$toolbin"
for tool in dotnet cargo make; do
  printf '#!/bin/sh\necho "%s $*" >> "$GO_LOG"\ncase "$*" in *--list*) [ -n "${FAKE_NO_SPEED_TEST:-}" ] || echo "text_positions_tests::ac8_one_hundred_thousand_round_trips_of_a_20_character_ukrainian_string: test"; [ -n "${FAKE_NO_ECC_SPEED_TEST:-}" ] || printf "ecc_repair_tests::ec13_repairs_within_the_bound: test\\necc_repair_tests::ec13_packs_within_the_bound: test\\n" ;; esac\n[ -z "${FAKE_WARN_ON:-}" ] || [ "$*" != "$FAKE_WARN_ON" ] || echo "warning: unused import" >&2\n[ -z "${FAKE_FAIL_ON:-}" ] || [ "$*" != "$FAKE_FAIL_ON" ] || exit 101\nexit "${FAKE_TOOL_EXIT:-0}"\n' "$tool" > "$toolbin/$tool"
  chmod +x "$toolbin/$tool"
done
for lang in csharp rust cpp java; do
  rm -f "$work/bare.rows"
  : > "$work/go.log"
  out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
    PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" "$lang" </dev/null 2>&1)"; code=$?
  [ "$code" -eq 0 ] || bad "$lang: a tree with its manifest failed (exit $code): $out"
  grep -Eqx "report-row $lang $lang suite [0-9]+ PASS " "$work/bare.rows" || bad "$lang: no PASS row: $(cat "$work/bare.rows" 2>&1)"
  if [ "$lang" != java ] && [ ! -s "$work/go.log" ]; then bad "$lang: its tool did not run"; fi
  out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
    FAKE_TOOL_EXIT=1 PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" "$lang" </dev/null 2>&1)"; code=$?
  if [ "$lang" != java ] && [ "$code" -eq 0 ]; then bad "$lang: a failing tool passed"; fi
done

# R1. rust runs the string speed test in the release configuration (AZ-2665 AC-1): after the debug suite, a
# `--release --lib` run of the ac8 test, preceded by the release `--list` that proves the test exists
rm -f "$work/bare.rows"; : > "$work/go.log"
env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" rust </dev/null >/dev/null 2>&1
grep -q 'cargo test --manifest-path .* --release --lib -- --list' "$work/go.log" || bad "rust: no release list of the tests: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --release --lib ac8_one_hundred_thousand_round_trips -- --nocapture' "$work/go.log" \
  || bad "rust: the string speed test does not run in the release configuration: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --release --lib ec13_ -- --nocapture' "$work/go.log" \
  || bad "rust: the message ECC speed tests (ec13_) do not run in the release configuration: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --no-default-features --test nostd_flat_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the heap-free API does not run without default features: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --no-default-features --features text --test nostd_text_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the text feature does not run without default features: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --no-default-features --features ecc --test nostd_ecc_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the ecc feature does not run without default features: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --features text,ecc --test nostd_dict_tests --test nostd_text_differential_tests --test nostd_hostile_tests --test nostd_hostile_pack_tests --test nostd_fixture_differential_tests --test nostd_raw_repeat_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the text differential and dictionary tests do not run with the feature on: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --no-default-features --features frame --test frame_vectors_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the frame fixture does not run without default features: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --features frame --test frame_vectors_tests -- --nocapture' "$work/go.log" \
  || bad "rust: the frame fixture does not run with std: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --features frame --lib frame_ -- --nocapture' "$work/go.log" \
  || bad "rust: the frame tests of the crate do not run: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --features frame,ecc --lib frame_ -- --nocapture' "$work/go.log" \
  || bad "rust: the frame tests do not run with ecc on: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --features frame --doc -- --nocapture' "$work/go.log" \
  || bad "rust: the frame doc example does not run: $(cat "$work/go.log")"
grep -q 'cargo test --manifest-path .* --all-features -- --nocapture' "$work/go.log" \
  || bad "rust: the all-features run is missing (AZ-3338 AC-6): $(cat "$work/go.log")"
# the test builds of every target of the 9 feature sets, last, after the release runs (AZ-3357 AC-9)
manifest="$present/rust/Cargo.toml"
expected="cargo check --manifest-path $manifest --no-default-features --tests
cargo check --manifest-path $manifest --no-default-features --features alloc --tests
cargo check --manifest-path $manifest --no-default-features --features text --tests
cargo check --manifest-path $manifest --no-default-features --features ecc --tests
cargo check --manifest-path $manifest --no-default-features --features text,ecc --tests
cargo check --manifest-path $manifest --no-default-features --features frame --tests
cargo check --manifest-path $manifest --no-default-features --features text,ecc,frame --tests
cargo check --manifest-path $manifest --tests
cargo check --manifest-path $manifest --all-features --tests"
[ "$(sed -n '15,23p' "$work/go.log")" = "$expected" ] || bad "rust: lines 15 to 23 are not the 9 test builds: $(cat "$work/go.log")"
[ "$(grep -c '^cargo ' "$work/go.log")" -eq 23 ] || bad "rust: not the debug suite, the nine heap-free API runs, the all-features run, the release list, the two release runs and the 9 test builds: $(cat "$work/go.log")"

# R2. a rust tree without the string speed test fails by name, and the filter is not run (a filter that matches
# nothing passes) (AZ-2665 AC-3)
rm -f "$work/bare.rows"; : > "$work/go.log"
out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  FAKE_NO_SPEED_TEST=1 PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" rust </dev/null 2>&1)"; code=$?
[ "$code" -ne 0 ] || bad "rust: a tree without the string speed test passed"
case "$out" in *"rust has no string speed test"*) ;; *) bad "rust: no message for the missing string speed test: $out" ;; esac
if grep -q 'ac8_one_hundred_thousand_round_trips -- --nocapture' "$work/go.log"; then bad "rust: the speed filter ran without the test: $(cat "$work/go.log")"; fi

# R3. a rust tree without the message ECC speed tests (ec13_) fails by name too, and neither release run starts
rm -f "$work/bare.rows"; : > "$work/go.log"
out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
  FAKE_NO_ECC_SPEED_TEST=1 PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" rust </dev/null 2>&1)"; code=$?
[ "$code" -ne 0 ] || bad "rust: a tree without the message ECC speed tests passed"
case "$out" in *"rust has fewer than two message ECC speed tests"*) ;; *) bad "rust: no message for the missing ECC speed tests: $out" ;; esac
if grep -q -- '--release --lib .* -- --nocapture' "$work/go.log"; then bad "rust: a release run started without the ECC speed tests: $(cat "$work/go.log")"; fi

# R4 and R5. a test build that prints a warning (on stderr, as cargo does) or fails stops the suite, the set is named in
# the output and the report row, and no later set is built (AZ-3357 AC-9)
for row in "warn frame printed a warning" "fail alloc failed"; do
  read -r kind set outcome <<< "$row"
  args="check --manifest-path $manifest --no-default-features --features $set --tests"
  rm -f "$work/bare.rows"; : > "$work/go.log"
  # Act
  if [ "$kind" = warn ]; then fake=(FAKE_WARN_ON="$args"); else fake=(FAKE_FAIL_ON="$args"); fi
  out="$(env SRC_ROOT="$present" FIXTURE="$present/fixtures/golden.hex" TEST_RESULTS="$work/bare" GO_LOG="$work/go.log" \
    "${fake[@]}" PATH="$toolbin:$PATH" perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" rust </dev/null 2>&1)"; code=$?
  # Assert
  [ "$code" -ne 0 ] || bad "rust: a test build of set $set that $outcome passed"
  case "$out" in *"run-suite: rust test build of feature set $set $outcome"*) ;; *) bad "rust: the set $set is not named: $out" ;; esac
  if [ "$kind" = warn ]; then
    case "$out" in *"printed a warning:"*"warning: unused import"*) ;; *) bad "rust: the warning line is not shown: $out" ;; esac
  fi
  grep -Eqx "report-row rust rust suite [0-9]+ FAIL rust test build of feature set $set $outcome" "$work/bare.rows" \
    || bad "rust: the report row does not name the set $set: $(cat "$work/bare.rows" 2>&1)"
  [ "$(tail -n 1 "$work/go.log")" = "cargo $args" ] || bad "rust: a step ran after set $set $outcome: $(cat "$work/go.log")"
done

# --- the timing notice (AZ-2607 AC-2) ---
# On GitHub Actions a run ends with ONE notice on stdout, so the seconds of a CI suite job are readable without a token:
# the title names the suite, the message is every step line of the run and the total line, each escaped (% first, then
# CR and LF) and joined by %0A. The plain lines stay on stderr. notice_run keeps stdout and stderr apart.
notice_run() { # lang tree [VAR=value ...]
  local lang="$1" tree="$2"
  shift 2
  rm -f "$work/notice.rows"
  : > "$work/go.log"
  env SRC_ROOT="$tree" FIXTURE="$tree/fixtures/golden.hex" TEST_RESULTS="$work/notice" GO_LOG="$work/go.log" \
    PATH="$gobin:$toolbin:$PATH" "$@" \
    perl -e 'alarm 60; exec @ARGV' -- bash "$suite_sh" "$lang" </dev/null >"$work/notice.out" 2>"$work/notice.err"
}
notice_is() { # title lang steps: the last notice_run printed one notice, that title over its own step and total lines
  local expected count
  expected="$(grep -E "^run-suite: $2 (step|total) took " "$work/notice.err" \
    | awk '{ gsub(/%/, "%25"); printf "%s%s", (NR > 1 ? "%0A" : ""), $0 }')"
  count="$(grep -c '^::notice' "$work/notice.out")"
  [ "$count" -eq 1 ] || bad "$2: $count notice lines on stdout, not 1: $(cat "$work/notice.out")"
  [ "$(grep -c "^run-suite: $2 step took " "$work/notice.err")" -eq "$3" ] || bad "$2: not $3 step lines: $(cat "$work/notice.err")"
  grep -Eq "^run-suite: $2 total took [0-9]+ s in $3 steps\$" "$work/notice.err" || bad "$2: no total line for $3 steps: $(cat "$work/notice.err")"
  [ "$(grep '^::notice' "$work/notice.out")" = "::notice title=$1::$expected" ] \
    || bad "$2: the notice is not '$1' over the timing lines: $(grep '^::notice' "$work/notice.out")"
}

# N1. a passing go run: one notice titled with the language, over the 6 step lines and the total line
# Act
notice_run go "$goroot" GO_FUZZ=1 GITHUB_ACTIONS=true; code=$?
# Assert
[ "$code" -eq 0 ] || bad "go: a clean tree failed under GITHUB_ACTIONS (exit $code): $(cat "$work/notice.err")"
notice_is "go suite timing" go 6

# N2. a failing step: the notice is still written, with the steps that ran and none of those skipped after it
# Act
notice_run go "$goroot" GO_FUZZ=1 GO_FAIL=test GITHUB_ACTIONS=true; code=$?
# Assert
[ "$code" -ne 0 ] || bad "go: a failing test passed under GITHUB_ACTIONS"
notice_is "go suite timing" go 3
row_file="$work/notice.rows"
grep -Eqx "report-row go go suite [0-9]+ FAIL suite failed" "$row_file" || bad "go: no FAIL row beside the notice: $(cat "$row_file" 2>&1)"

# N3. a label with % in it (the tree path) is escaped as %25, so GitHub does not read it as an escape
# Arrange
cp -R "$goroot" "$work/pct%2Ctree"
# Act
notice_run go "$work/pct%2Ctree" GO_FUZZ=1 GITHUB_ACTIONS=true
# Assert
notice_is "go suite timing" go 6
grep -qF 'pct%252Ctree/go' "$work/notice.out" || bad "go: the % of a label is not escaped as %25: $(cat "$work/notice.out")"
if grep -qF 'pct%2Ctree' "$work/notice.out"; then bad "go: a raw % of a label is in the notice: $(cat "$work/notice.out")"; fi

# N4. a run without steps (no manifest) and a run of another language: one notice each, titled with that language
# Act and assert
notice_run csharp "$bare" GITHUB_ACTIONS=true
notice_is "csharp suite timing" csharp 0
notice_run rust "$present" GITHUB_ACTIONS=true
notice_is "rust suite timing" rust 21

# N5. GITHUB_ACTIONS unset (the Mac), empty or anything but true: no notice, and the plain step lines as before
for value in unset "" false; do
  # Act
  if [ "$value" = unset ]; then notice_run go "$goroot" GO_FUZZ=1; else notice_run go "$goroot" GO_FUZZ=1 GITHUB_ACTIONS="$value"; fi
  # Assert
  if grep -q '::notice' "$work/notice.out" "$work/notice.err"; then bad "go: a notice with GITHUB_ACTIONS $value: $(cat "$work/notice.out")"; fi
  [ "$(grep -c '^run-suite: go step took [0-9]* s: ' "$work/notice.err")" -eq 6 ] || bad "go: the plain step lines changed with GITHUB_ACTIONS $value: $(cat "$work/notice.err")"
done

# N6. the eight suite services pass the runner's GITHUB_ACTIONS into the container as a bare key: Compose sets it from
# the host when it is set there and leaves it out when not (a value would make every Mac run write notices)
# Act
compose_ga="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import yaml_get
svc = yaml_get.load(sys.argv[2])["services"]
def passes_through(name):
    env = (svc.get(name) or {}).get("environment")
    return isinstance(env, dict) and "GITHUB_ACTIONS" in env and env["GITHUB_ACTIONS"] is None
print(" ".join(s for s in "csharp typescript python rust cpp java go swift".split() if not passes_through(s)))' \
  "$here/../../scripts/ci" "${RUN_SUITE_COMPOSE:-$repo/docker-compose.test.yml}" </dev/null)" || bad "docker-compose.test.yml: the suite services could not be read"
# Assert
[ -z "$compose_ga" ] || bad "docker-compose.test.yml: the suite services '$compose_ga' do not pass GITHUB_ACTIONS through as a bare key"

# --- swift (AZ-2521): in its own file, so neither file passes 500 lines ---
# shellcheck source=run-suite-swift.test.sh
. "$here/run-suite-swift.test.sh"

if [ "$fail" -eq 0 ]; then echo "run-suite.test.sh: all checks passed"; fi
exit "$fail"
