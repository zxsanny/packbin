# Batch 1 report — loop 26

Tasks: AZ-2513 (Swift core, 5 points). Worker: general-purpose, 41 minutes. No per-batch review (owner preference; the one total review runs before step 11).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2513 | Done | 8 of 8 ACs pass: 48 tests in 11 suites; strict release build (`-warnings-as-errors`, `-strict-concurrency=complete`) 0 warnings; thread sanitizer 0 reports (worker: 48 passed, TSan confirmed to fire on a planted race); AC-7 typed 0.37 s / map 0.19 s alone in release; 22 of 22 mutation proofs red. Parent re-ran the strict release build and the 48 tests: pass. |

CI-parity: no Swift CI exists yet (AZ-2521 adds it); the same commands the suite will run were run locally: `swift build -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` and `swift test` (flags in `AGENT_GOTCHAS.md`). Linux `swift:6` not run (AZ-2521).

## Public API fixed (later tasks extend, never rename)

`Scheme(_:_ fields...) throws`, `Field` constructors (`.u8`..`.i64`, `.f32/.f64`, `.bytes(size:)`, `.bool`, `.be`, `.flags`, `.flagByte`, `.when`, `.bind(get:set:)`), `FlagByte`, `Condition.eq`, `PackbinRow`, `pack` (typed and `[String: Any]`), `unpack`/`unpackMap` (variadic and array), `PackbinError{kind, field, name, needed, left, actual, reason}` with kinds `.short`(`short_packet`), `.trailing`(`trailing_bytes`), `.unknownType`(`type_mismatch`), `.badValue`, `.tooMany`, `.schemeError`, `.packError`. Internals: immutable `Node` with `with(...)`, name-keyed map walker, `Node.referenced` marks names a `when` reads, `ForeignNumber.swift` handles `NSNumber`, `FlagBits.swift`. Docs: `swift/Sources/Packbin/Packbin.docc/Packbin.md`.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | clear/unclear |
|---|----------|---------|-------------------|---------------|
| 1 | AC-8 / Constraints | Hostile terms are `short_packet`, `trailing_bytes`, `type_mismatch` (README), not `unknown_type` | raw values follow the README | clear |
| 2 | scheme checks | TypeScript builds `bytes(-1)`; Swift refuses it at construction (as Go) | keep; list as a documented difference in AZ-2514/AZ-2520 | clear |
| 3 | owner rulings | Swift refuses `2.0` for an integer and `1` for a bool bit (Go-1 B, Go-2 A) where TypeScript accepts | already ruled; noted for the parity task | clear |
| 4 | AZ-2521 | tests need swift-testing, so the `swift:5.9` step is library-only | written into AZ-2521 Constraints | clear |
| 5 | local recipe | `swift test` needs `-F`/rpath flags on this Mac | `AGENT_GOTCHAS.md` | clear |
| 6 | NSNumber on Linux | Bool/integer split verified on macOS only | first `swift:6` run in AZ-2521 decides | unclear |
| 7 | AC-7 margin | typed 0.53 s inside the parallel run; Linux runner may near 1 s | own `SpeedTests` step in AZ-2521; fallback: fill typed rows from the accessors | unclear |
