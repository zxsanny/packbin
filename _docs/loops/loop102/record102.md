# Autodev loop record - loop 102

loop: 102
branch: dev
plan_artifact: none (measurement loop: no package code changed, so no plan, no implement and no step 11 run)
tasks_shipped: []
decisions:
  - owner (2026-11-11): probe the six other packages for the unreadable colliding-key packet (answer "Yes, probe them" to the loop 101 question)
  - agent defaults: one probe per package with its own toolchain, run by three read-only agents in parallel (C# and Java, Python and Go, Rust and Swift); the two positive results were re-run by the parent; the probe sources are committed under `_docs/02_task_plans/lone-surrogate-key-probe/probes/` so the measurement can be repeated
measurements:
  - C#: pack writes `0102000410efbfbd010410efbfbd02` for two keys that differ only in unpaired surrogates (and for U+FFFD with a lone half); its own unpack refuses it (`ShortPacket(D, 0, 0)`): an unreadable packet
  - Java: pack writes a `?` (0x3F) for each lone half: `01020002103f0102103f02` for two lone halves, which its own unpack refuses; a lone half also merges with a real "?" and a single lone half reads back as "?" (data changed silently)
  - Python: pack refuses a lone surrogate in a key and in a text (`UnicodeEncodeError`, no field named); Go refuses invalid UTF-8 (`pack refused at d: d: the string is not valid UTF-8`); Rust and Swift cannot hold a lone surrogate (a lone half becomes U+FFFD at construction, one key); the heap-free Rust key bytes and the Swift NFC/NFD pair are refused at pack
  - smoke: 8/8 (all six probes re-run from the committed sources); no package file changed in this loop
review: "no code to review; the two positive findings were reproduced by the parent before they were recorded"
retro: none (no implementation, no incident)
leftovers:
  - owner decision: what to change in C# and Java. The project has no written rule for a lone surrogate: TypeScript, Dart and C# write U+FFFD; Java writes "?"; Python and Go refuse the string. Options: (A, recommended) C# refuses two keys that become one at pack, as TypeScript and Dart; Java writes U+FFFD (as the others) and refuses two keys that become one at pack; (B) as A for the collision only, leave Java's "?"; (C) refuse a lone surrogate outright in C# and Java (as Python and Go): a breaking change for callers
  - the same applies to a dictionary as a list or dict element in C# and Java (one code path each, `csharp/Walker.Collections.cs:102`, `java/.../Containers.java:60-84`)
  - owner (before the first tag that contains `dart/`; unchanged): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - the npm package `packbin` 0.4.0 is published without the loop 101 change; the next tag carries it
  - not run here: the vcpkg supports and consumer checks; a physical board; OIDC token lifetime and pub.dev's answer to a re-publish (unproven until the first tag)
  - from loops 98 to 101 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`; the open owner questions of loop 99 kept as built
  - Jira: no ticket this loop (no task); AZ-4168 and AZ-4153 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed at f730c9a; checks in smoke102.md)
smoke_artifact: _docs/loops/loop102/smoke102.md
loop_end_merge: main
