# Security Audit Report, loop 99 (Dart package and the pub.dev release target)

**Date**: 2026-11-11
**Mode**: full (`/security`, Phases 1 to 5, scoped to `git diff 10bff03 HEAD`; HEAD 1fe6139; 289 paths, about 36,700 added lines, of which the audited source is the 40 non-test files of `dart/lib/` (7,040 lines), the release and CI scripts, and one ADR)
**Scope**: `dart/lib/src/` unpack surface and crypto/frame mode; `publish.yml` and the `pubdev` target (ADR-011); the Dart ring, suite and `test.yml` changes; `dart/pubspec.yaml`, the pinned image; a grep of the diff for secrets and personal data.
**Verdict**: PASS_WITH_WARNINGS

Lite triggers answered by this full audit: T1 (CI files, `docker-compose*`, `publish*.sh`), T2 (`token`, `hash`, `encrypt`, `ssh`-class words in the Dart crypto and release code), T3 (far above 8 source files), T4 (new manifest `dart/pubspec.yaml`, new image tag `dart:3.13.7`), T5 (F47-style dict cost and F48 credentialed-step surface are touched).

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 0 |
| Medium   | 1 |
| Low      | 7 |

No Critical or High. The Dart untrusted-input walker, the compact text decoder and the error-correction repair held up under reading and under probes (no exception, no allocation from a wire count, no wrap of a negative `u64`, linear time) except for one measured CPU amplification: **D1**, a dictionary whose keys all share one string hash costs quadratic time, because the Dart VM string hash is not seeded. Crypto and frame mode match the 3.0.0 contract and showed no secret-dependent branch, no early exit and no buffer-aliasing fault. The release path adds one credential (a short-lived OIDC token, no stored secret) and the gate order is intact; the findings there are least-privilege and robustness points.

## OWASP Top 10 (2025) Assessment

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | PASS | none (no endpoints; frame replay window checked before hashing, committed only after the tag) |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | D3 (job-wide `PUB_TOKEN`), D5 (no `.pubignore`), D6 (no `platforms:`) |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | D7 (dev dependencies float, no lockfile), D8 (image tag, not digest); `setup-dart` and `actions/cache` are pinned by commit |
| A04 Cryptographic Failures | PASS | hand-written SHA-256, HMAC, HKDF, ChaCha20 equal the 27 crypto vectors and 157 frame vectors the suite holds (not re-run here); no data-dependent branch on a secret; see D4 for the shipped test hook |
| A05 Injection | PASS | tag name and version reach scripts only through env variables, quoted, and a `[0-9A-Za-z.+-]` check before `awk -v`; no markup built in source |
| A06 Insecure Design | PASS_WITH_WARNINGS | D1 (CPU amplification), D2 (token minted before the build phase) |
| A07 Authentication Failures | PASS | OIDC only; pub.dev accepts it from a tag run and an existing package |
| A08 Software or Data Integrity Failures | PASS | gate, build check and `build ok` log precede upload; version of the tag is written into a copy of `dart/`; no symlink in the artifact (`publish-check.py` pubdev in `CONTAINER_TARGETS`) |
| A09 Logging and Alerting Failures | PASS | no `set -x` anywhere under `.github/` or `scripts/`; the token is never printed (`publish-pubdev.sh` prints host names only) |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | D6 (`UnsupportedError` escapes unpack on a web build); on the VM nothing escaped in 300 k random text payloads, 352 hostile count probes and 200 k random frame calls |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| D1 | Medium | A06 / DoS | `dart/lib/src/collections_unpack.dart:65-66,95` | Dict keys with one shared string hash cost quadratic CPU (unseeded Dart string hash) |
| D2 | Low | A06 / release | `.github/workflows/publish.yml:69-77`, `publish-pubdev.sh:47-55`, `publish-upload.sh:102-120,178-189` | The OIDC token is minted before the build phase and used after the Maven wait: the release can fail at the guard every time |
| D3 | Low | A02 | `.github/workflows/publish-upload.sh:144-176`, `publish-pubdev.sh:19-31` | `PUB_TOKEN` is in the environment of every other upload tool, and every other secret is in the environment of `dart pub publish` |
| D4 | Low | A04 | `dart/lib/src/frame/frame_crypto.dart:42`, `frame_session.dart:361-372`, `mac_key.dart:78` | Test hooks shipped in `lib/src` reach live key buffers and the tag compare |
| D5 | Low | A02 | `.github/workflows/publish-dart-prepare.sh:28`, `dart/` (no `.pubignore`) | The published package carries 832 KB of tests and `tool/`; nothing but the checkout limits what is uploaded |
| D6 | Low | A10 | `dart/lib/src/unpack.dart:160`, `dart/pubspec.yaml` | No `platforms:`; a web build throws from unpack on any 64-bit integer field |
| D7 | Low | A03 | `dart/pubspec.yaml:15-17`, `.gitignore:22` | `pubspec.lock` is ignored; `test` and `lints` and about 48 transitive packages float on every CI run |
| D8 | Low | A03 | `docker-compose.test.yml:120`, `ring-dart.sh:43,95`, `publish-dart-prepare.sh` | Image `dart:3.13.7` is a tag, not a digest; the build that makes the published package runs in it |

### Finding details

**D1: Dict keys with one shared string hash cost quadratic CPU** (Medium / A06, availability)
- Location: `collections_unpack.dart:65-66` makes a plain `Map<String, Object?>` (or the typed `n.make!()` map) and `:95` does `items[key] = v` for each of up to 65,535 keys. Keys are only checked for strict UTF-8 order (`compareUtf8`), never for hash spread.
- Description: the Dart VM `String.hashCode` is deterministic across processes (checked: `"abc".hashCode` is 756227931 in two separate runs) and is a one-at-a-time hash, so equal-hash keys can be built on purpose. F47 records that Swift's `Hasher` is seeded per process; I did not test the other six packages for this, so whether Dart alone is exposed is not established.
- Evidence (probe project in the session scratchpad, `bin/h.dart` and `bin/flood.dart`, `dart run` on 3.13.5, macOS arm64, scheme `dict('d', u8(0,'v'))`): my re-implementation of the VM hash gives the same value as `hashCode` for `"abc"` and `"packbin"`. A Joux multi-collision (one 4-letter collision pair per stage, found by birthday on the 32-bit state, 16 stages) gives 65,536 keys of 64 letters with exactly one distinct `hashCode`. Unpack time of a dict of that many equal-hash keys: 1,024 keys 13 ms; 4,096 keys 93 ms; 8,192 keys 344 ms (quadratic: 4x keys, about 7x time); 65,535 keys, 2,768,856-byte packet: **19,960 ms**. Control, 65,535 ordinary keys, 4,325,313-byte packet: 66 ms. About 300 times, about 7 ms per KB of packet, one core.
- Impact: a Dart server or app that unpacks packets from a peer it does not trust with any scheme that has a `dict` (top level, in a group, as a list element) spends 20 s of one isolate on a 2.8 MB packet; N such dicts in one packet add up linearly. `maxBytes` bounds pack only and unpack takes a packet of any length, so a size cap is the caller's. Same class and rating as F47 (Swift, 25 s per MiB). Frame mode and message ECC cap the buffer at 255 and 254 bytes and are not affected.
- Remediation (owner decision): (a) build the dict into a `LinkedHashMap<String, Object?>(equals: ..., hashCode: ...)` whose hash mixes a per-process random salt (`Random.secure()` once), which still returns a `Map`; or (b) because the wire order is already strictly ascending, keep the pairs in a list and build the map once with a seeded hash; or (c) bound the summed key bytes or the key count of one call and refuse above it, as a limit next to `maxRounds`. Add a hostile case (`unpack_dict_equal_hash`, 4,096 colliding keys, at most 1 s) to `dart/test/hostile/` and a README line. Other packages need no change.

**D2: The OIDC token is minted before the build phase and used after the Maven wait** (Low / A06, release robustness)
- Location: the `setup-dart` step (`publish.yml:73-77`) runs before `publish-registries.sh`, which first builds and checks every target (`publish-registries.sh:121-125`) and only then uploads in tier order: csharp, typescript, python, rust, java, vcpkg, then `pubdev` (`publish-lib.sh` `PACKBIN_TARGETS`). `upload_maven` polls up to 90 times 15 s (`publish-upload.sh:102-120`). `publish-pubdev.sh:47-55` refuses a token with under 30 s left.
- Description: ADR-011 states the token lifetime is not documented and not measured. If it is shorter than the build phase (nine toolchain containers) plus the Maven wait, the guard fails the run after csharp, typescript, python, rust, java and vcpkg are published (versions there are immutable), and a re-run builds every target again before it reaches `pubdev`, so it can fail the same way again. Not a confidentiality problem; the guard behaves as designed and fails closed.
- Impact: a partial release (six registries, no Dart, no optional targets, no Go tag, no Swift check) that may need an extra patch version.
- Remediation: measure the token `exp` on the first run and log `left` at the guard (one line, no token); if it is short, mint the token in `publish-pubdev.sh` right before the upload (the ADR's rejected alternative, using `ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://pub.dev` as `pypi_oidc_token` does, then `dart pub token add https://pub.dev --env-var PUB_TOKEN`), or split the job so `setup-dart` runs in a step directly before the upload step. Not verified: no tag run was made.

**D3: `PUB_TOKEN` reaches every upload tool, and every secret reaches `dart pub publish`** (Low / A02)
- Location: `setup-dart` exports `PUB_TOKEN` with `core.exportVariable` (read from its source at the pinned commit), so it is in the environment of every later step. `publish-registries.sh` unsets it for the build phase (`PUB_TOKEN` is in `PACKBIN_CREDENTIALS`, `publish-lib.sh:103`), but `publish-upload.sh` keeps it for `cargo publish`, `npm publish`, `twine` and `pio`/`compote` (pip-installed), `dotnet nuget push` and the git pushes. In the other direction `publish-pubdev.sh` runs `dart pub publish --force` with `NUGET_TOKEN`, `CARGO_REGISTRY_TOKEN`, `MAVEN_GPG_PRIVATE_KEY`, `GITHUB_TOKEN` (`contents: write`) and the Actions token variables in env; `publish-swift.sh:25` already calls `unset_credentials` for the same reason (F48).
- Impact: small. The Dart token is a short-lived JWT for audience `https://pub.dev`; pub.dev accepts it only for a tag-triggered publish of the tag's own version of an existing package, so a stolen copy can at most publish the version the run publishes anyway. The reverse direction is larger in principle (the pub client resolves `test` and `lints` and runs no package code, so there is no known path). The masking of the token comes from `@actions/core` `getIDToken` (toolkit behaviour, not re-verified here); `publish-pubdev.sh` prints no token and no `set -x` exists.
- Remediation: in `publish-pubdev.sh` run `unset_credentials PUB_TOKEN` (keep only the Dart token) before `dart pub publish`; in `publish-upload.sh` run each non-pubdev target with `PUB_TOKEN` unset (`env -u PUB_TOKEN`, or unset it in `upload_target` for every case but `pubdev`).

**D4: Test hooks shipped in `lib/src`** (Low / A04, hardening)
- Location: `frame_crypto.dart:42` (`tagCompareProbe`, a public mutable global called with the index of every compared byte), `frame_session.dart:361-372` (`frameCurrentKeys`, `frameKeyBuffers`, `frameMacComputations`), `mac_key.dart:78` (`macKeyBytes`). None is exported from `package:packbin/packbin.dart`, but Dart does not hide `src/`: `import 'package:packbin/src/frame/frame_session.dart'` reaches them.
- Impact: any code in the same isolate (a dependency) can read the live session keys or watch the compare loop. It gets the index, never a byte, and in-isolate code can already do worse in a VM that allows mirrors or the service protocol, so this is hardening. The tag compare itself has no data-dependent branch and no early return except on length, which is public; `probe?.call(i)` adds a load-and-test per byte that does not depend on data.
- Remediation: move the hooks to a separate library under `test/` (the tests import it by path), or mark them `@visibleForTesting` and add a CI check that `lib/` has no such public symbol; at least document in the README that `src/` is not API.

**D5: No `.pubignore`; the upload is whatever `dart/` holds** (Low / A02)
- Location: `publish-dart-prepare.sh:28` (`cp -R "$root/dart/."`), `publish-pubdev.sh:66-69`. `dart/` has no `.pubignore`; pub then ships `test/` (832 KB, hostile vectors and frame vectors) and `tool/speed.dart`. ADR-011 lists this as AZ-4148 work; it is still open.
- Impact: package size and surface only; I found no secret, key, token, e-mail or home path in the diff (grep of all 36,676 added lines for key, token, PEM, `/Users/`, `/home/`, e-mail and service patterns: the only hits were the public GitHub handle `zxsanny` and the test string "zxsanny"). A pub.dev upload cannot be retracted after seven days, so any stray file in `dart/` ships forever. In CI the checkout is clean; on an owner's machine the first, hand-made upload (ADR-011 owner step 1) would include untracked files.
- Remediation: add `dart/.pubignore` (`test/`, `tool/`, `.dart_tool/`) and have the prepare step copy only tracked files (`git ls-files dart`) or fail when the copy holds a file outside an allow-list.

**D6: A web build throws from unpack on a 64-bit integer** (Low / A10)
- Location: `unpack.dart:160` (`data.getInt64`), `dart/pubspec.yaml` has no `platforms:` key; README says "The web is not supported".
- Evidence: a probe scheme `[u64(0,'n')]` compiled with `dart compile js` and run in Node 22 gives `Unsupported operation: Int64 accessor not supported by dart2js.` from `unpackRow`, whose contract is that it never throws on input. The compile succeeds; pub.dev infers platforms from imports (`dart:typed_data` only), so the package page can list Web.
- Remediation: declare `platforms:` (linux, macos, windows, android, ios) in `pubspec.yaml`, and either compile-time refuse web or read the 64 bits as two 32-bit halves for a build that has no Int64 accessor.

**D7: No lockfile; dev dependencies float** (Low / A03)
- Location: `dart/pubspec.yaml` (`test: ^1.33.0`, `lints: ^6.1.0`), `.gitignore` lines for `dart/pubspec.lock`. Library packages normally do not commit the lock, but the suite resolves about 48 packages (probe `dart pub get` listed 50) from pub.dev at each run. The package has no runtime dependency (`run-suite-dart.sh` `dart_deps` enforces it).
- Impact: a compromised release of a dev dependency runs in the Dart suite job (`test.yml` has `contents: read` and no secret) and its resolution happens in `dart pub publish` on the credentialed host, where pub downloads but runs no package code. The golden gate does not use them: the position and handoff drivers depend on `packbin` by path only (verified in `handoff-dart/pubspec.yaml`).
- Remediation: keep the lock out of the published package, but commit a lock for CI (for example `dart/ci/pubspec.lock` copied before `dart pub get`), or pin `test` and `lints` exactly as `tool-pins.txt` pins Python tools.

**D8: Image tag, not digest** (Low / A03)
- Location: `docker-compose.test.yml:120` (`image: dart:3.13.7`), `ring-dart.sh:43,95`. All nine suite images are tags (project precedent; `node:24` and `rust:1.98` float more than this one). The container builds `publish-dart-prepare.sh`'s output, which is what `dart pub publish` uploads.
- Remediation: pin the nine images by digest in one change (not Dart alone), with a check in `publish-pins.test.sh`.

## Verified clean (what was checked and how)

**Unpack walker, counted, rounds, collections (`unpack.dart`, `counted_unpack.dart`, `rounds_unpack.dart`, `collections_unpack.dart`, `limits.dart`, `item_size.dart`).** Read in full. Every read compares with `end - off` first; a `u64` above 2^63-1 is a negative `int`, and `countOf` returns null for a negative, so it is refused as a bad value; `raw + bias` cannot wrap to a positive (bias is 0 or -1, `packed` checks it). A `sized`, `bits` or `packed` count is checked against the bytes left before `Uint8List(count)` (so `bits` allocates at most 8 items per byte: 1 MB gives 8,000,000 items in 18 ms). A list or dict count is a `u16` checked as `count * minItem > left`; an item that reads nothing is refused; a `times` round that reads nothing is refused, a `repeat` round that reads nothing ends the repeat; every round is charged against `maxRounds` and `maxSlots` before it is read. Recursion depth is the depth of the scheme, never of the wire (no scheme node refers back to itself), so hostile nesting cannot deepen the stack. Probes (`bin/counts.dart`): 8 schemes (`sized`, `bits`, `packed` with bias -1, `times` over `u64`, `u32`, `i64`, a list round) times 11 count values (0, 1, 2, 65,535, 65,536, 2^31, 2^32-1, 2^62, 2^63-1, -2^63, -1) times 4 trailing lengths: 352 calls, 0 thrown, 260 ms in all. 65,535 nested empty lists in 131 KB: 2 ms.
**Compact text decoder (`text/text_decode.dart`, `text_model.dart`).** Varint of at most 3 bytes, size checked before use, raw branch limited to 65,535 bytes, symbol branch allocates at most `min(bits, 65,535)` words and every loop step consumes at least one bit. Every entry of all four 65,536-entry decode tables has a code length of at least 1 (no zero-advance loop). 300,000 random payloads: 0 thrown, 459 ms; a 2 MB buffer with a 2^21-1 count refused in under 1 ms; payloads of all-zero, all-one and alternating bits of 65 KB refused (`length` or `code`) in under 1 ms.
**Error correction (`ecc/`).** `n` is 0 to 32 and the buffer at most 254 bytes before any table index; the largest index is `log + i` at 254 + 31 in a 512-entry table; every division is by a constant; `inv` is called on checked non-zero values; the input is copied before repair and never written; the repaired word is re-verified. Work is bounded by 32 x 254 steps.
**Frame mode (`frame/`, `crypto/`).** Key schedule, nonce (`msg_id` 8 ‖ `(kind<<4)|d` ‖ epoch 24 bits, block counter 0), HKDF info `[d] ‖ "enc"|"mac"`, MAC-only info `0x00 ‖ label` and the tag input `N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext` match `pack-session.md` 3.0.0 (§ nonce, § tag). Open order is: argument checks, size checks before any hashing, window check, tag with current then previous key, decrypt into a copy, write to the caller's buffer, wipe the copy, window commit last. Seal builds the body apart and copies it last, so views of the output for `ad`, `clear` and `plain` give the same bytes (probe: in-place seal equals the separate-buffer seal; open with `plain` the same buffer as `body` returns the plaintext; `ad` aliasing the output seals). Tag compare folds all bytes with no early return except on length. SHA-256, ChaCha20 have no table indexed by a secret, no secret branch; ChaCha20 refuses a counter wrap; HMAC, SHA-256 state, schedule, pads, the PRK and every `full` MAC are wiped; `close` wipes both key slots and later calls are refused. `ReplayWindow` is `BigInt`, so a counter of 2^64-1 is exact and no shift reaches 64. A probe of 200,000 random `open` and `seal` calls with direction -2^63 to 4, kind up to 2^63-1, `msg_id` of 0 to 11 bytes, `ad` and `body` of up to 269 bytes, `clearLength` from -2^63 to 2^63-1, windows and counters up to 2^65: 6,580 opened or sealed, 393,420 refused, 0 thrown. Not changed by Dart and carried from loops 69, 71, 72, 75: the caller must never reuse a `msg_id` for one (key, epoch, direction); a 4-byte tag allows an online guess of 2^-32 a try with no rate limit in the library; the counter is not part of the tag. Not measured: that the Dart VM compare takes the same time for equal and unequal tags (the code promises none, and says so).
**Release path.** `dart-lang/setup-dart@6afc89df...` (commit exists in the upstream repository; its mapping to the tag `v1.8.1` was not re-checked) and every other action in `test.yml` and `publish.yml` are pinned by commit SHA. `id-token: write` is only on the `publish` job, which already held it; `precheck` and `test` have `contents: read`. The gate runs before any registry step and stops the job on a mismatch (`publish-gate.sh`; Dart is in `PACKBIN_LANGS`, a mismatch publishes 0 packages). The build phase unsets `PUB_TOKEN` and runs in the `dart` service on a read-only repository with no token variable passed into the container (`docker-compose.test.yml` lists only `SRC_ROOT`, `FIXTURE`, `TEST_RESULTS`, `GITHUB_ACTIONS`, `PUB_CACHE`). The tag run uses the checkout of the tagged commit; `PACKBIN_VERSION` is `github.ref_name` through `env:` (never interpolated into a script), `v` stripped, then limited to `[0-9A-Za-z.+-]` before `awk -v`; `publish-check.py pubdev` demands name `packbin`, pubspec version equal to the tag, no dependency or override, MIT `LICENSE`, no symlink, and a dry run with 0 errors. The upload copies the prepared package to a fresh `mktemp -d` outside any git tree and runs `dart pub publish --force < /dev/null`; the registry queries use `curl` with `--max-time`, no `-L` (a redirect is an unexpected status and stops the run), HTTPS, a body parsed by `json.loads` with a fixed shape, and an unreadable answer is never read as "not published". `PUBDEV_API_URL` can override the query URL only from the environment of the job, which the workflow does not set. `PUB_TOKEN` is never printed; `token_seconds_left` reads it from the environment (not the command line) and prints only seconds; there is no `set -x`.
**Ring and CI.** `ring-dart.sh` refuses a scratch directory not owned by the caller, builds on copies, runs the container as the caller (`--user`), never writes the repository. The cache of `/tmp/packbin-ring-dart` is skipped on a tag run; on a pull request run `actions/cache` writes are scoped to the pull request ref, and a restored build is rebuilt anyway because the fresh checkout is newer than the stamp, so a restored executable is not trusted (same design as the Swift cache). The workflow keeps `permissions: contents: read` and has no `pull_request_target`. Fixed `/tmp/packbin-ring-dart` default path on a shared runner is covered by the ownership check.
**Dependencies.** `dart/pubspec.yaml`: no runtime dependency, dev dependencies `test` and `lints` only (enforced by `dart_deps` in `run-suite-dart.sh`, which also forbids `dart:io`, `dart:ffi`, `dart:mirrors` under `lib/`; I confirmed no `dart:` import other than `dart:typed_data` in `lib/`). `pubspec.lock` is not tracked (`git ls-files` empty). The driver depends on `packbin` by path only.
**Secrets and personal data in the diff.** Zero hits for tokens, keys, PEM blocks, bearer strings, e-mail addresses, `/Users/`, `/home/`, private addresses; file names under `.env`, `.pem`, `.key`, credential or secret: none.

## Not verified

- No tag run, no pub.dev upload, no real OIDC token: the token lifetime (D2), the acceptance by pub.dev, and `exportVariable` writing `GITHUB_ENV` are read from the ADR and the action source, not observed.
- Docker, the rings, the publish gate and the whole suite were not run (instructions); only probes in a scratch project that depends on the package by path (`.../scratchpad/probe/`, outside the repo).
- A second collision attack shape (many shorter dicts) and the typed (`rowScheme`) dict path were not timed separately; the typed path uses the same insertion at `:65`.
- No Dart-VM constant-time measurement, no dart2js or AOT review of the crypto beyond the one `getInt64` probe.
- The seeded run and hostile suite were read, not re-run; the audit's own probes did not find what they do not reach beyond D1 and D6.

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none runtime (0 dependencies); dev `test` 1.33.x and `lints` 6.1.x with about 48 transitive packages: `dart pub audit` and a database lookup were not run (no network tool in scope) | — | — | — |

## Recommendations

### Immediate (Critical/High)
None.

### Short-term (Medium)
- D1: seed the dict map hash (or bound key bytes per call) and add a hostile case with equal-hash keys; the probe keys are reproducible from `bin/flood.dart` (16 stages, 65,536 keys).

### Long-term (Low / Hardening)
- D2: log the token's `exp` margin at the guard on the first tag run and mint the token next to the upload if it is short.
- D3: scope `PUB_TOKEN` to the `pubdev` target and drop every other credential there (`unset_credentials`, as `publish-swift.sh` does).
- D4: move the key, compare and counter hooks out of `lib/src`.
- D5: add `dart/.pubignore`; copy tracked files only.
- D6: declare `platforms:` in the pubspec; read 64-bit integers without `getInt64` or refuse web at build.
- D7, D8: commit a CI lockfile or exact pins for the dev dependencies; pin images by digest for all nine languages at once.

## Status after loop 99 round 1 (AZ-4149)

D1 fixed, D2 fixed, D3 fixed, D5 fixed, D6 fixed; D4, D7, D8 accepted. The merged table with F-numbers (F70 to F77) is in `security_report.md` (Loop 99 addendum).

