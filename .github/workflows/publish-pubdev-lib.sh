#!/usr/bin/env bash
# Sourced by publish-query.sh and publish-registries.sh. What the pubdev target (ADR-011) asks pub.dev, with read-only
# calls: whether the package packbin exists at all (pubdev_preflight) and whether it holds this version (the pubdev
# case of publish-query.sh). Needs registry_fetch and query_fail of publish-query.sh, and $version and $work.

# The package document: {"name": ..., "versions": [{"version": ...}, ...]}. 404 when pub.dev has no such package.
pubdev_api_url() {
  printf '%s\n' "${PUBDEV_API_URL:-https://pub.dev/api/packages/packbin}"
}

# Succeeds when pub.dev has the package packbin, fails (quietly) when it answers 404: pub.dev takes an automated publish
# only for a package that exists, so the owner publishes the first version by hand (ADR-011), and publish-registries.sh
# then skips the optional pubdev target with pubdev_skip_reason. A pub.dev that cannot be asked stops the run through
# registry_fetch (an unknown answer is never "exists", and never "absent").
pubdev_preflight() {
  registry_fetch pubdev "$(pubdev_api_url)"
}

# The one-line reason that the optional pubdev target is skipped: $1 is "token" (no GitHub OIDC token can be requested)
# or "package" (pub.dev has no package packbin). Both name the owner steps of ADR-011.
pubdev_skip_reason() {
  local steps="owner steps (ADR-011): publish the first version by hand with 'dart pub publish', then enable automated"
  steps="$steps publishing for zxsanny/packbin on pub.dev with the tag pattern v{{version}}"
  case "$1" in
    token) printf '%s\n' "the job has no GitHub OIDC token (id-token: write); $steps" ;;
    package) printf '%s\n' "pub.dev has no package packbin; $steps" ;;
    *)
      echo "pubdev_skip_reason: unknown reason $1" >&2
      return 1
      ;;
  esac
}
