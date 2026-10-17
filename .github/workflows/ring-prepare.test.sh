#!/usr/bin/env bash
# Test of ring-prepare.sh (AZ-2626 AC-3 to AC-5) in a temp tree with stand-in docker, npm, cargo, ring-go.sh and
# ring-swift.sh: start returns while the pulls and the Swift build go on, the second pull and the Swift build follow
# each other, build runs its three builds at the same time, wait names a failed, skipped or hung build with its log,
# and prints one timing notice on GitHub Actions only. The driver paths are the ones language-pair.sh reads. Mutants of
# the script (no background, serial builds, failures ignored) must each be caught.
# shellcheck disable=SC2016 # the sed expressions and the mutant checks are single-quoted on purpose
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
tmp="$(mktemp -d)"
trap 'touch "$tmp/stop"; rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }

# Both defaults must be the paths language-pair.sh runs the drivers from, or the ring builds them again.
for default in 'PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift' 'PACKBIN_GO_HANDOFF:-/tmp/packbin-handoff-go'; do
  grep -qF "$default" "$here/language-pair.sh" || fail "language-pair.sh does not read $default"
  grep -qF "$default" "$here/ring-prepare.sh" || fail "ring-prepare.sh does not build to $default"
done

# stand_in <path> <name expression>: a stand-in command that logs its call and working directory, sleeps FAKE_SLEEP
# seconds and logs "end <name>"; it fails when FAKE_FAIL names it and blocks (until $tmp/stop, at most 30 s) when
# FAKE_HANG does. Order checks read the log, not the clock: a loaded host makes every step slower, not reordered.
stand_in() {
  cat > "$1" <<EOF
#!/usr/bin/env bash
name=$2
EOF
  cat >> "$1" <<'EOF'
echo "$(basename "$0") $* @ $PWD" >> "$FAKE_LOG"
if [ "${FAKE_HANG:-}" = "$name" ]; then
  for _ in $(seq 150); do [ -f "$FAKE_STOP" ] && break; sleep 0.2; done
fi
sleep "${FAKE_SLEEP:-0}"
echo "end $name" >> "$FAKE_LOG"
if [ "${FAKE_FAIL:-}" = "$name" ]; then
  echo "stand-in $name failed on purpose"
  exit 3
fi
echo "stand-in $name done"
EOF
  chmod +x "$1"
}

# tree <dir> [<script>]: a repo tree with the script under test (default: the real one) and the stand-ins.
tree() {
  local t="$1"
  mkdir -p "$t/.github/workflows/drivers/handoff-rust" "$t/typescript" "$t/bin"
  cp "${2:-$here/ring-prepare.sh}" "$t/.github/workflows/ring-prepare.sh"
  stand_in "$t/.github/workflows/ring-swift.sh" swift-drivers
  stand_in "$t/.github/workflows/ring-go.sh" go
  stand_in "$t/bin/npm" npm
  stand_in "$t/bin/cargo" cargo
  # shellcheck disable=SC2016 # the stand-in names a pull by its image
  stand_in "$t/bin/docker" '"pull-${3%%:*}"'
}

# run_all <tree>: start, build, wait (exit statuses in start_rc, build_rc, wait_rc; start_ms, wait_ms); output in <tree>/out.
# start_early is yes when start returned before the swift pull finished.
run_all() {
  local t="$1" s="$1/.github/workflows/ring-prepare.sh" state="$1/state" ms
  export FAKE_LOG="$t/calls" FAKE_STOP="$tmp/stop" PACKBIN_SWIFT_RING="$t/swift-out" PACKBIN_GO_HANDOFF="$t/go-out"
  ms=$(now_ms)
  start_rc=0
  PATH="$t/bin:$PATH" bash "$s" start "$state" gcc:16 swift:6.3.3 > "$t/out" 2>&1 < /dev/null || start_rc=$?
  start_ms=$(( $(now_ms) - ms ))
  # Whether start returned while the swift pull still ran.
  start_early=yes
  [ -f "$state/pull-swift.rc" ] && start_early=no
  build_rc=0
  PATH="$t/bin:$PATH" bash "$s" build "$state" >> "$t/out" 2>&1 < /dev/null || build_rc=$?
  ms=$(now_ms)
  wait_rc=0
  PATH="$t/bin:$PATH" bash "$s" wait "$state" >> "$t/out" 2>&1 < /dev/null || wait_rc=$?
  wait_ms=$(( $(now_ms) - ms ))
}

has() { grep -qF -- "$2" "$1/out" || fail "$3: the output has no '$2'"; }

# overlap <tree>: npm, cargo and the Go build all began before the first of them ended.
overlap() {
  local last_begin first_end
  last_begin="$(grep -nE '^(npm|cargo|ring-go\.sh) ' "$1/calls" | tail -n 1 | cut -d: -f1)"
  first_end="$(grep -nE '^end (npm|cargo|go)$' "$1/calls" | head -n 1 | cut -d: -f1)"
  [ -n "$last_begin" ] && [ -n "$first_end" ] && [ "$last_begin" -lt "$first_end" ]
}

# 1. Success, each stand-in 2 s: start returns at once, the three builds overlap, every build is timed.
t="$tmp/ok"
tree "$t"
FAKE_SLEEP=2 GITHUB_ACTIONS=true run_all "$t"
[ "$start_rc$build_rc$wait_rc" = 000 ] || fail "success: exit statuses $start_rc $build_rc $wait_rc ($(cat "$t/out"))"
[ "$start_early" = yes ] || fail "success: start returned after the swift pull finished ($start_ms ms)"
overlap "$t" || fail "success: a build ended before all three began ($(tr '\n' ';' < "$t/calls"))"
for name in pull-gcc pull-swift swift-drivers npm cargo go; do has "$t" "ring-prepare: $name took " success; done
[ "$(grep -c '^::notice title=ring preparation timing::' "$t/out")" = 1 ] || fail "success: not exactly one notice"
grep -q '^::notice .*swift-drivers took [0-9]* s%0A.*%0Aring-prepare: the wait took' "$t/out" \
  || fail "success: the notice does not carry the build lines and the wait line"
for call in "docker pull --quiet gcc:16 @" "docker pull --quiet swift:6.3.3 @" "ring-swift.sh $t/swift-out @" \
  "npm ci @ $t/typescript" "cargo build --quiet --manifest-path $t/.github/workflows/drivers/handoff-rust/Cargo.toml @" \
  "ring-go.sh $t/go-out @"; do
  grep -qF -- "$call" "$t/calls" || fail "success: no call '$call' ($(tr '\n' ';' < "$t/calls"))"
done
[ "$(grep -n '^end pull-swift$' "$t/calls" | cut -d: -f1)" -lt "$(grep -n '^ring-swift.sh ' "$t/calls" | cut -d: -f1)" ] \
  || fail "success: the Swift build started before the swift image pull ended"
[ "$(grep -n '^docker pull ' "$t/calls" | tail -n 1 | cut -d: -f1)" -lt "$(grep -n '^end pull-' "$t/calls" | head -n 1 | cut -d: -f1)" ] \
  || fail "success: an image pull ended before the other began"

# 2. No notice outside GitHub Actions.
t="$tmp/local"
tree "$t"
GITHUB_ACTIONS=false run_all "$t"
if grep -q '::notice' "$t/out"; then fail "local: a notice annotation outside GitHub Actions"; fi

# 3 to 6. Failures: wait (or build) fails, names the build and prints its log.
for case in "swift-drivers:wait:ring-prepare: swift-drivers failed (exit 3)" \
  "pull-gcc:wait:ring-prepare: pull-gcc failed (exit 3)" \
  "pull-swift:wait:ring-prepare: swift-drivers did not run" \
  "cargo:build:ring-prepare: cargo failed (exit 3)"; do
  name="${case%%:*}" rest="${case#*:}"
  step="${rest%%:*}" message="${rest#*:}"
  t="$tmp/fail-$name"
  tree "$t"
  FAKE_FAIL="$name" run_all "$t"
  if [ "$step" = wait ]; then
    [ "$build_rc" = 0 ] && [ "$wait_rc" != 0 ] || fail "$name fails: build exited $build_rc, wait $wait_rc"
  else
    [ "$build_rc" != 0 ] || fail "$name fails: build passed"
  fi
  has "$t" "$message" "$name fails"
  has "$t" "stand-in $name failed on purpose" "$name fails (its log)"
done
grep -q 'ring-swift.sh' "$tmp/fail-pull-swift/calls" && fail "pull-swift fails: the Swift build still ran"
for name in npm go; do
  [ "$(cat "$tmp/fail-cargo/state/$name.rc")" = 0 ] || fail "cargo fails: $name did not finish"
done

# 7. A hung build: wait gives up at the limit and names it.
t="$tmp/hang"
tree "$t"
FAKE_HANG=swift-drivers PACKBIN_RING_WAIT_SECONDS=2 run_all "$t"
[ "$wait_rc" != 0 ] || fail "hang: wait passed"
[ "$wait_ms" -ge 1500 ] && [ "$wait_ms" -lt 6000 ] || fail "hang: wait took $wait_ms ms against a 2 s limit"
has "$t" "ring-prepare: swift-drivers did not finish" hang
touch "$tmp/stop"

# 8. Usage and state dir rules.
t="$tmp/rules"
tree "$t"
s="$t/.github/workflows/ring-prepare.sh"
rc=0; bash "$s" start < /dev/null > /dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "rules: one argument exited $rc, not 2"
rc=0; bash "$s" start "$t/nos" < /dev/null > /dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] && [ ! -e "$t/nos" ] || fail "rules: start without an image exited $rc or made the state dir"
mkdir "$t/taken"
rc=0; bash "$s" start "$t/taken" gcc:16 < /dev/null > /dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] || fail "rules: start on an existing dir exited $rc, not 1"
for sub in build wait; do
  rc=0; bash "$s" "$sub" "$t/taken" < /dev/null > /dev/null 2>&1 || rc=$?
  [ "$rc" = 1 ] || fail "rules: $sub on a dir start did not make exited $rc, not 1"
done

# 9. Mutants of the script: each must make one of the checks above fail.
# mutant <label> <sed expression> <check>: <check> is a shell condition on the run of the mutated copy.
mutant() {
  local t="$tmp/m$((++mutants))"
  sed "$2" "$here/ring-prepare.sh" > "$tmp/mutant.sh"
  cmp -s "$here/ring-prepare.sh" "$tmp/mutant.sh" && { fail "mutant unchanged: $1"; return; }
  tree "$t" "$tmp/mutant.sh"
  FAKE_SLEEP=1 FAKE_FAIL="${MUTANT_FAIL:-}" run_all "$t"
  if eval "$3"; then echo "caught: $1"; else fail "mutant not caught: $1"; fi
}
mutants=0
mutant "start in the foreground" 's/^    ) < \/dev\/null > "\$dir\/start.log" 2>&1 &$/    ) < \/dev\/null > "$dir\/start.log" 2>\&1/' \
  '[ "$start_early" = no ]'
mutant "builds one after the other" '/^    task [cgn][a-z]* /s/ &$//' '! overlap "$t"'
MUTANT_FAIL=swift-drivers mutant "wait ignores a failed build" 's/failures \$background || rc=1/failures $background || true/' \
  '[ "$wait_rc" = 0 ]'
MUTANT_FAIL=pull-swift mutant "Swift build after a failed pull" 's/= 0 \]; then$/!= x ]; then/' \
  'grep -q ring-swift.sh "$t/calls"'
touch "$tmp/stop"

if [ "$failures" -ne 0 ]; then
  echo "ring-prepare.test.sh: $failures failure(s)" >&2
  exit 1
fi
echo "ring-prepare.test.sh: all checks passed ($mutants mutants caught)"
