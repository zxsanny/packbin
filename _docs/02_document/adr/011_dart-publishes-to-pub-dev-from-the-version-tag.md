# ADR-011: Dart publishes to pub.dev from the version tag

- **Status**: Accepted
- **Date**: 2026-11-11
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

The Dart package (epic AZ-4133, `dart/`, package `packbin`) is the ninth language. pub.dev is a seventh registry for the release run, and it differs from the six of ADR-002: it takes an upload from CI only through a GitHub OIDC token, only from a run that a tag push started, and only for a package that already exists. ADR-002 publishes from the `vX.Y.Z` tag after every language matches the golden hex, ADR-004 adds the Go tag, ADR-005 the Swift check.

- Acceptance criteria addressed: DT-10, DT-11 (`_docs/02_task_plans/dart-package/acceptance_criteria.md`), AZ-4147 AC-1 to AC-6
- Fit decisions (`_docs/02_task_plans/dart-package/scenarios.md`): card 1, a `pubdev` target in the required tier and the first version published by the owner by hand; card 2, Dart joins the all-or-nothing golden gate
- Research source: https://dart.dev/tools/pub/automated-publishing and https://dart.dev/tools/pub/publishing, read 2026-11-10 and 2026-11-11, and the source of `dart-lang/setup-dart` at `v1.8.1` (`lib/main.dart`, function `createPubOIDCToken`)

What the two pages say, quoted:

- "Today, you can only automate publishing of existing packages." The first version is published with `dart pub publish` by hand.
- "Pub.dev rejects publishing from GitHub Actions triggered without a tag." The workflow needs the permission `id-token: write` (the example's comment: "Required for authentication using OIDC"), the token is created in the `dart-lang/setup-dart` step, and "subsequent steps can run `dart pub publish --force`".
- "The _tag pattern_ is a string that must contain `{{version}}`." With `v{{version}}`, pushing `v1.2.3` publishes `1.2.3`, so the `version` of `pubspec.yaml` must match.
- With an environment required on pub.dev, "GitHub Actions won't be able to publish unless they have `environment: pub.dev`".
- "Keep in mind that a published package lasts forever"; a version can be retracted within seven days of publication, and restored within seven days of retraction.
- Neither page says what a second publish of an existing version returns. The first says nothing about the lifetime of the GitHub OIDC token.

What `setup-dart` does (source, not documentation): when the job has `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (that is, `id-token: write`), it asks GitHub for a token with the audience `https://pub.dev`, exports it as `PUB_TOKEN` and runs `dart pub token add https://pub.dev --env-var PUB_TOKEN`.

## Decision

We will publish the Dart package from the same `vX.Y.Z` tag run, as a required `pubdev` target, through the official OIDC mechanism and nothing else.

- **Mechanism.** The `publish` job of `publish.yml` already holds `id-token: write` (NuGet, npm and PyPI use it) and is started by a tag push, which pub.dev requires. A `dart-lang/setup-dart` step (pinned by commit, `v1.8.1`, `6afc89df92d6eb3834022f73cd65adc8cdfcb92d`, the commit of both `v1` and `v1.8.1`; the Dart version is the `dart` pin of `tool-pins.txt`) runs before `publish-registries.sh`. The upload step, `publish-pubdev.sh`, runs `dart pub publish --force` on the prepared package. No token is stored, copied or created by a script; the service-account route that the documentation also names is not used.
- **Tag pattern.** The tags are `vX.Y.Z`, so the pattern on pub.dev is `v{{version}}`. The build phase writes the version of the tag into the `version:` line of `pubspec.yaml` in a copy of `dart/`; `dart/pubspec.yaml` itself keeps the placeholder `0.1.0`.
- **Precondition, expressed like the other required targets.** The credential of `pubdev` is `PUB_TOKEN` (`target_credentials` in `publish-lib.sh`). `setup-dart` exports it only when the job has the OIDC permission, so a run without it fails at the plan, before anything is built or written, with `pubdev is required and lacks: PUB_TOKEN`. A read-only preflight (`publish-pubdev-lib.sh`, a GET of `https://pub.dev/api/packages/packbin`) also fails the plan, before any write, when pub.dev has no package `packbin`: the automated route cannot create it, so the owner step below is missing.
- **Upload guards.** Before `dart pub publish --force`, `publish-pubdev.sh` checks that `PUB_TOKEN` is a JWT whose `exp` is more than 30 s away (the token is made when `setup-dart` runs, and a slow earlier upload, such as Maven Central's wait, can outlive it; the lifetime of the token is not documented and was not measured), and that `dart pub token list` shows `https://pub.dev` (without it `dart pub publish` would ask for an interactive login). A failure names the cause and says to run the tag again.
- **A version pub.dev already has.** The upload phase asks first, as for every target: `GET https://pub.dev/api/packages/packbin` lists the versions; with the tag's version in the list the run prints `already published pubdev X.Y.Z`, does not upload and does not fail (a retracted version stays in the list and counts). pub.dev's own answer to a second publish is not documented, so this query is the guard and the upload is never tried for a version the query shows. An unreadable answer (transport error, 5xx, 429, a body of another shape) fails the run, as for the other registries.
- **Gate.** `dart` is the ninth language of the golden gate. `publish-gate.sh` runs the position program of the Dart ring (`publish-position.sh dart`) in the read-only `dart` service and sums the byte mismatch with the others; a Dart mismatch publishes 0 packages of any language, 0 Go tags and no Swift check, and the run names `dart` (`golden mismatch in: dart`). A tree without `dart/pubspec.yaml` says `absent dart`, plans the other eight and plans no `pubdev` target.
- **Package.** The build phase (`publish-dart-prepare.sh`, in the `dart` image on the read-only repository) copies `dart/` without `.dart_tool`, `pubspec.lock` and `build`, sets the version, and runs `dart pub publish --dry-run` on a second copy in a temporary directory that is outside any git work tree (inside one, pub lists the files with git and would find `.github/workflows/out` ignored). `publish-check.py pubdev` checks the prepared copy: name `packbin`, version equal to the tag, an `environment: sdk` constraint, 0 runtime dependencies, no `dependency_overrides`, `lib/packbin.dart`, an MIT `LICENSE`, no symlink, and the saved dry run: **0 errors**. Warnings are recorded as `note:` lines. With `PACKBIN_DART_STRICT=1` (the default in `publish-lib.sh` is 0; AZ-4148 turns it on once the README, CHANGELOG and example exist) any warning, a missing `CHANGELOG.md` or a `CHANGELOG.md` without an entry for the version fails the check. pub.dev's checks beyond the dry run ("The server may enforce additional checks") are not reproduced.
- **Tier and order.** `pubdev` is required, so it uploads before the optional targets and before the final `go-tag` and `swift-check`. A failed upload fails the run.

### One-time owner steps (before the first tag that contains `dart/`)

Because `pubdev` is required and automated publishing works only for an existing package, the first release tag after this ADR fails at the plan (before any write) until these are done:

1. Publish a first version by hand with `dart pub publish`, from the owner's pub.dev account, in a checkout of the commit to release (the package is everything under `dart/` that `dart pub publish` includes). That account becomes the uploader; reserving the name is part of this step. Take the version of the first tag release: when the owner publishes `X.Y.Z` by hand and later pushes the tag `vX.Y.Z`, the run finds the version on pub.dev, reports `already published pubdev X.Y.Z` and uploads nothing.
2. On the package's pub.dev page, tab Admin, "Automated publishing", enable publishing from GitHub Actions: repository `zxsanny/packbin`, tag pattern `v{{version}}`.
3. Do not require a GitHub environment there. The `publish` job names none, and adding `environment: pub.dev` to it would change the claims of the OIDC token for NuGet, npm and PyPI trusted publishing too. If an environment is wanted later, that is a new decision.

Tags and the tag ruleset on `v*` (F44) are as in ADR-004 and ADR-005.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| An optional target (skipped when its credential is missing) | A release would silently leave Dart out. The fit decision is a required target; the cost is that the owner steps come first |
| A long-lived pub.dev credential or the Google Cloud service-account route | The documentation offers the OIDC route for GitHub Actions; a stored key is a secret to leak and rotate, and the task rules out a workaround |
| The reusable workflow `dart-lang/setup-dart/.github/workflows/publish.yml` | It would run as a second workflow and a second run of the tag, outside the all-or-nothing order (after the golden gate, with the other registries, before the Go tag) |
| Asking GitHub for the OIDC token inside `publish-pubdev.sh`, right before the upload | It would repeat what `setup-dart` does and skip the step the documentation names. The expiry guard and "run the tag again" cover a stale token instead |
| A dry run inside the checkout | pub would find the files through git and the ignored `out/` directory would publish nothing |
| Keep the version of each release in `dart/pubspec.yaml` | The other packages keep a placeholder; the tag is the only source of the version, written into a copy |

## Consequences

### Positive

- One tag still publishes everything; a Dart mismatch stops all nine languages
- No secret for pub.dev exists anywhere in the repository or the workflow
- A re-run of the tag is safe: a version pub.dev already has is skipped

### Negative

- The first release after this ADR needs the owner's hand-made first version and the setting on pub.dev. Until then every release run stops at the plan, for all languages
- A published version stays on pub.dev forever; retract within seven days, and fix a bad version with the next patch
- The OIDC token is made once, at the `setup-dart` step, and used when the upload phase reaches `pubdev`. If an earlier upload takes longer than the token lives, the run fails at the guard and a re-run uploads only what is missing
- The published package contains everything under `dart/` that pub includes, the tests among it, unless a `.pubignore` says otherwise (AZ-4148)

### Neutral / Open

- Not proven in the loop that adds this ADR (no tag, no upload, real uploads 0): that pub.dev accepts the token of this workflow, the lifetime of the token, the answer of pub.dev to a second publish, a Dart consumer that resolves from pub.dev (the path-dependency consumer in `publish-dart-package.test.sh` stands in for it)
- The package counts after the first Dart release are seven registry packages (the six of ADR-002 and pub.dev), one Go tag and no Swift artifact

## Evidence

- `.github/workflows/publish.yml`, `publish-lib.sh`, `publish-gate.sh`, `publish-build.sh`, `publish-inside.sh`, `publish-dart-prepare.sh`, `publish-check.py`, `publish-upload.sh`, `publish-query.sh`, `publish-pubdev-lib.sh`, `publish-pubdev.sh`, `publish-registries.sh`
- `.github/workflows/publish-dart.test.sh`, `publish-dart-package.test.sh`, `publish-readonly.test.sh`, `publish-jobs-layout.py`
- `docker-compose.publish.yml`, `docker-compose.publish-dart.yml`
- `_docs/02_document/adr/002_publish-from-version-tag.md`, `004_go-ships-as-a-git-tag.md`, `005_swift-installs-from-the-version-tag.md`
