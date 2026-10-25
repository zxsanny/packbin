# Security review — frame mode in C#, Java and Swift (loop 71)

Scope: AZ-3232, AZ-3233, AZ-3234 (commits `d99414e`, `a41caf5`). Reviewer: an independent read-only agent given the code and the contract, not the author's conclusions. Method: code read against `pack-session.md` 2.0.0 and ADR 008; no tests run by the reviewer. Verdict: **no Critical, no High**; one Medium (Java), Lows below. Owner decision (2026-10-25, "accept all recommended"): fix items 1 to 4 in loop 71, carry the rest.

## Findings and handling

| # | Severity | Package | Finding | Handling |
|---|----------|---------|---------|----------|
| 1 | Medium | Java | `setPrevious`, `clearPrevious` and `close` wipe a `Keys` object an in-flight `open` may still use (HMAC with a zero key; decrypt with a zero key); the class doc said "open is thread-safe" | **Fixed (docs)**: the three calls must not run beside `seal` or `open`, as in C# and Swift; no new lock (simplicity) |
| 2 | Low | C#, Java | the body was hashed and then read again to decrypt (check-then-use on a buffer that can change) | **Fixed**: one copy of at most 255 bytes, tag and decrypt use the copy (Swift: immutable array, immune) |
| 3 | Low | C#, Java | constant-time compare best effort (`NoOptimization`; a plain loop) | **Fixed**: `CryptographicOperations.FixedTimeEquals` on net10.0 (fold kept for netstandard2.0), `MessageDigest.isEqual` in Java; Swift unchanged (`@inline(never) @_optimize(none)`) |
| 4 | Info | all | docs overstated: "checked in constant time", "wiped on release" (only Swift wipes at deinit), "open is thread-safe" | **Fixed** in README, Java example comment, API docs, component descriptions |
| 5 | Low | C#, Java, Swift | test hooks (`derivedKeys`, `storedKey`, `*ForTest`, `InternalsVisibleTo`) ship in release builds | carried (handoff) |
| 6 | Low | C#, Java | `SessionPad.Block` leaves `state`/`work` unwiped; Java `full` HMAC array not wiped; Swift pad zeroed by a loop the optimizer may drop | carried: shared stream code, outside this loop |
| 7 | Low | Java, C# | a MAC counter on the production path (Java static `AtomicLong`) | carried |
| 8 | Info | C# | `Load` returns null for an empty direction set; Java, Swift and Rust build a session whose every call is `BadValue` | carried |
| 9 | Low (contract) | all | a forged high counter on a captured valid frame moves the window top (permanent `TooOld`); the counter must come from authenticated bytes | by contract; stated in every API doc |
| 10 | Low | C# | `Seal` with `plain` or `clear` overlapping `output` corrupts the message (authenticated, leaks nothing) | carried |

## Verified correct (reviewer, per check)

Order of operations (argument checks, replay check without MAC, tag with current then previous slot, plaintext written only after the tag, window committed only after Ok; a failed open writes nothing and leaves the window) in all three; tag compare over the full tag length without early exit; nonce `msg_id ‖ ((kind<<4)|d) ‖ epoch24`, block counter 0, key info `[d] ‖ "enc"` / `"mac"`, MAC-only key info `0x00 ‖ label`, no collision with the stream session keys, `open` never decrypts before the tag; epoch limit, unsigned counters, window shifts guarded (C#/Java shift-count masking never reached), negative or oversized `clear_len`, offsets and lengths rejected before use; no key or tag in logs, errors or `toString`; use after release is `BadValue`; no deviation from the contract bytes, order or rules (apart from item 8).

## After the fixes

C# 4,305 tests on both targets and Java `test.sh` pass again (`scripts/loop-tests.sh --only csharp,java`: csharp PASS 53 s, java PASS 15 s). The Swift code is unchanged by the fixes.
