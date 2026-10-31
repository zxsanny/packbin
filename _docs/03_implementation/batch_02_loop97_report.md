# Batch 02 report — loop 97

Tasks: AZ-3500 (Python), AZ-3501 (TypeScript), AZ-3502 (C#), AZ-3503 (Java); 12 points; four workers on disjoint package trees, joined and re-run by the parent.

| Task | Status | Tests run by the parent after the join |
|------|--------|-----------------------------------------|
| AZ-3500 | Done | pytest -v: 4992 passed (venv in the scratchpad) |
| AZ-3501 | Done | `npm test`: 3622 pass, 0 fail; `tsc -p tsconfig.build.json --noEmit` clean |
| AZ-3502 | Done | `dotnet test` 5340 passed, 0 failed, default and `-p:PackbinTarget=netstandard2.0` |
| AZ-3503 | Done | `bash java/test.sh` exit 0: `PackbinTest` 11,685 checks, all tests passed, `SchemeTest` and Frame mains passed |

Review: code-review (low) 0 findings. CI-parity: PASS (CI runs these suites and the TypeScript build; no other typecheck or lint step exists for them).

Parent rulings during the batch (plan-diff-sync): percentage 0 is exactly a scheme without parity (same dispatch setting as a count 0; the limit rule of count 0). The reference, the contract (new row "Percentage 0") and AC-8 follow; the row `fixp.p0.t16` was dropped (`percent-vectors.txt` has 1,032 rows). Python was corrected after its first report; the other three already behaved this way.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-1 `parp` | Java, C# (and Python/TypeScript through setters) cannot declare a percentage and a count in one constructor; in-range pairs are last-setter-wins, only out-of-range percentages are refused as `bad_parity` | contract already says last setter wins; the constructor refusal applies where a constructor takes both (TypeScript options, Python `with_limits` call) | clear |
| AC-4 | A scheme message always has a type byte, so clear length 0 is covered at the codec level only | accepted; the vectors cover L 0 | clear |
| AC-8 | Python and TypeScript return `repaired: 0` for p > 0 when intact; p 0 returns none (as count 0) | keep; the README (AZ-3509) states it | clear |
| messages | Refusal texts differ by package (their own style); Java uses `IllegalArgumentException` | no change; the README may quote them | clear |
