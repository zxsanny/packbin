#!/usr/bin/env bash
# The loop's test stages (step 11 and the loop smoke), one script. A stage runs only when a file it covers changed
# since the commit where it last passed here (a stamp in test-results/stamps); --all runs every stage. The language
# suites run in parallel (--jobs, default 3); a suite that fails in the pool is re-run once alone and both results
# are printed. The scaffold, the ARM stage, the ring, AC-10 and the publish gate run one after the other afterwards:
# the gate hashes the repository tree, so nothing else may write to it while it runs. The publish gate runs as the
# shares of its CI jobs (the --groups lists of test.yml), all at the same time, and fails when the tree changed.
#
# Usage: scripts/loop-tests.sh [--plan] [--all] [--serial] [--jobs N] [--only a,b]
# Exit: 0 every selected stage passed, 1 a stage failed, 2 usage.
# Environment: LOOP_TESTS_ROOT (repository, default the one holding this script), LOOP_TESTS_STAMPS (default
# test-results/stamps), LOOP_TESTS_PYTHON (a Python 3.10+ for the ring, default /opt/homebrew/bin/python3.14),
# LOOP_TESTS_HEARTBEAT (seconds between [hb] lines, default 30).
# No `set -u`: bash 3.2 (macOS) treats an empty array expansion as an unbound variable.
set -o pipefail

root="${LOOP_TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" || exit 2
stamps="${LOOP_TESTS_STAMPS:-$root/test-results/stamps}"
all=0
plan_only=0
jobs=3
only=""
hb_every="${LOOP_TESTS_HEARTBEAT:-30}"
case "$hb_every" in "" | *[!0-9]* | 0) echo "LOOP_TESTS_HEARTBEAT must be a number of seconds above 0" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --all) all=1 ;;
    --plan) plan_only=1 ;;
    --serial) jobs=1 ;;
    --jobs) shift; jobs="${1:?--jobs needs a number}" ;;
    --only) shift; only="${1:?--only needs a list}" ;;
    *) echo "usage: scripts/loop-tests.sh [--plan] [--all] [--serial] [--jobs N] [--only a,b]" >&2; exit 2 ;;
  esac
  shift
done

pool_stages="go typescript csharp python rust java cpp swift scaffold"
serial_stages="cpp-embedded-arm ring ac10 publish-gate"

is_test_path() {
  case "$1" in
    */tests/* | */test/* | java/src/test/* | *_test.go | go/testdata/* | swift/Tests/*) return 0 ;;
  esac
  return 1
}

suite_shared() {
  case "$1" in
    fixtures/* | docker-compose.test.yml | .github/workflows/run-suite.sh | .github/workflows/report-row.sh) return 0 ;;
    .github/workflows/tool-pin.sh | .github/workflows/tool-pins.txt) return 0 ;;
  esac
  return 1
}

# covers <stage> <path>: 0 when a change to <path> can change what <stage> proves.
covers() {
  local stage="$1" f="$2"
  case "$stage" in
    scaffold)
      case "$f" in .github/* | fixtures/* | cpp/embedded/* | docker-compose* | scripts/* | go/go.mod | Package.swift) return 0 ;; esac ;;
    csharp | typescript | python | rust | java | go | cpp)
      case "$f" in "$stage"/*) return 0 ;; esac
      suite_shared "$f" && return 0 ;;
    swift)
      case "$f" in swift/* | Package.swift | Package.resolved) return 0 ;; esac
      suite_shared "$f" && return 0 ;;
    cpp-embedded-arm)
      case "$f" in cpp/include/* | cpp/src/* | cpp/embedded/* | cpp/Makefile | docker-compose.test.yml) return 0 ;; esac ;;
    ring)
      is_test_path "$f" && return 1
      case "$f" in
        csharp/* | typescript/* | python/* | rust/* | java/* | go/* | swift/* | Package.swift | Package.resolved | cpp/include/* | cpp/src/*) return 0 ;;
        .github/workflows/language-pair.sh | .github/workflows/ring-* | .github/workflows/drivers/* | fixtures/* | scripts/ecc/*) return 0 ;;
      esac ;;
    ac10)
      case "$f" in csharp/*) return 0 ;; esac ;;
    publish-gate)
      case "$f" in
        .github/workflows/publish* | .github/workflows/tool-pin* | docker-compose* | README.md | LICENSE | go/LICENSE) return 0 ;;
        .github/workflows/test.yml | .github/workflows/run-suite.sh | .github/workflows/ring-* | .github/workflows/drivers/*) return 0 ;;
        */package.json | typescript/package-lock.json | csharp/*.csproj | python/pyproject.toml | rust/Cargo.*) return 0 ;;
        java/test.sh | cpp/library.json | cpp/idf_component.yml | cpp/CMakeLists.txt | go/go.mod | go/go.sum | Package.swift | Package.resolved) return 0 ;;
        fixtures/golden.hex) return 0 ;;
      esac ;;
  esac
  return 1
}

# A file added, deleted or renamed in a package changes what the publish gate packs.
changes_package_files() {
  is_test_path "$1" && return 1
  case "$1" in csharp/* | typescript/* | python/* | rust/* | java/* | cpp/* | go/* | swift/*) return 0 ;; esac
  return 1
}

# changed_since <base>: "status<TAB>path[<TAB>path]" for the commits after <base>, the tracked working tree changes
# and the untracked files.
changed_since() {
  git diff --name-status "$1" HEAD
  git diff --name-status HEAD
  git ls-files --others --exclude-standard | sed 's/^/A\t/'
}

reason=""
decide() {
  local stage="$1" stamp="$stamps/$1" base st p1 p2 p
  if [ "$all" -eq 1 ]; then reason="--all"; return 0; fi
  if [ ! -f "$stamp" ]; then reason="no stamp: never passed here"; return 0; fi
  base="$(cat "$stamp")"
  if ! git merge-base --is-ancestor "$base" HEAD; then
    reason="stamp ${base:0:7} is not an ancestor of HEAD"
    return 0
  fi
  while IFS=$'\t' read -r st p1 p2; do
    [ -n "$st" ] || continue
    for p in "$p1" ${p2:+"$p2"}; do
      if covers "$stage" "$p"; then reason="$p changed since ${base:0:7}"; return 0; fi
      if [ "$stage" = publish-gate ]; then
        case "$st" in A* | D* | R*)
          if changes_package_files "$p"; then reason="$p added, deleted or renamed since ${base:0:7}"; return 0; fi ;;
        esac
      fi
    done
  done < <(changed_since "$base")
  reason="unchanged since ${base:0:7}"
  return 1
}

wanted() {
  [ -z "$only" ] && return 0
  case ",$only," in *",$1,"*) return 0 ;; esac
  return 1
}

selected=""
skipped=""
echo "PLAN at $(git rev-parse --short HEAD), tree: $(git status --porcelain | wc -l | tr -d ' ') changed paths"
for stage in $pool_stages $serial_stages; do
  wanted "$stage" || continue
  if decide "$stage"; then
    selected="$selected $stage"
    echo "PLAN $stage RUN ($reason)"
  else
    skipped="$skipped $stage"
    echo "PLAN $stage SKIP ($reason)"
  fi
done
[ "$plan_only" -eq 1 ] && exit 0

logs="$(mktemp -d)"
export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
ring_env=()
if [ -x "${LOOP_TESTS_PYTHON:-/opt/homebrew/bin/python3.14}" ]; then
  mkdir -p "$logs/py"
  ln -sf "${LOOP_TESTS_PYTHON:-/opt/homebrew/bin/python3.14}" "$logs/py/python3"
  ring_env+=(PATH="$logs/py:$PATH")
fi
if command -v xcrun > /dev/null; then ring_env+=(PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"); fi
mkdir -p test-results "$stamps"

# The publish gate runs as the shares of its CI jobs (AZ-2607). A share is a line of test.yml that is, once trimmed and
# without a leading `- ` or `run: `, `bash .github/workflows/publish-gate.test.sh --groups <a,b,..>`; test.yml is the one
# list. Another line that names the gate, or no share at all, fails the stage: it never falls back to the whole gate.
gate_workflow=".github/workflows/test.yml"
gate_command="bash .github/workflows/publish-gate.test.sh"

# gate_shares <file>: writes the group list of every share to <file>, one per line in file order. Prints the reason
# and returns 1 when test.yml has no share, or a line that names the gate and is not one.
gate_shares() {
  local out="$1" line body list n=0
  : > "$out"
  if [ ! -f "$gate_workflow" ]; then
    echo "publish-gate: no $gate_workflow, so no shares to run"
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in '#'*) continue ;; *publish-gate.test.sh*) ;; *) continue ;; esac
    body="${line#- }"
    body="${body#run: }"
    list="${body#"$gate_command --groups "}"
    case "$list" in
      "$body" | "" | *[!a-z0-9,-]* | ,* | *, | *,,*)
        echo "publish-gate: $gate_workflow:$n names the gate but is not \`$gate_command --groups <a,b,..>\`: $line"
        return 1 ;;
    esac
    printf '%s\n' "$list" >> "$out"
  done < "$gate_workflow"
  if [ ! -s "$out" ]; then
    echo "publish-gate: $gate_workflow has no line \`$gate_command --groups <a,b,..>\`; the stage does not fall back to the whole gate"
    return 1
  fi
}

# tree_manifest <file>: one sorted line per tracked file and per untracked file that is not ignored: the hash of its
# content, x when it is executable (- when not) and the path; a tracked file that is gone is "missing -". Ignored paths
# (test-results/, .github/workflows/out/) are left out.
tree_manifest() {
  local path
  git ls-files -z --cached --others --exclude-standard | tr '\0' '\n' | LC_ALL=C sort -u > "$1.paths" || return 1
  while IFS= read -r path; do
    if [ ! -f "$path" ]; then
      printf 'm %s\n' "$path"
    elif [ -x "$path" ]; then
      printf 'x %s\n' "$path"
    else
      printf -- '- %s\n' "$path"
    fi
  done < "$1.paths" > "$1.kinds"
  sed -n 's/^[x-] //p' "$1.kinds" > "$1.present"
  sed -n 's/^\([x-]\) .*/\1/p' "$1.kinds" > "$1.modes"
  git hash-object --no-filters --stdin-paths < "$1.present" > "$1.hashes" || return 1
  { paste -d ' ' "$1.hashes" "$1.modes" "$1.present"; sed -n 's/^m /missing - /p' "$1.kinds"; } | LC_ALL=C sort > "$1"
}

# tree_changes <before> <after>: the paths whose manifest line differs, one per line.
tree_changes() {
  LC_ALL=C comm -3 "$1" "$2" | sed 's/^[[:space:]]*//; s/^[^ ]* [^ ]* //' | LC_ALL=C sort -u
}

# run_gate_shares: the publish-gate stage. Every share starts as its own process, its log next to the stage log, before
# any is waited for; then one line per share, the wall and summed seconds, and the tree check: on CI each gate job has
# its own checkout, here the shares share one tree, so a share that writes into it fails the stage.
run_gate_shares() {
  local shares="$logs/publish-gate.shares" list i=0 pids="" pid start wall sum=0 rc secs note failed=0 changed n
  if ! gate_shares "$shares"; then return 1; fi
  if ! tree_manifest "$logs/publish-gate.tree-before"; then echo "publish-gate: no tree manifest before the shares"; return 1; fi
  start=$(date +%s)
  while IFS= read -r list; do
    i=$((i + 1))
    (
      s=$(date +%s)
      rc=0
      env "${ring_env[@]}" bash .github/workflows/publish-gate.test.sh --groups "$list" || rc=$?
      echo "$rc $(( $(date +%s) - s ))" > "$logs/publish-gate.share-$i.end"
    ) < /dev/null > "$logs/publish-gate.share-$i.log" 2>&1 &
    pids="$pids $!"
  done < "$shares"
  for pid in $pids; do wait "$pid"; done
  wall=$(( $(date +%s) - start ))
  i=0
  while IFS= read -r list; do
    i=$((i + 1))
    rc="none" secs=0
    if [ -s "$logs/publish-gate.share-$i.end" ]; then read -r rc secs < "$logs/publish-gate.share-$i.end"; fi
    sum=$((sum + secs))
    note="$(grep -o 'NOT RUN: .*' "$logs/publish-gate.share-$i.log" | tail -n 1)"
    if [ "$rc" = 0 ]; then
      echo "SHARE $list: PASS (${secs}s)${note:+; $note}"
    else
      failed=1
      echo "SHARE $list: FAIL (${secs}s, exit $rc) log $logs/publish-gate.share-$i.log"
      tail -n 8 "$logs/publish-gate.share-$i.log" | sed 's/^/    | /'
    fi
  done < "$shares"
  echo "publish-gate shares: wall ${wall}s, sum of shares ${sum}s"
  if ! tree_manifest "$logs/publish-gate.tree-after"; then echo "publish-gate: no tree manifest after the shares"; return 1; fi
  changed="$(tree_changes "$logs/publish-gate.tree-before" "$logs/publish-gate.tree-after")"
  if [ -n "$changed" ]; then
    failed=1
    n=$(printf '%s\n' "$changed" | wc -l | tr -d ' ')
    echo "TREE changed while the shares ran ($n paths; on CI each gate job has its own checkout):"
    echo "    a share wrote them, or something else (an editor, another run) changed the repository while this stage ran"
    printf '%s\n' "$changed" | head -n 10 | sed 's/^/    | /'
    if [ "$n" -gt 10 ]; then echo "    | and $((n - 10)) more"; fi
  else
    echo "TREE the same before and after the shares ($(wc -l < "$logs/publish-gate.tree-after" | tr -d ' ') paths)"
  fi
  [ "$failed" -eq 0 ]
}

run_stage_command() {
  case "$1" in
    scaffold)
      grep -qx 4001000065cd1d00a3e1110100 fixtures/golden.hex \
        && bash .github/workflows/report-row.test.sh \
        && bash fixtures/hostile/cases.test.sh \
        && bash fixtures/hostile/check-cases.sh \
        && bash fixtures/text/check-vectors.test.sh \
        && bash scripts/text/check-emitted.test.sh \
        && bash scripts/text/check-emitted.sh \
        && bash fixtures/ecc/check-vectors.test.sh \
        && bash fixtures/ecc/check-contract.sh \
        && python3 -I scripts/ecc/fuzz_reference.py \
        && bash .github/workflows/ring-ecc.test.sh \
        && bash .github/workflows/run-suite.test.sh \
        && bash cpp/embedded/lib.test.sh \
        && bash cpp/embedded/run-parts.test.sh \
        && bash .github/workflows/ring-wiring.test.sh \
        && bash .github/workflows/ring-wiring-rows.test.sh \
        && bash .github/workflows/ring-wiring-swift.test.sh \
        && bash .github/workflows/ring-wiring-session-ecc.test.sh \
        && bash .github/workflows/ring-lib.test.sh \
        && bash .github/workflows/ring-prepare.test.sh \
        && bash scripts/loop-tests.test.sh ;;
    # The clean runs in the container, not on the host: Docker Desktop shows a container started within about a second
    # of a host `rm -rf` the directory as it was, so `mkdir -p build` saw the old one and the link failed (AZ-2565).
    cpp) docker compose -f docker-compose.test.yml run --rm cpp 'make -C /src/cpp clean && exec /src/.github/workflows/run-suite.sh cpp' ;;
    cpp-embedded-arm) docker compose -f docker-compose.test.yml run --rm cpp-embedded ;;
    go | typescript | csharp | python | rust | java | swift) docker compose -f docker-compose.test.yml run --rm "$1" ;;
    # The message ECC ring (AZ-2689) follows the ring and reuses its C# and C++ driver builds (PACKBIN_RING_WORK).
    ring) env "${ring_env[@]}" PACKBIN_RING_WORK="$logs/ring-work" bash .github/workflows/language-pair.sh \
        && env "${ring_env[@]}" PACKBIN_RING_WORK="$logs/ring-work" bash .github/workflows/ring-ecc.sh ;;
    ac10) dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" ;;
    # Its own lines are also its summary, which run_group prints in place of the tail of the stage log.
    publish-gate) run_gate_shares | tee "$logs/publish-gate.summary" ;;
  esac
}

passed=0
failed=0
retried=""
start_all=$(date +%s)

stamp_pass() {
  if [ -z "$(git status --porcelain)" ]; then git rev-parse HEAD > "$stamps/$1"; fi
}

# stage_progress <stage>: "<stage>(<log bytes> B) " for the heartbeat. A stage that runs shares (the publish gate) names
# each one with the bytes of its log while it runs, or "done", so the next heartbeat tells a quiet share from a hung one.
stage_progress() {
  local stage="$1" n=0 list shares=""
  if [ -f "$logs/$stage.shares" ]; then
    while IFS= read -r list; do
      n=$((n + 1))
      if [ -f "$logs/$stage.share-$n.end" ]; then
        shares="$shares, $list done"
      elif [ -f "$logs/$stage.share-$n.log" ]; then
        shares="$shares, $list $(wc -c < "$logs/$stage.share-$n.log" | tr -d ' ') B"
      else
        shares="$shares, $list not started"
      fi
    done < "$logs/$stage.shares"
  fi
  printf '%s(%s B%s) ' "$stage" "$(wc -c < "$logs/$stage.log" | tr -d ' ')" "${shares:+;${shares#,}}"
}

# Runs the stages of $1 (a list) with at most $2 at a time; failed stages go to $failed_stages. A stage that leaves a
# summary ($logs/<stage>.summary) gets it printed before its result line, in place of the tail of its log.
failed_stages=""
run_group() {
  local list="$1" width="$2" pending="" stage i n hb=0 now
  for stage in $list; do
    case " $selected " in *" $stage "*) pending="$pending $stage" ;; esac
  done
  local -a rpid rname rstart
  rpid=(); rname=(); rstart=()
  while [ -n "$pending" ] || [ "${#rpid[@]}" -gt 0 ]; do
    while [ -n "$pending" ] && [ "${#rpid[@]}" -lt "$width" ]; do
      stage="${pending# }"; stage="${stage%% *}"
      pending="${pending# }"; pending="${pending#"$stage"}"
      echo "START $stage"
      ( run_stage_command "$stage" ) < /dev/null > "$logs/$stage.log" 2>&1 &
      rpid+=("$!"); rname+=("$stage"); rstart+=("$(date +%s)")
    done
    sleep 1
    hb=$((hb + 1))
    n=${#rpid[@]}
    i=0
    while [ "$i" -lt "$n" ]; do
      if ! ps -p "${rpid[$i]}" > /dev/null; then
        wait "${rpid[$i]}"
        local rc=$? secs=$(( $(date +%s) - ${rstart[$i]} )) summary="$logs/${rname[$i]}.summary"
        if [ -f "$summary" ]; then cat "$summary"; fi
        if [ "$rc" -eq 0 ]; then
          passed=$((passed + 1)); stamp_pass "${rname[$i]}"
          echo "STAGE ${rname[$i]}: PASS (${secs}s)"
        else
          failed_stages="$failed_stages ${rname[$i]}"
          echo "STAGE ${rname[$i]}: FAIL (${secs}s, exit $rc) log $logs/${rname[$i]}.log"
          [ -f "$summary" ] || tail -n 8 "$logs/${rname[$i]}.log" | sed 's/^/    | /'
        fi
        unset "rpid[$i]" "rname[$i]" "rstart[$i]"
        rpid=("${rpid[@]}"); rname=("${rname[@]}"); rstart=("${rstart[@]}")
        n=${#rpid[@]}
        continue
      fi
      i=$((i + 1))
    done
    if [ $((hb % hb_every)) -eq 0 ] && [ "${#rpid[@]}" -gt 0 ]; then
      now=$(date +%s)
      echo "[hb] $(( now - start_all ))s running: $(for stage in "${rname[@]}"; do stage_progress "$stage"; done)load $(uptime | sed 's/.*averages*: //')"
    fi
  done
}

run_group "$pool_stages" "$jobs"
for stage in $failed_stages; do
  echo "RETRY $stage alone (it failed beside other suites; both results are kept)"
  mv "$logs/$stage.log" "$logs/$stage.first.log"
  s=$(date +%s)
  if ( run_stage_command "$stage" ) < /dev/null > "$logs/$stage.log" 2>&1; then
    passed=$((passed + 1)); retried="$retried $stage"
    stamp_pass "$stage"
    echo "STAGE $stage: PASS on the serial retry ($(( $(date +%s) - s ))s); the first failure is in $logs/$stage.first.log"
  else
    failed=$((failed + 1))
    echo "STAGE $stage: FAIL again alone; log $logs/$stage.log"
    tail -n 12 "$logs/$stage.log" | sed 's/^/    | /'
  fi
done
failed_stages=""
for stage in $serial_stages; do
  case " $selected " in *" $stage "*) ;; *) continue ;; esac
  run_group "$stage" 1
  failed=$((failed + $(printf '%s' "$failed_stages" | wc -w | tr -d ' ')))
  failed_stages=""
done

echo "RESULT $passed passed${retried:+ (passed only on the serial retry:$retried)}, $(printf '%s' "$skipped" | wc -w | tr -d ' ') skipped as unchanged, $failed failed, $(( $(date +%s) - start_all ))s; logs $logs"
[ "$failed" -eq 0 ]
