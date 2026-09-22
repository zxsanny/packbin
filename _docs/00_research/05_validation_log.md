# Validation Log

## Validation Scenario

Pack type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, motion flags clear. Unpack that hex. Then omit an optional uint16, set it, and cut the buffer inside it.

## Expected Based on Conclusions

The primitive walk emits `4001000065cd1d00a3e1110100` in both languages, unpacks to those fields, adds 0 or 2 bytes for the optional uint16, and returns no value when the buffer ends inside it.

## Actual Validation Results

`node _docs/00_research/raw/mve/position.mjs` and `dotnet run` on `_docs/00_research/raw/mve/cs` both printed that hex and passed the optional-width, short-buffer, conditional-width, and repeat-leftover checks. Elapsed times were 17.4 ms (Node 22) and 1.8 ms (.NET 10).

## Counterexamples

The MVE does not execute a GitHub Actions runner and does not push to npm or NuGet. Publish stays a documented workflow shape, not a completed upload.

A host-endian machine was not part of the run. Both programs passed `littleEndian: true` / `Write*LittleEndian`, so the bytes do not follow the host order. That is the mechanism, not a second machine.

## Review Checklist

- [x] Draft conclusions consistent with fact cards
- [x] No important dimensions missed
- [x] No over-extrapolation
- [x] Publish upload is marked experimental rather than selected

## Conclusions Requiring Revision

None for the walker. Do not describe the registry upload as already proven.
