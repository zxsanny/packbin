#!/usr/bin/env bash
# ccache for the Swift builds that CI keeps between runs (AZ-2627, C3). CI restores a Swift build's output with
# actions/cache, but SwiftPM compiles BoringSSL's C files (swift-crypto) again after every restore: it tracks a C file
# by its identity, which no restore keeps. Through ccache those compiles come from its cache. SwiftPM takes its C
# compiler from CC (a --toolset cCompiler is ignored for a host build). Best-effort: when ccache cannot be set up the
# build runs as before, and the summary says why. Runs as root in the swift image (Ubuntu).
#
# Sourced by run-suite.sh:  swift_ccache_start <dir>   then, after the builds, swift_ccache_summary
# Run by ring-swift.sh:     swift-ccache.sh run <dir> <uid> <gid> <command...>
#   sets ccache up as root, runs the command as <uid>:<gid> (setpriv), prints "swift-ccache: <summary>" to stderr and
#   exits with the command's status.
# <dir> is the kept directory: <dir>/debs the ccache packages (installed with dpkg when present, so a later run needs
# no apt-get update; else apt-get downloads them there), <dir>/cache the ccache cache.

# The ccache command and the compiler name that runs clang through it (Ubuntu's ccache package); a test points both
# at stand-ins.
swift_ccache_bin="${PACKBIN_SWIFT_CCACHE_BIN:-ccache}"
swift_ccache_cc="${PACKBIN_SWIFT_CCACHE_CC:-/usr/lib/ccache/clang}"
swift_ccache_note=
swift_ccache_on=
swift_ccache_uid=
swift_ccache_gid=

# The command as the build's user: the caller of `run`, else whoever runs this.
swift_ccache_as() {
  if [ -n "$swift_ccache_uid" ]; then
    setpriv --reuid="$swift_ccache_uid" --regid="$swift_ccache_gid" --clear-groups -- "$@"
  else
    "$@"
  fi
}

# <debs dir>: the kept packages when they install, else apt-get (copying the packages there for the next run). Their
# output goes to stderr (the job log); on failure the note names the command that failed. apt-get downloads into a
# directory of its own: it leaves a root-only lock file there, which the cache save could not read.
swift_ccache_install() {
  local debs="$1" archives
  if compgen -G "$debs/*.deb" > /dev/null; then
    if dpkg -i "$debs"/*.deb >&2; then return 0; fi
    echo "swift-ccache: the kept ccache packages in $debs did not install; apt-get instead" >&2
  fi
  if ! archives="$(mktemp -d)" || ! mkdir -p "$archives/partial"; then
    swift_ccache_note="unavailable: cannot create a download directory"
    return 1
  fi
  if ! DEBIAN_FRONTEND=noninteractive apt-get update -qq >&2; then
    swift_ccache_note="unavailable: apt-get update failed"
    return 1
  fi
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dir::Cache::archives="$archives" \
    ccache >&2; then
    swift_ccache_note="unavailable: apt-get install ccache failed"
    return 1
  fi
  # ccache is installed: a failed copy only costs the next run the apt-get.
  if ! { mkdir -p "$debs" && cp "$archives"/*.deb "$debs"/; }; then
    echo "swift-ccache: the ccache packages were not kept in $debs; the next run uses apt-get" >&2
  fi
}

swift_ccache_start() {
  local dir="$1" started
  started=$(date +%s)
  if ! command -v "$swift_ccache_bin" > /dev/null && ! swift_ccache_install "$dir/debs"; then return 0; fi
  if [ ! -x "$swift_ccache_cc" ]; then
    swift_ccache_note="unavailable: no $swift_ccache_cc"
    return 0
  fi
  export CCACHE_DIR="$dir/cache"
  # A restored cache keeps the counts of the run that saved it.
  if ! swift_ccache_as mkdir -p "$CCACHE_DIR" || ! swift_ccache_as "$swift_ccache_bin" --zero-stats > /dev/null; then
    swift_ccache_note="unavailable: ccache --zero-stats failed in $CCACHE_DIR"
    return 0
  fi
  export CC="$swift_ccache_cc"
  swift_ccache_on=1
  swift_ccache_note="ready in $(( $(date +%s) - started )) s"
}

# One line: the hits and misses since swift_ccache_start (ccache's machine-readable statistics), or why it was off.
swift_ccache_summary() {
  local stats
  if [ -z "$swift_ccache_on" ]; then
    printf '%s\n' "${swift_ccache_note:-unavailable: not started}"
    return 0
  fi
  if ! stats="$(swift_ccache_as "$swift_ccache_bin" --print-stats)"; then
    printf '%s, statistics unreadable\n' "$swift_ccache_note"
    return 0
  fi
  awk -F '\t' -v note="$swift_ccache_note" '
    $1 == "direct_cache_hit" || $1 == "preprocessed_cache_hit" { hits += $2 }
    $1 == "cache_miss" { misses += $2 }
    END { printf "%d hits, %d misses, %s\n", hits, misses, note }' <<< "$stats"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  if [ "${1:-}" != run ] || [ $# -lt 5 ]; then
    echo "usage: swift-ccache.sh run <dir> <uid> <gid> <command...>" >&2
    exit 2
  fi
  dir="$2" swift_ccache_uid="$3" swift_ccache_gid="$4"
  shift 4
  swift_ccache_start "$dir"
  rc=0
  swift_ccache_as "$@" || rc=$?
  echo "swift-ccache: $(swift_ccache_summary)" >&2
  exit "$rc"
fi
