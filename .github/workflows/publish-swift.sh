#!/usr/bin/env bash
# Check step of the swift-check target (ADR-005), run by publish-upload.sh last, after the Go tag. Swift has no
# registry and no tag of its own: Swift Package Manager fetches the package through the root Package.swift at the
# tag v<version> that started the run. The build phase recorded that tag and the commit of the checkout in
# $PACKBIN_OUT/artifacts/swift-check/tag.txt, with the consumer's main.swift (publish-build.sh, checked by
# publish-check.py).
#
# A throwaway consumer package depends on $(swift_package_url) at exactly <version> and builds the main.swift,
# which imports Packbin. `swift package resolve` must pin that URL to <version> at the recorded commit; then
# `swift build` must build it. The check only reads: it creates, moves and deletes no tag. A pin at another
# commit or version fails at once, naming both, because a Swift version never moves (a bad one is fixed by the
# next patch). A resolve or build that fails is retried for $PACKBIN_SWIFT_WINDOW seconds (default 1800) every
# $PACKBIN_SWIFT_PAUSE seconds (default 30), each try in a fresh scratch, cache, configuration and security
# directory, so the answer is what a new app's resolve would get. A re-run of the tag runs the check again.
#
# Needs: PACKBIN_OUT, PACKBIN_VERSION; swift and python3 on PATH. No credential: it unsets every one first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"
# SwiftPM compiles and runs the manifest of every dependency as a process that inherits this environment, so the
# check runs with no credential of the publish step (F48); it needs none. No argument: no credential is kept.
# shellcheck disable=SC2119
unset_credentials

version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
artifacts="$out/artifacts/swift-check"
url="$(swift_package_url)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

read -r tag commit < "$artifacts/tag.txt"

# The URL and the version are written into the consumer manifest as Swift string literals.
case "$url$version" in
  *'"'* | *'\'* | *$'\n'*)
    echo "swift package URL $url or version $version holds a quote, a backslash or a line break" >&2
    exit 1
    ;;
esac

consumer="$work/consumer"
mkdir -p "$consumer/Sources/consumer"
cp "$artifacts/main.swift" "$consumer/Sources/consumer/main.swift"
cat > "$consumer/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "packbin-consumer",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "$url", exact: "$version"),
    ],
    targets: [
        .executableTarget(
            name: "consumer",
            dependencies: [.product(name: "Packbin", package: "packbin")],
            path: "Sources/consumer"),
    ]
)
EOF

# "<version> <revision>" of the pin of $url in the consumer's Package.resolved; empty when there is none.
resolved_pin() {
  python3 -I - "$consumer/Package.resolved" "$url" <<'PY'
import json, sys
pins = json.load(open(sys.argv[1])).get("pins", [])
found = [p.get("state", {}) for p in pins if p.get("location") == sys.argv[2]]
print("%s %s" % (found[0].get("version"), found[0].get("revision")) if len(found) == 1 else "")
PY
}

swift_check() {
  local window="${PACKBIN_SWIFT_WINDOW:-1800}" pause="${PACKBIN_SWIFT_PAUSE:-30}"
  local deadline attempt=0 reason pin state opts
  deadline=$((SECONDS + window))
  while :; do
    attempt=$((attempt + 1))
    state="$work/try-$attempt"
    opts=(--package-path "$consumer" --scratch-path "$state/build" --cache-path "$state/cache"
      --config-path "$state/config" --security-path "$state/security")
    rm -f "$consumer/Package.resolved"
    if ! swift package "${opts[@]}" resolve > "$state.log" 2>&1 < /dev/null; then
      reason="swift package resolve failed"
    else
      pin="$(resolved_pin)" || pin=""
      if [ "$pin" != "$version $commit" ]; then
        echo "swift package $url resolves $version to [${pin:-no pin}], but $tag is at $commit: a Swift" \
          "version never moves and the check moves no tag; fix it in the next patch version" >&2
        return 1
      fi
      if swift build "${opts[@]}" > "$state.log" 2>&1 < /dev/null; then
        echo "swift consumer resolves $url $version at $commit and builds Packbin (try $attempt)"
        return 0
      fi
      reason="swift build failed"
    fi
    echo "swift check try $attempt: $reason; $(tail -n 1 "$state.log")"
    rm -rf "$state"
    if [ "$SECONDS" -ge "$deadline" ]; then
      break
    fi
    sleep "$pause"
  done
  echo "a consumer of $url $version did not resolve and build after $attempt tries in ${window}s;" \
    "no tag was created, moved or deleted; run the tag again to check again" >&2
  return 1
}

swift --version < /dev/null
swift_check
