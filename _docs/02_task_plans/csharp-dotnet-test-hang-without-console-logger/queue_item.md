---
kind: queue-item
order: 500
source: loop109 record (leftovers: "`dotnet test csharp` without a console logger hung twice (host idle) while the logger run took 11 s")
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# C#: `dotnet test csharp` hangs without a console logger

## Problem
In loop 109 `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` hung twice on an idle host, while the same run with a console logger finished in 11 s. The known hang (MSBuild node reuse, `SchemeTests.CompileFailRequiresScheme`) is already avoided by the variable, so this is another cause. It was not looked into.

## Outcome
The cause is named with evidence, and either fixed or written down as a recipe where the suite is run (`run-suite.sh`, the gotchas).

## Code sections
`csharp/` test project and its child-build tests, `.github/workflows/run-suite.sh` (the `csharp` part), `scripts/loop-tests.sh`, `_docs/AGENT_GOTCHAS.md`.

## Acceptance checks
- The hang is reproduced or shown not to reproduce in at least 10 runs each with and without `--logger "console;verbosity=normal"`, with host load noted.
- If it reproduces: the stuck process and its stack or child are named, and the fix or the recipe is in place; the whole C# suite passes both ways.
- If it does not: the gotcha says so with the run counts.

## Needs
none

## Constraints
No change to what the suite tests.
