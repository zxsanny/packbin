#!/usr/bin/env bash
# Two-phase publish failure scenarios (AZ-2096 AC-2 and AC-4). Sourced by publish-phases.test.sh, whose
# harness they run on (ph_setup, ph_publish, ph_bares, ph_no_refs, ph_set_credentials and the $ph_* paths;
# fail, assert_eq and $here come from publish-gate.test.sh): a build that fails after others succeeded,
# fabricated artifacts that each break one check, and a wrong version or a missing license in the real
# pipeline. Each one ends with no registry write.

# shellcheck disable=SC2154

# AC-2: a build that fails after others succeeded leaves every registry untouched.
ph_failure_injection() {
  local fail_bin="$ph_dir/fail-bin"
  ph_set_credentials
  mkdir -p "$fail_bin"
  printf '#!/bin/sh\necho "gpg stub: signing refused" >&2\nexit 1\n' > "$fail_bin/gpg"
  chmod +x "$fail_bin/gpg"
  ph_bares gpg-fails
  ph_publish gpg-fails "$fail_bin" "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2096 AC-2 publish passed with a failing gpg"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-2 a registry command ran after the java build failed: $(head -n 3 "$ph_log")"
  ph_no_refs "AZ-2096 AC-2 gpg"
  grep -qx 'build ok arduino' "$ph_out/artifacts/build.log" || fail "AZ-2096 AC-2 earlier targets were not built"
  grep -q '^build failed: java$' "$ph_dir/gpg-fails.out" || fail "AZ-2096 AC-2 failure does not name java"
  if git --git-dir="$ph_vcpkg" rev-parse --verify --quiet vcpkg >/dev/null; then
    fail "AZ-2096 AC-2 vcpkg ref exists"
  fi

  ph_bares gpg-dry
  ph_publish gpg-dry "$fail_bin" PACKBIN_BUILD_ONLY=1
  [ "$ph_code" -ne 0 ] || fail "AZ-2096 AC-3 build-only passed with a failing gpg"
  [ -e "$ph_out/artifacts/dry-run" ] || fail "AZ-2096 AC-3 a failed build-only run left no dry-run marker"
  if env PACKBIN_PUBLISH=1 PACKBIN_OUT="$ph_out" PACKBIN_VERSION=v0.1.9 \
    bash "$here/publish-upload.sh" csharp >"$ph_dir/dry-failed-upload.out" 2>&1; then
    fail "AZ-2096 AC-3 the upload phase accepted the artifacts of a failed build-only run"
  fi
  grep -q 'build-only run; refusing to upload' "$ph_dir/dry-failed-upload.out" || fail "AZ-2096 AC-3 upload did not refuse for the dry-run marker"

  printf 'cpp\n' > "$ph_plan"
  printf '#!/bin/sh\necho "pio stub: pack failed" >&2\nexit 1\n' > "$fail_bin/pio"
  chmod +x "$fail_bin/pio"
  ph_bares pio-fails
  ph_publish pio-fails "$fail_bin" "${ph_creds[@]}"
  [ "$ph_code" -ne 0 ] || fail "AZ-2096 AC-2 publish passed with a failing platformio pack"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-2 a registry command ran after the platformio build failed"
  ph_no_refs "AZ-2096 AC-2 pio"
  grep -qx 'build ok vcpkg' "$ph_out/artifacts/build.log" || fail "AZ-2096 AC-2 vcpkg was not prepared before the failure"
  grep -q '^build failed: platformio$' "$ph_dir/pio-fails.out" || fail "AZ-2096 AC-2 failure does not name platformio"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}

# AC-4 on fabricated artifacts: a control that passes, then one violation per case.
ph_fabricated_checks() {
  local fab="$ph_dir/fab" case_dir expected target keyword
  python3 - "$fab" <<'PY'
import hashlib, io, json, sys, tarfile, zipfile
from pathlib import Path

fab = Path(sys.argv[1])
V = "0.1.9"

def put(case, name, data):
    path = fab / case
    path.mkdir(parents=True, exist_ok=True)
    (path / name).write_bytes(data)

def zipped(files):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        for name, data in files.items():
            z.writestr(name, data)
    return buffer.getvalue()

def tarred(files):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as t:
        for name, data in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
    return buffer.getvalue()

def nupkg(case, version=V, license_xml="<license type=\"expression\">MIT</license>", frameworks=("netstandard2.0", "net10.0")):
    spec = f"<package xmlns=\"x\"><metadata><id>Packbin</id><version>{version}</version>{license_xml}</metadata></package>"
    files = {"Packbin.nuspec": spec, "README.md": "r"}
    for framework in frameworks:
        files[f"lib/{framework}/Packbin.dll"] = "d"
    put(case, f"Packbin.{V}.nupkg", zipped(files))

nupkg("csharp-ok")
nupkg("csharp-version", version="0.1.0")
nupkg("csharp-license", license_xml="")
nupkg("csharp-payload", frameworks=("net10.0",))

def npm(case, version=V, license="MIT", index=True):
    manifest = json.dumps({"name": "packbin", "version": version, "license": license, "types": "./dist/index.d.ts", "exports": {".": {"types": "./dist/index.d.ts", "import": "./dist/index.js"}}}).encode()
    files = {"package/package.json": manifest, "package/README.md": b"r"}
    if index:
        files["package/dist/index.js"] = b"x"
        files["package/dist/index.d.ts"] = b"x"
    put(case, f"packbin-{V}.tgz", tarred(files))

npm("typescript-ok")
npm("typescript-version", version="0.1.0")
npm("typescript-license", license="")
npm("typescript-payload", index=False)

def python(case, version=V, license="License: MIT", init=True):
    metadata = f"Name: packbin\nVersion: {version}\n{license}\n".encode()
    files = {f"packbin-{V}.dist-info/METADATA": metadata}
    if init:
        files["packbin/__init__.py"] = b""
    put(case, f"packbin-{V}-py3-none-any.whl", zipped(files))
    pkg_info = f"Name: packbin\nVersion: {version}\n{license}\n".encode()
    put(case, f"packbin-{V}.tar.gz", tarred({f"packbin-{V}/PKG-INFO": pkg_info, f"packbin-{V}/src/packbin/__init__.py": b""}))

python("python-ok")
python("python-version", version="0.1.0")
python("python-license", license="License: Proprietary")
python("python-payload", init=False)

def java(case, major=61, sign=True):
    klass = b"\xca\xfe\xba\xbe\x00\x00" + major.to_bytes(2, "big")
    base = f"io/github/zxsanny/packbin/{V}/packbin-{V}"
    pom = f"<project xmlns=\"x\"><version>{V}</version><name>packbin</name><licenses><license><name>MIT</name></license></licenses></project>".encode()
    parts = {".pom": pom, ".jar": zipped({"packbin/A.class": klass}), "-sources.jar": b"s", "-javadoc.jar": b"j"}
    files = {}
    for suffix, data in parts.items():
        files[base + suffix] = data
        if sign:
            files[base + suffix + ".asc"] = b"-----BEGIN PGP SIGNATURE-----\n"
        files[base + suffix + ".md5"] = hashlib.md5(data).hexdigest().encode()
        files[base + suffix + ".sha1"] = hashlib.sha1(data).hexdigest().encode()
    put(case, "maven-bundle.zip", zipped(files))

java("java-ok")
java("java-major", major=52)
java("java-signature", sign=False)
PY
  for case_dir in "$fab"/*; do
    target="$(basename "$case_dir")"
    target="${target%%-*}"
    expected="$(basename "$case_dir")"
    expected="${expected#*-}"
    keyword=""
    case "$expected" in
      version) keyword="version" ;;
      license) keyword="license" ;;
      payload) keyword="missing" ;;
      major) keyword="major 52" ;;
      signature) keyword=".asc" ;;
    esac
    if [ "$expected" = "ok" ]; then
      python3 "$here/publish-check.py" "$target" "$case_dir" v0.1.9 >"$ph_dir/fab.out" 2>&1 \
        || fail "AZ-2096 AC-4 control $target was rejected: $(cat "$ph_dir/fab.out")"
      continue
    fi
    if python3 "$here/publish-check.py" "$target" "$case_dir" v0.1.9 >"$ph_dir/fab.out" 2>&1; then
      fail "AZ-2096 AC-4 $(basename "$case_dir") passed the check"
    elif ! grep -q "^check failed: $target: .*$keyword" "$ph_dir/fab.out"; then
      fail "AZ-2096 AC-4 $(basename "$case_dir") did not name $target and $keyword: $(cat "$ph_dir/fab.out")"
    else
      echo "artifact check rejects $(basename "$case_dir"): $(cat "$ph_dir/fab.out")"
    fi
  done
}

# AC-4 through the real pipeline: a version that is not rewritten, and a missing license.
ph_pipeline_violations() {
  local csproj="$ph_tree/csharp/Packbin.csproj" pyproject="$ph_tree/python/pyproject.toml"
  ph_set_credentials
  ph_bares violation
  cp "$pyproject" "$ph_dir/pyproject.orig"
  sed "s/^version = \"0.1.0\"/version = '0.1.0'/" "$ph_dir/pyproject.orig" > "$pyproject"
  cmp -s "$pyproject" "$ph_dir/pyproject.orig" && fail "AZ-2096 AC-4 pyproject copy is unchanged"
  printf 'python\n' > "$ph_plan"
  ph_publish violation-version - "${ph_creds[@]}"
  cp "$ph_dir/pyproject.orig" "$pyproject"
  [ "$ph_code" -ne 0 ] || fail "AZ-2096 AC-4 a wheel with the wrong version was published"
  grep -q '^check failed: python: packbin-0.1.0-py3-none-any.whl does not carry version 0.1.9$' "$ph_dir/violation-version.out" \
    || fail "AZ-2096 AC-4 version failure not named: $(ph_quote "$ph_dir/violation-version.out")"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-4 an upload ran after a failed check"

  cp "$csproj" "$ph_dir/csproj.orig"
  grep -v 'PackageLicenseExpression' "$ph_dir/csproj.orig" > "$csproj"
  printf 'csharp\n' > "$ph_plan"
  ph_publish violation-license - "${ph_creds[@]}"
  cp "$ph_dir/csproj.orig" "$csproj"
  [ "$ph_code" -ne 0 ] || fail "AZ-2096 AC-4 a nupkg without a license was published"
  grep -q '^check failed: csharp: license MIT is not declared' "$ph_dir/violation-license.out" \
    || fail "AZ-2096 AC-4 license failure not named: $(ph_quote "$ph_dir/violation-license.out")"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-4 an upload ran after a failed license check"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}
