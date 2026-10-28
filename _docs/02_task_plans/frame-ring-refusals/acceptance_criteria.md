# Acceptance criteria — frame ring refusals (loop 78)

Counts below are the figures to read on HEAD after the change; the "was" figures come from the loop 77 record (`refusals <lang>: 16 rows`) and are re-read in the first batch.

## Rows

- AC-1: `ring-cases.txt` holds the 22 refusal cases of `vectors.txt` (11 seal, 6 open, 5 MAC) as ring rows; total refusal rows per language 38 (was 16).
- AC-2: Every error name `TooLong`, `BadValue`, `BufferFull` and `ShortPacket` is the expected value of at least 3 rows; direction 0, direction 4 and a direction not in `dirs` each have at least one seal row and one open row.
- AC-3: The loader stops with exit 1 and names the row when the reference codec gives another name than the row (a row edited to `TooLong` where the reference says `BadValue`).
- AC-4: `ring-frame.sh` on HEAD with all 8 languages exits 0 and prints `refusals <lang>: 38 rows, 0 mismatched` for each of the 8 languages, and `64 pairs, mismatched: 0`.

## Drivers

- AC-5: With a seal or open line whose direction is 0, 4 or not in `dirs`, each of the 8 drivers prints `BadValue`, exits 0 and answers the next line.
- AC-6: With `out_len` one byte below the needed size each driver prints `BufferFull`; with exactly the needed size it prints the body or plaintext (checked for 2 rows per language).
- AC-7: A line without `dirs` and `out_len` gives the same answers as before (the 64 existing pairs still match).
- AC-8: A line with a bad hex digit, an odd-length hex token or a missing field makes each of the 8 drivers exit non-zero (never 0) and print a message that holds the line number; checked by a script that runs the real drivers on 3 malformed lines each (24 runs).
- AC-9: The Go driver exits non-zero on a malformed epoch, direction, tag length or kind (4 runs) and on a line over 1 MiB; none of its 12 parse errors is discarded (`grep -c ', _ := strconv' frame.go` gives 0).
- AC-10: `open-skip` and `verify-skip` get `skip` from all 8 drivers (was 7).

## Checker and self-test

- AC-11: A writer that prints `TooLong` for its first seal row makes `check` print `<writer>: <case> seal gave TooLong` and exit 1; no reader is reported as `frame-batch (open) failed`; the other 7 writers' pairs still print `0 mismatched`.
- AC-12: `ring-frame.test.sh` has a case for a driver that accepts a forbidden row (a stand-in that opens with a direction not loaded) and a case for a driver that aborts on `dir=0`; both end in exit 1 naming the row.
- AC-13: `ring-frame.test.sh`, `ring-lib.test.sh` and the new driver script pass in the `ring` job of CI and in `scripts/loop-tests.sh --all`; CI jobs 20 of 20 green on `dev` and `main`.

## Non-functional

- AC-14: The `ring-frame.sh` wall time on this Mac grows by no more than 20 % over its loop 77 figure (51 s in step 11, re-measured in the first batch at the same load).
- AC-15: No source file the loop touches ends above 500 lines unless it was above before; the C++ `handoff.cpp` is not split by this loop.
