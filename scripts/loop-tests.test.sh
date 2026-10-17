#!/usr/bin/env bash
# Tests scripts/loop-tests.sh in a temporary git repository: which stages a change selects, which it skips, and that a
# missing, foreign or dirty state runs (`--plan`); then stages run against stand-ins only (a fake docker, a recording
# make, a stand-in publish gate), never a real suite or the real gate.
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
      *" $stage "*) grep -q "^PLAN $stage RUN" <<< "$out" || bad "$label: $stage was skipped, expected to run: $(echo "$out" | grep "PLAN $stage ")" ;;
      *) grep -q "^PLAN $stage SKIP" <<< "$out" || bad "$label: $stage runs, expected to skip: $(echo "$out" | grep "PLAN $stage ")" ;;
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
grep -q "^PLAN go RUN (stamp .* is not an ancestor" <<< "$out" || bad "foreign stamp: go did not run for that reason: $(echo "$out" | grep 'PLAN go ')"

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
grep -q "^RETRY typescript alone" <<< "$out" || bad "execution: no retry line for typescript: $out"
grep -q "^STAGE typescript: PASS on the serial retry" <<< "$out" || bad "execution: typescript did not pass on the retry: $out"
grep -q "^STAGE rust: PASS" <<< "$out" || bad "execution: rust did not pass: $out"
grep -q "^STAGE java: FAIL again alone" <<< "$out" || bad "execution: java did not fail alone: $out"
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

# 15. the cpp stage does not write cpp/build on the host (AZ-2565). The container mounts the repository, and Docker Desktop
# shows a container started within about a second of a host `rm -rf` the directory as it was: `mkdir -p build` found the
# old one, the link then failed with "cannot open output file build/packbin_tests". The stage cleans inside the container.
# cpp_host_writes <script>: runs the cpp stage with a recording `make` and `docker`; prints a line for each host-side make
# and, when the container command does not clean cpp/build itself, one for that.
cpp_host_writes() {
  local sh="$tmp/cpp-shims" log="$tmp/cpp-calls"
  rm -rf "$sh" "$log"; mkdir -p "$sh"
  printf '#!/bin/sh\necho "host make $*" >> "%s"\n' "$log" > "$sh/make"
  printf '#!/bin/sh\necho "docker $*" >> "%s"\n' "$log" > "$sh/docker"
  chmod +x "$sh/make" "$sh/docker"
  PATH="$sh:$PATH" LOOP_TESTS_ROOT="$repo" LOOP_TESTS_STAMPS="$tmp/cpp-stamps" bash "$1" --all --only cpp < /dev/null > /dev/null 2>&1 || true
  grep '^host make' "$log" || true
  grep -q '^docker .* make -C /src/cpp clean' "$log" || echo "the container command of the cpp stage does not run make -C /src/cpp clean"
}
out="$(cpp_host_writes "$script")"
[ -z "$out" ] || bad "cpp stage: writes cpp/build from the host and from its container (stage cpp, path cpp/build): $out"
# The old stage command put back must be rejected.
mutant="$tmp/loop-tests-old-cpp.sh"
sed 's|^    cpp) docker compose .*|    cpp) make -C cpp clean \&\& docker compose -f docker-compose.test.yml run --rm cpp ;;|' "$script" > "$mutant"
cmp -s "$script" "$mutant" && bad "cpp stage: the mutant (the old command) was not applied"
[ -n "$(cpp_host_writes "$mutant")" ] || bad "cpp stage: the old command (host make clean, then the container) was not rejected"

# 16. the publish-gate stage runs the shares of the CI gate jobs, the --groups lists of test.yml, at the same time; a
# failing share fails it and is named; no share, or a line that names the gate without a list, fails it before anything
# runs; a share that writes into the tree fails it and the path is named (AZ-2607). A stand-in gate in the temporary
# repository logs each call and acts by its group names; its markers are outside the tree.
gate_stub="$tmp/gate"
printf 'test-results/\n.github/workflows/out/\n' > "$repo/.gitignore"
cat > "$repo/.github/workflows/publish-gate.test.sh" <<'STUB'
#!/usr/bin/env bash
# Stand-in gate. Without --groups it passes, as the whole gate would. meet-*: waits at most 10 s until $GATE_MEET meet
# groups started, which only shares that run at the same time do; fail-*: fails; write-*: writes into the tree;
# ignored-*: writes into the ignored test-results/; slow-*: works for 3 s, so a heartbeat sees it run.
set -u
echo "[$*]" >> "$GATE_STUB/calls"
[ "${1:-}" = --groups ] || { echo "publish gate tests passed"; exit 0; }
for g in $(printf '%s' "$2" | tr , ' '); do
  case "$g" in
    meet-*)
      : > "$GATE_STUB/$g.started"
      end=$((SECONDS + 10))
      until [ "$(ls "$GATE_STUB" | grep -c '^meet-.*\.started$')" -ge "$GATE_MEET" ]; do
        [ "$SECONDS" -lt "$end" ] || { echo "FAIL: $g met no other share within 10 s"; exit 1; }
        sleep 0.1
      done ;;
    fail-*) echo "FAIL: stand-in failure in $g"; exit 1 ;;
    write-*) echo stray > stray.txt; echo edit >> csharp/A.cs; chmod +x go/a.go ;;
    ignored-*) mkdir -p test-results .github/workflows/out; echo x > test-results/from-share; echo x > .github/workflows/out/x ;;
    slow-*) echo working; sleep 3 ;;
  esac
  echo "publish-gate: $g took 0 s"
done
echo "publish gate tests passed"
STUB
# gate_run <test.yml>: writes the fixture test.yml and runs the publish-gate stage alone, with a heartbeat every second;
# the output is in $out and the exit code in $code.
gate_run() {
  printf '%s\n' "$1" > "$repo/.github/workflows/test.yml"
  rm -rf "$gate_stub"
  mkdir -p "$gate_stub"
  code=0
  out="$(GATE_STUB="$gate_stub" GATE_MEET=2 LOOP_TESTS_HEARTBEAT=1 LOOP_TESTS_ROOT="$repo" LOOP_TESTS_STAMPS="$tmp/gate-stamps" \
    bash "$script" --all --only publish-gate < /dev/null 2>&1)" || code=$?
}
gate_calls() { if [ -f "$gate_stub/calls" ]; then LC_ALL=C sort "$gate_stub/calls" | paste -sd '|' -; fi; }

# 16a. Arrange: three shares in three spellings, a comment that names the gate, two shares that only meet when they run
# at the same time, a share that writes only ignored paths and one that works long enough for the heartbeat
# Act
gate_run '# The gate jobs; this comment names publish-gate.test.sh --groups and is no share.
jobs:
  publish-gate-one:
    steps:
      - name: publish gate
        run: bash .github/workflows/publish-gate.test.sh --groups meet-a
  publish-gate-two:
    steps:
      - run: |
          set -euo pipefail
          bash .github/workflows/publish-gate.test.sh --groups meet-b,ignored-b
  publish-gate-three:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups slow-c'
# Assert
[ "$code" -eq 0 ] || bad "gate shares: exit $code, expected 0: $out"
[ "$(gate_calls)" = "[--groups meet-a]|[--groups meet-b,ignored-b]|[--groups slow-c]" ] || bad "gate shares: the calls are not the three lists of test.yml: [$(gate_calls)]"
[ "$(echo "$out" | sed -n 's/^\(SHARE [^:]*\): PASS ([0-9]*s)$/\1/p' | paste -sd '|' -)" = "SHARE meet-a|SHARE meet-b,ignored-b|SHARE slow-c" ] \
  || bad "gate shares: no PASS line per share in file order: $out"
grep -Eq '^publish-gate shares: wall [0-9]+s, sum of shares [0-9]+s$' <<< "$out" || bad "gate shares: no wall and sum line: $out"
grep -q '^TREE the same before and after the shares' <<< "$out" || bad "gate shares: writes into ignored paths changed the tree manifest: $out"
grep -Eq '^\[hb\] .*publish-gate\([0-9]+ B;.* slow-c [0-9]+ B' <<< "$out" || bad "gate shares: no heartbeat with the log bytes of the running share: $(echo "$out" | grep '^\[hb\]')"
grep -q '^STAGE publish-gate: PASS' <<< "$out" || bad "gate shares: the stage did not pass: $out"

# 16b. Arrange: a share that passes and one that fails
# Act
gate_run 'jobs:
  publish-gate-a:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups ok-a
  publish-gate-b:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups fail-b'
# Assert
[ "$code" -eq 1 ] || bad "failing share: exit $code, expected 1: $out"
grep -q '^SHARE fail-b: FAIL ([0-9]*s, exit 1) log ' <<< "$out" || bad "failing share: not named as failed: $out"
grep -q '^    | FAIL: stand-in failure in fail-b$' <<< "$out" || bad "failing share: the tail of its log is not shown: $out"
grep -q '^SHARE ok-a: PASS' <<< "$out" || bad "failing share: the passing share is not shown as passed: $out"
grep -q '^STAGE publish-gate: FAIL' <<< "$out" || bad "failing share: the stage did not fail: $out"

# 16c. Arrange: a test.yml whose only mention of the gate is a comment
# Act
gate_run 'jobs:
  scaffold:
    steps:
      # publish-gate.test.sh --groups is named in this comment only
      - run: bash scripts/loop-tests.test.sh'
# Assert
[ "$code" -eq 1 ] || bad "no share: exit $code, expected 1: $out"
grep -qF "has no line \`bash .github/workflows/publish-gate.test.sh --groups <a,b,..>\`" <<< "$out" || bad "no share: no message: $out"
[ -z "$(gate_calls)" ] || bad "no share: the gate ran without --groups lines (a fallback to the whole gate): [$(gate_calls)]"

# 16d. Arrange: one share and one line that runs the whole gate
# Act
gate_run 'jobs:
  publish-gate-a:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups ok-a
  publish-gate-b:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh'
# Assert
[ "$code" -eq 1 ] || bad "malformed share: exit $code, expected 1: $out"
grep -q 'test.yml:7 names the gate but is not' <<< "$out" || bad "malformed share: the line is not named: $out"
[ -z "$(gate_calls)" ] || bad "malformed share: a share ran before the list was refused: [$(gate_calls)]"

# 16e. Arrange: a share that adds an untracked file, edits a tracked one and makes one executable, beside one that passes
# Act
gate_run 'jobs:
  publish-gate-a:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups write-a
  publish-gate-b:
    steps:
      - run: bash .github/workflows/publish-gate.test.sh --groups ok-b'
# Assert
[ "$code" -eq 1 ] || bad "tree write: exit $code, expected 1: $out"
grep -q '^TREE changed while the shares ran (3 paths' <<< "$out" || bad "tree write: the changed tree is not reported: $out"
for path in stray.txt csharp/A.cs go/a.go; do
  grep -qx "    | $path" <<< "$out" || bad "tree write: $path is not named: $out"
done
grep -q '^STAGE publish-gate: FAIL' <<< "$out" || bad "tree write: the stage did not fail: $out"
rm -f "$repo/stray.txt"
chmod -x "$repo/go/a.go"
git -C "$repo" checkout -q csharp/A.cs

if [ "$fail" -eq 0 ]; then echo "loop-tests.test.sh: all checks passed"; fi
exit "$fail"
