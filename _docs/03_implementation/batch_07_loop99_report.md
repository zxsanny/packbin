# Batch 7 report — loop 99 (Dart package)

Task: AZ-4147 dart_release (5).

Dart is in the all-or-nothing golden gate (a mismatch publishes 0 packages of any language and names Dart) and the release run has a required `pubdev` target (ADR-011). Mechanism read from dart.dev: `setup-dart` (pinned by commit `6afc89df…`, v1.8.1, verified with `gh api`) creates the OIDC token and exports it as `PUB_TOKEN`; `publish-pubdev.sh` runs `dart pub publish --force` from a copy outside any git tree; a version already on pub.dev is reported and not uploaded. Proof without any upload: gate group `dart` (mismatch, absent tree, missing credential, already published, stubbed upload, and a real prepared copy for test tag 9.8.7 in the dart image: pubspec version, `publish-check.py`, dry run 0 errors, a path-dependency consumer prints the golden hex), and every other publish group. `test.yml` has 14 jobs. Real uploads: 0. No tag.

## Owner steps (once, before the first tag that contains `dart/`)
1. Publish a first version by hand: `dart pub publish` from your pub.dev account (it needs the final README, CHANGELOG, example: they exist now).
2. On the package's pub.dev Admin tab enable automated publishing from GitHub Actions for `zxsanny/packbin` with tag pattern `v{{version}}`.
3. Do not require a GitHub environment there (the publish job names none; it would change the OIDC claims for NuGet, npm and PyPI).
Until step 1 is done, a release run stops at the plan for ALL languages (the `pubdev` target is required and the package preflight reads 404 today).

## Discovered during implementation

| finding | handling | clear/unclear |
|---------|----------|---------------|
| `pubdev` is a required target and a package that pub.dev does not have yet fails the plan: it blocks the release of the other eight languages until the owner publishes the first Dart version | as the spec says (required tier) | unclear: owner may prefer `optional` until the first publish |
| the OIDC token is created once before the other uploads and its lifetime is undocumented; Maven's wait could outlive it | expiry guard (30 s before `exp`): "run the tag again" | unclear until the first tag |
| pub.dev's answer to a re-publish and whether it accepts this workflow's token are unproven | the version query before upload is the guard | unclear |
| `PACKBIN_DART_STRICT` (0 warnings) defaults to 0: a real tag `X.Y.Z` warns when `dart/CHANGELOG.md` has no entry for it | strict would force a CHANGELOG edit per release | unclear: owner |
| a third compose file `docker-compose.publish-dart.yml` (compose 2.24.3 has no `!override`; the nested tmpfs mount failed on a clean checkout) | the read-only test checks the merged config | clear |
| the published package includes `test/` and `tool/` (161 KB) | a `.pubignore` could drop them | unclear |
| `vcpkg supports check` and `vcpkg consumer check` NOT RUN (no vcpkg on this host) | run in CI | clear |
