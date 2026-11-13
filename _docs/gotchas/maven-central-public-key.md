---
title: "When Maven Central cannot find the signing key, run the publish-key workflow and re-run the failed job; the owner pushes tags"
applies_when: "a v* release fails at Maven Central with a missing public key, or a release needs a tag or GitHub release"
source: "loop 105 (the v0.5.0 run)"
---

Maven Central rejects a release when it cannot find the signing key's public half on a keyserver it reads (the `v0.5.0` run, loop 105: "Could not find a public key by the key fingerprint"): the private key is only the secret `MAVEN_GPG_PRIVATE_KEY` (no machine has it), so do not ask the owner to find a key; run the workflow `publish-key` (Actions tab or `gh workflow run publish-key.yml --ref dev`, it needs about 3 minutes and runner time) and re-run the failed job (`gh run rerun <id> --failed`).

A tag creation and push, and the GitHub release, are denied to the agent by the permission classifier: the owner pushes the tag.
