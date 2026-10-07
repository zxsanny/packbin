#!/usr/bin/env python3
"""Checks one built artifact directory before anything is uploaded.

Usage: publish-check.py <target> <artifact directory> <version>

Every target must carry the tag version, declare MIT and hold its main payload. On failure the
script prints `check failed: <target>: <what>` to stderr and exits 1; on success it prints
`check ok: <target>` and exits 0. Exit code 2 is a usage error.
"""
import hashlib
import io
import json
import posixpath
import re
import subprocess
import sys
import tarfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

TARGETS = {}


class CheckFailed(Exception):
    pass


def need(condition, what):
    if not condition:
        raise CheckFailed(what)


def target(name):
    def register(function):
        TARGETS[name] = function
        return function
    return register


def single(directory, pattern):
    found = sorted(directory.glob(pattern))
    need(len(found) == 1, f"expected one {pattern} in {directory}, found {len(found)}")
    return found[0]


def zip_members(source, label):
    need(zipfile.is_zipfile(source), f"{label} is not a zip archive")
    with zipfile.ZipFile(source) as archive:
        return {name: archive.read(name) for name in archive.namelist() if not name.endswith("/")}


def tar_members(path):
    need(tarfile.is_tarfile(path), f"{path.name} is not a tar archive")
    members = {}
    with tarfile.open(path) as archive:
        for member in archive.getmembers():
            if member.isfile():
                members[member.name.removeprefix("./")] = archive.extractfile(member).read()
    return members


def member(members, name, archive):
    need(name in members, f"{archive} lacks {name}")
    return members[name]


def header_value(text, key):
    match = re.search(rf"(?mi)^{re.escape(key)}:[ \t]*(.+?)[ \t]*$", text)
    return match.group(1) if match else None


def xml_text(root, tag):
    element = root.find(f".//{{*}}{tag}")
    return element.text.strip() if element is not None and element.text else None


@target("csharp")
def check_csharp(directory, version):
    package = single(directory, "*.nupkg")
    need(package.name == f"Packbin.{version}.nupkg", f"{package.name} is not Packbin.{version}.nupkg")
    members = zip_members(package, package.name)
    specs = [name for name in members if name.endswith(".nuspec") and "/" not in name]
    need(len(specs) == 1, f"{package.name} lacks its nuspec")
    spec = ET.fromstring(members[specs[0]])
    need(xml_text(spec, "id") == "Packbin", "nuspec id is not Packbin")
    need(xml_text(spec, "version") == version, f"nuspec version {xml_text(spec, 'version')} is not {version}")
    need(xml_text(spec, "license") == "MIT", "license MIT is not declared in the nuspec")
    for framework in ("netstandard2.0", "net10.0"):
        need(f"lib/{framework}/Packbin.dll" in members, f"lib/{framework}/Packbin.dll is missing")
    need("README.md" in members, "README.md is missing")


# The npm entry points and the relative imports of the compiled files (`from "./x.js"`, `import "./x.js"`,
# `import("./x.js")`); the .d.ts files keep a `.ts` specifier.
NPM_TYPES = "./dist/index.d.ts"
NPM_EXPORTS = {".": {"types": NPM_TYPES, "import": "./dist/index.js"}}
NPM_RELATIVE_IMPORT = re.compile(r"""(?:\bfrom\s*|\bimport\s*\(?\s*)["'](\.{1,2}/[^"']+)["']""")


@target("typescript")
def check_typescript(directory, version):
    package = single(directory, "*.tgz")
    need(package.name == f"packbin-{version}.tgz", f"{package.name} is not packbin-{version}.tgz")
    members = tar_members(package)
    manifest = json.loads(member(members, "package/package.json", package.name))
    need(manifest.get("name") == "packbin", "package.json name is not packbin")
    need(manifest.get("version") == version, f"package.json version {manifest.get('version')} is not {version}")
    need(manifest.get("license") == "MIT", "license MIT is not declared in package.json")
    need(manifest.get("types") == NPM_TYPES, f"package.json types is {manifest.get('types')!r}, not {NPM_TYPES!r}")
    need(manifest.get("exports") == NPM_EXPORTS, f"package.json exports is {manifest.get('exports')!r}, not {NPM_EXPORTS!r}")
    need("package/dist/index.js" in members, "dist/index.js is missing")
    need("package/dist/index.d.ts" in members, "dist/index.d.ts is missing")
    need(not any(name.startswith("package/src/") for name in members), "src/ is in the tarball")
    need("package/README.md" in members, "README.md is missing")
    for name in sorted(members):
        if name.startswith("package/dist/") and name.endswith((".js", ".d.ts")):
            for specifier in NPM_RELATIVE_IMPORT.findall(members[name].decode()):
                path = posixpath.normpath(posixpath.join(posixpath.dirname(name), specifier))
                if name.endswith(".d.ts"):
                    path = path.removesuffix(".ts").removesuffix(".js") + ".d.ts"
                shown = name.removeprefix("package/")
                need(path in members, f"{shown} imports {specifier}, but {path.removeprefix('package/')} is not in the tarball")


@target("python")
def check_python(directory, version):
    wheel = single(directory, "*.whl")
    need(wheel.name.startswith(f"packbin-{version}-"), f"{wheel.name} does not carry version {version}")
    members = zip_members(wheel, wheel.name)
    metadata_names = [name for name in members if name.endswith(".dist-info/METADATA")]
    need(len(metadata_names) == 1, f"{wheel.name} lacks METADATA")
    metadata = members[metadata_names[0]].decode()
    need(header_value(metadata, "Version") == version, f"wheel version {header_value(metadata, 'Version')} is not {version}")
    need("MIT" in (header_value(metadata, "License-Expression"), header_value(metadata, "License")), "license MIT is not declared in the wheel metadata")
    need("packbin/__init__.py" in members, "packbin/__init__.py is missing from the wheel")
    sdist = single(directory, "*.tar.gz")
    need(sdist.name == f"packbin-{version}.tar.gz", f"{sdist.name} is not packbin-{version}.tar.gz")
    files = tar_members(sdist)
    info = member(files, f"packbin-{version}/PKG-INFO", sdist.name).decode()
    need(header_value(info, "Version") == version, f"sdist version {header_value(info, 'Version')} is not {version}")
    need("MIT" in (header_value(info, "License-Expression"), header_value(info, "License")), "license MIT is not declared in the sdist")
    need(f"packbin-{version}/src/packbin/__init__.py" in files, "src/packbin/__init__.py is missing from the sdist")


@target("rust")
def check_rust(directory, version):
    crate = single(directory, "*.crate")
    need(crate.name == f"packbin-{version}.crate", f"{crate.name} is not packbin-{version}.crate")
    members = tar_members(crate)
    manifest = member(members, f"packbin-{version}/Cargo.toml", crate.name).decode()
    need(re.search(rf'(?m)^version = "{re.escape(version)}"$', manifest), f"Cargo.toml version is not {version}")
    need(re.search(r'(?m)^license = "MIT"$', manifest), "license MIT is not declared in Cargo.toml")
    need(f"packbin-{version}/src/lib.rs" in members, "src/lib.rs is missing")
    need(f"packbin-{version}/README.md" in members, "README.md is missing")
    staged = (directory / "stage" / "Cargo.toml")
    need(staged.is_file(), "the staged directory for the crates.io upload is missing")
    need(re.search(rf'(?m)^version = "{re.escape(version)}"$', staged.read_text()), f"staged Cargo.toml version is not {version}")
    need(not (directory / "stage" / "target").exists(), "the staged directory holds a build target")


@target("java")
def check_java(directory, version):
    bundle = single(directory, "maven-bundle.zip")
    members = zip_members(bundle, bundle.name)
    need(not any(name == "META-INF" or name.startswith("META-INF/") for name in members), "the bundle contains META-INF")
    base = f"io/github/zxsanny/packbin/{version}/packbin-{version}"
    for name in (".pom", ".jar", "-sources.jar", "-javadoc.jar"):
        path = base + name
        data = member(members, path, bundle.name)
        signature = member(members, path + ".asc", bundle.name)
        need(signature.startswith(b"-----BEGIN PGP SIGNATURE-----"), f"{path}.asc is not an armored signature")
        for algorithm in ("md5", "sha1"):
            expected = hashlib.new(algorithm, data).hexdigest()
            need(member(members, f"{path}.{algorithm}", bundle.name).decode().strip() == expected, f"{path}.{algorithm} does not match the file")
    pom = ET.fromstring(members[base + ".pom"])
    need(xml_text(pom, "version") == version, f"pom version {xml_text(pom, 'version')} is not {version}")
    license_name = pom.find(".//{*}licenses/{*}license/{*}name")
    need(license_name is not None and license_name.text.strip() == "MIT", "license MIT is not declared in the pom")
    jar = zip_members(io.BytesIO(members[base + ".jar"]), "the jar")
    classes = {name: data for name, data in jar.items() if name.endswith(".class")}
    need(any(name.startswith("packbin/") for name in classes), "the jar holds no packbin classes")
    for name, data in classes.items():
        major = int.from_bytes(data[6:8], "big")
        need(data[:4] == b"\xca\xfe\xba\xbe" and major == 61, f"{name} is class file major {major}, not 61 (Java 17)")


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    need(result.returncode == 0, f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


@target("vcpkg")
def check_vcpkg(directory, version):
    repo = directory / "reg"
    need((repo / ".git").exists(), "the prepared vcpkg clone is missing")
    port = repo / "ports" / "packbin"
    manifest = json.loads((port / "vcpkg.json").read_text())
    need(manifest.get("name") == "packbin", "vcpkg.json name is not packbin")
    need(manifest.get("version") == version, f"vcpkg.json version {manifest.get('version')} is not {version}")
    need(manifest.get("license") == "MIT", "license MIT is not declared in vcpkg.json")
    need((port / "portfile.cmake").is_file(), "portfile.cmake is missing")
    need((port / "include" / "packbin" / "packbin.hpp").is_file(), "include/packbin/packbin.hpp is missing from the port")
    need(any((port / "src").rglob("*.cpp")), "the port holds no sources")
    cmake, licence = port / "CMakeLists.txt", port / "LICENSE"
    need(cmake.is_file() and "add_library(packbin" in cmake.read_text(), "CMakeLists.txt is missing or does not build the packbin library")
    need(licence.is_file() and "MIT License" in licence.read_text(), "LICENSE is missing or is not the MIT license text")
    dependencies = manifest.get("dependencies")
    hosts = {entry.get("name") for entry in dependencies if isinstance(entry, dict) and entry.get("host") is True} if isinstance(dependencies, list) else set()
    for name in ("vcpkg-cmake", "vcpkg-cmake-config"):
        need(name in hosts, f"vcpkg.json lacks the host dependency {name}")
    baseline = json.loads((repo / "versions" / "baseline.json").read_text())
    need(baseline["default"]["packbin"]["baseline"] == version, f"baseline.json is not {version}")
    history = json.loads((repo / "versions" / "p-" / "packbin.json").read_text())["versions"][0]
    need(history["version"] == version, f"the newest versions entry is {history['version']}, not {version}")
    need(history["git-tree"] == git(repo, "rev-parse", "HEAD:ports/packbin"), "the versions entry git-tree is not the committed port tree")
    need(git(repo, "status", "--porcelain") == "", "the vcpkg clone has uncommitted changes")


@target("arduino")
def check_arduino(directory, version):
    repo = directory / "reg"
    need((repo / ".git").exists(), "the prepared Arduino clone is missing")
    properties = (repo / "library.properties").read_text()
    need(re.search(rf"(?m)^version={re.escape(version)}$", properties), f"library.properties version is not {version}")
    need("MIT License" in (repo / "LICENSE").read_text(), "license MIT is not declared in LICENSE")
    need((repo / "src" / "packbin.h").is_file(), "src/packbin.h is missing")
    need(git(repo, "rev-parse", f"arduino-{version}^{{commit}}") == git(repo, "rev-parse", "HEAD"), f"tag arduino-{version} is not at HEAD")
    need(git(repo, "status", "--porcelain") == "", "the Arduino clone has uncommitted changes")


@target("platformio")
def check_platformio(directory, version):
    package = single(directory, "*.tar.gz")
    need(package.name == f"packbin-{version}.tar.gz", f"{package.name} is not packbin-{version}.tar.gz")
    members = tar_members(package)
    manifest = json.loads(member(members, "library.json", package.name))
    need(manifest.get("version") == version, f"library.json version {manifest.get('version')} is not {version}")
    need(manifest.get("license") == "MIT", "license MIT is not declared in library.json")
    need("include/packbin/packbin.hpp" in members, "include/packbin/packbin.hpp is missing")
    need("src/core/pack.cpp" in members, "src/core/pack.cpp is missing")


@target("esp-idf")
def check_idf(directory, version):
    package = single(directory, "*.tgz")
    need(package.name == f"packbin_{version}.tgz", f"{package.name} is not packbin_{version}.tgz")
    members = tar_members(package)
    manifest = member(members, "idf_component.yml", package.name).decode()
    need(re.search(rf"""(?m)^version: ["']?{re.escape(version)}["']?$""", manifest), f"idf_component.yml version is not {version}")
    need(re.search(r"""(?m)^license: ["']?MIT["']?$""", manifest), "license MIT is not declared in idf_component.yml")
    need("include/packbin/packbin.hpp" in members, "include/packbin/packbin.hpp is missing")
    need("src/core/pack.cpp" in members, "src/core/pack.cpp is missing")
    need("CMakeLists.txt" in members, "CMakeLists.txt is missing")


# The five targets built in a container: a symlink in their tree could make the host tools that run
# next (cargo package, publish-sign.sh, publish-upload.sh) read or write a file outside it.
CONTAINER_TARGETS = ("csharp", "typescript", "python", "rust", "java")


def refuse_symlinks(directory):
    for path in sorted(directory.rglob("*")):
        need(not path.is_symlink(), f"{path.relative_to(directory)} is a symlink")


def main(argv):
    if len(argv) != 4 or argv[1] not in TARGETS:
        print(f"usage: publish-check.py <{'|'.join(TARGETS)}> <directory> <version>", file=sys.stderr)
        return 2
    name, directory, version = argv[1], Path(argv[2]), argv[3].removeprefix("v")
    try:
        need(directory.is_dir(), f"{directory} is not a directory")
        if name in CONTAINER_TARGETS:
            refuse_symlinks(directory)
        TARGETS[name](directory, version)
    except (CheckFailed, OSError, KeyError, IndexError, ValueError, zipfile.BadZipFile, tarfile.TarError, ET.ParseError) as error:
        reason = error if isinstance(error, CheckFailed) else f"{type(error).__name__}: {error}"
        print(f"check failed: {name}: {reason}", file=sys.stderr)
        return 1
    print(f"check ok: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
