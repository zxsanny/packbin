# Question decomposition — Mode A Phase 1

Question type: Knowledge organization + decision support.

Scope: are the written acceptance criteria and restrictions realistic for a fixed-layout binary pack/unpack library, and which outcome gaps are worth adding before solution research.

Novelty sensitivity: **High** for runtime version numbers and registry publish auth (they move yearly). **Low** for fixed-width integer packing, exact buffer-size checks, and cross-language byte equality. Version facts use official release pages. Protocol facts have no time cutoff.

## Sub-questions

1. Is 100000 pack-then-unpack round trips of a 13-byte record in ≤ 1 second on one core inside the range published serializers already beat?
2. Is a 0-byte mismatch between two languages a realistic done line for a layout the caller already fixed?
3. Are tests on every push and pull request, and publish on a version tag, how GitHub Actions ships public libraries to npm and NuGet?
4. Which .NET and Node lines are the current LTS on 2026-09-22, and does "current LTS at first publish" stay valid?
5. Which outcome checks do comparable unpackers treat as mandatory that these criteria do not yet name?

## Out of this pass

Component selection, walker design, and replacing `solution.md`. Those are Phase 2, and only after this assessment is confirmed.
