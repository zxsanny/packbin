# Loop 15 — close the three open Medium security findings

Loop: 15 (on `dev`; no worktree, as loops 11 to 14). Owner request 2026-10-06: "Fix F10, F12, F13", with F10 option A (a limit on unpack, not compact rounds, not documentation only).
Source: `_docs/05_security/security_report.md` (F10 carried since loop 13, F12 and F13 new in loop 14), `_docs/loops/loop14/record14.md`, `_docs/loops/loop14/assessment14.md`.

## What

Three independent changes, one epic (AZ-2069):

1. **F10 — unpack of a `repeat` or `times` round has no budget.** Every round creates one slot per name the round can hold (aligned lists in C#, TypeScript and Java, a map per round in Rust). A 1 MiB packet of one-byte rounds costs 0.3 to 1.4 GB of memory (TypeScript 401 MB with a 36-name body, C# 525 MB, Java 570 MB, Rust 311 MB and 1.4 GB with eight flag bits set). Today the only defence is the README sentence "cap the packet length where you read it". The wire format is not involved.
2. **F12 — unpinned code runs in the credentialed publish job.** `actions/checkout@v7`, `actions/setup-node@v7` and `NuGet/login@v1` are moving tags; `twine`, `platformio`, `idf-component-manager`, `build` and `setuptools` are installed with `pip` at whatever version PyPI serves that day; `npm@11` is a moving range. All of them run with the registry tokens in the environment.
3. **F13 — what the build checks is not what the host later uploads.** The six build containers mount the whole repo read-write and run as root. A build step can change `publish-upload.sh` or an already checked artifact of an earlier target, and the host then runs and uploads them with the credentials.

## Who

The package owner (the only publisher) and every service that unpacks packets it did not produce (F10). The CI is the actor in F12 and F13.

## In scope

- F10: a limit on the number of rounds and on the number of slots a single unpack call may create, in the four packages that build per-round slots (C#, TypeScript, Java, Rust); a default that no documented example or existing test reaches; a refusal with the package's existing interim error; the limits are properties of the scheme and a caller can raise them for a scheme that needs more; a hostile case, a generated size test per package, the README sentence and the security docs.
- F12: pin the three actions by commit SHA, pin every pip tool and `npm` to an exact version in one place, and a structure check that fails when a non-local `uses:` is not a 40-hex commit SHA.
- F13: build containers see the repo read-only and write only their own artifacts folder.

## Out of scope

- Compact round representation (option B), changing the wire format or any result shape.
- C++ and Python code: C++ unpacks into caller-owned fixed arrays and already returns `Error::TooMany` (capacity at most 65,535); Python keeps only values it read, so its memory stays flat (33 MB in the audit). Both are recorded in the docs only.
- A distinct error kind for the refusal (C15 stays deferred: the interim error is used, as for every other bad value).
- F14 to F16, F1 to F3 (open Lows), a `tsc` job in `test.yml`.
- The v0.2.2 tag: after the loop, with its own go.

## Decisions made while grasping (the owner can change any of them)

- **D1 — limits live on the scheme, not on the call.** `BinaryPacker.Unpack(bytes, params handlers)` (C#), `unpack(bytes, first, ...rest)` (TypeScript), `unpack(byte[], Handler...)` (Java) and the Rust `On` handler have no room for an extra argument without a breaking overload. The scheme is the object that knows its shape and the caller owns it, so a caller raises the limits where it declares the scheme. Same effect as "per call" for a caller that needs more.
- **D2 — two limits.** `maxRounds`: the most rounds one `repeat` or `times` field may have in one unpack call, default 65,535. `maxSlots`: the most slots (rounds x names the round can hold) all rounds of one unpack call may create together, default 4,194,304 (2^22). Why two: Rust costs about 300 bytes per round whatever the names, so only a rounds limit bounds it; C#, TypeScript and Java cost about 7.5 to 13 bytes per slot, so a slot limit bounds them. At the defaults the worst case is about 30 to 90 MB per call.
- **D3 — the defaults clear every existing use.** The largest use found is `typescript/tests/round-roundtrip.test.ts` (50,000 rounds x 37 names = 1,850,000 slots, under both defaults); the README examples have 2 rounds, the Rust tests at most 300. A packet above the default is refused until the scheme raises the limit.
- **D4 — a refused call is a failed unpack.** Same contract as any bad value: the error is returned (or thrown, as the package already does), the handler is not called, no partial row is visible. The error is the package's interim bad-value error (`ShortPacket` shape with `needed` 0, label of the round field), C15 deferred.
- **D5 — limits are checked when a round starts (lazy), changed 2026-10-06 after the spec pass.** `maxRounds` is checked at the start of each round: the (maxRounds + 1)th round of a `repeat` or `times` is refused, and so is the round that would take the slot total above `maxSlots`. A `times` count field is NOT refused up front. Why: the first draft refused a count above `maxRounds` before any round existed; running that against the code showed it changes today's error for hostile packets and breaks three existing assertions (C# `HostileUnpackTests.Counts.cs` Ac3, Java `HostileUnpackTest.java:157-160`, the TypeScript replay of `oversize_count_times`), while the lazy check bounds memory equally (a round needs at least one byte, and nothing is allocated for rounds that never start). No allocation proportional to the refused size happens before the refusal.
- **D6 — invalid limits are refused at construction** (zero, negative) with the package's construction error; there is no "unlimited" value (a very large number is the way to raise it).
- **D7 — nothing else changes.** Pack, wire bytes, result shapes, session and dispatch behavior, list and dict counts (u16), `bits` and `packed` (bounded by bytes left).

## Acceptance criteria (loop level; the task specs carry the testable Given/When/Then)

- AC-L1: a packet that would create more than `maxRounds` rounds or `maxSlots` slots is refused in C#, TypeScript, Java and Rust, with peak memory bounded by the limits, not by the packet length.
- AC-L2: a packet at or below the limits unpacks exactly as before (all existing tests, rings and the 50,000 x 37 test pass unchanged).
- AC-L3: a scheme can raise or lower the limits; the new values apply to that scheme's unpacks only.
- AC-L4: a hostile case with outcome `too_many` is replayed by C#, TypeScript, Java and Rust (small packet, low limit on the case's scheme); each package also has a generated test with the defaults (a packet of `maxRounds + 1` one-byte rounds is refused, one of `maxRounds` is accepted).
- AC-L5: every non-local `uses:` in `.github/workflows/*.yml` is a 40-hex commit SHA; every pip tool and `npm` of the publish and test scripts has an exact version from one place; a structure check fails on a tag.
- AC-L6: a build container cannot write outside its artifacts folder (a probe write fails), the publish build still produces the same nine artifacts, and the host does not run a script a container could have changed.

## Scenarios walked (new-task Part B, compact)

| id | scenario | status |
|----|----------|--------|
| S1 | 1 MiB of one-byte rounds, default limits, 36-name body | confirmed: refused at round 65,536 (rounds limit) or when slots pass 4,194,304 (whichever first); memory below 100 MB |
| S2 | 50,000 rounds x 37 names (the existing test) | confirmed: accepted |
| S3 | A service that legitimately sends 200,000 rounds | confirmed: refused at default; the scheme raises `maxRounds` |
| S4 | `times` count field says 4,294,967,295 | confirmed: unchanged (a short packet after round 1 today, still; the limit only matters when the packet really holds more than `maxRounds` rounds) |
| S5 | Rust `times` nested in a `repeat` | confirmed: inner rounds count toward `maxSlots` and each inner `times` toward `maxRounds` |
| S6 | Typed row (Rust) with 8 flag bits set, 1 MiB | confirmed: refused by `maxRounds` (about 1.3 KB per round x 65,535 = 85 MB worst case) |
| S7 | Dispatch (several handlers) or a session | confirmed: each handler's own scheme limits apply; a session decrypts first, then the same unpack |
| S8 | Limits of 0 or negative | confirmed: refused at construction |
| S9 | C++ and Python | out-of-scope (documented): C++ `Error::TooMany` capacity, Python flat |
| S10 | Pack side | out-of-scope: pack is bounded by the caller's own data |
| S11 | A build step rewrites `publish-upload.sh` in the container | confirmed (F13): the container cannot, the mount is read-only |
| S12 | A new workflow step uses `actions/foo@v1` | confirmed (F12): the structure check fails the gate test |
| S13 | A pip tool releases a new version | confirmed (F12): nothing changes until the pin is bumped on purpose |

## Fit decisions

- The refusal reuses the interim error because C15 (kind and label) is the owner's open decision; a new public error kind would pre-empt it. The hostile format already has the term `too_many`.
- The limits object is new public surface in four packages; it is the smallest one that works with `params` / rest / varargs signatures (D1). Complexity Budget Check done at the owner's choice of option A (2026-10-06); the API shape is a recorded default.
