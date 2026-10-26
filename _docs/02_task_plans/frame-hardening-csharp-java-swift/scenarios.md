# Scenarios — loop 72, frame hardening

Matrix cap: 12 rows (8 points). Every row `confirmed` (proposed behavior auto-confirmed, new-task Step 4.7 Part C). AC refs point to the task specs.

| id | Scenario | Status | Behavior | AC | Source |
|----|----------|--------|----------|----|--------|
| S1 | An app links the released Swift package and calls `session.derivedKeys(for: .up)` | confirmed | does not compile: the member is `package` | AZ-3256 AC-1 | intake |
| S2 | A .NET app names its assembly `Packbin.Tests` to reach Packbin's internals | confirmed | the internal hooks are reachable, as for any `InternalsVisibleTo` grant (accepted: API hygiene, not a boundary; decision B) | AZ-3254 AC-1 | intake |
| S3 | A jar on the classpath declares `package packbin;` and calls a key hook | confirmed | it can call the package-private hooks, as any split package can (accepted: decision B) | AZ-3255 AC-1 | intake |
| S4 | The test suites still check that `Dispose`, `close` and `deinit` zero the keys | confirmed | the wipe tests pass through the hooks (`internal`, package-private, `package`) | AZ-3254 AC-1, AZ-3255 AC-1, AZ-3256 AC-1 | intake |
| S5 | A stream session pads 1 MiB of payloads | confirmed | same bytes as before; `state` and `work` are zero after each block; the timing tests pass | AZ-3254 AC-2, AZ-3255 AC-2, AZ-3256 AC-2 | intake |
| S6 | 16 threads open frames on 16 Java sessions at once | confirmed | each session counts only its own MACs; no shared static counter | AZ-3255 AC-3 | intake |
| S7 | A replay refusal on a Java session (Duplicate, TooOld) | confirmed | that session's MAC count does not move | AZ-3255 AC-3 | intake |
| S8 | C# `Load` with no direction | confirmed | a session; every `Seal` and `Open` is `BadValue` and writes nothing | AZ-3254 AC-3 | intake |
| S9 | C# `Seal` in place (`plain` inside `output` after `clear`) | confirmed | the E1 body byte for byte | AZ-3254 AC-4 | intake |
| S10 | C# `Seal` with `plain` at `output[0]`, or `ad` inside `output` | confirmed | the same bytes as with separate buffers | AZ-3254 AC-4 | intake |
| S11 | C# `Seal` that fails after the checks (none can today) | confirmed | nothing written to `output`, as before | AZ-3254 AC-4 | intake |
| S12 | All vectors on the changed code | confirmed | 157 frame rows and 27 crypto rows equal in three packages; ring and stream vectors unchanged | AZ-3254 AC-5, AZ-3255 AC-4, AZ-3256 AC-3 | intake |
