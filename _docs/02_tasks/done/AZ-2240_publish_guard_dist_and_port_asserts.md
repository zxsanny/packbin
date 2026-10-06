# Tag-time publish guard asserts the npm dist layout and the vcpkg port parts

**Task**: AZ-2240_publish_guard_dist_and_port_asserts
**Name**: `publish-check.py` checks `exports`, `types` and the dist modules of the npm tarball, and the CMake file, LICENSE and host dependencies of the vcpkg port
**Description**: `publish-check.py` is the guard that runs in the tag-time build phase before any upload. `check_typescript` also requires the `exports` and `types` entries of `package.json` and every module the dist files import; `check_vcpkg` also requires the port's `CMakeLists.txt`, its `LICENSE` and the `vcpkg-cmake` and `vcpkg-cmake-config` host dependencies. Negative cases are built from the real tarball and the real staged port.
**Complexity**: 1 point
**Dependencies**: AZ-2103_typescript_npm_javascript (the dist layout), AZ-2098_vcpkg_port_builds (the port parts). AZ-2232_vcpkg_supported_platforms_minor_version edits `publish-vcpkg.test.sh` too (other functions; land in either order).
**Component**: shared harness (`.github/workflows/publish-check.py` and its tests)
**Tracker**: AZ-2240
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, G3, answered by the owner on 2026-10-06 ("take all recommendations, implement everything now"). Probes ran against the committed HEAD 2eb9875 on a scratch copy.

- `publish-build.sh` line 75 runs `python3 publish-check.py <target> <artifacts/target> <version>` for every target in the build phase; a failure stops the tag run before any upload. Project AC-14: "A tag that fails the golden-byte check publishes 0 packages".
- What `check_typescript` sees (the real tarball, built as `publish-inside.sh` builds it: `npm ci --ignore-scripts && npm run build && npm pack`, observed): `packbin-0.1.0.tgz` with 24 files: `package/README.md`, `package/package.json`, and for each of the 11 modules `fields, flag-bits, flag-scope, index, kinds, member-names, pack-fields, ref-scope, rounds, session-pad, walker` a `package/dist/<module>.js` and a `package/dist/<module>.d.ts`. `package.json` holds `name` packbin, `version`, `license` MIT, `type` module, `types` `./dist/index.d.ts`, `exports` `{".": {"types": "./dist/index.d.ts", "import": "./dist/index.js"}}`, `files` `["dist", "README.md"]`. `dist/index.js` imports 8 of the modules by `./<module>.js`; the `.js` files hold 22 relative imports and the `.d.ts` files 19, which keep a `.ts` specifier (`./fields.ts`; the AZ-2103 note). The only bare imports are `@noble/hashes/hkdf.js` and `@noble/hashes/sha2.js`.
- HEAD's check requires the manifest name, version and license, `dist/index.js`, `dist/index.d.ts`, no `src/`, and `README.md`. Nine mutants of the real tarball all pass it (`check ok: typescript`): `dist/walker.js` removed; `dist/walker.d.ts` removed; `exports` removed; `exports` pointing at `./src/index.ts`; `exports` without `types`; `types` removed; `types` pointing at `./src/index.ts`; `dist/index.js` importing `./nope.js`; `dist/index.d.ts` importing `./nope.ts`. A tarball in which `index.js` imports a module that is not shipped installs and fails at the consumer's first import.
- What `check_vcpkg` sees (the real staged artifact, `publish-embedded.sh vcpkg` against an empty bare registry, observed): a git clone `artifacts/vcpkg/reg` whose `ports/packbin` holds 20 files: `CMakeLists.txt`, `LICENSE`, `portfile.cmake`, `vcpkg.json`, ten headers under `include/packbin/`, and under `src/` `core/{pack,session,unpack,values}.cpp`, `core/values.hpp`, `os_random.cpp`; plus `versions/baseline.json` and `versions/p-/packbin.json`; two commits (`port packbin <version>`, `version packbin <version>`). `vcpkg.json` holds name, version, description, license, homepage and the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`.
- HEAD's check requires the manifest name, version and license, `portfile.cmake`, one header, one `.cpp` under `src`, the baseline and history entries, the git-tree match and a clean clone. Eight committed mutants all pass it: no `CMakeLists.txt`; no `LICENSE`; no `vcpkg-cmake` host dependency; no `vcpkg-cmake-config`; no `dependencies` at all; both entries with `"host": false`; an empty `LICENSE`; a `CMakeLists.txt` that is a comment. A port without `CMakeLists.txt` cannot build: the portfile configures `${CURRENT_PORT_DIR}`. A port without the host dependencies fails at the user's `vcpkg install`. The gate checks these parts only at test time (`publish-vcpkg.test.sh` `vcpkg_port_checks`), not at tag time.
- Fixtures that the new check would reject: the fabricated `typescript-ok` tarball in `publish-phases.test.sh` (`npm()` helper) and the `good` layout of `publish-npm.test.sh` (`npm_layout_checks`) carry a manifest with only `name`, `version` and `license`. With the prototype guard the control reports `check failed: typescript: package.json types is None, not './dist/index.d.ts'` (observed), so both fixtures need the two manifest entries.
- The owner's uncommitted C# hunks sit in the same two files: `check_csharp` in `publish-check.py` (the `lib/<framework>/Packbin.dll` loop) and the `nupkg()` helper of `publish-phases.test.sh`. The TypeScript hunk there (`npm()`, 2 lines below `nupkg()`) and the TypeScript and vcpkg hunks of `publish-check.py` are clean at HEAD.

## Outcome

- At tag time a tarball whose `package.json` does not export the compiled entry, or whose compiled files import a module that is not in the tarball, fails the build phase, and nothing is uploaded.
- At tag time a vcpkg port without its `CMakeLists.txt`, its `LICENSE` text, or the two host dependencies fails the build phase.
- Real artifacts still pass. Every new assertion has a negative case that fails with a message naming the missing part.

## Scope

### Included
- `.github/workflows/publish-check.py`: the TypeScript hunk (`check_typescript`), the vcpkg hunk (`check_vcpkg`) and the `import posixpath` line.
- Tests (see the placement note in Flagged concerns): `npm_guard_checks` in `publish-npm.test.sh` (negative cases from the real tarball; the `good` fixture of `npm_layout_checks` gains the two manifest entries); `vcpkg_guard_checks` in `publish-vcpkg.test.sh` (negative cases from the real staged port); the `npm()` fixture of `publish-phases.test.sh` gains the two manifest entries (a TypeScript hunk, 1-2 lines).
- Commit through the patch route (`git apply --cached`) so the owner's C# hunks stay uncommitted.

### Excluded
- The C# hunks (`check_csharp`, `nupkg()`): untouched.
- Other targets' guards (python, rust, java, arduino, platformio, esp-idf) and the `refuse_symlinks` rule.
- `vcpkg.json` field `supports` (AZ-2232 asserts it at test time; see Flagged concerns).
- Content checks beyond the three port parts and the npm entries (for example comparing the port `CMakeLists.txt` with `cpp/CMakeLists.txt`: the gate does that at test time and the guard gets no repository root).

## Acceptance Criteria

**AC-1: The tarball's manifest exports the compiled entry**
Given the real npm tarball and mutants of it
When `python3 publish-check.py typescript <dir> v0.1.0` runs
Then the real tarball prints `check ok: typescript`; and exit 1 with `check failed: typescript: package.json exports is ...` for `exports` removed, `exports` to `./src/index.ts`, and `exports` without `types`; `check failed: typescript: package.json types is ...` for `types` removed and `types` to `./src/index.ts`. The required values are exactly `types` = `./dist/index.d.ts` and `exports` = `{".": {"types": "./dist/index.d.ts", "import": "./dist/index.js"}}` (the same values `publish-npm.test.sh` asserts on the source `package.json`). At HEAD all five mutants pass (observed). The check is `npm_guard_checks` in `publish-npm.test.sh`, fed the tarball that `npm_dist_checks` built with the real `publish-inside.sh`.

**AC-2: Every module the dist files import is in the tarball**
Given the real tarball and four mutants: `dist/walker.js` removed; `dist/walker.d.ts` removed; an appended `export * from "./nope.js";` in `dist/index.js`; an appended `export * from "./nope.ts";` in `dist/index.d.ts`
When the check runs
Then each exits 1 with a message that names the importing file, the specifier and the missing member, for example `check failed: typescript: dist/index.js imports ./walker.js, but dist/walker.js is not in the tarball` and `... dist/index.d.ts imports ./walker.ts, but dist/walker.d.ts is not in the tarball`. Rule: for every `package/dist/*.js` member, each relative specifier (`from "./x.js"`, `import "./x.js"`, `import("./x.js")`) names a `package/dist/x.js` member; for every `package/dist/*.d.ts` member, each relative specifier `./x.ts` or `./x.js` names a `package/dist/x.d.ts` member. On the real tarball all 22 plus 19 specifiers resolve (observed). At HEAD all four mutants pass. The check is `npm_guard_checks`.

**AC-3: The port carries its CMake file and LICENSE**
Given the real staged port and mutants of its working tree
When `python3 publish-check.py vcpkg <artifacts/vcpkg> v<version>` runs
Then the real port prints `check ok: vcpkg`; with `CMakeLists.txt` removed, or replaced by a one-line comment, it exits 1 with `check failed: vcpkg: CMakeLists.txt is missing or does not build the packbin library` (the file must hold `add_library(packbin`); with `LICENSE` removed or empty it exits 1 with `check failed: vcpkg: LICENSE is missing or is not the MIT license text` (the file must hold `MIT License`). At HEAD the committed forms of all four mutants pass (observed). The check is `vcpkg_guard_checks` in `publish-vcpkg.test.sh`, fed `$vcpkg_tmp/out-first/artifacts/vcpkg`, the artifact `vcpkg_stage_registry` already builds with the real `publish-registries.sh`; it copies the directory and edits the copy.

**AC-4: The port declares both host dependencies**
Given the real staged port and mutants of its `vcpkg.json`
When the check runs
Then with the `vcpkg-cmake` entry removed it exits 1 with `check failed: vcpkg: vcpkg.json lacks the host dependency vcpkg-cmake`; with `vcpkg-cmake-config` removed, `... vcpkg-cmake-config`; with `dependencies` removed, or both entries set to `"host": false`, it names `vcpkg-cmake`. Rule: each of the two names is an object dependency with `"host": true`. At HEAD all four mutants pass. The check is `vcpkg_guard_checks`.

**AC-5: Real artifacts and fixtures still pass**
Given the real tarball, the real staged port (version `$vcpkg_version`), and the fabricated `typescript-ok` and `good` fixtures with the two manifest entries added
When the guard runs on them
Then all print `check ok: <target>`; the fabricated negative cases of `publish-phases.test.sh` (`typescript-version`, `typescript-license`, `typescript-payload`) still fail with the same keywords. The real-artifact passes are the control cases of AC-1 to AC-4; the fixtures are checked by the existing `ph_fabricated_checks` and `npm_layout_checks`; the full pipeline through `publish-build.sh` is the existing `ph_full_publish`.

**AC-6: The owner's hunks are byte-identical**
Given `publish-check.py` and `publish-phases.test.sh` with the owner's uncommitted C# hunks
When the change is committed through the patch route (a patch of only the TypeScript and vcpkg hunks, built against HEAD with `-U0` or `-U1` because the `nupkg()` and `npm()` hunks are 2 lines apart, applied with `git apply --cached`)
Then `git diff -U0 HEAD -- <file> | grep '^[+-][^+-]'` of each file, taken before the change and after the commit, shows the same lines (the C# hunks only), and `git show HEAD:<file>` after the commit holds the new hunks and none of the owner's. The check is a recorded before/after comparison in the batch report; no repository script holds it.

## Non-Functional Requirements

**Reliability**
- The guard stays a pure read of the artifact directory: standard library only (`json`, `posixpath`, `re`, archive readers), no network, no repository root, no subprocess beyond the existing `git` calls.
- Every new `need(...)` message names the part and the file; the first failure is reported as `check failed: <target>: <what>` on stderr with exit 1 (unchanged format).
- New assertions run before the git-tree and clean-clone checks of `check_vcpkg`, so a missing part is named as itself.

**Performance**
- The TypeScript scan reads each of the 22 dist members once; the artifact is 212 kB unpacked. The test mutants add about ten runs of a Python process (under 2 s).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | real tarball plus five `exports`/`types` mutants | control `check ok: typescript`; five exit 1 naming `exports` or `types` |
| AC-2 | four dist mutants | exit 1 naming the importing file, the specifier and the missing member |
| AC-3 | real port plus four CMake/LICENSE mutants | control `check ok: vcpkg`; four exit 1 naming the part |
| AC-4 | four `vcpkg.json` mutants | exit 1 naming the host dependency |
| AC-5 | fabricated fixtures with the new manifest entries | the controls pass, the old negatives still fail |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | full publish scenarios of `publish-phases.test.sh` (`ph_full_publish`) | the real build phase runs the guard on all nine artifacts | every `build ok <target>` line is still written | Reliability |
| AC-6 | working tree with the owner's C# hunks | before/after `git diff -U0` comparison | identical lines | Reliability |

## Constraints

- ADR-001: harness only; no product source changes.
- Files at or under 500 lines: `publish-phases.test.sh` is 501 lines at HEAD and this task adds at most the two manifest entries there (no new lines if they go on the existing `manifest = ...` line); `publish-npm.test.sh` is 149 lines and `publish-vcpkg.test.sh` 311 (AZ-2232 adds about 80), so the new functions (about 40 lines each) fit; `publish-check.py` is 262 and grows by about 15.
- Error kind and label of existing errors unchanged (decision C15): the `check failed: <target>: <what>` format and every existing message keep their text.
- The edit of `publish-check.py` is limited to the TypeScript and vcpkg hunks and the import line, as AZ-2103 was, with the owner's approval of 2026-10-06 extended by the owner's answer "implement everything now" to the assessment that listed this gap.
- `bash.md` rules for the test scripts; temp dirs through `mktemp` and `trap`; no `2>/dev/null`.
- Wire bytes: none involved. The tarball and port listings above come from real runs; the implementer re-derives them.

## Risks & Mitigation

**Risk 1: The import scan rejects a valid tarball**
- *Risk*: a relative specifier inside a comment or string would count as an import; a future `.d.ts` style (`import("./x")` without extension) would not resolve under the rule.
- *Mitigation*: the rule is checked on the real tarball (41 specifiers, 0 unresolved); the control case in `npm_guard_checks` fails first when a build starts to emit another style, and the message names the file and specifier.

**Risk 2: The exact `exports` equality blocks a deliberate package change**
- *Risk*: adding a second entry point to `exports` fails the guard until the guard is updated.
- *Mitigation*: the same exact value is already asserted at test time on the source `package.json` (`publish-npm.test.sh`, AZ-2103 AC-6); both move together.

**Risk 3: The vcpkg `CMakeLists.txt` content check is looser than the gate's equality**
- *Risk*: `add_library(packbin` is present in a wrong file.
- *Mitigation*: the gate (`vcpkg_port_checks`) compares the port file with `cpp/CMakeLists.txt` byte for byte at test time; the guard only refuses an absent or non-library file.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket says to add the negative cases in `publish-phases.test.sh`. That file is 501 lines at HEAD, over the 500 cap, and one new vcpkg case there needs a fabricated git clone (about 35 lines). This spec builds the negative cases from the real artifacts that `publish-npm.test.sh` and `publish-vcpkg.test.sh` already produce (stronger evidence, files under the cap) and touches `publish-phases.test.sh` only for the two manifest entries its TypeScript fixture needs. If the owner wants the cases in `publish-phases.test.sh`, the placement moves and the file stays over the cap | owner | open | Low |
| `supports: "linux \| osx"` (AZ-2232) is a port part too; this task does not make the tag-time guard assert it, so a regression of that line is caught by the gate at test time only. A one-line `need` after AZ-2232 would close it | owner | open | Low |
| The mutants of the vcpkg test are edits of an uncommitted working tree, so HEAD's guard also rejects them, but at its clean-clone check; the test therefore asserts the part name in the message, not only the exit code. The HEAD evidence in this spec comes from committed mutants | implementer | accepted-risk | Low |

## Owner decision (2026-10-06)

DECIDED, take all recommendations (feature assessment of loop 16, "implement everything now"): G3 is done now, as a harness task: the tag-time guard gets the missing assertions and negative cases, the TypeScript and vcpkg hunks of `publish-check.py` and `publish-phases.test.sh` are edited and committed through the patch route (`git apply --cached`) exactly as AZ-2103 did, and the owner's uncommitted C# hunks are verified byte-identical before and after. The open concerns above are resolved by this section except the placement row and the `supports` row, which the owner may answer "take the recommendation".

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), with AZ-2232 in one worker; `publish-check.py` and `publish-phases.test.sh` carry the owner's uncommitted C# hunks, so the change went in by patch route (two patch files, `git apply --check` exit 0 in both modes, applied by the coordinator; the owner's `check_csharp` and `nupkg()` hunks are untouched, AC-6).

What shipped:
- `publish-check.py` (about +25 lines): `import posixpath`, the constants `NPM_TYPES`, `NPM_EXPORTS` and `NPM_RELATIVE_IMPORT`; `check_typescript` requires `types` and `exports` to equal the compiled layout and every relative import of a `dist/*.js` or `dist/*.d.ts` to name a member of the tarball (`.d.ts` specifiers map to `.d.ts`); `check_vcpkg` requires `CMakeLists.txt` that builds the library, a `LICENSE` that holds the MIT text and the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`, before the baseline, git-tree and clean-clone checks. Every existing message is unchanged.
- `publish-npm.test.sh` (149 to 221 lines): `npm_guard_checks`, the guard on the real tarball plus nine mutants (`exports` removed, pointed at `src`, without `types`; `types` removed, pointed at `src`; `walker.js` and `walker.d.ts` removed; a `./nope.js` and a `./nope.ts` import), full-message regex. `publish-vcpkg.test.sh`: `vcpkg_guard_checks`, a control plus eight mutants (no `CMakeLists.txt`, a comment-only one, no `LICENSE`, an empty one, no `vcpkg-cmake`, no `vcpkg-cmake-config`, no `dependencies`, both host entries off), exact-message equality. The `good` layout of `npm_layout_checks` and the `npm()` fixture of `publish-phases.test.sh` (1 line, the file stays at 501 lines as at HEAD) gain the two manifest entries.

Evidence: the real tarball and the real staged port pass `publish-check.py` (`check ok`); with HEAD's fixtures the patched guard rejects as intended (`package.json types is None, not './dist/index.d.ts'`); the worker's 14 guard mutants and the reviewer's 24 npm and 14 port mutants are all rejected; removing each of the nine new rules makes `npm_guard_checks` or `vcpkg_guard_checks` fail; a full `publish-gate.test.sh` passes (380 s, HEAD 372 s). `--npm` also passes on a copy that holds the working-tree TypeScript with `element-kinds.ts`.

Review finding F4 (open, Low; the spec's Risk 1 accepts the first part): the import regex counts a quoted `from "./x"` inside a comment or string, `require("./nope.js")` and an undeclared bare import such as `import "lodash"` pass, and a non-UTF-8 member gives a `UnicodeDecodeError` traceback instead of a named part.

Open: `supports` is not asserted at tag time (the spec excludes it; a committed port without `supports` passes the guard and only the clean-clone check catches a working-tree one; an optional one-line `need(manifest.get("supports") == "linux | osx", ...)` plus a mutant case would close it); `shellcheck` and Docker were not available to the worker (the reviewer ran shellcheck 0.11 clean); AZ-2238 also edits the npm area, but in `publish-position.test.sh`, so the two additions do not touch the same functions. The Ubuntu runner proves the import-specifier style under its node and npm and the guard on all nine real artifacts (`ph_full_publish`).
