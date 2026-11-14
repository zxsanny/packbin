# Feature assessment — loop 126 (AZ-4294 to AZ-4303, scheme depth limit)

verdict: COMPLETE
assess_round: 0

Intent (owner D18, "Shared limit (256)"): every package refuses, when the scheme is built, a nesting depth above 256, with its own scheme error and one shared text; 256 levels still work; the loop 125 probe shows no raw error, crash or hang.

| intent angle | spec / source | covered by | status |
|--------------|---------------|-----------|--------|
| 257 levels refused at build, nine packages | AC-1 of each task, contract | per-package depth tests; probe 60 lines all `refused` | covered |
| one shared text | contract | whole-text comparisons in every package | covered |
| 256 levels build, pack, unpack with the same bytes | AC-2 | per-kind tests; `pack_depth_*_256` hostile cases | covered, with the debug small-thread exception (D19) |
| no stack error / crash / hang at 1,000 to 50,000 | AC-4 | `scripts/probes/scheme-depth/run.sh`: 60 refused, 64 s | covered |
| shared cases | AZ-4294 | four cases in `fixtures/hostile`, replayed by nine loaders | covered |
| device pins hold or are reported | Rust, C++ tasks | C++ unchanged; Rust +168 B flash, +16 B stack, re-pinned and documented | covered |
| Python at 256 | flagged concern | worst kind 397 levels at the default recursion limit | covered |
| angle found while implementing: debug builds on small threads (Rust map API about 3 MiB, Swift 640 KiB) | — | D19 (applied: keep 256), gotcha, hygiene item | covered |
| angle found by the review: Dart counted a flag bit; DAG re-walk; C# typed element row count | — | Dart fixed; rest in `hygiene.md` | covered |

Gap-clear: none. Gap-unclear: none.
