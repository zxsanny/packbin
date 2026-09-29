# Loop 7 smoke — proposed checks

LOCAL_URL: none — library, no server. Read `README.md` in the editor.
Branch: main (short loop)

## Perform these checks in the open editor

- [x] `### Packed` shows values `0, 1, 2, 3` as the byte `e4`.
- [x] Bias −1 with a count of 9 and eight 1-bits is `ff`. A count of 1 writes no bitset bytes.
- [x] `### Times` unpacks two pairs and leaves the trailing byte `7`.
- [x] The route packet is `34 10 00 15 00 06 2d 00 02 0d 00 65 cd 1d 00 a3 e1 11 10 8c cd 1d 10 ca e1 11 01`.
- [x] `_docs/01_solution/schema.md` lists `packed` and `times`.

## Agent walk

No browser surface. The product is a library. The checks are the README and `schema.md`.

README `### Packed` contains `e4` and `ff`. `### Times` contains the trailing `07` and the route bytes above. `schema.md` has both helper rows.

## Result

PASS

## Notes

No server account. The six language suites already passed in batch 01.
