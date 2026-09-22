# Feature assessment — loop 1

loop: 1
feature: packbin
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-09-22
**Implement pass**: batches 01..04, implementation report `_docs/03_implementation/implementation_report_packbin_loop1.md`
**Verdict**: CLARIFY — 6 covered / 0 out-of-scope / 0 gap-clear / 2 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Each language packs the position row to the golden hex | covered | AC-1 of each pack task; language tests `Ac1` / `ac1_position_pack` / `test_ac1_position_pack`; `pack` in each package | batch_02, batch_03 |
| S2 | The tag calls all six packs in order and compares them to the fixture | covered | AZ-1875 AC-1, AC-5; `.github/workflows/publish-gate.test.sh`; `.github/workflows/publish-gate.sh` | batch_04 |
| S3 | A mismatch publishes nothing | covered | AZ-1875 AC-3; gate test with fixture `00` leaves an empty plan; `publish.yml` runs registries only after the gate | batch_04 |
| S4 | A missing language is not published | covered | AZ-1875 AC-4; gate test removes `java/` and the plan has five lines; `language_present` in `publish-lib.sh` | batch_04 |
| S5 | Toolchain images without CMake or Maven still build | covered | AZ-1880 / AZ-1881; `cpp/Makefile` `make test`; `java/test.sh` `javac` | batch_01, batch_03 |
| S6 | The test job does not hold registry tokens | covered | AZ-1866 constraint; `.github/workflows/test.yml` has no token env; gate test asserts that | batch_01 |
| D1 | Which Maven Central coordinates and credentials the Java upload uses | gap-unclear | question below | batch_03, batch_04 |
| D2 | Which git remote receives the vcpkg registry | gap-unclear | question below | batch_04 |

### Gaps that need a decision (gap-unclear)

#### D1: Maven Central coordinates

**What is not decided**
The tag is supposed to publish Maven Central `packbin` after the golden bytes match. The Java package has no `pom.xml`, and no document names a group id. Today the tag reads a secret `MAVEN_GROUP_ID` and, when Java is in the tree and that secret is empty, it writes no registry at all. Central may also require a signing key that is not in the secret list.

**Options**
- **A — You name the group id**: the tag uses that group id, artifact `packbin`, and `MAVEN_CENTRAL_TOKEN`. Trade-off: the first tag waits until you set the secret.
- **B — Publish the other five and skip Java**: a matching tag still publishes npm, NuGet, PyPI, crates.io, and vcpkg. Trade-off: the first tag is not six packages.
- **C — Use group id `packbin`**: artifact and group are both `packbin`, token only. Trade-off: Central usually rejects a group id that is not a domain you own.

**Recommendation**: A — Central will not accept a guessed group id.

#### D2: vcpkg git remote

**What is not decided**
C++ publish is a git push of a public vcpkg registry, using the repository credential, not a sixth token. No document names the remote. Today the tag pushes branch `vcpkg` on `https://github.com/zxsanny/packbin.git` unless `VCPKG_REGISTRY_URL` is set.

**Options**
- **A — Same repository, branch `vcpkg`**: consumers add that git registry. Trade-off: the source repo gains a second branch that must not be force-pushed.
- **B — You name another git URL**: the tag pushes that URL. Trade-off: the remote has to exist before the first tag.

**Recommendation**: A — it is the only git URL the project names, and it uses the repository credential.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| — | — | — | — |

### Not walked

- A later registry upload fails after an earlier language in the same tag already published. The golden check still runs before every upload.

### Harness gaps

- `scenarios.md` was absent (pre-4.7 spec). Round 1 created `_docs/02_task_plans/packbin/scenarios.md` for the two gap rows.

## Round 2

**Date**: 2026-09-22
**Implement pass**: Maven group id `packbin` and vcpkg branch `vcpkg` on `https://github.com/zxsanny/packbin.git`, chosen in clarify
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D1 | Maven Central group id and artifact are `packbin`, token only | covered | operator choice C; `<groupId>packbin</groupId>` in `.github/workflows/publish-inside.sh`; gate test rejects `MAVEN_GROUP_ID` | assess-round-1 |
| D2 | vcpkg push is branch `vcpkg` on this GitHub repository | covered | operator choice A; `VCPKG_REGISTRY_URL` default in `.github/workflows/publish-registries.sh`; gate test pushes a local `vcpkg` ref | assess-round-1 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

none

### Harness gaps

none

