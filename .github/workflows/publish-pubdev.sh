#!/usr/bin/env bash
# Upload step of the pubdev target (ADR-011), run by publish-upload.sh in the required tier, and only for a version
# pub.dev does not hold yet (publish-query.sh asked; a version it holds is reported "already published" and never
# reaches this script). The build phase prepared the package in $PACKBIN_OUT/artifacts/pubdev/package with the version of
# the tag in its pubspec.yaml and a dry run that reported no error (publish-dart-prepare.sh, publish-check.py).
#
# The official mechanism, and nothing else: the job runs with `id-token: write` from the push of a version tag, the
# dart-lang/setup-dart step trades that for a short-lived OIDC token, exports it as PUB_TOKEN and registers it with
# `dart pub token add https://pub.dev --env-var PUB_TOKEN`, and this script runs `dart pub publish --force`. It stores no
# token and creates none. Before the upload it checks, read-only, what a failure would otherwise show late and unclearly:
# PUB_TOKEN is a JWT that has not expired, and `dart pub token list` shows pub.dev registered (without it `dart pub
# publish` would ask for an interactive login). A token past its `exp` fails the run with "run the tag again": a re-run
# only uploads what is missing.
#
# The package is published from a copy in a fresh temporary directory outside any git repository: pub lists the files of
# a package inside a work tree with git, which would find .github/workflows/out ignored and publish nothing.
#
# Needs: PACKBIN_OUT, PACKBIN_VERSION, PUB_TOKEN; dart and python3 on PATH.
set -euo pipefail

version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
package="$out/artifacts/pubdev/package"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ -z "${PUB_TOKEN:-}" ]; then
  echo "PUB_TOKEN is not set: the job needs id-token: write and a dart-lang/setup-dart step before this one (ADR-011)" >&2
  exit 1
fi

# Seconds until the token expires (negative: it has), from the exp claim of the JWT; fails when it is not a JWT with one.
token_seconds_left() {
  python3 -I -c '
import base64, json, os, sys, time
parts = os.environ["PUB_TOKEN"].split(".")
if len(parts) != 3:
    sys.exit("PUB_TOKEN is not a JWT")
payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
if not isinstance(payload.get("exp"), (int, float)):
    sys.exit("the PUB_TOKEN payload has no exp")
print(int(payload["exp"] - time.time()))
'
}

left="$(token_seconds_left)" || {
  echo "cannot read the OIDC token that setup-dart exported as PUB_TOKEN" >&2
  exit 1
}
if [ "$left" -lt 30 ]; then
  echo "the OIDC token of setup-dart expired ${left#-} s ago or is about to (left: $left s); nothing was uploaded;" \
    "run the tag again: a re-run uploads only what is missing" >&2
  exit 1
fi

registered="$(dart pub token list < /dev/null)" || {
  echo "dart pub token list failed" >&2
  exit 1
}
if ! grep -qxF "https://pub.dev" <<< "$registered"; then
  echo "setup-dart did not register a token for https://pub.dev: dart pub token list shows [$registered]" >&2
  exit 1
fi

mkdir -p "$work/package"
cp -R "$package/." "$work/package/"
echo "dart pub publish --force packbin $version"
(cd "$work/package" && dart pub publish --force < /dev/null)
