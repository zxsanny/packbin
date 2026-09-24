# Loop 4 smoke — proposed checks

LOCAL_URL: none — library, no server. Read `README.md` in the editor.
Branch: dev (short loop)

## Perform these checks in the open editor

- [x] The position example builds a `Scheme` with type number `0x40`. The row has no type field.
- [x] The position bytes under that example are `40 01 00 00 65 cd 1d 00 a3 e1 11 01 00`.
- [x] The C# user example binds fields by order id (`Field.Utf8<User>(0, …)`), and the first packed byte is the type number `01`.
- [x] The marker hex `2001000065cd1d00a3e111010000000000` is the same 17 bytes in each language test.

## Agent walk

No browser surface. The product is a library. The checks are the README and the shared marker hex.

`test-results/report.csv` appends every suite run. Three older rows are `FAIL` (cpp, then rust, then cpp). Each of those languages has a later `PASS` row. The last six rows are csharp, typescript, python, rust, cpp, and java, all `PASS`.

## Result

PASS
