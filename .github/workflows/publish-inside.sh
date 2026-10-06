#!/usr/bin/env bash
# Builds one language's package inside its toolchain image and leaves the artifact in
# $PACKBIN_OUT/artifacts/<lang>/. It holds no registry credential and makes no network write;
# publish-upload.sh sends what this builds.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

lang="${1:?language}"
root="$(publish_root)"
version="${PACKBIN_VERSION:-0.1.0}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
dest="$out/artifacts/$lang"
work="${PACKBIN_WORK:-}"
made_work=0
if [ -z "$work" ]; then
  work="$(mktemp -d)"
  made_work=1
fi
mkdir -p "$dest"

# The container runs as root; the host user must own what it leaves, or the host cannot chmod,
# sign or delete it (a Linux runner is not the owner, unlike Docker Desktop on a Mac).
finish() {
  local code=$?
  if [ "$made_work" = 1 ]; then
    rm -rf "$work"
  fi
  if [ -n "${PACKBIN_HOST_UID:-}" ]; then
    chown -R "$PACKBIN_HOST_UID:${PACKBIN_HOST_GID:-$PACKBIN_HOST_UID}" "$dest" || code=$?
  fi
  exit "$code"
}
trap finish EXIT

set_version() {
  python3 -c '
import re, sys
from pathlib import Path
path, version = Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
path.write_text(re.sub(r"(?m)^version = \".*\"$", f"version = \"{version}\"", text, count=1))
' "$1" "$version"
}

case "$lang" in
  csharp)
    dotnet pack "$root/csharp/Packbin.csproj" -c Release -o "$work/nupkg" \
      -p:Version="$version" -v q --nologo
    cp "$work/nupkg/"*.nupkg "$dest/"
    ;;
  typescript)
    cp -a "$root/typescript/." "$work/typescript"
    cp "$root/README.md" "$work/typescript/README.md"
    rm -rf "$work/typescript/node_modules"
    npm version "$version" --no-git-tag-version --allow-same-version --prefix "$work/typescript"
    npm pack "$work/typescript" --pack-destination "$dest"
    ;;
  python)
    cp -a "$root/python/." "$work/python"
    rm -f "$work/python/README.md"
    cp "$root/README.md" "$work/python/README.md"
    set_version "$work/python/pyproject.toml"
    build_pin="$(bash "$here/tool-pin.sh" build)"
    python3 -m pip install --quiet --only-binary=:all: "build==$build_pin"
    PIP_CONSTRAINT="$here/tool-pins.txt" python3 -m build "$work/python" --outdir "$dest"
    ;;
  rust)
    stage="$dest/stage"
    cp -a "$root/rust/." "$stage"
    cp "$root/README.md" "$stage/README.md"
    rm -rf "$stage/target"
    set_version "$stage/Cargo.toml"
    cargo package --allow-dirty --manifest-path "$stage/Cargo.toml"
    cp "$stage/target/package/packbin-$version.crate" "$dest/"
    rm -rf "$stage/target"
    ;;
  java)
    classes="$work/classes"
    bundle="$dest/maven"
    mkdir -p "$classes" "$work/javadoc"
    sources=()
    while IFS= read -r -d '' f; do
      sources+=("$f")
    done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
    javac --release 17 -encoding UTF-8 -d "$classes" "${sources[@]}"
    javadoc --release 17 -encoding UTF-8 -d "$work/javadoc" -sourcepath "$root/java/src/main/java" packbin
    path="io/github/zxsanny"
    pkg="$bundle/$path/packbin/$version"
    mkdir -p "$pkg"
    jar --create --file "$pkg/packbin-$version.jar" -C "$classes" .
    jar --create --file "$pkg/packbin-$version-sources.jar" -C "$root/java/src/main/java" .
    jar --create --file "$pkg/packbin-$version-javadoc.jar" -C "$work/javadoc" .
    cat > "$pkg/packbin-$version.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.github.zxsanny</groupId>
  <artifactId>packbin</artifactId>
  <version>${version}</version>
  <name>packbin</name>
  <description>Pack and unpack a caller-owned field list</description>
  <url>https://github.com/zxsanny/packbin</url>
  <licenses>
    <license>
      <name>MIT</name>
      <url>https://opensource.org/license/mit</url>
    </license>
  </licenses>
  <developers>
    <developer>
      <name>zxsanny</name>
      <url>https://github.com/zxsanny</url>
    </developer>
  </developers>
  <scm>
    <connection>scm:git:https://github.com/zxsanny/packbin.git</connection>
    <developerConnection>scm:git:https://github.com/zxsanny/packbin.git</developerConnection>
    <url>https://github.com/zxsanny/packbin</url>
  </scm>
</project>
EOF
    ;;
  *)
    echo "unknown language: $lang" >&2
    exit 1
    ;;
esac
