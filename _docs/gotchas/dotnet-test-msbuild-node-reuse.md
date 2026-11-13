---
title: "Always run dotnet test csharp with MSBUILDDISABLENODEREUSE=1"
applies_when: "running the C# suite (dotnet test csharp) or writing a C# worker prompt"
source: "loop 18 (hang at 646 of 649), loop 109 (two hangs), loop 115 (AZ-4241, logger probe)"
---

`dotnet test csharp` without `MSBUILDDISABLENODEREUSE=1` hangs forever on this Mac at 646 of 649 tests: `SchemeTests.CompileFailRequiresScheme` starts a child `dotnet build` that deadlocks with MSBuild node reuse (loop 18, a worker lost 15 minutes). Always run `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`, as `run-suite.sh` does; put the variable in every C# worker prompt.

`dotnet test csharp` does not hang without a console logger (loop 115, AZ-4241): 10 runs with `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` and 10 with `--logger "console;verbosity=normal"` added, alternating, host load 10 to 26, all exit 0 with 5,474 tests in 18 to 30 s and 18 to 35 s; the two hangs of loop 109 did not come back (cause unknown; if one does, save `ps` of the tree and `sample <pid> 3` of each dotnet process before killing it). `MSBUILDDISABLENODEREUSE=1` stays required.
