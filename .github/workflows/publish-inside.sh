#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

lang="${1:?language}"
root="$(publish_root)"
version="${PACKBIN_VERSION:-0.1.0}"
version="${version#v}"
work="${PACKBIN_WORK:-$(mktemp -d)}"

case "$lang" in
  csharp)
    dotnet pack "$root/csharp/Packbin.csproj" -c Release -o "$work/nupkg" \
      -p:Version="$version" -v q --nologo
    dotnet nuget push "$work/nupkg/"*.nupkg \
      --api-key "$NUGET_TOKEN" \
      --source https://api.nuget.org/v3/index.json \
      --skip-duplicate
    ;;
  typescript)
    cp -a "$root/typescript/." "$work/typescript"
    rm -rf "$work/typescript/node_modules"
    npm version "$version" --no-git-tag-version --allow-same-version --prefix "$work/typescript"
    printf '//registry.npmjs.org/:_authToken=%s\n' "$NPM_TOKEN" > "$work/npmrc"
    npm publish --userconfig "$work/npmrc" --access public --prefix "$work/typescript"
    ;;
  python)
    cp -a "$root/python/." "$work/python"
    python3 -c '
import re, sys
from pathlib import Path
path, version = Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
path.write_text(re.sub(r"(?m)^version = \".*\"$", f"version = \"{version}\"", text, count=1))
' "$work/python/pyproject.toml" "$version"
    python3 -m pip install --quiet build twine
    python3 -m build "$work/python" --outdir "$work/pypi"
    python3 -m twine upload --non-interactive -u __token__ -p "$PYPI_TOKEN" "$work/pypi"/*
    ;;
  rust)
    cp -a "$root/rust/." "$work/rust"
    rm -rf "$work/rust/target"
    python3 -c '
import re, sys
from pathlib import Path
path, version = Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
path.write_text(re.sub(r"(?m)^version = \".*\"$", f"version = \"{version}\"", text, count=1))
' "$work/rust/Cargo.toml" "$version"
    cargo publish --token "$CARGO_REGISTRY_TOKEN" --allow-dirty --manifest-path "$work/rust/Cargo.toml"
    ;;
  java)
    classes="$work/classes"
    bundle="$work/bundle"
    mkdir -p "$classes" "$work/javadoc"
    sources=()
    while IFS= read -r -d '' f; do
      sources+=("$f")
    done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
    javac -encoding UTF-8 -d "$classes" "${sources[@]}"
    javadoc -encoding UTF-8 -d "$work/javadoc" -sourcepath "$root/java/src/main/java" packbin
    path="packbin"
    dest="$bundle/$path/packbin/$version"
    mkdir -p "$dest"
    jar --create --file "$dest/packbin-$version.jar" -C "$classes" .
    jar --create --file "$dest/packbin-$version-sources.jar" -C "$root/java/src/main/java" .
    jar --create --file "$dest/packbin-$version-javadoc.jar" -C "$work/javadoc" .
    cat > "$dest/packbin-$version.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>packbin</groupId>
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
    out="${PACKBIN_OUT:-$root/.github/workflows/out}"
    rm -rf "$out/maven"
    mkdir -p "$out/maven"
    cp -R "$bundle/." "$out/maven/"
    ;;
  *)
    echo "unknown language: $lang" >&2
    exit 1
    ;;
esac
