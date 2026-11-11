---
loop: 107
branch: dev
---

# Maven signing key: upload it with every publish run

Short loop on the launcher (one CI-script change, no new service or API).

The 0.5.0 tag run failed at Maven Central because Central could not find the public half of the signing key
(`MAVEN_GPG_PRIVATE_KEY`) on a keyserver; the one-click workflow `publish-key.yml` fixed it by hand. Make the publish
run do that check itself, so a dropped key never fails a release.

## Code sections / UI locations for this loop

Owner chose the option "Automate key upload" (loop 105 leftover): `.github/workflows/publish-sign.sh` (the build phase
already imports the key). The registry write itself belongs to `publish-upload.sh` (`upload_maven`): the build phase
writes nothing to a registry, and `publish-upload.sh` may not call gpg (static check AZ-2096 AC-3/AC-5), so the build
phase leaves the public key and its fingerprint beside the bundle and the upload phase sends it with curl.

## Flagged concerns

| concern | policy/owner | status | severity |
|---------|--------------|--------|----------|
| keyserver outage must not add a release blocker Central would not have | Central stays the authority: an unconfirmed upload is a warning, not a stop | accepted-risk | Low |

## Acceptance criteria

- AC-1: after a build with a real key, `artifacts/java` holds `signing-key.asc` (public key only, no secret block) and
  `signing-key.fpr` (40 hex characters); a build-only run writes neither.
- AC-2: when `keys.openpgp.org` already serves the fingerprint, the upload phase sends 0 key uploads (1 lookup).
- AC-3: when it does not, the upload phase sends exactly 1 key upload, then looks the fingerprint up again (at most 6
  attempts, 10 s apart), and goes on to the Maven upload in both outcomes; a key still missing after the attempts
  prints a `::warning::` line.
- AC-4: 0 bytes of the secret key reach any curl argument or log line.
- AC-5: the existing static checks stay green (`publish-upload.sh` has no `gpg`, no upload word in the build files).

## Expected I/O

| scenario | curl calls (ordered) |
|----------|----------------------|
| key served | lookup (200), bundle upload, status |
| key missing, upload works | lookup (404), key upload, lookup (200), bundle upload, status |
| key missing, never served | lookup (404), key upload, 6 lookups (404), warning, bundle upload, status |
