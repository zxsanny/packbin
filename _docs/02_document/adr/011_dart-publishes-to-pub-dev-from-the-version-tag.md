# ADR-011: Dart publishes to pub.dev from the version tag

- **Status**: Accepted
- **Date**: 2026-11-11
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —
- **Amended**: 2026-11-11 (AZ-4149, owner decisions 11 and 20): the token is made inside the upload step and `pubdev` is an optional target

## Context

The Dart package (epic AZ-4133, `dart/`, package `packbin`) is the ninth language. pub.dev is a seventh registry for the release run, and it differs from the six of ADR-002: it takes an upload from CI only through a GitHub OIDC token, only from a run that a tag push started, and only for a package that already exists. ADR-002 publishes from the `vX.Y.Z` tag after every language matches the golden hex, ADR-004 adds the Go tag, ADR-005 the Swift check.

- Acceptance criteria addressed: DT-10, DT-11 (`_docs/02_task_plans/dart-package/acceptance_criteria.md`), AZ-4147 AC-1 to AC-6
- Fit decisions (`_docs/02_task_plans/dart-package/scenarios.md`): card 1, a `pubdev` target (required at first; optional since the amendment of 2026-11-11) and the first version published by the owner by hand; card 2, Dart joins the all-or-nothing golden gate
- Research source: https://dart.dev/tools/pub/automated-publishing and https://dart.dev/tools/pub/publishing, read 2026-11-10 and 2026-11-11, and the source of `dart-lang/setup-dart` at `v1.8.1` (`lib/main.dart`, function `createPubOIDCToken`)

What the two pages say, quoted:

- "Today, you can only automate publishing of existing packages." The first version is published with `dart pub publish` by hand.
- "Pub.dev rejects publishing from GitHub Actions triggered without a tag." The workflow needs the permission `id-token: write` (the example's comment: "Required for authentication using OIDC"), the token is created in the `dart-lang/setup-dart` step, and "subsequent steps can run `dart pub publish --force`".
- "The _tag pattern_ is a string that must contain `{{version}}`." With `v{{version}}`, pushing `v1.2.3` publishes `1.2.3`, so the `version` of `pubspec.yaml` must match.
- With an environment required on pub.dev, "GitHub Actions won't be able to publish unless they have `environment: pub.dev`".
- "Keep in mind that a published package lasts forever"; a version can be retracted within seven days of publication, and restored within seven days of retraction.
- Neither page says what a second publish of an existing version returns. The first says nothing about the lifetime of the GitHub OIDC token.

What `setup-dart` does (source, not documentation), read again for the amendment at commit `6afc89df92d6eb3834022f73cd65adc8cdfcb92d` (`lib/main.dart`, function `createPubOIDCToken`, called once from the setup step): it returns without a token unless `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` are set (that is, `id-token: write`); otherwise it calls `core.getIDToken('https://pub.dev')`, then `core.exportVariable('PUB_TOKEN', token)`, then runs `dart pub token add https://pub.dev --env-var PUB_TOKEN`. The request that `getIDToken` makes is in `@actions/core` (`packages/core/src/oidc-utils.ts`): a GET of `ACTIONS_ID_TOKEN_REQUEST_URL` plus `&audience=` and the URL-encoded audience (`https%3A%2F%2Fpub.dev`), with the bearer credential `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (`BearerCredentialHandler`), and the token is the field `value` of the JSON answer (a missing field is an error); it is then masked (`setSecret`). The token is made once, in the setup step, and exported to every later step of the job.

## Decision

We will publish the Dart package from the same `vX.Y.Z` tag run, as an optional `pubdev` target, through the official OIDC mechanism and nothing else.

- **Mechanism.** The `publish` job of `publish.yml` already holds `id-token: write` (NuGet, npm and PyPI use it) and is started by a tag push, which pub.dev requires. A `dart-lang/setup-dart` step (pinned by commit, `v1.8.1`, `6afc89df92d6eb3834022f73cd65adc8cdfcb92d`; the Dart version is the `dart` pin of `tool-pins.txt`) stays before `publish-registries.sh`, because the runner has no Dart SDK: it is kept for the SDK, and the token it makes early is no longer relied on (it is exported as `PUB_TOKEN` to the later steps, and `publish-registries.sh`, `publish-upload.sh` and `publish-pubdev.sh` unset it). The upload step, `publish-pubdev.sh`, makes its own token right before the upload, because a GitHub OIDC token lives about five minutes and the upload comes after the build phase and after the Maven Central wait: it asks GitHub for an ID token with the audience `https://pub.dev` exactly as `getIDToken` does (above: GET `$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https%3A%2F%2Fpub.dev`, bearer `$ACTIONS_ID_TOKEN_REQUEST_TOKEN` in a header file, the JSON field `value`), masks it with `::add-mask::`, exports it as `PUB_TOKEN` in that process only, runs `dart pub token add https://pub.dev --env-var PUB_TOKEN` (the call `setup-dart` makes), checks the expiry and `dart pub token list`, and runs `dart pub publish --force`. The token is never printed, never stored and never given to another tool; the service-account route that the documentation also names is not used.
- **Tag pattern.** The tags are `vX.Y.Z`, so the pattern on pub.dev is `v{{version}}`. The build phase writes the version of the tag into the `version:` line of `pubspec.yaml` in a copy of `dart/`; `dart/pubspec.yaml` itself keeps the placeholder `0.1.0`.
- **Precondition and skip, expressed like the other optional targets.** The credentials of `pubdev` are `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (`target_credentials` in `publish-lib.sh`; `PUB_TOKEN` is no longer a plan credential). A run without the OIDC permission skips `pubdev` at the plan with one `::warning::` line and a job-summary line that name the owner steps below; the other targets run unchanged. A read-only preflight (`publish-pubdev-lib.sh`, a GET of `https://pub.dev/api/packages/packbin`, before anything is built or written) that answers 404 (no package `packbin`: the automated route cannot create it) skips `pubdev` the same way. An answer that cannot be read (transport error, 5xx, 429) still stops the run: an unknown answer is neither "exists" nor "absent". A run whose plan holds only `pubdev` and skips it says `publishing 0 packages`. A `pubdev` upload that starts and fails fails the run.
- **Upload guards.** After it made the token, `publish-pubdev.sh` checks that it is a JWT whose `exp` is more than 30 s away (a failed request, an answer without a token, or a token past its `exp` stops before the upload with "run the tag again": a re-run uploads only what is missing) and that `dart pub token list` shows `https://pub.dev` (without it `dart pub publish` would ask for an interactive login). The lifetime of the token is not documented and was not measured; making it right before the upload keeps it far inside the five minutes the platform gives.
- **Credential scope.** `publish-pubdev.sh` reads the OIDC request variables into its own variables and unsets every credential of `PACKBIN_CREDENTIALS` (`unset_credentials`, as `publish-swift.sh`) before it asks for the token, so `dart` sees no secret of another registry and no `GITHUB_TOKEN`. The other upload tools run with `PUB_TOKEN` unset (`publish-registries.sh`, `publish-upload.sh`); the token exists only inside `publish-pubdev.sh`.
- **A version pub.dev already has.** The upload phase asks first, as for every target: `GET https://pub.dev/api/packages/packbin` lists the versions; with the tag's version in the list the run prints `already published pubdev X.Y.Z`, does not upload and does not fail (a retracted version stays in the list and counts). pub.dev's own answer to a second publish is not documented, so this query is the guard and the upload is never tried for a version the query shows. An unreadable answer (transport error, 5xx, 429, a body of another shape) fails the run, as for the other registries.
- **Gate.** `dart` is the ninth language of the golden gate. `publish-gate.sh` runs the position program of the Dart ring (`publish-position.sh dart`) in the read-only `dart` service and sums the byte mismatch with the others; a Dart mismatch publishes 0 packages of any language, 0 Go tags and no Swift check, and the run names `dart` (`golden mismatch in: dart`). A tree without `dart/pubspec.yaml` says `absent dart`, plans the other eight and plans no `pubdev` target.
- **Package.** The build phase (`publish-dart-prepare.sh`, in the `dart` image on the read-only repository) copies `dart/` without `.dart_tool`, `pubspec.lock` and `build`, sets the version, and runs `dart pub publish --dry-run` on a second copy in a temporary directory that is outside any git work tree (inside one, pub lists the files with git and would find `.github/workflows/out` ignored). `publish-check.py pubdev` checks the prepared copy: name `packbin`, version equal to the tag, an `environment: sdk` constraint, 0 runtime dependencies, no `dependency_overrides`, `lib/packbin.dart`, an MIT `LICENSE`, no symlink, and the saved dry run: **0 errors**. Warnings are recorded as `note:` lines. With `PACKBIN_DART_STRICT=1` (the default in `publish-lib.sh` is 0; AZ-4148 turns it on once the README, CHANGELOG and example exist) any warning, a missing `CHANGELOG.md` or a `CHANGELOG.md` without an entry for the version fails the check. pub.dev's checks beyond the dry run ("The server may enforce additional checks") are not reproduced.
- **Tier and order.** `pubdev` is optional, so it uploads after the required targets (with the other optional ones) and before the final `go-tag` and `swift-check`. A failed upload of a present target fails the run.

### One-time owner steps (before the first release that should publish Dart)

Because automated publishing works only for an existing package, until these are done every release run publishes the other eight languages and reports `pubdev` as skipped (a `::warning::` and a summary line):

1. Publish a first version by hand with `dart pub publish`, from the owner's pub.dev account, in a checkout of the commit to release (the package is everything under `dart/` that `dart pub publish` includes). That account becomes the uploader; reserving the name is part of this step. Take the version of a tag release: when the owner publishes `X.Y.Z` by hand and later pushes the tag `vX.Y.Z`, the run finds the version on pub.dev, reports `already published pubdev X.Y.Z` and uploads nothing.
2. On the package's pub.dev page, tab Admin, "Automated publishing", enable publishing from GitHub Actions: repository `zxsanny/packbin`, tag pattern `v{{version}}`.
3. Do not require a GitHub environment there. The `publish` job names none, and adding `environment: pub.dev` to it would change the claims of the OIDC token for NuGet, npm and PyPI trusted publishing too. If an environment is wanted later, that is a new decision.

Tags and the tag ruleset on `v*` (F44) are as in ADR-004 and ADR-005.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| A required target (the original decision) | The first release after the ADR would stop at the plan, for all languages, until the owner's hand-made first version and the pub.dev setting exist. Owner decision 11 (2026-11-11) made it optional: the other eight publish, and Dart is reported as skipped with a visible warning naming the steps |
| A long-lived pub.dev credential or the Google Cloud service-account route | The documentation offers the OIDC route for GitHub Actions; a stored key is a secret to leak and rotate, and the task rules out a workaround |
| The reusable workflow `dart-lang/setup-dart/.github/workflows/publish.yml` | It would run as a second workflow and a second run of the tag, outside the all-or-nothing order (after the golden gate, with the other registries, before the Go tag) |
| The token of the `setup-dart` step, used when the upload phase reaches `pubdev` (the original decision) | It is made early in the job and an earlier upload (Maven Central's wait) can outlive the five minutes it lives. Owner decision 20 (2026-11-11): `publish-pubdev.sh` asks GitHub for the token right before the upload, the same request `setup-dart` makes; `setup-dart` stays for the SDK |
| A dry run inside the checkout | pub would find the files through git and the ignored `out/` directory would publish nothing |
| Keep the version of each release in `dart/pubspec.yaml` | The other packages keep a placeholder; the tag is the only source of the version, written into a copy |

## Consequences

### Positive

- One tag still publishes everything it can; a Dart mismatch stops all nine languages
- No secret for pub.dev exists anywhere in the repository or the workflow
- A re-run of the tag is safe: a version pub.dev already has is skipped
- The token is made right before the upload, so a slow earlier upload cannot make it stale, and no other tool sees it

### Negative

- Until the owner steps are done, a release publishes eight languages and Dart is only a warning: a missing pub.dev release is visible in the job summary but does not fail the run
- A published version stays on pub.dev forever; retract within seven days, and fix a bad version with the next patch
- `publish-pubdev.sh` repeats the request that `setup-dart` makes (a second copy of a small piece of its behavior); the pinned `setup-dart` step is kept only for the Dart SDK
- The published package contains everything under `dart/` that pub includes, the tests among it, unless a `.pubignore` says otherwise (AZ-4148, AZ-4149)

### Neutral / Open

- Not proven in the loop that adds this ADR or its amendment (no tag, no upload, real uploads 0): that pub.dev accepts the token of this workflow (made by the upload step, not by `setup-dart`), the lifetime of the token, the answer of pub.dev to a second publish, a Dart consumer that resolves from pub.dev (the path-dependency consumer in `publish-dart-package.test.sh` stands in for it)
- The package counts after the first Dart release are seven registry packages (the six of ADR-002 and pub.dev), one Go tag and no Swift artifact

## Evidence

- `.github/workflows/publish.yml`, `publish-lib.sh`, `publish-gate.sh`, `publish-build.sh`, `publish-inside.sh`, `publish-dart-prepare.sh`, `publish-check.py`, `publish-upload.sh`, `publish-query.sh`, `publish-pubdev-lib.sh`, `publish-pubdev.sh`, `publish-registries.sh`
- `.github/workflows/publish-dart.test.sh`, `publish-dart-package.test.sh`, `publish-readonly.test.sh`, `publish-jobs-layout.py`
- `docker-compose.publish.yml`, `docker-compose.publish-dart.yml`
- `_docs/02_document/adr/002_publish-from-version-tag.md`, `004_go-ships-as-a-git-tag.md`, `005_swift-installs-from-the-version-tag.md`
