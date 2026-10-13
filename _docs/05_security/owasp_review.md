# OWASP Top 10 review

**Date**: 2026-10-06
**List**: OWASP Top 10 2025, confirmed at https://owasp.org/www-project-top-ten/ ("the most current released version is the OWASP Top 10 2025") at the start of this audit; A01 to A10 names unchanged from earlier reviews
**Scope**: loop 16 (`git diff 9db438e..HEAD`, HEAD 5c95950): unpack of untrusted bytes in Java (nested rounds, typed rows), TypeScript and Rust (u64 counts), TypeScript, Python, Java and C++ (split-form flag bits), Python (round and slot limits, `_flag_scope.py`), the hostile session tests; session key and nonce handling; the npm JavaScript build, the vcpkg port, the tag-time guard, the `ring` CI job and its `gcc:16` wrapper; the new and changed shell scripts. C# and the owner's uncommitted hunks are out of scope. Static analysis only: no DAST, no repository settings.

## Loop 16

| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | library has no request path. CI permissions unchanged and least-privilege: workflow `contents: read` (`test.yml:9-10`, `publish.yml:8-9`), only `publish` holds `contents: write` and `id-token: write` (`publish.yml:23-25`); the new `ring` job is part of the called `test` workflow, so it has `contents: read` and no secret on a push, a pull request and a tag. Anyone with write access can still publish with a `v*` tag, with no environment or documented tag rule (F14, Low, carried) |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | `docker-compose.publish.yml` unchanged (six build containers, repo read-only). New: the `ring` compiler container mounts the repository and the host `/tmp` read-write, keeps the default network and capabilities, image by tag (F20, Low; the hardening is the known open item Q9). Fixed host `/tmp` names are executed or deleted by `language-pair.sh` and `publish-position.sh` (F24, Low). F13 residue as before |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1 stays fixed: all 10 non-local `uses:` are 40-hex commits equal to their tags (the three new ones, `setup-dotnet` v6.0.0, `setup-python` v7.0.0, `setup-java` v6.0.1, verified with `git ls-remote`). npm: `dist` is built in the credential-free container from the lockfile with `npm ci --ignore-scripts` (`publish-inside.sh:66`), `files` is `dist` only, `exports` closes deep imports; vcpkg: the port vendors its sources and installs nothing from a tag archive, and the README tells consumers to pin the registry by `baseline`. Open: F12 (unpinned transitive wheels in the credentialed job, unchanged), F2, F3 (now also `gcc:16` in the `ring` job) |
| A04 Cryptographic Failures | PASS_WITH_WARNINGS | the zero-nonce hazard is fixed (Python `start`/`join`/`load` accept only bytes-like of the exact size, TypeScript `load` checks the `Uint8Array` brand; probed). Documented properties, not findings: no tag, so a changed byte is not detected, and a dropped or injected packet desynchronizes the receiver (`README.md:20,458-460`, `pack-session.md`). New Low (F19): an explicit nonce has no freshness guard and no reuse warning in the docs, the Python and TypeScript constructors and TypeScript `start`/`join` do not share the strict check of `load`. TLS verified on every registry call; OIDC trusted publishing unchanged |
| A05 Injection | PASS_WITH_WARNINGS | no shell injection: `ref_name` reaches scripts through `env:`, every expansion in the new scripts is quoted, no `eval`; the vcpkg JSON is written from an unquoted `$version` heredoc but the guard compares the parsed value with the tag (F15, extended, Low). C++ `unpack` hands back unvalidated UTF-8 as borrowed bytes (F22, Low, documented) |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10 reduced again: the README now states the bound correctly (`README.md:1075,1133`) and Python gained `Scheme.with_limits` with the same two defaults (65,535 rounds, 4,194,304 slots, checked before each round, per call); what remains is the high default ceiling (Python +112 MB for a 1 MiB packet at the slot limit) and the linear cost of counted fields and elements (Python `bits` +69 MB, 16 lists of 65,535 group elements +212 MB for 1 MiB). F21 (Low): `pack` writes as many rounds as the row's count states |
| A07 Authentication Failures | N/A | no accounts. Registry auth: OIDC where available; `PYPI_TOKEN` beside OIDC (F12) |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F13 narrower: the loop 15 follow-up refuses symlinks in the five container-built trees (`publish-check.py:257-276`, verified); still open are non-regular files, the check-to-upload digest gap and the Rust `stage/` tree against the checked `.crate`. F23 (Low): the new npm and vcpkg assertions leave gaps (`supports`, `require`, bare imports). F16 unchanged |
| A09 Security Logging and Alerting Failures | N/A | libraries do not log. Pipeline logs carry no secret in the new scripts |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | unpack returns an error value for every limit and count refusal in Python, TypeScript, Java and Rust (fuzz: 29.8 million calls over the delta schemes, 0 exceptions). Two exceptions reachable from a well-formed packet when the scheme's accessors do not fit: C# typed `Unpack` of a round (F17, carried) and Java `unpack` with a typed accessor in an anchored-group element (F18, probed: `ClassCastException`). The README sentence "does not throw" holds for the first only with its stated exception |

### What changed in the trust boundaries this loop

- **Untrusted bytes** (unpack): Python gained the round and slot budget; TypeScript and Rust handle every u64 count by refusing a count that cannot be held exactly; Java nested rounds fold into one list per outer round under the shared slot budget; split-form flag bits are numbered and bound per scope at construction in four packages. None adds an allocation sized by a packet count before a bytes-left check (probed for u64 counts 2^64-1 to 0 in TypeScript, Rust, Java and Python).
- **Keys and nonces**: `_exact_bytes` (Python) and `isUint8Array` (TypeScript) close the fixed-zero-nonce and zero-key routes through untyped arguments; Rust `PackSession::pack` returns `Result` and uses a pad position only after a successful pack.
- **Publish**: the npm tarball is now compiled JavaScript from a credential-free container; the vcpkg port is a built, vendored, versioned port; the guard learned both. No credential, registry write path or secret was added to any script or container, and the new test scripts run with tokens unset or stubbed.
- **CI**: one new job (`ring`) runs the six-language cross-check on every push and pull request, without secrets, through a `gcc:16` container.

### Who can publish what

Unchanged from loop 15: a `v*` tag by anyone with write access starts `publish`, secrets are repository-level, `needs: test` (`publish.yml:16-22`) now also requires the `ring` job to pass. Neither the npm build nor the vcpkg staging adds a write path outside `publish-upload.sh`.

## Earlier loops (condensed)

- Loop 15: A01 to A10 as above for the round limits (F10, F11, F17), read-only build containers (F13), CI pins (F1 fixed, F12 reduced). Full table: `git show 9db438e:_docs/05_security/owasp_review.md`.
- Loop 10/11/13/14: no access control (library); F4 to F9 fixed; F10, F11 opened in loop 13; F12 to F16 opened in loop 14. Full tables are in git history (`git show 43af2f6:_docs/05_security/owasp_review.md`).

## Loop 17 addendum (2026-10-07)

List unchanged (OWASP Top 10 2025). Only C# changed in loop 17. A10 Mishandling of Exceptional Conditions stays PASS_WITH_WARNINGS with two more findings: F25 (a hostile element value throws out of typed `Unpack` when the member's element type is narrower than the field, Medium) and F26 (unsupported collection members throw at unpack, Low), next to F17 (typed rounds) and F18 (Java). A06 Insecure Design: F10 unchanged in kind, the C# figures are in the report. All other categories: no new evidence from the C# diff (no access control, crypto, injection, auth, logging or SSRF surface in the package).

## Loop 18 addendum (2026-10-11)

List unchanged (OWASP Top 10 2025, re-confirmed at https://owasp.org/Top10/2025/ on 2026-10-11: A01 Broken Access Control to A10 Mishandling of Exceptional Conditions). Scope `aea6344..HEAD` over the six packages and `.github`/`fixtures`.

| Category | Status | Loop 18 evidence |
|----------|--------|------------------|
| A06 Insecure Design | PASS_WITH_WARNINGS | F21 re-rated Low to Medium and widened: `pack` of a `times` with a lone scalar (or a valueless body) runs `n` rounds for any `n`, in TypeScript, Python, Java, C# and (new in loop 18) Rust; 4 bytes of count ask for gigabytes; C++ is bounded by its `Array`. F10 unchanged (no unpack source changed in five packages; C# re-measured at 298 and 312 MiB per 1 MiB packet). The unpack side of the new `flags`-member shapes refuses oversized claimed counts in microseconds with no allocation tied to them |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F25 (Medium) and F26 (Low) fixed: the C# scheme refuses a narrow or unsupported collection member when it is built, verified by probe on 26 combinations; 6.2 million typed unpacks raised nothing. F17 re-verified and not widened by the `flags`-member shapes (`InvalidCastException` only for a set round). F18 unchanged. New F27: the collection checks are skipped inside rounds, latent behind F17 |
| A05 Injection | PASS_WITH_WARNINGS | `fixtures/hostile/check-cases.sh` runs no code on a hostile case file and README (command substitution, backticks, globs, option-like fields, control bytes; canary files probe); it echoes raw field bytes into its error text (log hygiene, observation). F15, F22 unchanged |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | `ring-wiring.test.sh` reads the workflow with `YAML.safe_load`, takes no repository text into a shell; the C# ring driver parses only fixed hex. F13, F16, F23 unchanged |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F20 unchanged; F24 gains one reused class file (`HandoffElements.class`) |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | no manifest changed; npm, NuGet and OSV queries give 0 (see `dependency_scan.md`); F12, F2, F3 unchanged |
| A01, A04, A07, A09 | unchanged | no surface in the diff (F14 carried; F19 carried; A07 and A09 N/A) |

Earlier findings re-stated: F10 Medium open (unchanged); F12 Medium open (unchanged); F17 Low open; F25 and F26 fixed; F21 now Medium open.

## Loop 19 (2026-10-11)

List: OWASP Top 10 2025 (names unchanged since loop 16). Scope: `git diff e1a791e..HEAD` (see `security_report.md`).

| Category | Status | Evidence |
|----------|--------|----------|
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F32: the default venv `/tmp/packbin-pytest` is executed and, behind a symlink, emptied by `--clear`; F13, F20, F24 unchanged |
| A06 Insecure Design | PASS_WITH_WARNINGS | F28 (no pack-wide output budget; the count cap of F21 is fixed), F31 (`pack` writes packets `unpack` refuses), F10 unchanged |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F29 (Java buffer growth overflow), F30 (Java count truncation), F17 and F27 unchanged (C# typed round) |
| A03 Supply Chain | PASS_WITH_WARNINGS | no manifest or lockfile changed; `npm audit` and `dotnet list package --vulnerable` 0; F12 unchanged |
| A01, A04, A05, A07, A08, A09 | unchanged | no surface in the diff (F14, F15, F16, F19, F22, F23 carried; A07 and A09 N/A) |

Earlier findings re-stated: F10 Medium open (unchanged); F12 Medium open (unchanged); F17 Low open; F27 Low open; F21 fixed for the count, F28 Medium open.

## Loop 20 (2026-10-12)

List: OWASP Top 10 2025 (names unchanged since loop 16). Scope: `git diff a27433e..HEAD -- csharp typescript python java rust cpp fixtures` (HEAD 803625f; see `security_report.md`, "Loop 20 findings").

| Category | Status | Evidence |
|----------|--------|----------|
| A06 Insecure Design | PASS_WITH_WARNINGS | F28 fixed: one pack output budget (`maxBytes`, 16 MiB) plus `maxSlots` per round and the `repeat` cap on pack; the lone string under a `times` is refused in 4 to 30 ms in five packages, element and round routes in 0.37 to 7.4 s. F31 fixed in four packages, partly in Python (8 slots per name per run). New Lows: F33 (an empty round body charges nothing: CPU unbounded, TypeScript 93 s for a 1.1 MB request), F34 (TypeScript `sliceRound` copies the whole scope per round). F10 unchanged (no unpack limit changed) |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F17, F27, F29, F30 fixed: 5.6 million typed C# unpacks over 9 to 10 round shapes raised 0 exceptions, five member types that cannot hold a round are refused at construction, the Java buffer grows once past 2^30 and refuses with a typed error at the array limit, Java `sized`/`bits` counts above `Integer.MAX_VALUE` are refused. F18 (Java typed accessor in an anchored-group element) unchanged. The new refusals are typed in every package (`RangeError`, `ValueError`, `IllegalArgumentException`, `ArgumentException`, `PackError::Type`) and name the member |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F32 untouched (`.github/` not in the diff); F13, F20, F24 unchanged |
| A03 Software Supply Chain | PASS_WITH_WARNINGS | no manifest, lockfile, workflow, image or script changed; `npm audit` 0, `dotnet list package --vulnerable` 0; F12 unchanged |
| A01, A04, A05, A07, A08, A09 | unchanged | no surface in the diff: the new tests start two fixed child processes (Python AC-1, Java `LoneUtf8Budget`, TypeScript `spawnSync`) without a shell, secret or network; F14, F15, F16, F19, F22, F23 carried; A07 and A09 N/A |

Earlier findings re-stated: F10 Medium open (unchanged); F12 Medium open (unchanged); F28 fixed; F31, F32, F33, F34 Low open.

## Loop 23 (2026-10-13)

List: OWASP Top 10 2025 (names unchanged since loop 16). Scope: `git diff b8b2809..807e718` (HEAD 807e718; see `security_report.md`, "Loop 23 findings"; loops 21 and 22 are recorded there only).

| Category | Status | Evidence |
|----------|--------|----------|
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F37 fixed: the Rust map form refuses or checks every value kept under a `repeat` body name or nested `__times_<anchor>` key (fuzz: 0 silent drops at HEAD). F40 new (Low): C# dictionary rows give a nested-row group the outer row's values. F35 open, documented in the README. F13, F16, F23 carried |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F36 fixed: a C++ `when` with an `eq` source id outside 0..32 767 is `SchemeInvalid`. F39 new (Low): C++ count and own ids still wrap. F18 carried |
| A03 Software Supply Chain | PASS_WITH_WARNINGS | no manifest, lockfile, workflow, image or script changed; F12 unchanged |
| A01, A02, A04, A05, A06, A07, A09 | unchanged | no surface in the diff; F10 Medium open (no unpack limit changed); A07 and A09 N/A |

Earlier findings re-stated: F10 and F12 Medium open; Low open 16.

