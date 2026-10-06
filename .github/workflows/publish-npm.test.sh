#!/usr/bin/env bash
# npm package checks (AZ-2103). Sourced by publish-gate.test.sh, which defines fail, assert_eq, $root,
# $here and $expected; `bash publish-gate.test.sh --npm` runs only these.

# shellcheck disable=SC2154,SC2016
# AZ-2103: publish-check.py takes the compiled layout and refuses the old one (three small tarballs).
npm_layout_checks() {
  local tmp layout dir out
  tmp="$(mktemp -d)"
  python3 - "$tmp" <<'PY'
import io, json, sys, tarfile
from pathlib import Path

manifest = json.dumps({"name": "packbin", "version": "0.1.9", "license": "MIT"}).encode()
base = {"package/package.json": manifest, "package/README.md": b"r"}
dist = {"package/dist/index.js": b"x", "package/dist/index.d.ts": b"x"}
src = {"package/src/index.ts": b"x"}
cases = {"good": {**base, **dist}, "sources-only": {**base, **src}, "dist-and-sources": {**base, **dist, **src}}
for case, files in cases.items():
    folder = Path(sys.argv[1]) / case
    folder.mkdir()
    with tarfile.open(folder / "packbin-0.1.9.tgz", "w:gz") as archive:
        for name, data in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
PY
  for layout in good sources-only dist-and-sources; do
    dir="$tmp/$layout"
    if out="$(python3 "$here/publish-check.py" typescript "$dir" v0.1.9 2>&1)"; then
      [ "$layout" = good ] || fail "AZ-2103 publish-check.py accepted the $layout npm layout"
    else
      [ "$layout" != good ] || fail "AZ-2103 publish-check.py refused the compiled npm layout: $out"
      case "$layout" in
        sources-only) grep -qF 'dist/index.js is missing' <<< "$out" || fail "AZ-2103 sources-only layout: wrong message: $out" ;;
        dist-and-sources) grep -qF 'src/ is in the tarball' <<< "$out" || fail "AZ-2103 dist-and-sources layout: wrong message: $out" ;;
      esac
    fi
  done
  rm -rf "$tmp"
}

# AZ-2103: the npm tarball holds the compiled package and a consumer can use it. The tarball comes from
# the real publish-inside.sh branch, run on the host (node and npm, and the npm registry for the two
# locked packages) over a copy of the repo whose typescript folder carries a stale dist.
npm_dist_checks() {
  local tmp tree work out tgz app got members build_line pack_line
  npm_layout_checks
  grep -qx 'typescript/dist/' "$root/.gitignore" || fail "AZ-2103 dist is not in .gitignore"
  python3 - "$root/typescript/package.json" <<'PY' || fail "AZ-2103 AC-6 package.json does not point at dist"
import json, sys
package = json.load(open(sys.argv[1]))
dist = {"types": "./dist/index.d.ts", "import": "./dist/index.js"}
assert package["exports"] == {".": dist}, package["exports"]
assert package["types"] == "./dist/index.d.ts", package["types"]
assert package["files"] == ["dist", "README.md"], package["files"]
assert package["scripts"]["build"], "no build script"
PY
  build_line="$(grep -n 'npm run build' "$here/publish-inside.sh" | head -n 1 | cut -d: -f1 || true)"
  pack_line="$(grep -n 'npm pack' "$here/publish-inside.sh" | head -n 1 | cut -d: -f1 || true)"
  if [ -z "$build_line" ] || [ -z "$pack_line" ] || [ "$build_line" -ge "$pack_line" ]; then
    fail "AZ-2103 publish-inside.sh does not build before it packs"
  fi

  tmp="$(mktemp -d)"
  tree="$tmp/tree"
  work="$tmp/work"
  out="$tmp/out"
  app="$tmp/app"
  mkdir -p "$tree" "$work" "$out" "$app"
  tar -C "$root" --exclude node_modules --exclude dist -cf - typescript | tar -C "$tree" -xf -
  cp "$root/README.md" "$tree/README.md"
  mkdir "$tree/typescript/dist"
  printf 'stale\n' > "$tree/typescript/dist/stale.js"
  if ! SRC_ROOT="$tree" PACKBIN_WORK="$work" PACKBIN_OUT="$out" PACKBIN_VERSION=0.1.0 \
    bash "$here/publish-inside.sh" typescript > "$tmp/build.log" 2>&1; then
    fail "AZ-2103 the npm build failed: $(tail -n 5 "$tmp/build.log")"
    rm -rf "$tmp"
    return
  fi

  tgz="$out/artifacts/typescript/packbin-0.1.0.tgz"
  members="$(tar -tzf "$tgz")"
  for member in package/dist/index.js package/dist/index.d.ts package/README.md package/package.json; do
    grep -qx "$member" <<< "$members" || fail "AZ-2103 AC-3 the npm tarball lacks $member"
  done
  if grep -E '^package/(src|tests)/' <<< "$members"; then
    fail "AZ-2103 AC-3 the npm tarball holds sources or tests"
  fi
  if grep -qx 'package/dist/stale.js' <<< "$members"; then
    fail "AZ-2103 a stale dist from the checkout was packed"
  fi

  # AC-4: the only bare import is the locked dependency, and nothing reaches for Node.
  tar -xzf "$tgz" -C "$tmp"
  if grep -rnE 'node:|require\(|\bBuffer\b|\bprocess\b' --include='*.js' "$tmp/package/dist"; then
    fail "AZ-2103 AC-4 the built JavaScript uses a Node-only name"
  fi
  if grep -rhoE 'from "[^."][^"]*"' --include='*.js' "$tmp/package/dist" | grep -v 'from "@noble/hashes/'; then
    fail "AZ-2103 AC-4 the built JavaScript imports something besides @noble/hashes"
  fi

  # AC-1: an empty project with no TypeScript imports the tarball under plain node.
  printf '{"private":true,"type":"module"}\n' > "$app/package.json"
  if ! (cd "$app" && npm install --no-audit --no-fund "$tgz" > "$tmp/install.log" 2>&1); then
    fail "AZ-2103 AC-1 installing the tarball failed: $(tail -n 5 "$tmp/install.log")"
    rm -rf "$tmp"
    return
  fi
  cat > "$app/main.mjs" <<'EOF'
import { scheme, u16, i32, u8, flags, i16, BinaryPacker } from "packbin"

const position = scheme(
  0x40,
  u16(0, (r) => r.sid),
  i32(1, (r) => r.lat),
  i32(2, (r) => r.lon),
  u8(3, (r) => r.profile),
  flags(4, [u16(4, (r) => r.heading), u8(5, (r) => r.speed), i16(6, (r) => r.altitude)]),
)
const row = { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }
console.log(Buffer.from(BinaryPacker.pack(position, row)).toString("hex"))
EOF
  if got="$(cd "$app" && node main.mjs 2>&1)"; then
    assert_eq "$got" "$expected" "AZ-2103 AC-1 node consumer packs the golden row"
  else
    fail "AZ-2103 AC-1 node could not import the tarball: $got"
  fi

  # AC-2: strict tsc without allowImportingTsExtensions; the ts-expect-error line fails the check
  # if a row can be packed without its scheme.
  cat > "$app/consumer.ts" <<'EOF'
import { BinaryPacker, scheme, u16, u8 } from "packbin"

type Row = { sid: number; mode: number }

const layout = scheme<Row>(1, u16(0, (r: Row) => r.sid), u8(1, (r: Row) => r.mode))
const row: Row = { sid: 1, mode: 2 }
const wire: Uint8Array = BinaryPacker.pack(layout, row)
// @ts-expect-error a row cannot be packed without its scheme
BinaryPacker.pack(row)
console.log(wire.length)
EOF
  if ! got="$(cd "$app" && "$work/typescript/node_modules/.bin/tsc" --noEmit --strict --target es2022 \
    --module nodenext --moduleResolution nodenext consumer.ts 2>&1)"; then
    fail "AZ-2103 AC-2 the consumer does not type-check: $got"
  fi
  rm -rf "$tmp"
}
