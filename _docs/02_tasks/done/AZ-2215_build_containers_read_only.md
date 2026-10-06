# Publish build containers see the repo read-only

**Task**: AZ-2215_build_containers_read_only
**Name**: Read-only repo mount for the publish containers (F13)
**Description**: The containers the publish run starts (the six golden-gate checks and the five language builds) mount the repo read-only and write only their own `artifacts/<lang>` folder, so nothing a container does can change a script, a source file or an earlier artifact that the host uses next.
**Complexity**: 5 points
**Dependencies**: None (implement after AZ-2214: both edit `publish-inside.sh` and `publish-gate.test.sh`, in different hunks)
**Component**: ci-publish
**Tracker**: AZ-2215
**Epic**: AZ-2069

## Problem

The check in the build phase does not bind what the host later runs and uploads. Every container of the publish run mounts the whole repo read-write and runs as root:

- `docker-compose.test.yml` mounts `./:/src` with no mode in all six language services (lines 12, 25, 38, 51, 64, 77) and `./test-results:/test-results` read-write (lines 14, 27, 40, 53, 66, 79).
- `run_inside` starts a build container with `docker compose run -T --rm --no-deps` and only `-e` overrides, no `-v` (`publish-build.sh:36-56`, command at 48-55). It runs for csharp, typescript, python, rust and java (`publish-build.sh:62-67`).
- The golden gate starts the same services the same way (`publish-gate.sh:17-26`, command at 22-25), once for each of the six languages, in the same job and before the credentialed step; the host then runs `publish-registries.sh` from the same tree (`publish.yml:30-31,44-57`).
- Inside `/src` live the scripts the host runs next with every credential (`publish-upload.sh`, `publish-lib.sh`, `publish-query.sh`, `publish-check.py`, `crates-token.sh`), the artifacts of the targets built earlier (they are already checked), `.git` and any `.cargo/config.toml` (audit F13, `_docs/05_security/security_report.md`). A root process in one container can rewrite any of them. The build script itself is a running bash script on the same tree.
- The Python build downloads `setuptools` and `build` as root (`publish-inside.sh:67-68`; AZ-2214 pins them), and the gate runs `npm ci` as root in the repo when `typescript/node_modules` is absent, which it is on a fresh checkout (`publish-position.sh:22-24`). This is the "upstream compromise" precondition of F12; F13 is what that compromise can then reach.

What each step writes today (read from the scripts; csharp also run on a read-only mount):

| Step | Runs | Writes today | Under a read-only repo |
|------|------|--------------|------------------------|
| build csharp | container, `publish-inside.sh:50-54` | `dotnet pack "$root/csharp/Packbin.csproj"` builds in place: `csharp/bin`, `csharp/obj` | fails (probe 2026-10-06: `Read-only file system : '/src/csharp/obj'`); needs a copy |
| build typescript | container, `:55-61` | copy to `$work/typescript`, `npm pack` into `$dest` | no repo write |
| build python | container, `:62-69` | copy to `$work/python`, pip and `build` output in the container, wheel and sdist into `$dest` | no repo write |
| build rust | container, `:70-79` | copy to `$dest/stage`, `cargo package` writes `$dest/stage/target`, crate into `$dest` | no repo write |
| build java | container, `:80-125` | classes and javadoc in `$work`, bundle in `$dest/maven`; reads sources with `-sourcepath` and `jar -C` | no repo write |
| vcpkg, arduino | host, `publish-embedded.sh:95-124` | clones in `$dest/reg`, scratch in `mktemp -d` (`:18-19`); `stage-arduino.sh:16-20` writes only its argument | not containers |
| platformio, esp-idf | host, `publish-embedded.sh:126-138` | copy of `cpp/` in `$work`, archive in `$dest` | not containers |
| gate csharp | container, `publish-position.sh:19` | `dotnet run` of `drivers/csharp/Position.csproj` builds `drivers/csharp/{bin,obj}` and, through its project reference, `csharp/{bin,obj}` | needs a copy |
| gate typescript | container, `:22-25` | `npm ci` writes `typescript/node_modules` | needs a copy |
| gate python, rust, cpp, java | container, `:28,31-32,35-44,47-55` | python only tries `.pyc` files (Python skips them silently on a read-only path); rust, cpp, java write under `/tmp` | no change |

The typescript, python, rust and java rows are read from the code, not run on a read-only mount (the probe run of those four was blocked in this session); the blackbox tests below prove them. The csharp row was run: `dotnet pack` from a copy of `csharp/` plus `README.md` on a read-only `/src` produced `Packbin.0.1.9.nupkg`. The copy needs `README.md` one directory above `csharp/` because the project packs `..\README.md` (`csharp/Packbin.csproj:20`).

The loop-14 chown (`publish-inside.sh:25-37`, host uid and gid passed at `publish-build.sh:53-54`) hands `$dest` to the host user, because on Linux the container writes as root and the host could not chmod it. Commit `b45335d` records that this failed only on the runner.

Compose behavior probed on 2026-10-06 (Docker Desktop macOS arm64, Docker 25.0.2, Compose 2.24.3; the runner image has Docker 28.0.4 and Compose 2.38.2):
- `docker compose run -v "$PWD:/src:ro"` for a target the service already mounts is **silently ignored**: a write to `/src` succeeded. A read-only mount through `run -v` would look configured and not be.
- A second compose file that lists `./:/src:ro` for the service replaces the mount (volumes merge by target): `docker compose config` shows `read_only: true` and a write fails with `Read-only file system`.
- Another second-file entry `type: tmpfs, target: /test-results` replaces the repo's `/test-results` bind; the host folder stays empty.
- `run -v <host dir>:/out/artifacts/<lang>` for a new target works and is writable; a chown there works.

## Outcome

- A process in any publish container cannot create, change, delete or chmod anything under `/src` (scripts, sources, `.git`, `.cargo`). Attempts fail with a read-only error and the host files stay byte-identical.
- The only host path a container can write is its own `artifacts/<lang>` folder, mounted outside `/src`. It does not see the other targets' folders. Its scratch space is the container's own filesystem, gone with `--rm`.
- Every language build produces the same artifact as before: same file names, same `publish-check.py` result.
- The gate containers have the same limits; the gate output is unchanged.
- The host runs only what the checkout holds: after a full build run the tree outside `.github/workflows/out/` is byte-identical to before, so no script the host executes could have been changed by a container (S11).
- A probe test fails if the read-only mount is ever dropped.

## Scope

### Included
- Decision, how the mount is made read-only: a new compose override file beside `docker-compose.test.yml` that sets `./:/src:ro` for the six language services and replaces `/test-results` with a tmpfs; the publish container invocation passes both files. Not `run -v` (silently ignored, probe above). Not an edit of `docker-compose.test.yml`: the suites in `test.yml:44-50` need a writable tree (`run-suite.sh:25,30,45,50` build in `bin`, `obj`, `node_modules`, `target`, `test-results`). The override file says in a header comment that it is for publish only.
- Decision, the writable folder: `run -v <host>/artifacts/<lang>:/out/artifacts/<lang>` and `PACKBIN_OUT=/out` in the container, set in `run_inside` (`publish-build.sh:48-55`). `/out` is outside the read-only tree, so there is no nested mount in `/src`, and the rule "PACKBIN_OUT must be inside the repo" (`publish-build.sh:43-46`) goes away. The host creates the folder first, as it does now (`publish-build.sh:60`), so Docker does not create it as root.
- Decision, one canonical way to start a container: the compose command (both files, project name, `-T --rm --no-deps`) is built in one function of `publish-lib.sh`, used by `publish-build.sh` and `publish-gate.sh`. No second `docker compose` call remains in the publish scripts. The probe test goes through the same function.
- Decision, C# packs from a copy: `publish-inside.sh` copies `csharp/` (without any `bin` or `obj`) and `README.md` into the work directory, keeping the relative layout, and runs `dotnet pack` there. The existing `-o "$work/nupkg"` and `cp` to `$dest` stay. Stale `bin`/`obj` of a developer machine are not copied. Typescript, python, rust and java already work from a copy or from `$dest` and keep their code.
- Decision, the gate is in scope: its containers have the same mount and run code fetched at run time (`npm ci`) before the host runs the publish scripts, so leaving it out would leave the Outcome's last point false. `publish-position.sh` runs the csharp and typescript drivers from a container-local copy that keeps the relative layout the drivers need (`Position.csproj` references `../../../../csharp/Packbin.csproj`; `position.ts:1` imports `../../../typescript/src/index.ts`), and `npm ci` runs in that copy. On a developer machine with `typescript/node_modules` present, behavior stays as today.
- Decision, the loop-14 chown stays, on `$dest` only (`publish-inside.sh:32-34`): on the Linux runner the container still writes the folder as root. `chmod -R a+rwX` stays gone (`publish-phases.test.sh:196`).
- Decision, `PACKBIN_DOCKER=0` (`publish-build.sh:39-42`, `publish-gate.sh:18-21`): a host path with no container, used by `registry_checks` (`publish-gate.test.sh:62,79`); `publish.yml` never sets it. No read-only guarantee is claimed there. The csharp copy lives in `publish-inside.sh`, so this path no longer leaves `bin` and `obj` in the tree either. A gate check fails if any workflow sets `PACKBIN_DOCKER`.
- Decision, no tmpfs for work and no `--read-only` root filesystem: dotnet, cargo, pip and npm write caches and temp files in the container's own filesystem, and a tmpfs has a size cap that nobody has measured.
- Tests: new sibling test file sourced by `publish-gate.test.sh` (it is 447 lines; `publish-phases.test.sh` is already 500).
- Docs: `_docs/04_deploy/docker_stack.md:3` (says the only compose file is `docker-compose.test.yml`), `containerization.md`, and the build-phase paragraph of `packages.md:36`; `test.yml:27-37` required-file list gains the new compose file.

### Excluded
- A digest of each artifact taken at check time and verified before upload, and the Rust re-archive of the staged tree (`publish-upload.sh:152-154` vs `publish-check.py:135-138`): F13 remediation items not in the loop-15 wording. Flagged.
- Host-side steps of the embedded targets and signing (`publish-embedded.sh`, `publish-sign.sh`): they run on the host, not in containers. F12 and AZ-2214 cover what they install.
- Dropping root, capabilities, the network or pinning image digests (F3); the python build needs the network.
- The `docker-compose.test.yml` services used by `test.yml` and the two embedded services (`cpp-embedded`, `cpp-embedded-esp`): not part of the publish run.
- Any change to what is built, its names or its checks.

## Acceptance Criteria

**AC-1: Source and scripts are read-only in every publish container (S11)**
Given each of the six language services started the way `publish-build.sh` and `publish-gate.sh` start them
When a command in the container appends to `/src/.github/workflows/publish-upload.sh` and `publish-lib.sh`, edits `/src/.git/config`, creates `/src/.cargo/config.toml` and `/src/<lang>/new-file`, deletes a tracked file, and changes a file mode
Then every operation fails with a read-only error and the host files are byte-identical (hashes before and after) with no new file.

**AC-2: Only the own artifacts folder is writable, and no other target's**
Given the csharp artifact already built and checked
When a later container (typescript, python, rust or java) writes under its own `/out/artifacts/<lang>` and tries to list or write `/out/artifacts/csharp`
Then its own write appears on the host, `/out/artifacts/csharp` does not exist in its view, a write to `/test-results` lands in a tmpfs (the host `test-results` folder stays empty), and the host csharp artifact has the same SHA-256 after the whole build phase.

**AC-3: Every language still builds the same artifact**
Given the tree copy and the six languages in the plan
When the build phase runs with `PACKBIN_BUILD_ONLY=1` through the real containers
Then the nine targets log `build ok`, and the artifact folders hold exactly the files they held before the change: `csharp/Packbin.<v>.nupkg`, `typescript/packbin-<v>.tgz`, `python/packbin-<v>-py3-none-any.whl` and `python/packbin-<v>.tar.gz`, `rust/packbin-<v>.crate` and `rust/stage/`, `java/maven-bundle.zip`, `vcpkg/reg`, `platformio/packbin-<v>.tar.gz`, `esp-idf/packbin_<v>.tgz`, `arduino/reg` (plus `build.log` and `dry-run`), and `publish-check.py` accepts each. Contents are not compared byte for byte (zips and PE headers vary between runs).

**AC-4: C# packs from a copy**
Given `csharp/` with a stale `bin` and `obj` (as on a developer machine) in the tree copy
When the csharp build runs in the read-only container
Then the nupkg is produced and checked, the tree copy has no new file under `csharp/`, and the stale `bin` and `obj` were not carried into the build.

**AC-5: The golden gate runs under the same mount with the same result**
Given the real tree and the bad-fixture and missing-java copies of `gate_checks` (`publish-gate.test.sh:117-165`), with no `typescript/node_modules`
When `publish-gate.sh` runs the six languages through the containers
Then it prints six `pack` lines equal to the golden bytes with `mismatch 0` and the same plan as before (the bad copy still exits non-zero with an empty plan, the missing-java copy plans five), `npm ci` ran in the container copy, and no file of the tree outside `.github/workflows/out/` changed or appeared.

**AC-6: The host runs only what the checkout holds**
Given a tree copy with a manifest (path and SHA-256 of every file outside `.github/workflows/out/`)
When the gate and a full build-only run (all containers, the host embedded targets, signing) complete
Then the manifest is identical afterwards: no script, source, `.git` file or new `bin`, `obj`, `node_modules` or `target` exists, so nothing a container wrote can be executed by a later host step.

**AC-7: The read-only mount cannot be dropped silently**
Given the merged compose configuration of the two files
When the test reads it for the six services
Then `/src` is a bind with `read_only: true`, `/test-results` is a tmpfs, no other bind of a repo path is writable, both publish scripts start containers only through the shared function (no other `docker compose` call in `.github/workflows/publish-*.sh`), and no workflow sets `PACKBIN_DOCKER`. A temp copy of the shared function with the override file removed makes the AC-1 probe fail.

**AC-8: Ownership and the host path are unchanged**
Given `PACKBIN_HOST_UID` and `PACKBIN_HOST_GID` passed to the container (and, separately, `PACKBIN_DOCKER=0`)
When the build finishes
Then on a Linux runner every file under `artifacts/<lang>` is owned by the host user, the host chown touched nothing outside it, and `chmod -R a+rwX` is not used (static check kept); with `PACKBIN_DOCKER=0` the csharp build still produces its nupkg and leaves no `bin` or `obj` in the tree. On Docker Desktop, where ownership is mapped and not observable, the ownership assertion prints that it cannot be checked there and the CI run is its proof.

## Non-Functional Requirements

**Reliability**
- A read-only error in a build step fails the run before any upload (the container's non-zero exit stops `publish-build.sh` under `set -e`); it is never ignored.
- Local runs prove the mount, the copy and the artifact equality. They do not prove Linux ownership. The `scaffold` job's `publish gate` step on `ubuntu-latest` is the final proof (see Risks).

**Performance**
- Copying `csharp/` (a few hundred KB) and, in the gate, `typescript/` without `node_modules` adds seconds. `npm ci` costs what it cost before. The probe adds six short container starts.

**Compatibility**
- Works with Compose 2.24.3 (the owner's Mac) and 2.38.2 (the runner), and with Docker Desktop and Linux Docker.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-7 | `docker compose -f docker-compose.test.yml -f <override> config --format json` for the six services | `/src` bind `read_only: true`; `/test-results` tmpfs; fixture bind read-only; no writable repo bind |
| AC-7 | scan `.github/workflows/publish-*.sh` for `docker compose`; parse every workflow for `PACKBIN_DOCKER` | one call site (the shared function); no workflow sets it |
| AC-7 | temp copy of the shared function without the override file, then the AC-1 probe | probe fails (the write succeeds); the negative proof is reported |
| AC-8 | existing static checks (`publish-phases.test.sh:193-196`): `PACKBIN_HOST_UID` passed, `chown -R` present, no `chmod -R a+rwX` | pass |
| AC-4, AC-8 | `PACKBIN_DOCKER=0` csharp build on the tree copy (the host path of `registry_checks`) | nupkg built; no `bin`/`obj` under the copy's `csharp/` |

## Blackbox Tests

All in the `scaffold` job through `publish-gate.test.sh`, with real containers, on a copy of the tree like `ph_setup` (`publish-phases.test.sh:90-130`).

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | tree copy; for each of the six services a probe command through the shared function (for the five build languages, the probe replaces `publish-inside.sh` in the copy and runs through `publish-build.sh`) | the write, create, delete, chmod attempts listed in AC-1 | each fails read-only; host hashes unchanged | Reliability |
| AC-2 | csharp artifact present, then a typescript probe | list and write under `/out`, `/test-results` | own folder writable and visible on host; no `/out/artifacts/csharp`; host `test-results` empty; csharp SHA-256 unchanged after the full build | Reliability |
| AC-3 | `ph_setup` tree, plan of six languages | full build-only run | nine `build ok`; the file lists of AC-3 present; checks pass | Compatibility |
| AC-4 | csharp tree copy with `csharp/bin/x`, `csharp/obj/x` added | csharp build | nupkg checked; copy's `csharp/` unchanged | Reliability |
| AC-5 | real tree and `gate_checks` copies, no `node_modules` | `publish-gate.sh` | as AC-5; tree manifest unchanged | Compatibility |
| AC-6 | manifest of the tree copy | gate plus full build-only run | manifest equal | Reliability |
| AC-8 | Linux runner only for ownership | `stat -c %u` on `artifacts/<lang>` files | equals the runner uid; on Docker Desktop the assertion reports "not observable here" | Reliability |

How the AC is proven where: the owner's Mac (Docker Desktop) runs everything except the ownership assertion; the first green `test.yml` `scaffold` job on GitHub after the change proves ownership and the Compose 2.38.2 behavior. No laptop publish and no manual run substitutes for it.

## Constraints

- Canonical path only: the build and the gate stay `publish.yml` → `publish-gate.sh` → `publish-registries.sh` → `publish-build.sh`. No laptop publish and no second way to start these containers (meta-rule: one canonical path).
- No force flags and no workaround flags (`--privileged`, disabling the mount to make a build pass). A build that needs to write the tree is fixed by working from a copy, not by relaxing the mount.
- `bash.md`: `#!/usr/bin/env bash`, `set -euo pipefail`, quoted expansions, `mktemp` plus `trap` for scratch, no `2>/dev/null`, `shellcheck` and `bash -n` on every changed script.
- 500-line soft cap: new assertions go in a new sibling test file; `publish-phases.test.sh` (500) and `publish-gate.test.sh` (447) get a `source` line at most. `publish-build.sh` is 79 lines and `publish-lib.sh` 182.
- `docker-compose.test.yml` stays unchanged; the suites keep their writable tree.
- Build containers still receive no registry credential (`publish-registries.sh:110-118` unsets them); this task adds no variable to the container.

## Risks & Mitigation

**Risk 1: Linux behaves differently from Docker Desktop**
- *Risk*: on Docker Desktop (virtiofs) root writes appear owned by the host user and `chown` does not change the group; on the Ubuntu runner the files stay root-owned and a missing chown makes the host's `publish-sign.sh` and `rm` fail. Loop 14 hit exactly this (`b45335d`: every scenario failed at its first target in CI only). A read-only mount could likewise differ in an edge case (a mountpoint Docker must create, a bind source that does not exist).
- *Mitigation*: the writable folder is created by the host before the container starts; ownership is asserted on Linux; read-only behavior is asserted by a probe that really attempts writes, not by reading the configuration; the first CI run is named as the final proof and nothing is declared done on a green local run alone.

**Risk 2: Compose version differences**
- *Risk*: `run -v` on an already-mounted target is ignored on 2.24.3 and may error or override on 2.38.2.
- *Mitigation*: the read-only mount is in a compose file (spec-defined merge by target), the only `-v` is for a new target, and the probe fails loudly if either behaves differently.

**Risk 3: A build quietly depends on writing the tree**
- *Risk*: typescript, python, rust and java were not run on a read-only mount while writing this spec.
- *Mitigation*: AC-3 and AC-6 run all of them; a failure is an immediate red `scaffold` job and is fixed with a copy, not by loosening the mount.

**Risk 4: Gate scope grows the task**
- *Risk*: the gate needs the same copy treatment for two languages.
- *Mitigation*: the copy is container-local and small; flagged for the owner.

**Risk 5: The probe passes while the real build is unprotected**
- *Mitigation*: the probe runs through the shared function that the real scripts use (AC-7), and the manifest test (AC-6) checks the real full run, not only the probe.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Linux-only semantics (root-owned output, mountpoint creation, Compose 2.38.2) are not reproducible on the Mac; the CI `scaffold` job is the only full proof, as in loop 14 | owner (first CI run decides) | open | Medium |
| Host-side steps still hold write access to earlier artifacts and the scripts: the embedded targets run pip tools on the host (`publish-embedded.sh:126-138`), `publish-sign.sh` writes in `artifacts/java`. The F13 remediation "sha256 of every artifact at check time, verified before upload" and the Rust re-archive of the staged tree (`publish-upload.sh:152-154`, only `Cargo.toml` and the absence of `target/` checked, `publish-check.py:135-138`) are not in this task | owner (follow-up task) | open | Medium |
| The gate containers were not listed in audit F13 but have the same mount and run `npm ci` as root; this spec puts them in scope. If the owner reads the loop wording ("build containers") narrowly, AC-5 and the gate part of AC-6 drop out and AC-L6's last clause stays false for the gate | owner | open | Medium |
| Size: 3 points was tight (a new compose file, a shared invocation function, csharp and two gate copies, two test files, docs). Lesson 2026-10-06: a publish restructure sized by AC count grew to 15 files | orchestrator | resolved: sized at 5 points | Low |
| Containers still run as root with network access and image tags, not digests (F3): a compromised download can still poison its own folder's content before the check | owner | accepted-risk | Low |
| Compose `run -v` on an already-mounted target is silently ignored on 2.24.3; behavior on newer versions was not probed | implementer | resolved (not used; the probe guards it) | Low |
| Someone who adds the override to the test suites breaks them (they write the tree); the override's header comment and the config test are the only guard | owner | accepted-risk | Low |
