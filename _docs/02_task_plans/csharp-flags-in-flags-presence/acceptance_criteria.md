# Feature acceptance criteria: a `flags` inside a `flags` (loop 118)

Inherited baseline: `_docs/00_problem/acceptance_criteria.md` (byte-equal packets across packages; a value given is written or refused, never dropped). This feature exercises the cross-package byte equality criterion for one scheme shape.

Scheme `S`: type 1, `flags(flags(u8 x), bool b)`: an outer `flags` whose first bit guards an inner `flags` (one bit, `u8 x`) and whose second bit is the bool `b`.

| id | criterion | measure |
|----|-----------|---------|
| F-1 | C# packs `S` with `x = 9`, `b = true` as `01 03 01 09` (TypeScript and Java bytes) and the typed unpack returns `x = 9`, `b = true` | hex equal; read-back equal |
| F-2 | C# packs the other three combinations as TypeScript does: `x` only `01 01 01 09`, `b` only `01 02`, neither `01 00`, each read back | hex equal; read-back equal |
| F-3 | A committed probe prints, for each of the nine packages and each of the four combinations, the packet and the read-back | 9 x 4 lines, `run.sh` exits 0 |
| F-4 | Any package other than C# that differs from TypeScript is listed in a findings file and becomes one owner decision row for the class (no fix in this loop) | findings file; `OPERATOR_TODO.md` row when needed |
| F-5 | The whole C# suite passes on `net10.0` and `netstandard2.0` | `dotnet test`, 0 failed |
