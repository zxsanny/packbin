# Handoff to loop 50

From the loop 49 record (`record49.md`). Nothing here is owner-decided yet.

## Candidates

| Row | Work | Owns |
|-----|------|------|
| Rust no_std core | `_docs/02_tasks/todo/AZ-2749_rust_nostd_core.md`: 5 points, Rust package builds without std and alloc for Cortex-M4F (meshbell); the spec says epic pending and needs the Complexity Budget A/B/C before code | `rust/` (core, features, embedded CI) |
| Compact memo | C++ repeated text that compacts still parses each round; only if real messages repeat long texts | `cpp/src/core/text_encode.hpp` (flash margin 272 B, stack 8 B: arm embedded stage) |
| Retrospective | Last retro `retro_2026-10-20_loop46.md`; due by loop 51 | `_docs/06_metrics` |

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Read after the push

- `test.yml` on `dev` and `main` for the loop 49 push (loop 48: wall about 220 s, longest job `embedded-esp-core` 204 s).

## CI read after the push (loop 49, `4fb2fe6`)

`test.yml` on `dev` (run 39384078387): green. On `main` (run 39384081368): 19 of 20 jobs green, `suites (csharp rust)` FAILED (`suites failed | csharp`; both `dotnet test` steps reported their timing, 37 s and 33 s). The same job on `dev` passed on the same commit. The failing test name is in the job log, which needs a token; the annotations do not name it.

- Likely cause: unknown from annotations. The push changed only a C++ test file, so it is not this loop's code.
- Flaky vs real: looks flaky (same commit green on `dev`), not proven.
- Next canonical action: read the job log (118499654249) with the owner's token, or push again; no queue or manual re-run is invented here.

Retrigger (docs-only push `7ac9268` to `dev` and `main`): `dev` run 39385267962 and `main` run 39385272798 both green, 20 of 20 jobs. The `suites (csharp rust)` failure on `main` run 39384081368 did not repeat; recorded as an unproven flake (the failing test was never read: the job log needs a token and none was given). If it shows again, read the log first.
