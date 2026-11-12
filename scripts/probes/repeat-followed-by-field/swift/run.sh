#!/usr/bin/env bash
# Swift probe of AZ-4206 (see ../README.md). Builds Sources/repeatprobe against the package of this
# checkout in a temporary directory and prints one line per shape. Build messages go to stderr.
# Nothing is written into the repository: the package manifest, the build and Package.resolved all
# live in the temporary directory. Exit 0 when the probe ran, whatever it found.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

shapes=(control a b c d e-when e-flags f)

# A path as the text of a Swift string literal.
swift_text() {
  local text="${1//\\/\\\\}"
  printf '%s' "${text//\"/\\\"}"
}

# One shape in a process of its own. The probe writes each cell as it gets it, so when it dies inside
# a call (a trap, a signal) the cells so far are kept and the call that died is a `threw:` cell.
run_shape() {
  local shape="$1" line status=0 tabs what
  line="$("$bin" "$shape" </dev/null)" || status=$?
  if ((status != 0)); then
    if ((status < 128)); then
      printf 'run.sh: the probe ended with status %s for shape %s\n' "$status" "$shape" >&2
      return 1
    fi
    what="threw: the probe ended with signal $(kill -l "$((status - 128))")"
    tabs="$(printf '%s' "$line" | tr -cd '\t' | wc -c | tr -d ' ')"
    if ((tabs == 4)); then
      line+="$what"
    elif ((tabs == 3)); then
      line+="$what"$'\t-'
    elif ((tabs == 2)); then
      line+="$what"$'\t-\t-'
    else
      line="swift"$'\t'"$shape"$'\t'"$what"$'\t-\t-'
    fi
  fi
  printf '%s\n' "$line"
}

copy="$out/repeatprobe"
mkdir -p "$copy"
cp -R "$here/Sources" "$copy/Sources"
# A package given by path is named by its directory, so the directory name of this checkout is used.
cat >"$copy/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "repeatprobe",
    platforms: [.macOS(.v12)],
    dependencies: [.package(path: "$(swift_text "$root")")],
    targets: [
        .executableTarget(
            name: "repeatprobe",
            dependencies: [.product(name: "Packbin", package: "$(swift_text "$(basename "$root")")")]),
    ]
)
EOF

swift build --package-path "$copy" --scratch-path "$out/build" </dev/null >&2
bin="$(swift build --package-path "$copy" --scratch-path "$out/build" --show-bin-path </dev/null)/repeatprobe"

# A shape whose process could not run is reported by run_shape; the shapes after it still print.
failed=0
for shape in "${shapes[@]}"; do
  run_shape "$shape" || failed=1
done
exit "$failed"
