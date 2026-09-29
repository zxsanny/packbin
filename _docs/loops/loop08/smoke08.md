# Loop 8 smoke — proposed checks

LOCAL_URL: none — library, no server. Read `README.md` and `_docs/01_solution/schema.md` in the editor.
Branch: dev (loop work landed on dev)

## Perform these checks in the open editor

- [x] The sentence after "Field order is wire order" names a gap, a repeated id, and an anchor that is not the next value id, and it says the anchor is not written.
- [x] README says the same failure rule, and `repeat`, `when`, `times`, and `flags` take an anchor.
- [x] A list, a dict, and a nested group still start at 0. The anchor is not a parent number on `list` or `dict`.
- [x] The position golden hex is still `4001000065cd1d00a3e1110100`.

## Agent walk

No browser surface. The product is a library.

`schema.md` opens with "Field order is wire order" and the next sentence names the gap, the repeated id, and the bad anchor, and says the anchor is not written. README repeats that sentence. The helper table shows `flags(anchor, …)`, `when(anchor, …)`, `repeat(anchor, …)`, and `times(anchor, …)`. `fixtures/golden.hex` is still `4001000065cd1d00a3e1110100`.

## Result

PASS

## Notes

No server. The six language containers passed in this session. Publish-and-tag checks were not run here.
