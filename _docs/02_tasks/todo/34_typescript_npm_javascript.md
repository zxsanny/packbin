# npm package ships compiled JavaScript and type declarations

**Task**: 34_typescript_npm_javascript
**Name**: npm package as JavaScript + .d.ts
**Description**: The published npm `packbin` contains ES-module JavaScript and `.d.ts` files built from `typescript/src` at publish time, so plain Node, `tsc` projects and bundlers can all import it.
**Complexity**: 3 points
**Dependencies**: None (coordinate with publish tasks 26–28, which edit the same publish scripts)
**Component**: typescript
**Tracker**: pending
**Epic**: AZ-2069

## Problem

`typescript/package.json` sets `"exports": { ".": "./src/index.ts" }` and `"files": ["src", "README.md"]`. The publish path (`.github/workflows/publish-inside.sh:23-29`) copies `typescript/`, removes `node_modules`, sets the version and runs `npm publish` with no build step. So npm `packbin` contains only `.ts` sources that import each other with `.ts` extensions (`index.ts:1-15`).

Who can use that today:
- **Plain Node (any version, including 22.23 and 24): fails.** Node refuses type stripping under `node_modules`. Reproduced on `d108141`: copy `typescript/src` + `package.json` + `@noble/hashes` into a scratch `node_modules/packbin`, then run `import { scheme, u8, BinaryPacker } from "packbin"` → `Error [ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING]: Stripping types is currently unsupported for files under node_modules, for ".../node_modules/packbin/src/index.ts"`.
- **TypeScript consumers using `tsc`** must enable `allowImportingTsExtensions` and must compile a dependency's sources under their own settings.
- **Vite (Vue/React)** works because it transpiles `.ts` from `node_modules`.

`languages.md` and the component description name Node as a consumer ("Vue, React, and Node"). Repo-internal users run from source and are unaffected: the tests (`node --test tests/*.ts`), the CI drivers (`node --experimental-strip-types .github/workflows/drivers/handoff.ts`) and `publish-position.sh`.

## Outcome

- `npm pack` of the package contains `dist/**/*.js` (ES modules) and `dist/**/*.d.ts`, plus `README.md` and `package.json`. It contains no `src/*.ts` and no tests.
- `package.json` `exports` maps `"."` to `{ "types": "./dist/index.d.ts", "import": "./dist/index.js" }`, and `types` points to the same `.d.ts`.
- Plain Node imports the packed tarball and packs the golden row. A strict `tsc` project type-checks against it without `allowImportingTsExtensions`. A Vite build still works.
- `dist/` is produced in the publish path from the tagged commit and is never committed (`.gitignore`).

## Scope

### Included
- A TypeScript build configuration that compiles `src` to `dist` (JS + declarations) with the existing `typescript` dev dependency. Relative `.ts` import specifiers must become `.js` in the output; TS ≥ 5.7 can rewrite them.
- `package.json`: `exports`, `types`, `files`, and a build script.
- The publish path builds before `npm publish`. That means installing dev dependencies in the work copy, because `publish-inside.sh` removes `node_modules` today.
- A consumer smoke check in the TS test suite or publish gate: `npm pack` → install the tarball into a temp project → import it under plain Node and pack the golden row → `tsc --noEmit --strict` a consumer file.
- `.gitignore` entry for `typescript/dist/`.

### Excluded
- CommonJS output (`require`). The package is `"type": "module"`.
- Changing the source layout, tests, or CI drivers (they keep running from `src`).
- Registry policy and publish ordering (tasks 26–28).

## Acceptance Criteria

**AC-1: Node consumer imports the published shape**
Given the tarball from `npm pack` installed into an empty project with no TypeScript
When `node main.mjs` runs `import { scheme, u16, i32, u8, flags, i16, BinaryPacker } from "packbin"` and packs the golden row
Then it prints `4001000065cd1d00a3e1110100` and no `ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING` is raised

**AC-2: tsc consumer type-checks**
Given the same install and a consumer `.ts` file with `strict`, `module: NodeNext`, and no `allowImportingTsExtensions`
When `tsc --noEmit` runs
Then it exits 0, and `BinaryPacker.pack(row)` without a scheme still fails to type-check (the existing compile-fail intent)

**AC-3: tarball contents**
Given `npm pack --dry-run`
When its file list is read
Then it contains `dist/index.js`, `dist/index.d.ts`, `README.md`, `package.json`, and contains no `src/` and no `tests/`

**AC-4: browser safety kept**
Given the built `dist/*.js`
When it is searched for `node:`, `require(`, `Buffer`, `process`
Then there are 0 hits. The only bare import is `@noble/hashes/…`

**AC-5: repo workflows unchanged**
Given the TS test suite, the language-pair drivers and `publish-position.sh`
When they run
Then they still run from `src` and pass, with golden and handoff hex unchanged

**AC-6: publish gate**
Given `.github/workflows/publish-gate.test.sh`
When it runs
Then its npm checks pass: license MIT, README copied, plus the new checks for `dist` contents and `exports`

## Non-Functional Requirements

**Compatibility**
- Node ≥ 22 (current `engines`) can import the package without flags.
- `@noble/hashes` stays the only runtime dependency, pinned `2.4.0`.

**Reliability**
- Publishing from a tag builds `dist` from that tag's sources. A stale or committed `dist` cannot be published.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-3 | `npm pack lists dist and no src` | `npm pack --dry-run --json` | `dist/index.js`, `dist/index.d.ts` present; no `src/` (today: only `src/*.ts`) |
| AC-4 | `built output has no Node-only imports` | grep over `dist` | 0 hits |
| AC-1 | `packed tarball imports under plain node` | temp project + golden row | golden hex (today `ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`) |
| AC-2 | `packed tarball type-checks` | strict consumer | exit 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/golden.hex` | Node consumer of the tarball packs the position row | equals the fixture | project AC-1/3 |
| AC-5 | language-pair handoffs | unchanged runs from source | pass | project AC-3 |
| AC-6 | publish dry run (`publish-gate.test.sh`) | npm job in the gate | builds `dist`, passes | project AC-12 |

## Constraints

- ADR-002: publish only from a version tag in CI; no laptop upload. The build happens inside the publish job.
- Browser-safe output (`src` already is).
- No committed build output (no binaries/dist dumps in git).
- `typescript` stays a dev dependency; no bundler is added.

## Risks & Mitigation

**Risk 1: Publish job lacks dev dependencies**
- *Risk*: `publish-inside.sh` deletes `node_modules` before `npm publish`, so a build step finds no `tsc`.
- *Mitigation*: Build with `npm ci` in the work copy before publish; the publish gate dry run proves it.

**Risk 2: Import specifier rewriting**
- *Risk*: Output `.js` files that still import `./fields.ts` break at runtime.
- *Mitigation*: AC-1 imports the real tarball under plain Node.

**Risk 3: Overlap with publish tasks 26–28**
- *Mitigation*: Land this after or together with them. Edit only the npm branch of the publish scripts.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Changes the npm publish layout (`src` → `dist`, `exports` map). Anyone importing deep paths like `packbin/src/fields.ts` breaks; only `"."` was ever exported | release owner | open | Medium |
| Edits `.github/workflows/publish-inside.sh` and `publish-gate.test.sh`, which tasks 26–28 (writer D) also change | coordinator | open | Medium |
| Earlier npm versions (0.1.x) are unusable from plain Node; consider a note or deprecation once this ships | release owner | open | Low |
