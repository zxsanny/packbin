#!/usr/bin/env bash
# Sourced by publish-query.sh and publish-registries.sh. What the pubdev target (ADR-011) asks pub.dev, with read-only
# calls: whether the package packbin exists at all (pubdev_preflight) and whether it holds this version (the pubdev
# case of publish-query.sh). Needs registry_fetch and query_fail of publish-query.sh, and $version and $work.

# The package document: {"name": ..., "versions": [{"version": ...}, ...]}. 404 when pub.dev has no such package.
pubdev_api_url() {
  printf '%s\n' "${PUBDEV_API_URL:-https://pub.dev/api/packages/packbin}"
}

# Fails when pub.dev has no package packbin: pub.dev takes an automated publish only for a package that exists, so the
# first version is published by the owner by hand (ADR-011), and the run must say so before it writes anywhere.
# A pub.dev that cannot be asked stops the run through registry_fetch (an unknown answer is never "exists").
pubdev_preflight() {
  if registry_fetch pubdev "$(pubdev_api_url)"; then
    return 0
  fi
  echo "pub.dev has no package packbin: automated publishing works only for an existing package, so the owner" \
    "publishes the first version by hand with 'dart pub publish' (ADR-011); nothing was built or written" >&2
  return 1
}
