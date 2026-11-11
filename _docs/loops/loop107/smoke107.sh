#!/usr/bin/env bash
# Loop 107 smoke (AZ-4196): the signing key files and the live keyserver lookup. Needs gpg, shellcheck, curl, python3.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
w=.github/workflows
pass=0; failn=0
step() { if "${@:2}" >/tmp/smoke107.step 2>&1; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; sed 's/^/    /' /tmp/smoke107.step | tail -n 8; failn=$((failn+1)); fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GNUPGHOME="$tmp/ring"; mkdir -m 700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key smoke107 rsa3072 sign 0 2>/dev/null
secret="$(gpg --armor --export-secret-keys)"
mk_tree() { mkdir -p "$1/maven/g"; printf 'x' > "$1/maven/g/a.pom"; printf 'y' > "$1/maven/g/a.jar"; }

s1() { shellcheck -S warning "$w/publish-sign.sh" "$w/publish-upload.sh"; }
s2() { mk_tree "$tmp/real"; ( unset GNUPGHOME; MAVEN_GPG_PRIVATE_KEY="$secret" bash "$w/publish-sign.sh" "$tmp/real" ) && [ -s "$tmp/real/signing-key.asc" ] && [ -s "$tmp/real/signing-key.fpr" ]; }
s3() { grep -qx '[0-9A-F]\{40\}' "$tmp/real/signing-key.fpr"; }
s4() { head -n 1 "$tmp/real/signing-key.asc" | grep -qx -- '-----BEGIN PGP PUBLIC KEY BLOCK-----' && ! grep -q 'PRIVATE' "$tmp/real/signing-key.asc"; }
s5() { mk_tree "$tmp/bo"; ( unset GNUPGHOME; PACKBIN_BUILD_ONLY=1 bash "$w/publish-sign.sh" "$tmp/bo" ) && [ ! -e "$tmp/bo/signing-key.asc" ] && [ ! -e "$tmp/bo/signing-key.fpr" ]; }
s6() { [ "$(curl -s -m 30 -o /dev/null -w '%{http_code}' https://keys.openpgp.org/vks/v1/by-fingerprint/3C51A862BEA87BC1BE7B0AB5AC576082216B95B9)" = 200 ]; }
s7() { ! grep -q 'gpg' "$w/publish-upload.sh"; }

step "1 shellcheck warnings on the two scripts: none" s1
step "2 real key: signing-key.asc and signing-key.fpr written" s2
step "3 fingerprint is 40 hex characters" s3
step "4 key file is public only" s4
step "5 build-only run writes no key file" s5
step "6 live: production key is served by keys.openpgp.org (HTTP 200, so no upload is sent)" s6
step "7 publish-upload.sh holds no gpg call" s7
echo "smoke107: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
