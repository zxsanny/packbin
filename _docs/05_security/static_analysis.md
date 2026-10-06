# Static analysis

**Date**: 2026-10-06
**Scope**: loop 14 (`git diff c6c389c..HEAD`): `.github/workflows/publish*.sh|py|yml`, `crates-token.sh`, `test.yml`, `java/api-check.sh`, `java/tools/*.java`, `java/test.sh`, the Java API-26 replacements. Earlier loops condensed at the end.

## Loop 14

### Injection and shell safety (publish scripts)

| Check | Result |
|-------|--------|
| `${{ }}` expressions in `run:` | none. `github.ref_name` reaches the scripts only through `env: PACKBIN_VERSION` (`publish.yml:48`), so the YAML layer cannot inject; `github.ref` is used only in `concurrency.group` (`publish.yml:12`) |
| `eval`, `bash -c "<built string>"`, `curl | sh`, `sudo`, `set -x` in `publish-*.sh`, `crates-token.sh` | none |
| `$version` in shell | always double-quoted (`publish-build.sh:47,48`, `publish-upload.sh:77,145,159,162`, `publish-query.sh:104,106,109`). Heredocs expand it once as text (`publish-inside.sh:81-109`, `publish-embedded.sh:59-67`); command text inside a value is not re-evaluated. A tag `v1.0.0$(x)` becomes the literal string `1.0.0$(x)` everywhere. **No shell injection found** |
| Version validation | **none anywhere**: the only filter is the trigger glob `v*` (`publish.yml:6`) and `${version#v}`. `git check-ref-format` accepts `v1.0.0$(x)`, `v1.0.0;Foo=1`, `v1/x`, `v1"2`, `v1#2` (rejects spaces and `..`). Consequences, none of which gains a tag writer anything they lack (F15): `dotnet pack -p:Version=...;Foo=1` splits into two MSBuild properties (`publish-inside.sh:36-37`); a `"` breaks `set_version` / `vcpkg.json` / the pom (the checks then refuse: `publish-check.py:86,99,113,131,180`); `/` and `#` change URL paths in `publish-query.sh:104-109` |
| Registry answers | `publish-published.py` parses with `json.loads` and indexes fixed keys; a wrong shape raises and `publish-query.sh:49-50` turns that into a stop. Responses are never passed to a shell: only the string `yes`/`no`, and for PlatformIO the `profile.username` that is placed in one URL path (`publish-query.sh:91-94,119`); the registry's own API is the source. No `-L` on any curl, so no redirect is followed and no `Authorization` header can be forwarded to another host; TLS verification is the default (no `-k`, no `http://`) |
| Untrusted archive parsing | `publish-check.py` reads archives the repo's own build produced (`zip_members`, `tar_members` read every member into memory; no extraction to disk, so no path traversal). Not attacker input unless the build container is compromised (F13) |
| `git` pushes | `push_branch` (`publish-lib.sh:140-162`) pushes `--atomic`, never `--force`; the askpass helper is a `mktemp` file (mode 0700) that reads `$GITHUB_TOKEN` from the environment, the token is not written to it or to argv (`publish-lib.sh:148-157`) |

### Secrets handling

| Check | Result |
|-------|--------|
| Token on argv (visible in `ps` to local processes) | yes, six sites: `twine -p "$token"` (`publish-upload.sh:97`), `dotnet nuget push --api-key` (`:146`), `cargo publish --token` (`:153`), `curl -H "Authorization: Bearer $MAVEN_CENTRAL_TOKEN"` (`:103,109`, `publish-query.sh:113`), `curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN"` (`publish-upload.sh:49`, `crates-token.sh:18`), revoke (`crates-token.sh:57`). GitHub masks them in logs, and a process that can read another's argv can also read its environment, so the extra exposure is real only on a shared or self-hosted runner. F16 |
| Token echoed to the log | no. `printf '%s\n' "$state"` (`publish-upload.sh:111`) prints Central's status JSON (deployment id, state, purls, error text), not the bearer. The npm `.npmrc` is `mktemp` (0600) and removed on both paths (`:82-88`); only used when `NPM_TOKEN` is set, which `publish.yml` never sets, so npm uses OIDC. `crates-token.sh:42` masks before writing `GITHUB_OUTPUT`; the PyPI token is minted in `$(...)` and masked (`publish-upload.sh:94-95`) |
| GPG key | imported by pipe, not argv (`publish-sign.sh:22`); keyring is `mktemp -d` mode 0700 and removed on exit (`:16-18`). The key stays in the environment of the whole build subshell, including host-side `pip install` (F12). The key must be passphrase-less (loopback pinentry, no passphrase) |
| Build-only mode | `PACKBIN_BUILD_ONLY=1` unsets all 11 credential variables (`publish-registries.sh:35-39`, list at `publish-lib.sh:86-90`); `publish-sign.sh:23-25` generates a throwaway key only in that mode; `publish-registries.sh:116` writes `artifacts/dry-run`, and `publish-upload.sh:36-39` refuses to start when it exists. A later real run does `rm -rf "$artifacts"` first (`publish-build.sh:28`), so the marker cannot linger. Nothing in `publish-build.sh`, `publish-inside.sh`, `publish-embedded.sh`, `publish-sign.sh`, `publish-check.py` holds `push`, `publish`, `upload` or a write call (read: `git ls-remote`/`clone` of the registry URL, local `git commit`/`tag`, `pip install`). The throwaway key never reaches an upload |

### Java (`java/api-check.sh`, `tools/Fetch.java`, `tools/ApiCheck.java`)

| Check | Result |
|-------|--------|
| Download integrity | `Fetch.java:34-37` hashes the body and throws on mismatch **before** `Files.write` (`:38`); a cached file is reused only if its hash matches (`:25`). `HttpClient.newHttpClient()` does not follow redirects (default `NEVER`); a non-200 throws (`:31-33`). Host `repo1.maven.org`, HTTPS, hardcoded in `api-check.sh:9`. All three hashes verified against Central (dependency_scan.md) |
| Where the jars run | `java -cp animal-sniffer:asm ApiCheck.java` (`api-check.sh:19`) inside the `java` test container, which holds no credential; it is the `test` job (`contents: read`, no secrets). The jars execute with the repo mounted read-write (F13 applies to the publish job only, where this script does not run) |
| Cache path | `java/out/api-tools` (gitignored); a poisoned cache file fails the hash check |
| API-26 replacements | `Field.immutableCopy` (`Field.java:83-91`) copies and rejects null items like `List.copyOf`; `Arrays.asList(fields)` passed to the constructor is copied there, so the caller's array is not aliased. `Containers.compareUnsigned` is byte-identical in order to `Arrays.compareUnsigned` (unsigned bytes, then length); `Collections.emptyList()` replaces `List.of()` for results that are read, not mutated; `((Buffer) buf).flip()` is the API-26-safe form. No behavior change that affects unpack of hostile bytes |

### Earlier loops (condensed)

- Loop 10: C++ core: no heap, exceptions or RTTI; every `memcpy` guarded; 20 M ASan/UBSan fuzz packets, 0 reports; F0 (32-bit count truncation, High) found and fixed.
- Loop 11: unpack paths in five packages hardened (F4 to F9, fixed; re-verified in loop 13, no production source in those packages changed in loop 14).
- Loop 13: 2.63 million unpack calls, 0 hang, 0 panic, 0 walker exception; F10 (cost per round, Medium) and F11 (no size-scaled test, Low) recorded; GPG key in `publish-gate.test.sh:199-205` is generated into a temporary keyring.
