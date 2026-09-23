# Feature assessment — loop 2

loop: 2
feature: strings-lists-dicts
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-09-23
**Implement pass**: batches 01..04
**Verdict**: COMPLETE — 14 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Empty string, list, and dictionary | covered | AZ-1940 AC-4; `csharp/tests/PackbinTests.cs` `CountedDict`; `csharp/Walker.Counted.cs` | intake |
| S2 | User value packed twice | covered | AZ-1940 AC-1; `CountedDict`; `csharp/Walker.Counted.cs` | intake |
| S3 | Two callers pack the user value at once | covered | AZ-1940 AC-1; `CountedDict` two threads; `csharp/Walker.Counted.cs` | intake |
| S4 | String count 7 with 2 bytes left | covered | AZ-1938 AC-4; `Utf8String`; `csharp/Walker.Counted.cs` | intake |
| S5 | String of 65536 UTF-8 bytes | covered | AZ-1938 AC-3; `Utf8String`; `csharp/Walker.Counted.cs` | intake |
| S6 | Duplicate dictionary key | covered | AZ-1940 AC-5; `CountedDict`; `csharp/Walker.Counted.cs` | intake |
| S7 | Position record | covered | AZ-1941 AC-3; `.github/workflows/language-pair.sh`; `csharp/Walker.cs` | intake |
| S8 | Access keys inserted out of order | covered | AZ-1940 AC-2; `CountedDict`; `csharp/Walker.Counted.cs` | intake |
| S9 | Counted list then another field | covered | AZ-1939 AC-3; `CountedList`; `csharp/Walker.Counted.cs` | intake |
| S10 | Six languages pack the user value | covered | AZ-1940 AC-1; `language-pair.sh` user handoffs; each language `pack` | intake |
| S11 | List of one big-endian u16 | covered | AZ-1939 AC-2; `CountedList`; `csharp/Walker.Counted.cs` | intake |
| S12 | Unpack the 103-byte user buffer | covered | AZ-1940 AC-3; `CountedDict`; `csharp/Walker.Counted.cs` | intake |
| S13 | C# handoff shares a folder with the position driver | covered | AZ-1941 AC-1; `language-pair.sh`; `Handoff.csproj` `BaseOutputPath` | assess-round-1 |
| S14 | Mac clang needs the SDK C++ include | covered | AZ-1941 AC-3; `language-pair.sh`; `publish-position.sh` | assess-round-1 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- Permission denied: the library has no accounts or tokens.
- Undo: pack does not store the previous buffer.
- A process killed mid-pack: there is no partial file to recover.

### Harness gaps

none
