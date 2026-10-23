# Expected results — loop 65

| # | Input | Expected |
|---|-------|----------|
| E1 | `test.yml` `on.push` after the change | `branches: ["**"]` and `paths-ignore: ["_docs/**"]`; `pull_request`, `workflow_call` as before |
| E2 | `limits.txt` after the change | `text 27964 2898`, `ecc 18879 798`, `session 19325 1924`, `base 16384 512` |
| E3 | `limits.txt` with a `-` for any set of `feature-sets.txt` | `checks.test.sh` fails |
| E4 | stage with text flash limit 26,631 B | exit 1, message `text: flash 26632 B over 26631 B` |
| E5..E8 | scheme 0x5e rows 0..3 (Python package bytes, 2026-10-23) | row 0 `5e0201010701010801010901050101070101080101090106`; row 1 `5e020001010700`; row 2 `5e0101010701010800`; row 3 `5e020100010001000000` |
| E9 | arm stage stack of rows 0..3 | pack and unpack each at most 512 B, figure printed as `FLAG_ROUND_CHAIN_PACK_STACK` / `FLAG_ROUND_CHAIN_UNPACK_STACK` |
