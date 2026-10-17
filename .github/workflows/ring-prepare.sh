#!/usr/bin/env bash
# Prepares the drivers of the cross-language ring (language-pair.sh) off the critical path of the ring job (AZ-2626):
#   ring-prepare.sh start <state dir> <image>...
#                                      right after checkout: pulls the images (the ring job: gcc:$RING_GCC and
#                                      swift:$RING_SWIFT) at the same time and builds the Swift drivers (ring-swift.sh)
#                                      once the swift image is in, all in the background; returns at once, so the setup
#                                      actions run meanwhile.
#   ring-prepare.sh build <state dir>  after the setup actions: npm ci (typescript), the Rust driver (cargo) and the Go
#                                      driver (ring-go.sh) at the same time; names a failed one, but leaves the verdict
#                                      to wait, so a background failure is reported in the same run.
#   ring-prepare.sh wait <state dir>   waits for the background builds (at most PACKBIN_RING_WAIT_SECONDS, default 900:
#                                      below the job's 30-minute timeout), fails naming each build of start or build
#                                      that failed or did not finish, with its log, and prints the seconds of every
#                                      build; on GitHub Actions also as ONE notice (annotations need no token to read).
# Run build, then wait, last in the same step (ring-wiring-swift.test.sh holds the order in test.yml).
# Each build keeps <name>.log, <name>.s (seconds) and <name>.rc (exit status, written last) in the state dir. The
# drivers go where language-pair.sh looks (PACKBIN_GO_HANDOFF, PACKBIN_SWIFT_RING, the same defaults), and it rebuilds
# one only when a source is newer, so the ring reuses these builds.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
foreground="npm cargo go"
usage="usage: ring-prepare.sh start <state dir> <image>... | build <state dir> | wait <state dir>"

if [ $# -lt 2 ] || { [ "$1" = start ] && [ $# -lt 3 ]; } || { [ "$1" != start ] && [ $# -ne 2 ]; }; then
  echo "$usage" >&2
  exit 2
fi
dir="$2"

# task <name> <command...>: runs the command with stdin from /dev/null and its output in <name>.log, then writes its
# seconds and, last, its exit status (wait reads a present .rc as finished).
task() {
  local name="$1" started rc=0
  shift
  started=$(date +%s)
  "$@" < /dev/null > "$dir/$name.log" 2>&1 || rc=$?
  echo $(( $(date +%s) - started )) > "$dir/$name.s"
  echo "$rc" > "$dir/$name.rc.new"
  mv "$dir/$name.rc.new" "$dir/$name.rc"
}

# npm ci after a cd: `npm ci --prefix` refuses the lock file when the path holds a symlink (AGENT_GOTCHAS).
npm_ci() { cd "$root/typescript" && npm ci; }

# failures <name>...: prints each named build that failed, did not run or did not finish, with the end of its log;
# returns 1 when there is any.
failures() {
  local name rc bad=0
  for name in "$@"; do
    rc=unfinished
    [ -f "$dir/$name.rc" ] && rc="$(cat "$dir/$name.rc")"
    [ "$rc" = 0 ] && continue
    bad=1
    case "$rc" in
      unfinished) echo "ring-prepare: $name did not finish; the end of its log:" >&2 ;;
      skipped) echo "ring-prepare: $name did not run (the image pull before it failed)" >&2 ;;
      *) echo "ring-prepare: $name failed (exit $rc); the end of its log:" >&2 ;;
    esac
    [ -f "$dir/$name.log" ] && tail -n 200 "$dir/$name.log" | sed 's/^/  | /' >&2
  done
  return "$bad"
}

# A state dir another local user made could hold results that wait would then trust. Its `names` file lists the
# background builds (pull-<image name>... swift-drivers), `started` the time start ran.
owned_state() {
  if [ ! -d "$dir" ] || [ ! -O "$dir" ] || [ ! -f "$dir/started" ] || [ ! -f "$dir/names" ]; then
    echo "ring-prepare: $dir is not a state dir of ring-prepare.sh start owned by $(id -un)" >&2
    exit 1
  fi
  background="$(cat "$dir/names")"
}

case "$1" in
  start)
    if [ -e "$dir" ]; then
      echo "ring-prepare: $dir already exists; pass a new state dir" >&2
      exit 1
    fi
    shift 2
    background=""
    for image in "$@"; do
      # The image name (no registry path) names the build's files: two images of one name would share them.
      case "${image%%:*}" in */* | "") echo "ring-prepare: $image: pass a Docker Hub name:tag" >&2; exit 2 ;; esac
      case " $background " in *" pull-${image%%:*} "*) echo "ring-prepare: two images named ${image%%:*}" >&2; exit 2 ;; esac
      background="$background pull-${image%%:*}"
    done
    background="${background# } swift-drivers"
    mkdir -p "$(dirname "$dir")"
    mkdir -m 700 "$dir"
    date +%s > "$dir/started"
    echo "$background" > "$dir/names"
    # Detached from the step: no stdin, the output in a file, so the step ends while the builds go on.
    (
      swift_pull=""
      for image in "$@"; do
        task "pull-${image%%:*}" docker pull --quiet "$image" &
        if [ "${image%%:*}" = swift ]; then swift_pull=$!; fi
      done
      # The Swift build runs in the swift image: after its pull, and not at all when that pull failed.
      if [ -n "$swift_pull" ]; then wait "$swift_pull"; fi
      if [ ! -f "$dir/pull-swift.rc" ] || [ "$(cat "$dir/pull-swift.rc")" = 0 ]; then
        task swift-drivers bash "$here/ring-swift.sh" "${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}"
      else
        echo 0 > "$dir/swift-drivers.s"
        echo skipped > "$dir/swift-drivers.rc"
      fi
      wait
    ) < /dev/null > "$dir/start.log" 2>&1 &
    echo "ring-prepare: started $background in the background ($dir)"
    ;;
  build)
    owned_state
    task npm npm_ci &
    task cargo cargo build --quiet --manifest-path "$here/drivers/handoff-rust/Cargo.toml" &
    task go bash "$here/ring-go.sh" "${PACKBIN_GO_HANDOFF:-/tmp/packbin-handoff-go}" &
    wait
    # shellcheck disable=SC2086 # the names are single words
    if failures $foreground; then echo "ring-prepare: built $foreground"; else echo "ring-prepare: wait fails the step"; fi
    ;;
  wait)
    owned_state
    limit="${PACKBIN_RING_WAIT_SECONDS:-900}"
    waited=$(date +%s)
    # Whole seconds: -le, so the wait gives up after the full limit (up to 1 s later), never before it.
    for name in $background; do
      while [ ! -f "$dir/$name.rc" ] && [ $(( $(date +%s) - waited )) -le "$limit" ]; do
        sleep 0.2
      done
    done
    waited=$(( $(date +%s) - waited ))
    rc=0
    # shellcheck disable=SC2086
    failures $background $foreground || rc=1
    lines=""
    # shellcheck disable=SC2086
    for name in $background $foreground; do
      [ -f "$dir/$name.s" ] || continue
      line="ring-prepare: $name took $(cat "$dir/$name.s") s"
      echo "$line" >&2
      lines="${lines:+$lines%0A}$line"
    done
    # The Swift driver build's cache state and ccache hits (ring-swift.sh, swift-ccache.sh) when CI keeps its output
    # (AZ-2627): no such lines otherwise.
    if [ -f "$dir/swift-drivers.log" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        echo "$line" >&2
        lines="${lines:+$lines%0A}$line"
      done <<< "$(grep -E '^(ring-swift: cache |swift-ccache: )' "$dir/swift-drivers.log" || true)"
    fi
    line="ring-prepare: the wait took $waited s (limit $limit s), $(( $(date +%s) - $(cat "$dir/started") )) s since start"
    echo "$line" >&2
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
      echo "::notice title=ring preparation timing::$lines%0A$line"
    fi
    exit "$rc"
    ;;
  *)
    echo "$usage" >&2
    exit 2
    ;;
esac
