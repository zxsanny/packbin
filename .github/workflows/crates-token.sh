#!/usr/bin/env bash
set -euo pipefail

endpoint="https://crates.io/api/v1/trusted_publishing/tokens"
agent="packbin-publish"

json_field() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1"
}

exchange() {
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] || [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
    echo "id-token permission is required" >&2
    exit 1
  fi
  local oidc jwt body code token
  oidc="$(curl -sS \
    -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    -H "User-Agent: ${agent}" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=crates.io")"
  jwt="$(printf '%s' "$oidc" | json_field value)"
  if [ -z "$jwt" ]; then
    echo "GitHub did not return an OIDC token" >&2
    exit 1
  fi
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -H "User-Agent: ${agent}" \
    --data-binary "{\"jwt\":\"${jwt}\"}")"
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    echo "crates.io token request failed: ${code}" >&2
    rm -f "$body"
    exit 1
  fi
  token="$(json_field token <"$body")"
  rm -f "$body"
  if [ -z "$token" ]; then
    echo "crates.io token response had no token" >&2
    exit 1
  fi
  echo "::add-mask::${token}"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf 'token=%s\n' "$token" >> "$GITHUB_OUTPUT"
  fi
}

revoke() {
  if [ -z "${CARGO_REGISTRY_TOKEN:-}" ]; then
    echo "no crates.io token to revoke"
    return 0
  fi
  local attempt code pause
  pause="${PACKBIN_CRATES_REVOKE_PAUSE:-5}"
  for attempt in 1 2 3 4 5; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$endpoint" \
      -H "Authorization: Bearer ${CARGO_REGISTRY_TOKEN}" \
      -H "User-Agent: ${agent}" || true)"
    case "$code" in
      2??)
        echo "crates.io token revoked"
        return 0
        ;;
      000|502|503|504)
        echo "crates.io revoke returned ${code}"
        if [ "$attempt" -lt 5 ]; then
          sleep "$pause"
        fi
        ;;
      *)
        echo "crates.io revoke returned ${code}"
        return 0
        ;;
    esac
  done
  echo "crates.io revoke still unavailable"
}

case "${1:-}" in
  exchange) exchange ;;
  revoke) revoke ;;
  *)
    echo "usage: crates-token.sh exchange|revoke" >&2
    exit 1
    ;;
esac
