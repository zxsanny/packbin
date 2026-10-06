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

entry = {"types": "./dist/index.d.ts", "import": "./dist/index.js"}
manifest = json.dumps({"name": "packbin", "version": "0.1.9", "license": "MIT", "types": entry["types"], "exports": {".": entry}}).encode()
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

# AZ-2240: the tag-time guard (publish-check.py typescript) on the real tarball $1 and on mutants of it, in scratch
# directory $2. The real tarball must pass; each mutant must fail with a message that names the missing part.
npm_guard_checks() {
  python3 - "$here/publish-check.py" "$1" "$2/guard" <<'PY' || fail "AZ-2240 the npm guard did not behave as expected"
import io, json, re, shutil, subprocess, sys, tarfile
from pathlib import Path

check, tgz, work = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
version = tgz.name.removeprefix("packbin-").removesuffix(".tgz")
with tarfile.open(tgz) as archive:
    real = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
manifest = json.loads(real["package/package.json"])


def with_manifest(**changes):
    edited = {key: value for key, value in manifest.items() if key not in changes}
    edited.update({key: value for key, value in changes.items() if value is not None})
    return {**real, "package/package.json": json.dumps(edited).encode()}


def without(name):
    return {key: value for key, value in real.items() if key != name}


def appended(name, text):
    return {**real, name: real[name] + text.encode()}


def gone(importer, specifier, member):
    return f"{importer} imports {re.escape(specifier)}, but {re.escape(member)} is not in the tarball"


src = "./src/index.ts"
any_js, any_dts = r"dist/\S+\.js", r"dist/\S+\.d\.ts"
cases = [
    ("control", real, None),
    ("exports removed", with_manifest(exports=None), r"package\.json exports is None, not .*"),
    ("exports to src", with_manifest(exports={".": {"types": src, "import": src}}), r"package\.json exports is .*"),
    ("exports without types", with_manifest(exports={".": {"import": "./dist/index.js"}}), r"package\.json exports is .*"),
    ("types removed", with_manifest(types=None), r"package\.json types is None, not .*"),
    ("types to src", with_manifest(types=src), r"package\.json types is '\./src/index\.ts', not .*"),
    ("walker.js removed", without("package/dist/walker.js"), gone(any_js, "./walker.js", "dist/walker.js")),
    ("walker.d.ts removed", without("package/dist/walker.d.ts"), gone(any_dts, "./walker.ts", "dist/walker.d.ts")),
    ("index.js imports ./nope.js", appended("package/dist/index.js", 'export * from "./nope.js";\n'),
     gone(r"dist/index\.js", "./nope.js", "dist/nope.js")),
    ("index.d.ts imports ./nope.ts", appended("package/dist/index.d.ts", 'export * from "./nope.ts";\n'),
     gone(r"dist/index\.d\.ts", "./nope.ts", "dist/nope.d.ts")),
]
errors = 0
for name, files, wanted in cases:
    folder = work / name.replace(" ", "-")
    folder.mkdir(parents=True)
    with tarfile.open(folder / tgz.name, "w:gz") as archive:
        for member, data in files.items():
            info = tarfile.TarInfo(member)
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
    result = subprocess.run([sys.executable, check, "typescript", str(folder), f"v{version}"], capture_output=True, text=True)
    if wanted is None:
        ok = result.returncode == 0 and result.stdout.strip() == "check ok: typescript"
    else:
        ok = result.returncode == 1 and re.fullmatch(f"check failed: typescript: {wanted}", result.stderr.strip())
    if not ok:
        errors += 1
        print(f"{name}: exit {result.returncode}, stdout {result.stdout.strip()!r}, stderr {result.stderr.strip()!r}")
shutil.rmtree(work)
sys.exit(1 if errors else 0)
PY
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
  npm_guard_checks "$tgz" "$tmp"

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
