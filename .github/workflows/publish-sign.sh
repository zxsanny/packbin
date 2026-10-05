#!/usr/bin/env bash
# Signs the Maven tree that publish-inside.sh java left in <dir>/maven, adds the .md5/.sha1
# files Central requires and zips it to <dir>/maven-bundle.zip. Runs on the host, in the build phase.
# The key comes from MAVEN_GPG_PRIVATE_KEY. A build-only run (PACKBIN_BUILD_ONLY=1) has no key and
# signs with a throwaway one, so its bundle exercises the same steps but can never be accepted.
# Usage: publish-sign.sh <artifacts/java directory>
set -euo pipefail

dest="${1:?java artifact directory}"
src="$dest/maven"
if [ ! -d "$src" ]; then
  echo "maven bundle directory is missing" >&2
  exit 1
fi

ring="$(mktemp -d)"
chmod 700 "$ring"
trap 'rm -rf "$ring"' EXIT
export GNUPGHOME="$ring"

if [ -n "${MAVEN_GPG_PRIVATE_KEY:-}" ]; then
  printf '%s\n' "$MAVEN_GPG_PRIVATE_KEY" | gpg --batch --import
elif [ "${PACKBIN_BUILD_ONLY:-}" = "1" ]; then
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "packbin-build-only" rsa3072 sign 0
else
  echo "MAVEN_GPG_PRIVATE_KEY is required before any registry write" >&2
  exit 1
fi

while IFS= read -r -d '' file <&3; do
  case "$file" in
    *.pom|*.jar)
      gpg --batch --yes --pinentry-mode loopback \
        --detach-sign --armor --output "$file.asc" "$file"
      python3 - "$file" <<'PY'
import hashlib, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
for name in ("md5", "sha1"):
    path.with_name(path.name + "." + name).write_text(hashlib.new(name, data).hexdigest() + "\n")
PY
      ;;
  esac
done 3< <(find "$src" -type f -print0)

python3 - "$src" "$dest/maven-bundle.zip" <<'PY'
import sys, zipfile
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(src.rglob("*")):
        if path.is_file():
            bundle.write(path, path.relative_to(src).as_posix())
PY
rm -rf "$src"
