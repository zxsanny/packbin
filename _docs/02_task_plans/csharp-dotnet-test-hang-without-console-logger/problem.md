---
loop: 115
branch: dev
tracker: AZ-4241
---
# C#: does `dotnet test csharp` hang without a console logger?

## Problem
In loop 109 `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` hung twice on an idle host, while the same run with `--logger "console;verbosity=normal"` finished in 11 s. The known hang (MSBuild node reuse in `SchemeTests.CompileFailRequiresScheme`) is avoided by the variable, so if the hang is real it has another cause. The project's own runners (`.github/workflows/run-suite.sh` lines 287 and 289) pass `-v n`; `scripts/loop-tests.sh` stage `ac10` passes neither `-v` nor a logger.

## Outcome
The cause is named with evidence and fixed, or written down as a recipe where the suite is run; or the gotcha records that it does not reproduce, with the run counts.

## Code sections
`csharp/` test project (child-build tests), `.github/workflows/run-suite.sh` (`csharp`), `scripts/loop-tests.sh` (`ac10`), `_docs/AGENT_GOTCHAS.md`.

## Acceptance checks
- AC-1: 10 runs each, with and without `--logger "console;verbosity=normal"`, each with a 300 s limit and the host load noted.
- AC-2: if a run hangs, the process tree and the stuck process (a `sample` of it) are saved before it is killed, the cause is named, and the fix or recipe is in place; the whole C# suite then passes both ways.
- AC-3: if no run hangs, `_docs/AGENT_GOTCHAS.md` says so with the counts.

## Needs
none

## Constraints
No change to what the suite tests. Short loop (investigation, ≤2 points, no product code planned).
