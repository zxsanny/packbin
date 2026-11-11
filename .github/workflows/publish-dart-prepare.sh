#!/usr/bin/env bash
# Prepares the Dart package for the pubdev target (ADR-011): publish-dart-prepare.sh <repo root> <version> <artifact dir>.
# Run by publish-inside.sh in the dart image (or on the host with PACKBIN_DOCKER=0). It holds no credential and writes
# nothing outside the artifact directory and its own temporary directory; the repository may be read-only.
#
# 1. <artifact dir>/package is a copy of dart/ without what a build leaves (.dart_tool, pubspec.lock, build), with
#    `version:` of pubspec.yaml set to the version of the tag. This copy is what the upload step publishes.
# 2. `dart pub publish --dry-run` runs on a second copy in a temporary directory outside any git repository (pub lists
#    the files of a package inside a work tree with git, and out/ is ignored there), so the prepared copy stays clean.
#    Its whole output and exit code go to <artifact dir>/publish-dry-run.txt, the last line being `exit <code>`;
#    publish-check.py reads the errors and warnings from it. The dry run reads pub.dev (dependencies) and uploads nothing.
set -euo pipefail

root="${1:?repo root}"
version="${2:?version}"
dest="${3:?artifact dir}"

case "$version" in
  "" | *[!0-9A-Za-z.+-]*)
    echo "version $version holds a character a pubspec version does not" >&2
    exit 1
    ;;
esac

package="$dest/package"
rm -rf "$package"
mkdir -p "$package"
cp -R "$root/dart/." "$package/"
rm -rf "$package/.dart_tool" "$package/pubspec.lock" "$package/build"

awk -v version="$version" '
  /^version:/ && !done { print "version: " version; done = 1; next }
  { print }
' "$package/pubspec.yaml" > "$package/pubspec.yaml.new"
mv "$package/pubspec.yaml.new" "$package/pubspec.yaml"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/package"
cp -R "$package/." "$work/package/"
code=0
(cd "$work/package" && dart pub publish --dry-run < /dev/null) > "$work/dry-run.txt" 2>&1 || code=$?
{
  cat "$work/dry-run.txt"
  echo "exit $code"
} > "$dest/publish-dry-run.txt"
sed -n '/^Validating package/,$p' "$work/dry-run.txt"
echo "dart pub publish --dry-run exit $code"
