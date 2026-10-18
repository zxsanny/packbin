# Review Lows cleanup — acceptance criteria

- **RL-1.** The C++ host `Makefile` build (Apple clang and `gcc:16`) passes `-Wframe-larger-than=<limit>` with the repository's `-Werror`, with the limit chosen above the largest legitimate frame; a check compiles (not `-fsyntax-only`, the warning needs code generation) a file that declares a `Scratch<65535>` as a local and expects the build to fail, and a file with a static one to pass (mutant: the flag removed makes the check fail). `core.hpp` gains a comment only; the Cortex-M4F flash stays 8,132 B and stack 492 B.
- **RL-2.** `csharp/tests/CompactTextTests.cs` is replaced by files of at most 500 lines each; `dotnet test` reports the same number of compact-text tests, all passing.
- **RL-3.** `bench.py` takes the alphabets and the canonical code construction from `scripts/text/textfmt.py` (its own tokenizer stays: it runs experimental schemes with other prefix and mode widths that `textfmt.parse` cannot express), each research file is at most 500 lines, and a run prints the same table of numbers as before the split.
- **RL-4.** The loop record closes findings 7 and 8 as accepted with the reason; no source file changes for them.
