#!/usr/bin/env bash
# Upload step of the pubdev target (ADR-011), run by publish-upload.sh in the optional tier, and only for a version
# pub.dev does not hold yet (publish-query.sh asked; a version it holds is reported "already published" and never
# reaches this script). The build phase prepared the package in $PACKBIN_OUT/artifacts/pubdev/package with the version of
# the tag in its pubspec.yaml and a dry run that reported no error (publish-dart-prepare.sh, publish-check.py).
#
# The official mechanism, and nothing else: the job runs with `id-token: write` from the push of a version tag. This
# script asks GitHub for an OIDC token with the audience https://pub.dev right before the upload (what the
# dart-lang/setup-dart step does through @actions/core getIDToken: GET $ACTIONS_ID_TOKEN_REQUEST_URL&audience=<encoded
# audience>, bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN, the token in the JSON field "value"), exports it as PUB_TOKEN for
# this process only, registers it with `dart pub token add https://pub.dev --env-var PUB_TOKEN` (the same call as
# setup-dart) and runs `dart pub publish --force`. A token made earlier by setup-dart is not used: a GitHub OIDC token
# lives about five minutes, and the upload comes after the build phase and after the Maven Central wait. No token is
# stored, and the token is never printed (only `::add-mask::`, which the runner consumes). Before the upload it checks,
# read-only: the token is a JWT that has not expired, and `dart pub token list` shows pub.dev registered (without it
# `dart pub publish` would ask for an interactive login). A token past its `exp` fails the run with "run the tag again":
# a re-run only uploads what is missing.
#
# No credential of another registry is visible to dart (loop 99 audit, D3): every one is unset before the token is requested, the
# OIDC request variables included (they are read into this script's variables first).
#
# The package is published from a copy in a fresh temporary directory outside any git repository: pub lists the files of
# a package inside a work tree with git, which would find .github/workflows/out ignored and publish nothing.
#
# Needs: PACKBIN_OUT, PACKBIN_VERSION, ACTIONS_ID_TOKEN_REQUEST_URL, ACTIONS_ID_TOKEN_REQUEST_TOKEN; dart, curl and
# python3 on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
package="$out/artifacts/pubdev/package"
request_url="${ACTIONS_ID_TOKEN_REQUEST_URL:-}"
request_token="${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}"
# No argument: no credential is kept, not even the OIDC request variables, and a PUB_TOKEN made by setup-dart is gone.
# shellcheck disable=SC2119
unset_credentials
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ -z "$request_url" ] || [ -z "$request_token" ]; then
  echo "no GitHub OIDC token can be requested: the job needs id-token: write (ADR-011)" >&2
  exit 1
fi

# Asks GitHub for the OIDC token of audience https://pub.dev and prints it. The bearer token goes to curl in a header
# file, not on the command line.
pubdev_oidc_token() {
  local code body="$work/oidc.json" token
  umask 077
  printf 'Authorization: Bearer %s\n' "$request_token" > "$work/oidc-header"
  code="$(curl --silent --show-error --max-time 20 --connect-timeout 10 \
    -H "@$work/oidc-header" -H "User-Agent: packbin-publish" -H "Accept: application/json" \
    -o "$body" -w '%{http_code}' "${request_url}&audience=https%3A%2F%2Fpub.dev")" || {
    echo "the request for the pub.dev OIDC token failed; nothing was uploaded; run the tag again" >&2
    return 1
  }
  if [ "$code" != 200 ]; then
    echo "GitHub answered $code to the request for the pub.dev OIDC token; nothing was uploaded; run the tag again" >&2
    return 1
  fi
  token="$(python3 -I -c 'import json, sys; v = json.load(open(sys.argv[1])).get("value"); print(v if isinstance(v, str) else "")' "$body")" \
    || token=""
  if [ -z "$token" ]; then
    echo "GitHub did not return an OIDC token for pub.dev; nothing was uploaded; run the tag again" >&2
    return 1
  fi
  printf '%s\n' "$token"
}

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

mkdir -p "$work/package"
cp -R "$package/." "$work/package/"

# The token is made here, after the build phase and after every earlier upload, and lives in this process only.
PUB_TOKEN="$(pubdev_oidc_token)"
export PUB_TOKEN
echo "::add-mask::$PUB_TOKEN"

left="$(token_seconds_left)" || {
  echo "cannot read the OIDC token that GitHub returned for pub.dev" >&2
  exit 1
}
if [ "$left" -lt 30 ]; then
  echo "the OIDC token for pub.dev expired ${left#-} s ago or is about to (left: $left s); nothing was uploaded;" \
    "run the tag again: a re-run uploads only what is missing" >&2
  exit 1
fi

dart pub token add https://pub.dev --env-var PUB_TOKEN < /dev/null
registered="$(dart pub token list < /dev/null)" || {
  echo "dart pub token list failed" >&2
  exit 1
}
if ! grep -qxF "https://pub.dev" <<< "$registered"; then
  echo "dart pub token add did not register a token for https://pub.dev: dart pub token list shows [$registered]" >&2
  exit 1
fi

echo "dart pub publish --force packbin $version"
(cd "$work/package" && dart pub publish --force < /dev/null)
