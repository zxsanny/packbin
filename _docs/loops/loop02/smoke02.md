# Loop 2 smoke — proposed checks

LOCAL_URL: none — library, no server
Branch: dev (launcher; loop/2-strings-lists-dicts is the unused worktree)

## Checks

- [x] Six handoffs unpack the 103-byte user value. Wrong fields 0, bytes left 0. AZ-1941 AC-1
- [x] Six handoffs unpack the 58-byte nested dictionary. AZ-1941 AC-2
- [x] Each language still packs the position record to `4001000065cd1d00a3e1110100`. AZ-1941 AC-3

## Agent walk

No browser surface. `language-pair.sh` printed `language pairs passed`.

## Result

PASS
