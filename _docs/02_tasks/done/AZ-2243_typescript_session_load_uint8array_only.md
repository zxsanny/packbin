# TypeScript `PackSession.load` returns null for a seed that is not a Uint8Array

**Task**: AZ-2243_typescript_session_load_uint8array_only
**Name**: TypeScript `PackSession.load` takes only a `Uint8Array` seed
**Description**: `PackSession.load(seed)` returns `null`, and throws nothing, for anything that is not a `Uint8Array` (a `Buffer` is one) of exactly 32 bytes, so a string, a plain array, an object with a `length`, another typed array, `null` or `undefined` can no longer open a session or throw `TypeError`.
**Complexity**: 1 point
**Dependencies**: AZ-2231_python_session_load_bytes_only (the Python twin, done); AZ-2103_typescript_npm_javascript (the npm package ships JavaScript, so a caller does not have the types)
**Component**: typescript
**Tracker**: AZ-2243
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment round 2 (`_docs/loops/loop16/assessment16.md`, row X1, gap-clear). The contract says a seed that is not 32 bytes creates no session (`_docs/02_document/contracts/library/pack-session.md:20`: "Load | 32 bytes | a session that is not yet open | length other than 32 creates 0 sessions"). TypeScript `load` (`typescript/src/index.ts`, `PackSession.load`) tests only `seed.length !== 32` and then copies with `Uint8Array.from(seed)`, so anything that has a `length` of 32 opens a session, and `Uint8Array.from` turns it into bytes without an error. Observed on `35544ed` (a `git archive` export, node 22.23, run from the `.ts` source and again from a `tsc -p tsconfig.build.json` build of `dist`: the same results). Every "packs" cell is the first packet of a one-`u8` scheme `scheme(1, u8(0, r => r.a))` with `{a: 0}`, session opened with `start` and the nonce `01` x 16:

| `PackSession.load(...)` | Today | `load(new Uint8Array(32))` packs the same |
|--------------------------|-------|------------------------------------------|
| `"a".repeat(32)` | a session; packs `5781` | yes: the key is 32 zero bytes (every letter became 0) |
| `"0123456789abcdef0123456789abcdef"` (a 32-character env text) | a session; packs `d31a` | no: the key is its digits with every letter turned to 0 |
| `{length: 32}` | a session; packs `5781` | yes (zero key) |
| `new Array(32).fill("x")` | a session; packs `5781` | yes (zero key) |
| `new Array(32).fill(7)` | a session; packs `5e43` | same as `new Uint8Array(32).fill(7)` |
| `new Uint16Array(32).fill(0x0107)` | a session; packs `5e43` | the key is 32 bytes of `07` (the high byte is cut off) |
| `new Int8Array(32)`, `new Uint8ClampedArray(32)` | a session; packs `5781` | not a `Uint8Array`, still a session |
| `32`, `true`, `new ArrayBuffer(32)`, `new SharedArrayBuffer(32)`, `new DataView(new ArrayBuffer(32))`, `new Uint32Array(8)` | `null` | (these have no `length` of 32) |
| `null` | throws `TypeError: Cannot read properties of null (reading 'length')` | |
| `undefined` | throws `TypeError: Cannot read properties of undefined (reading 'length')` | |
| `new Proxy(new Uint8Array(32), {})` | throws `TypeError: Method get TypedArray.prototype.length called on incompatible receiver [object Uint8Array]` | |
| `{get length() { throw new Error("boom") }}` | throws `Error: boom` (the caller's own getter runs) | |
| `new Uint8Array(31)`, `new Uint8Array(33)`, `new Uint8Array(0)`, a detached `Uint8Array(32)` | `null` | |
| `Uint8Array` 1..32, `Buffer` of the same bytes, `Buffer.alloc(32)`, a 32-byte `subarray` of a 64-byte array, a `Uint8Array` subclass, a `Uint8Array` over a `SharedArrayBuffer(32)` | a session (1..32 packs `d9bc`, zero packs `5781`) | |
| a `Uint8Array(32)` made in another realm (`vm.runInNewContext("new Uint8Array(32)")`, `instanceof Uint8Array` is `false`, `ArrayBuffer.isView` is `true`) | a session; packs `5781` | |

A caller that passes a text, a plain array or the wrong typed array gets a session whose key is derived from the length or from the low bytes of the items, and the other side, loaded with the real bytes, cannot read it; a caller that passes `null` gets a `TypeError` that names `length`. The npm package ships JavaScript (AZ-2103), so untyped callers are first-class and the `Uint8Array` annotation does not stop them. Java `load(null)` and Python `load` since AZ-2231 return no session.

**What `start`, `join` and the constructor do for the same bad values** (run on the same export; the session was loaded with `Uint8Array` 1..32; "stays closed" = a later `start(new Uint8Array(16).fill(1))` or `join(...)` on the same session still opens):

| Call | Today |
|------|-------|
| `start("a".repeat(16))`, `start({length: 16})`, `start(new Array(16).fill(1))`, `start(new Uint16Array(16).fill(0x0101))` | throws `TypeError: "key" expected Uint8Array, got type=string` (`type=object` for the other three), from the hash library; nothing opens, the session stays closed |
| `start(new ArrayBuffer(16))`, `start(16)`, `start(new Uint8Array(15))` | `null`, the session stays closed |
| `start(null)` | throws `TypeError: Cannot read properties of null (reading 'length')` |
| `start(undefined)` | not a bad value: it is the form that draws 16 random bytes and returns them |
| `join(...)` of the same values | the same throws; `join(new ArrayBuffer(16))`, `join(16)`, `join(new Uint8Array(15))` return `false`; `join(null)` and `join(undefined)` throw `Cannot read properties of ... (reading 'length')` |
| `new PackSession(...)` from plain JavaScript (the constructor is `private` only in the `.d.ts`: `private constructor();`) | builds from anything: `new PackSession(new Uint8Array(5))` is a session keyed by 5 bytes (packs `39ea`), `new PackSession(null)` builds a session that `start` never opens (`null`), a string, a number, a plain array, `{length: 32}` and `undefined` build and then throw `TypeError: expected Uint8Array, got type=...` at `start` |

So `start` and `join` do not have the hole: a value that is not a `Uint8Array` never opens a session, it throws (the hash library's type check) or returns `null` / `false`. They are not changed (the mix of `TypeError` and `null` is the existing label, decision C15). The constructor does have a hole of the same kind as the Python one (AZ-2231 Excluded: `PackSession([7] * 32)`): it checks neither type nor length. It is reachable only by a caller that bypasses the types, and it is reported, not changed.

## Outcome

- `PackSession.load(seed)` returns a session only when `seed` is a `Uint8Array` (a `Buffer`, any subclass, a view over a `SharedArrayBuffer`, and a `Uint8Array` made in another realm are all one) of exactly 32 bytes.
- For anything else it returns `null`. It never throws for the type or the shape of its argument: `null`, `undefined`, a `Proxy` and an object with a throwing `length` return `null` (today they throw).
- The test is the brand, not `instanceof`: `ArrayBuffer.isView(seed) && Object.prototype.toString.call(seed) === "[object Uint8Array]"`, then the length. A `Uint8Array` from another realm (a `node:vm` context, a Jest environment, an iframe) is not `instanceof Uint8Array` of the package's realm, and it opens a session today; an `instanceof` test would turn it into a silent `null`. The other checks in the package use `instanceof Uint8Array` (`index.ts`, `pack-fields.ts`, `kinds.ts`) but there a miss falls through to copying, not to a refusal. The expression above gives the results in the table of AC-1 to AC-5 (probed on a scratch copy, see Constraints); the worker may write it differently if the results are the same.
- The signature `static load(seed: Uint8Array): PackSession | null`, `start`, `join`, `pack`, `unpack`, the constructor, the session bytes and the session vector `b55d0a29c56c203712b241232e` are unchanged.

## Scope

### Included
- The type check in `PackSession.load` (`typescript/src/index.ts`; the file is 234 lines).
- Tests for the probes below.
- The text that says the old behaviour (the docs pass): README, `_docs/02_document/components/02_typescript_package/description.md` (§3 `PackSession` table row for `load`, the known limitation on the constructor) and its `tests.md` (Loop 16 table). Exact sentences under Constraints.

### Excluded
- `start` and `join`: they do not have the hole (table above); their throws and `null` / `false` results stay as they are.
- The constructor `PackSession(seed)`: it is `private` in the types; reachable from plain JavaScript, where it checks neither type nor length. It is reported (a decision for the owner, as AZ-2231 left the Python constructor), not changed here.
- Other buffer-like values (`ArrayBuffer`, `DataView`, `Int8Array`, `Uint8ClampedArray`, `Uint16Array`, a Node `Buffer` is a `Uint8Array` and stays): they now return `null`; a caller converts with `new Uint8Array(buffer)` or `Uint8Array.from(items)`.
- The contract line `pack-session.md:20`: a value that is not bytes has no length of 32 bytes, so the line already says it; no edit.
- Changing the `.d.ts` parameter type (it stays `Uint8Array`; untyped callers are covered at run time).

## Acceptance Criteria

**AC-1: A text, a plain list or an object with a length is not a seed**
Given `"a".repeat(32)`, `"0123456789abcdef0123456789abcdef"`, `{length: 32}`, `new Array(32).fill("x")` and `new Array(32).fill(7)`
When each is passed to `PackSession.load`
Then each returns `null` and throws nothing (today each returns a session, packing `5781`, `d31a`, `5781`, `5781` and `5e43`).

**AC-2: Another typed array is not a seed**
Given `new Uint16Array(32).fill(0x0107)`, `new Int8Array(32)`, `new Uint8ClampedArray(32)`, `new Uint32Array(8)`, `new DataView(new ArrayBuffer(32))`, `new ArrayBuffer(32)` and `new SharedArrayBuffer(32)`
When each is passed to `PackSession.load`
Then each returns `null` (today the first three return a session, packing `5e43`, `5781`, `5781`; the others already return `null`).

**AC-3: Values that threw return null and throw nothing**
Given `null`, `undefined`, `32`, `true`, `new Proxy(new Uint8Array(32), {})`, `Object.create(Uint8Array.prototype)` and `{get length() { throw new Error("boom") }}`
When each is passed to `PackSession.load`
Then each returns `null` and the getter is never run (today `null`, `undefined`, the proxy, the prototype object and the getter throw `TypeError` or `Error`; `32` and `true` already return `null`).

**AC-4: A Uint8Array of 32 bytes still opens a session**
Given `Uint8Array.from({length: 32}, (_, i) => i + 1)`, a `Buffer` of the same bytes, `Buffer.alloc(32)`, `new Uint8Array(64).subarray(8, 40)`, `new (class extends Uint8Array {})(32)`, `new Uint8Array(new SharedArrayBuffer(32))` and a `Uint8Array(32)` made by `vm.runInNewContext`
When each is passed to `PackSession.load`, and the session is started with the nonce `01` repeated 16 times for the one-`u8` packets and with the nonce `01000000000000000000000000000000` for the position row
Then each returns a session, as today; the first packs `{a: 0}` of the one-`u8` scheme `scheme(1, u8(0, r => r.a))` as `d9bc`, the zero-keyed ones as `5781`, and the opener packs the position row to `b55d0a29c56c203712b241232e` (the C# vector; `session.test.ts` AC-1; the language-pair `pack-session` hand-off `handoff.ts` prints the same hex).

**AC-5: Wrong sizes still return null**
Given `new Uint8Array(31)`, `new Uint8Array(33)`, `new Uint8Array(0)` and a detached `Uint8Array(32)` (`structuredClone(a.buffer, {transfer: [a.buffer]})`)
When each is passed to `PackSession.load`
Then each returns `null`, as today.

**AC-6: `start` and `join` keep their results**
Given a session from `PackSession.load(Uint8Array 1..32)`
When `start("a".repeat(16))`, `start(null)`, `start(new ArrayBuffer(16))`, `start(new Uint8Array(15))`, `join({length: 16})`, `join(new Uint8Array(15))` and `join(null)` are called, each on a fresh session
Then they throw `TypeError: "key" expected Uint8Array, got type=string`, throw `TypeError: Cannot read properties of null (reading 'length')`, return `null`, return `null`, throw `TypeError: "key" expected Uint8Array, got type=object`, return `false`, throw the `null` `TypeError`, and after each of them `start(new Uint8Array(16).fill(1))` still returns the nonce (the session stayed closed), as today.

## Non-Functional Requirements

**Compatibility**
- No wire change. A caller that passed a `Uint8Array` or `Buffer` of 32 bytes gets the same session and the same bytes; a caller that passed anything else now gets `null`. The position vector, the language-pair `session` hand-offs (`.github/workflows/drivers/handoff.ts` passes `Uint8Array.from({length: 32}, ...)`) and the 463 existing TypeScript tests are unchanged.

**Security**
- A seed that is not bytes can no longer produce a session whose key is derived from the length of a text or from the low byte of each item, and a caller that does not check for `null` fails at the first `start`, not by sending traffic under a key anyone can derive.

**Reliability**
- `load` does not run caller code: no getter, no `Symbol.toPrimitive`, no proxy trap (the brand check reads no property of a value that is not a typed array).

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | the five text, list and object seeds | `null`, no throw | `typescript/tests/session.test.ts` |
| AC-2 | the seven typed-array and buffer values | `null` | `typescript/tests/session.test.ts` |
| AC-3 | `null`, `undefined`, `32`, `true`, a proxy, a prototype object, a throwing `length` getter | `null`, the getter not called | `typescript/tests/session.test.ts` |
| AC-4 | the seven `Uint8Array` shapes | a session each; the seed 1..32 packs the vector (extends `AC-1 opener pack matches C# ciphertext`, which is unchanged); the cross-realm one through `node:vm` | `typescript/tests/session.test.ts` |
| AC-5 | the four wrong sizes | `null` (extends `AC-4 bad lengths create nothing`) | `typescript/tests/session.test.ts` |
| AC-6 | the seven `start` / `join` calls | the results above; the session stays closed | `typescript/tests/session.test.ts` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | language-pair `session` hand-offs, TypeScript as opener and waiter (`.github/workflows/drivers/handoff.ts` `pack-session`, `unpack-session`) | unchanged run | `b55d0a29c56c203712b241232e`, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: TypeScript only; no cross-package import. The Python rule (`isinstance` of three types) is the intent, not code to copy.
- Browser-safe `src`: the check uses only `ArrayBuffer.isView` and `Object.prototype.toString`, no `Buffer` and no Node import.
- Files at or under 500 lines (`index.ts` is 234, `session.test.ts` 126).
- Error kind and label of existing errors unchanged (decision C15): `start`, `join` and `pack` keep their errors; `load` adds no error, it returns `null`.
- No new dependency; no `.d.ts` change.
- Probe results above come from a `git archive` export of `35544ed` (scratch `specs3-spec1/`). The target results of AC-1 to AC-5 come from a throwaway patch of `load` on a scratch copy (`if (!isUint8Array(seed) || seed.length !== 32) return null`, with `isUint8Array(v) = ArrayBuffer.isView(v) && Object.prototype.toString.call(v) === "[object Uint8Array]"`): every row of the table above gave the "after" result, the cross-realm `Uint8Array` still opened a session, a plain object with `Symbol.toStringTag: "Uint8Array"` and a `Uint8Array` with its own `toStringTag` `"X"` returned `null`, the 463 TypeScript tests passed and `tsc --noEmit` on the build config was clean. The worker re-derives them from a real run.
- Docs pass (exact sentences proposed; the worker may reword, not drop the facts):
  - README, the upgrade paragraphs at the end of `## Untrusted input` (a new paragraph after "TypeScript packaging changed"): "TypeScript `PackSession.load` returns `null` for anything that is not a `Uint8Array` or `Buffer` of 32 bytes. A string, a plain array, an object with a `length` of 32, a `Uint16Array`, an `Int8Array` or a `Uint8ClampedArray` used to open a session keyed by zeros or by the low byte of each item (`PackSession.load("a".repeat(32))` was keyed by 32 zero bytes), and `null` or `undefined` threw `TypeError`. In calling code, convert the seed first: `Uint8Array.from(items)`, `new Uint8Array(arrayBuffer)`, `Buffer.from(hex, "hex")`."
  - `description.md` §3 `PackSession` table, `load` row: input "a `Uint8Array` or `Buffer` of 32 bytes", error types "anything that is not a `Uint8Array`, or a length other than 32, creates 0 sessions and throws nothing". New known limitation: "The `PackSession` constructor is `private` in the types but plain JavaScript can call it: it checks neither the type nor the length of the seed (`new PackSession(new Uint8Array(5))` opens a session keyed by 5 bytes). Use `PackSession.load`; the constructor check is open for the owner (AZ-2243)."
  - `tests.md`, Loop 16 table, a row: "`AZ-2243 PackSession.load takes only a Uint8Array` | a string, a plain array, an object with a length of 32, another typed array, `null`, `undefined`, a proxy and a throwing getter return `null`; a `Uint8Array`, `Buffer`, subclass, subarray, shared-memory view and cross-realm `Uint8Array` of 32 bytes open a session and the vector `b55d0a29c56c203712b241232e` is unchanged; `start` and `join` keep their results | `typescript/tests/session.test.ts`". Add AZ-2243 to the section title list.
  - `pack-session.md` and the other components: no edit.
- Differential: against HEAD, every call with a `Uint8Array` (any subclass, view or realm) or `Buffer` of 32 bytes opens a session with the same key, so the same `start`, `join`, `pack` and `unpack` bytes; every `Uint8Array` of another length returns `null` as before; `start`, `join`, `pack`, `unpack` and clear `BinaryPacker.pack` / `unpack` are byte-identical for every scheme (the change is one guard in `load`). The rows that change are exactly the "Today" rows above that are not `null`.

## Risks & Mitigation

**Risk 1: Callers that passed a text, a plain array or another typed array**
- *Risk*: a caller that passed `Buffer.from(hex)` as a string, an `Array` of 32 integers, a `Uint16Array`, an `Int8Array` or an `ArrayBuffer` opened a session before (the first three) or got `null` (the last); now all of them get `null`.
- *Mitigation*: `Uint8Array.from(...)` restores the plain array, `new Uint8Array(buffer)` the `ArrayBuffer`. The README upgrade note names them. The first parameter type is already `Uint8Array`, so a TypeScript caller was never allowed to pass them.

**Risk 2: `null` hides a type mistake that threw before**
- *Risk*: `load(null)` and `load(undefined)` threw `TypeError` and now give `null`, which a caller may not check (`PackSession.load(seed)!` in the README example then fails later at `start`).
- *Mitigation*: it is the existing "bad seed gives no session" rule and the contract's failure column; the owner chose `null` over raising for Python (AZ-2231, Q2 A) and this twin follows it.

**Risk 3: A `Uint8Array` the brand test refuses**
- *Risk*: a `Uint8Array` whose own `Symbol.toStringTag` was overridden returns `null`; the brand test also depends on `Object.prototype.toString`, which a host can patch.
- *Mitigation*: both need deliberate tampering. If the owner prefers the repo's usual `instanceof Uint8Array`, it is a one-line change that makes a cross-realm `Uint8Array` (Jest environments, `node:vm`, iframes) return `null`; the ticket does not say which, so the worker keeps the brand test unless told otherwise.

## Owner decision (2026-10-06)

Assessment round 2 routed this as gap-clear; the quoted contract lines are the basis; no owner question. Basis: "Load | 32 bytes | a session that is not yet open | length other than 32 creates 0 sessions" (`_docs/02_document/contracts/library/pack-session.md:20`) and "For anything else it returns `None`. It never raises for the type of its argument" (AZ-2231 Outcome, owner answer A to Q2).

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3). `PackSession.load` returns `null`, and throws nothing, for anything that is not a `Uint8Array` of exactly 32 bytes (a `Buffer`, a subclass, a shared-memory view and a `Uint8Array` made in another realm all count). `typescript/src/index.ts` (+7/-1, 240 lines): a module-level `isUint8Array(v)` (`ArrayBuffer.isView(v) && Object.prototype.toString.call(v) === "[object Uint8Array]"`, a brand and not `instanceof`, so a cross-realm array from `node:vm` or Jest still opens a session; `isView` runs first, so no caller code runs) and `load` is `if (!isUint8Array(seed) || seed.length !== PackSession.SeedSize) return null`. Signature, constructor, `start`, `join`, `pack`, `unpack` and the `.d.ts` are unchanged. A string, a plain array, `{length: 32}`, a `Uint16Array`, an `Int8Array` or a `Uint8ClampedArray` used to open a session keyed by zeros or by the low bytes (`5781`, `5e43`), and `null`, `undefined`, a Proxy and a throwing `length` getter threw. No wire change for a `Uint8Array` or `Buffer` seed.

Tests (`typescript/tests/session.test.ts`, +178 lines, 304 total; `describe "session load takes only a Uint8Array (AZ-2243)"`, 7 tests; the TypeScript suite is 470, 463 before): AC-1 `a text, a plain list or an object with a length is not a seed`; AC-2 `another typed array or buffer is not a seed` (seven values); AC-3 `a value that threw returns null and runs no caller code` (a counter stays 0, so no getter or trap ran); AC-4 `a Uint8Array of 32 bytes still opens a session` (seven shapes, `vm.runInNewContext` included, `instanceof` is `false` for it) and `a subarray, a Buffer and an other-realm seed pack the position vector` (`b55d0a29c56c203712b241232e`); AC-5 `a wrong size still returns null` (31, 33, 0, a detached 32-byte buffer); AC-6 `start and join keep their results`. AC-1 to AC-3 failed on the HEAD export; AC-4 to AC-6 pass both ways, as the spec says. Strict `tsc` and `tsc -p tsconfig.build.json` exit 0; a build to a scratch `outDir` gives the same results; the other 462 tests are untouched.

Evidence: a differential of 34 probes between the HEAD export and the working tree (19 identical, the 15 changed are exactly the rows of the Problem table that were not `null`, plus the throws); 3,000 random seeds in three shapes (`Uint8Array`, `Buffer`, a view over a `Buffer`'s `ArrayBuffer`): 9,000 compared, 0 differences in `start`, `pack` (one-`u8` and position schemes) and the second pack; base opener against new waiter and the reverse, 3,000 runs, 0 differences; 3,000 random wrong lengths are `null` before and after. Re-run for the docs pass: the probes of the README paragraph give the stated results on the working tree.

Review (PASS, no findings): the brand test deviates only for deliberate `Symbol.toStringTag` tampering: a real 32-byte `Uint8Array` with its own `toStringTag` set to something else now returns `null` (it opened a session before; no AC pins it). A tamper-proof brand is the `%TypedArray%.prototype[@@toStringTag]` getter called on the value: optional hardening, the owner's call (Risk 3).

Discoveries: the AC-4 sentence of this spec mixed the two nonces (`d9bc` and `5781` come from `01` repeated 16 times, the position vector from `0100...00`; with `0100...00` the one-`u8` packets are `f45c` and `46be`): corrected in the spec after the worker re-derived all four hexes. `load(null)` and `load(undefined)` return `null` now (Risk 2), so the README example `PackSession.load(seed)!` fails at the first `start`; covered by the upgrade note. Open, owner (Excluded, reported only): the constructor accepts a 5-byte key (`new PackSession(new Uint8Array(5))` packs `39ea`), `new PackSession(null)` builds a session that `start` never opens, a string, number, plain array or `{length: 32}` builds one that throws `TypeError: expected Uint8Array` at `start`; `start` and `join` throw for a nonce that is not a `Uint8Array` (V8 and node 22 wording) and are pinned by AC-6. Docs: README patch, TypeScript description and `tests.md`, `contracts/library/pack-session.md`.
