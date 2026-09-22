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
    mkdir -p "$classes"
    sources=()
    while IFS= read -r -d '' f; do
      sources+=("$f")
    done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
    javac -encoding UTF-8 -d "$classes" "${sources[@]}"
    jar --create --file "$work/packbin-$version.jar" -C "$classes" .
    path="${MAVEN_GROUP_ID//.//}"
    dest="$bundle/$path/packbin/$version"
    mkdir -p "$dest"
    cp "$work/packbin-$version.jar" "$dest/packbin-$version.jar"
    cat > "$dest/packbin-$version.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${MAVEN_GROUP_ID}</groupId>
  <artifactId>packbin</artifactId>
  <version>${version}</version>
  <name>packbin</name>
  <description>Pack and unpack a caller-owned field list</description>
  <licenses>
    <license><name>MIT</name></license>
  </licenses>
</project>
EOF
    out="${PACKBIN_OUT:-$root/.github/workflows/out}"
    mkdir -p "$out"
    jar --create --file "$out/maven-bundle.zip" -C "$bundle" .
    ;;
  *)
    echo "unknown language: $lang" >&2
    exit 1
    ;;
esac
