# Loop 9 smoke — proposed checks

LOCAL_URL: none — library, no server. Read `README.md` and `fixtures/golden.hex` in the editor.
Branch: dev (loop work landed on dev)

## Perform these checks in the open editor

- [x] README has one session example. It names Load, Start, Join, Pack, and Unpack. It sends 16 bytes once and says there is no second handshake.
- [x] A clear pack example is still above that session section.
- [x] `fixtures/golden.hex` is `4001000065cd1d00a3e1110100`.
- [x] The field-order sentence is still in the README: a gap, a repeated id, or a bad anchor fails construction, and the anchor is not written.

## Agent walk

No browser surface. The product is a library.

README "Example" says load a 32-byte seed, start, send those 16 bytes once, and join. The C# block calls `PackSession.Load`, `Start`, `Join`, `Pack`, and `Unpack`. The next sentence says the 16 bytes leave once and there is no second handshake. Clear pack examples stay in the sections above that. `fixtures/golden.hex` is `4001000065cd1d00a3e1110100`. The field-order sentence is still in the data-types section.

## Result

PASS

## Notes

No server. The six language containers passed in this session. Publish-and-tag checks were not run here.
