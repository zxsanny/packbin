# Loop 107 smoke - agent run

Branch: dev. CI-script loop (AZ-4196): no UI, no local deploy. The checks are the script `smoke107.sh` in this folder.

## Agent walk (2026-11-11, at cc9b439)

- [x] PASS 1 shellcheck warnings on publish-sign.sh and publish-upload.sh: none
- [x] PASS 2 real key: signing-key.asc and signing-key.fpr written
- [x] PASS 3 fingerprint is 40 hex characters
- [x] PASS 4 key file is public only
- [x] PASS 5 build-only run writes no key file
- [x] PASS 6 live: the production key is served by keys.openpgp.org (HTTP 200, so the upload phase sends no key)
- [x] PASS 7 publish-upload.sh holds no gpg call

smoke107: 7 passed, 0 failed.

## For the operator

Nothing (rule 2026-10-12: all steps passed, the agent closes the gate).
