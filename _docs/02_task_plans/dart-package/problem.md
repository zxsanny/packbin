---
loop: 99
branch: dev
---

# Loop 99 — Dart package (AZ-4133, full parity)

Loop 99 (on `dev`; no worktree). Intake: the owner's order of 2026-11-10 ("Dart language support. Also check for the notes about that and some implementation in the sibling archangel repository in dev folder") and the Archangel note `_docs/02_task_plans/live-socket-streamline/packbin_dart_needs.md` in that repository (read only; nothing there changes).

## What

A ninth package, `dart/`: a Dart implementation of packbin that writes and reads the same bytes as C#, TypeScript, Python, Rust, C++, Java, Go and Swift for every feature they share today:

- the wire format (scalars, flags, `bool`, `when`, `repeat`, `times`, `sized`, two-bit slots, `bits`, `packed`, groups, flag-byte bits), schemes, first-byte dispatch, field-id binding and the scheme checks;
- `utf8` in the compact text format (ADR-006), lists and dictionaries (ascending keys);
- the limits (`maxRounds`, `maxSlots`, `maxBytes`) and the shared hostile vectors;
- message error correction: parity bytes by count and by percentage, unpack with repair (ADR-007, ADR-010);
- frame mode: `FrameSession`, `MacKey`, the replay window, keys wiped on close (ADR-008, ADR-009).

Plus a Dart driver in the language-pair, ECC and frame rings, a Dart service in the CI suite, the speed bound, a pub.dev publish target in the release run, and a Dart section in the README.

The removed stream session (`PackSession`, ADR-009) is not built.

## Why and for whom

The Archangel Android app (Flutter) reads the live socket with a hand-written reader (about 620 lines) while the server and the web client use packbin. Every wire change is made three times. With a Dart package the phone's parsers become schemes that mirror the C# and TypeScript ones. Archangel loop 240 (the move to packbin 0.4.0) waits for the Dart release.

What the app needs (from the Archangel note, all inside full parity):

1. Unpack of every construct the server's schemes use, including a handler table keyed by the first byte, and an unknown type byte reported as a value, not an exception.
2. Pack for the small client frames.
3. Pure Dart, null-safe, no `dart:mirrors` (Flutter builds ahead of time), no FFI. Schemes built from closures. Runs in a background isolate.
4. Errors as values on unpack: a bad frame is dropped, the socket stays open.
5. Cheap on a phone: several hundred frames a second on a low-end device, no allocation per frame beyond the row.
6. The shared fixtures pass in Dart.

## What carries over from Archangel

`src/mobile/lib/live/byte_reader.dart` (74 lines): a bounds-checked little-endian reader and a `packed(bits, count)` reader. Useful as a starting shape for the Dart reader only. Its `utf8String()` reads the old 0.1.12 string form and is not reused. The app's parsers (`object_parsers.dart`, `frame_decoder.dart`) are not library code; they list the constructs the Dart API must express. The 121 live packet fixtures of that repository are 0.1.12 bytes and are not copied here.

## Code sections / UI locations for this loop

Owner (2026-11-10): "Dart language support" — a new top-level `dart/` folder (confirmed in the scope question the same day), plus the shared files every language package is wired into: `.github/workflows/` (suite, rings, publish path), `docker-compose.test.yml`, `docker-compose.publish.yml`, `scripts/`, `fixtures/hostile/` (checker and `Run by` lines), `fixtures/*/README.md`, `README.md`, `_docs/02_document/`.

## Owner decisions (2026-11-10)

- **D-1** Full parity in this loop, as Go and Swift were added (not the app's subset first).
- **D-2** Released on pub.dev as `packbin`. The first publish needs the owner's pub.dev account and explicit go; this loop builds and tests the path with a dry run only. No tag is pushed.
- **D-3** Dart 3.13 and newer; one CI image.
- **D-4** Native targets only (Dart VM and ahead-of-time builds). The web (Dart compiled to JavaScript) is not supported and not tested.
- **D-5** `_docs/_autodev_state.md` is tracked again.

## Agent defaults (auto-applied; a typed correction overrides)

- **A-1** Dart copies TypeScript row for row where the packages differ, with the owner's Go decisions Go-1 to Go-4 as Swift took them.
- **A-2** Unpack returns a result object with an `error` value (kinds named as the hostile outcome terms); it does not throw on bad input. Pack and scheme construction throw a typed error that names the field, as TypeScript does.
- **A-3** `u64` and `i64` are Dart `int`. A `u64` above 2^63 - 1 is the same 64 bits read as a negative `int`, as Java's `long` (no `BigInt`, no allocation).
- **A-4** No package dependency: SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 are written in the package and checked on `fixtures/crypto/vectors.txt`. Dev dependencies: `test` and `lints` only.
- **A-5** Rows are typed objects bound by getter and setter closures, plus a `Map<String, Object?>` form. `null` is no value; an empty list is a value with 0 items. No code generator.
- **A-6** The Dart suite shares a CI job with another short suite, so `test.yml` stays at 20 jobs (the free plan's limit).
- **A-7** The version in `dart/pubspec.yaml` is a committed placeholder; the release run writes the tag's version, as it does for npm and NuGet.

## Out of scope

The web target; a code generator or annotations; a Flutter plugin; the stream session; a real pub.dev publish or a tag in this loop; any change in the Archangel repository; the 121 Archangel fixtures; the leftovers of loop 98 (U24, vcpkg `supports`, a public-key pairing step, the s390x packet comparison).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| pub.dev publishes from CI only through a GitHub OIDC token on a tag-triggered workflow, and only after the package exists: the first version is published by hand from the owner's account, and the owner turns on automated publishing with the tag pattern `v{{version}}` | owner (account, first publish, pub.dev admin setting); the release task reads the pub.dev documentation and records the exact steps | open | High |
| The name `packbin` on pub.dev is free today (Archangel note, 2026-11-10) but not reserved until the first publish | owner | open | Medium |
| 61 points in one loop (Swift was 47): compact text, ECC and frame mode did not exist when Swift was added | waves with disjoint file sets; one total review and one step-11 run | accepted-risk | Medium |
| Dart `int` is 64-bit and wraps silently: a size or count computed from input can overflow without an error | every size and index from input is range-checked before use; hostile vectors and the seeded run cover it | open | High |
| `test.yml` is at the 20-job limit | A-6: Dart shares a suites job; the publish-gate jobs take Dart into an existing group | open | Medium |
| Keys cannot be wiped at garbage collection in Dart (a finalizer cannot reach the object) | keys are wiped on `close()` only; documented | accepted-risk | Low |

## pub.dev publishing rules (read 2026-11-10 from dart.dev/tools/pub/automated-publishing and /publishing)

- The first version cannot be automated: "you can only automate publishing of existing packages"; it is published with `dart pub publish` by hand, and that account becomes the only uploader.
- From GitHub Actions, pub.dev accepts a publish only when the workflow was triggered by pushing a git tag, with `id-token: write`, after a `dart-lang/setup-dart` step (it sets up the OIDC token); then `dart pub publish --force`. A run started by `workflow_dispatch` is rejected.
- The owner sets, on the package's pub.dev Admin tab, the repository (`zxsanny/packbin`) and a tag pattern that contains `{{version}}` (`v{{version}}` fits the existing tags). A GitHub Actions environment can be required there.
- Other documented route: a Google Cloud service account (long-lived key). Not needed here.
- A published version stays forever; it can be retracted within seven days. What a re-publish of an existing version returns is not stated.
- The real publish checks that `git status` is clean; the package is everything under `dart/` not ignored by `.gitignore` or `.pubignore`.
