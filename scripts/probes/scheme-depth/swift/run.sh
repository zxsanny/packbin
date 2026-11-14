#!/usr/bin/env bash
# Swift probe of AZ-4291 (scheme depth). Builds Sources/schemedepthprobe against the package of this
# checkout in a temporary directory and runs it once per case (shape, depth) through ../case.sh, so a
# stack overflow, trap or hang is one `crashed:` line. stdout: 6 lines. stderr: every build message.
# Nothing is written into the repository: the package manifest, the build and Package.resolved all live
# in the temporary directory. The build is `release` (what a user ships; debug frames are larger, so a
# deep scheme overflows there earlier): PROBE_PROFILE=debug builds that instead. Exit 0 when the probes ran.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
case_sh="$here/../case.sh"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

profile="${PROBE_PROFILE:-release}"
case "$profile" in
  release | debug) ;;
  *) echo "run.sh: PROBE_PROFILE is release or debug, not $profile" >&2; exit 2 ;;
esac

# A path as the text of a Swift string literal.
swift_text() {
  local text="${1//\\/\\\\}"
  printf '%s' "${text//\"/\\\"}"
}

copy="$out/schemedepthprobe"
mkdir -p "$copy"
cp -R "$here/Sources" "$copy/Sources"
# A package given by path is named by its directory, so the directory name of this checkout is used.
cat >"$copy/Package.swift" <<MANIFEST
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "schemedepthprobe",
    platforms: [.macOS(.v12)],
    dependencies: [.package(path: "$(swift_text "$root")")],
    targets: [
        .executableTarget(
            name: "schemedepthprobe",
            dependencies: [.product(name: "Packbin", package: "$(swift_text "$(basename "$root")")")]),
    ]
)
MANIFEST

swift build -c "$profile" --package-path "$copy" --scratch-path "$out/build" </dev/null >&2
bin="$(swift build -c "$profile" --package-path "$copy" --scratch-path "$out/build" --show-bin-path </dev/null)/schemedepthprobe"

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$case_sh" swift "$shape-$depth" 60 "$bin" "$shape" "$depth"
  done
done
