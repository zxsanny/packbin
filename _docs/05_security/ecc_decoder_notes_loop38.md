# Message ECC decoders: notes for the audit (loop 38, AZ-2690)

**This is not an audit, and nothing was audited yet.** The `/security` audit (AZ-2666) is run by the owner. This file only states what the new decoders read, the bounds the contract sets for them, and what the audit should check. No finding below is a result.

## What is new

Seven packages (Python, TypeScript, C#, Java, Rust, Go, Swift) have a decoder for a protected message: `repair` in `python/src/packbin/_ecc.py`, `typescript/src/ecc.ts`, `csharp/EccRepair.cs`, `java/src/main/java/packbin/EccRepair.java`, `rust/src/ecc.rs`, `go/ecc_repair.go`, `swift/Sources/Packbin/Ecc.swift`. C++ is pending (AZ-2688) and is not covered. The decoder runs before the type byte picks a handler, so it reads bytes nobody has checked yet. A session payload goes through it before the pad is removed.

## Bounds the contract sets (`contracts/library/message-ecc.md`, "Hostile bytes")

| Bound | Value |
|-------|-------|
| Input length | at most 254 bytes; longer is refused (`too_long`) before any arithmetic |
| Input shorter than `n` | refused (a short-packet error naming `parity`) before any arithmetic |
| Work | at most 255 x 32 field operations, plus the unprotected walk |
| Allocation | nothing proportional to `n` beyond a few arrays of `n + 1` bytes |
| Failure | never throws or traps on hostile bytes; the caller's mistakes (`n` above 32, a correction limit above `n / 2`, a mix of parity counts) are refused before any byte is read |
| Repair | verified: after the values are XORed in, all `n` syndromes are recomputed and any nonzero one is uncorrectable |
| Locator | its degree must be between 1 and `t`, and the number of roots in 0 to `N - 1` must equal the degree; a zero derivative is uncorrectable |

The audit should confirm that the input buffer is not written in these seven packages (TypeScript and Go state it).

## What the audit should check

1. Every index into the received bytes and the polynomial arrays stays inside the arrays for `N` = `n` to 254 and `n` = 1 to 32, in the Swift and Rust paths where an overflow traps or panics.
2. The GF(256) tables are indexed by values below 256 (the log of 0 is never taken; the inverse of 0 is never taken; the `% 255` on exponents).
3. The error positions come from the roots found, not from the locator degree, and a position outside 0 to `N - 1` cannot be written.
4. A repaired message that passes the syndrome check can still be a different valid message when the corruption is larger than `n - t` bytes. This is the documented trade-off (risk R06), not a bug: the contract lists the chances.
5. No parity count above 32, no limit above `n / 2` and no mix of counts reaches the decoder.
6. Session: a refused payload advances the receive index the same way in every package, so a hostile payload cannot desynchronize the session more than an unprotected one can.

## Not covered by the code

- Parity is not authentication: anyone can compute valid parity for a forged message. The session adds no tag either (ADR-007, out of scope).
- Timing: the repair path is not constant time; the bytes it reads are not secrets in the clear case, and in a session they are padded bytes.

Nothing here has been run as a fuzz or audit result. The speed bound EC-13 is an acceptance criterion, not a measurement recorded here.
