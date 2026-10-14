#!/usr/bin/env bash
# Tests the stage selection of scripts/loop-tests.sh in a temporary git repository: which stages a change selects,
# which it skips, and that a missing, foreign or dirty state runs. Only `--plan` is used: no stage runs.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/loop-tests.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
stamps="$tmp/stamps"
fail=0
bad() { echo "FAIL: $1"; fail=1; }

git init -q "$repo"
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
mkdir -p "$repo/csharp/tests" "$repo/typescript" "$repo/go" "$repo/swift/Sources" "$repo/swift/Tests" "$repo/cpp/include" "$repo/cpp/tests" "$repo/fixtures" "$repo/.github/workflows"
for f in csharp/A.cs csharp/tests/T.cs typescript/a.ts go/a.go go/a_test.go swift/Sources/a.swift swift/Tests/t.swift Package.swift cpp/include/a.hpp cpp/tests/t.cpp README.md \
  fixtures/golden.hex .github/workflows/publish.yml .github/workflows/language-pair.sh .github/workflows/test.yml; do
  echo "$f" > "$repo/$f"
done
git -C "$repo" add -A
git -C "$repo" commit -q -m base

stages="go typescript csharp python rust java cpp swift scaffold cpp-embedded-arm ring ac10 publish-gate"
plan() { LOOP_TESTS_ROOT="$repo" LOOP_TESTS_STAMPS="$stamps" bash "$script" --plan "$@"; }
stamp_all() {
  mkdir -p "$stamps"
  for s in $stages; do git -C "$repo" rev-parse HEAD > "$stamps/$s"; done
}
change() { # file: edit and commit
  echo "edit $RANDOM" >> "$repo/$1"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "edit $1"
}
# expect <label> <run list> : every stage in the list runs, every other one is skipped.
expect() {
  local label="$1" want=" $2 " out stage
  out="$(plan)"
  for stage in $stages; do
    case "$want" in
      *" $stage "*) echo "$out" | grep -q "^PLAN $stage RUN" || bad "$label: $stage was skipped, expected to run: $(echo "$out" | grep "PLAN $stage ")" ;;
      *) echo "$out" | grep -q "^PLAN $stage SKIP" || bad "$label: $stage runs, expected to skip: $(echo "$out" | grep "PLAN $stage ")" ;;
    esac
  done
}

# 1. no stamps: everything runs
out="$(plan)"
[ "$(echo "$out" | grep -c ' RUN (no stamp')" -eq 13 ] || bad "no stamps: not all 13 stages run: $out"

# 2. stamped at HEAD and nothing changed: everything skips
stamp_all
expect "unchanged" ""

# 3. a C# source file: the C# suite, the ring and AC-10; not the publish gate (no file added or removed)
change csharp/A.cs; expect "csharp source" "csharp ring ac10"; stamp_all

# 4. a C# test file: the C# suite and AC-10 only
change csharp/tests/T.cs; expect "csharp test" "csharp ac10"; stamp_all

# 5. README.md is packed: only the publish gate
change README.md; expect "readme" "publish-gate"; stamp_all

# 6. a file added in a package changes what the gate packs
echo new > "$repo/csharp/New.cs"; git -C "$repo" add -A; git -C "$repo" commit -q -m add
expect "added source file" "csharp ring ac10 publish-gate"; stamp_all

# 7. a C++ header: the C++ suite, the ARM stage and the ring; a C++ test: the C++ suite only
change cpp/include/a.hpp; expect "cpp header" "cpp cpp-embedded-arm ring"; stamp_all
change cpp/tests/t.cpp; expect "cpp test" "cpp"; stamp_all

# 8. a Go test file: the Go suite only
change go/a_test.go; expect "go test" "go"; stamp_all

# 8b. Swift: a test file runs both Swift suites only; a source file also the ring; the manifest also the scaffold and the gate
change swift/Tests/t.swift; expect "swift test" "swift"; stamp_all
change swift/Sources/a.swift; expect "swift source" "swift ring"; stamp_all
change Package.swift; expect "swift manifest" "swift scaffold ring publish-gate"; stamp_all

# 9. the golden row and fixtures: every suite, the scaffold, the ring and the gate
change fixtures/golden.hex
expect "fixtures" "go typescript csharp python rust java cpp swift scaffold ring publish-gate"; stamp_all

# 9b. test.yml is parsed by the gate's own test and checked by the scaffold: both run, no suite
change .github/workflows/test.yml; expect "test.yml" "scaffold publish-gate"; stamp_all

# 10. a tracked change that is not committed
echo dirty >> "$repo/typescript/a.ts"; expect "dirty tree" "typescript ring"; git -C "$repo" checkout -q typescript/a.ts

# 11. an untracked new file counts as added
echo new > "$repo/go/b.go"; expect "untracked file" "go ring publish-gate"; rm "$repo/go/b.go"

# 12. a stamp that is not an ancestor of HEAD runs the stage
git -C "$repo" checkout -q --orphan other
git -C "$repo" commit -q -m orphan --allow-empty
git -C "$repo" rev-parse HEAD > "$stamps/go"
git -C "$repo" checkout -q -f master 2> /dev/null || git -C "$repo" checkout -q -f main
out="$(plan)"
echo "$out" | grep -q "^PLAN go RUN (stamp .* is not an ancestor" || bad "foreign stamp: go did not run for that reason: $(echo "$out" | grep 'PLAN go ')"

# 13. --all runs everything; --only picks the listed stages
stamp_all
[ "$(plan --all | grep -c ' RUN (--all)')" -eq 13 ] || bad "--all: not all 13 stages run"
out="$(plan --only ring,ac10)"
[ "$(echo "$out" | grep -cE '^PLAN [a-z0-9-]+ (RUN|SKIP)')" -eq 2 ] || bad "--only ring,ac10 did not list exactly two stages: $out"

# 14. execution with a fake docker: a suite that fails beside the others is re-run alone and both results show; one that
# fails again fails the run; only a stage that passed on a clean tree gets a stamp
shims="$tmp/shims"
mkdir -p "$shims" "$tmp/calls"
cat > "$shims/docker" <<'SHIM'
#!/bin/sh
for a; do svc="$a"; done
n=$(cat "$CALLS/$svc" 2> /dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$CALLS/$svc"
[ "$svc" = java ] && exit 1
[ "$svc" = typescript ] && [ "$n" -eq 1 ] && exit 1
exit 0
SHIM
chmod +x "$shims/docker"
rm -rf "$stamps"
code=0
out="$(PATH="$shims:$PATH" CALLS="$tmp/calls" LOOP_TESTS_ROOT="$repo" LOOP_TESTS_STAMPS="$stamps" bash "$script" --all --only typescript,rust,java < /dev/null)" || code=$?
[ "$code" -eq 1 ] || bad "execution: exit $code, expected 1 (java fails twice): $out"
echo "$out" | grep -q "^RETRY typescript alone" || bad "execution: no retry line for typescript: $out"
echo "$out" | grep -q "^STAGE typescript: PASS on the serial retry" || bad "execution: typescript did not pass on the retry: $out"
echo "$out" | grep -q "^STAGE rust: PASS" || bad "execution: rust did not pass: $out"
echo "$out" | grep -q "^STAGE java: FAIL again alone" || bad "execution: java did not fail alone: $out"
head_sha="$(git -C "$repo" rev-parse HEAD)"
[ "$(cat "$stamps/typescript")" = "$head_sha" ] || bad "execution: typescript has no stamp at HEAD"
[ "$(cat "$stamps/rust")" = "$head_sha" ] || bad "execution: rust has no stamp at HEAD"
[ ! -f "$stamps/java" ] || bad "execution: java got a stamp although it failed"
[ "$(cat "$tmp/calls/typescript")" -eq 2 ] || bad "execution: typescript ran $(cat "$tmp/calls/typescript") times, expected 2"
# a stamp is not written from a dirty tree
rm -rf "$stamps"
echo dirty >> "$repo/README.md"
PATH="$shims:$PATH" CALLS="$tmp/calls" LOOP_TESTS_ROOT="$repo" LOOP_TESTS_STAMPS="$stamps" bash "$script" --all --only rust < /dev/null > /dev/null || bad "execution: rust failed on the dirty tree"
[ ! -f "$stamps/rust" ] || bad "execution: a stamp was written from a dirty tree"

if [ "$fail" -eq 0 ]; then echo "loop-tests.test.sh: all checks passed"; fi
exit "$fail"
