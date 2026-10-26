# Security review — frame hardening in C#, Java and Swift (loop 72)

Scope: commit `ce0658a` against `dc98688` (`git diff dc98688 ce0658a -- csharp java swift`): AZ-3254, AZ-3255 and AZ-3256, which close items 5, 6, 7, 8 and 10 of `frame_mode_managed_loop71.md`. Reviewer: an independent read-only agent. It got the code and the contract (`pack-session.md` 2.0.0), not the author's conclusions, and ran no builds or tests. Line numbers are at `ce0658a`.

**Verdict: PASS.** No finding of any severity.

## Notes (no failure scenario)

- **Swift `MacKey.tag` with n = 32 (`MacKey.swift:65-67`).** `Array(full[0..<32])` may share `full`'s buffer. The deferred `FrameCrypto.wipe(&full)` makes the buffer unique before zeroing (copy-on-write), so the returned tag is correct. The wipe zeroes a copy, and the only uncleared copy is the tag the caller asked for.
- **Hot-path counters.** Java (`FrameSession.java:316`, `MacKey.java:81`) and C# (`FrameSession.cs:238`) do one atomic increment per MAC, per instance, as intended.

## Checks and evidence

1. **No wire change; no wipe before use.**
   - C# `Seal` builds nonce, clear, ciphertext and tag in the old order, copies the tag, then zeroes `full`, then copies the body to `output` last (115-130).
   - `SessionPad.Block` writes its output before zeroing `state` and `work` (66-70), and `Xor` zeroes `block` after the loop (29).
   - Java `seal` zeroes `tag` after its arraycopy (201-202); `matching` and the `MacKey` methods zero `full` after the copy or compare.
   - Java `hkdfExpand` feeds T(i-1) into the next block before zeroing it (43-55), and `block` writes its output before zeroing (125-130).
   - Swift `seal` wipes `tag` after `replaceSubrange` (185-186); `tagMatches` and `verify` wipe in a `defer` after the compare; `ChaCha20.xor` wipes the pad after the loop (46); `PackSession.wipe` goes through `FrameCrypto.wipe` (224-226).
2. **A refusal writes nothing; a failed open writes no plaintext and leaves the window.**
   - C# refusals return before the `stackalloc` (104-113), and `output` is written once, at 128.
   - Java and Swift check before writing.
   - In all three, `open` writes plaintext only after the tag matches and commits the window last.
3. **The open order is unchanged.** In all three: arguments, then the replay check with no MAC, then the current tag and the previous tag, then decryption, then the commit. Only the insides of `matching` and `tagMatches` changed.
4. **Thread safety.**
   - Java counters are `private final AtomicLong` per instance, and no non-final static is left in `java/src/main`.
   - C# uses `Interlocked` per instance.
   - All temporaries are per call.
   - C# `stackalloc` happens after the ≤ 255 check, in both `Seal` (119) and `Open` (177).
5. **C# `Load` with `None`.**
   - `FrameKeys.Derive` skips directions that were not loaded, and `Enc` and `Mac` are reached only after `CallAllowed`, which needs the direction bit, so every call is `BadValue`.
   - `_previous` is derived with the same directions.
   - `Wipe`, `Arrays` and `KeyArrays` skip null entries.
   - This matches Java (mask 0), Swift and Rust (`check_load` checks only the epoch).
6. **Swift `package`.**
   - All 20 `package` declarations map one to one to the former `@_spi(Vectors) public` ones. No `public` member is left inside a `package` type, nothing was widened, and no `_spi` or `@testable` remains.
   - The publish consumer depends on the package by URL.
   - C# hooks stay `internal` and Java hooks stay package-private (owner decision B).
7. **Other.**
   - C# overlap: every input is read before the single copy into `output`.
   - Swift availability annotations match every caller.
   - No plain zeroing loops are left in the Swift pad, session, frame or MAC code.
