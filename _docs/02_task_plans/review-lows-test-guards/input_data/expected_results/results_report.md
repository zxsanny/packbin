# Expected results — loop 58

| Input | Expected output |
|-------|-----------------|
| Rust nostd loader with a filter that also drops lines starting with a letter (broken copy) | the corpus test fails naming expected and loaded counts |
| Rust nostd corpus test on the unmodified loader; `corpus.txt` copy with one extra input line | passes in both |
| Go `hostileRefusals` without one `pack_error` case id (copy) | the refusal test fails naming that case id |
| Go `hostileRefusals` with one extra id (copy) | the refusal test fails naming that id |
| Dict keys `0x7f` then `0x80` (raw strings) | packs |
| Dict keys `0x80` then `0x7f` | refused |
| Dict keys `"a"` then `"ab"` | packs |
| Dict keys `"ab"` then `"a"`, and `"a"` twice | refused |
| `keys_ascending` with a signed compare, and with a length-first compare (scratch copy) | the new test fails for each |
| Cortex-M4F arm stage, no edit under `cpp/src` or `cpp/include` | flash 8,032 B, stacks as in loop 57 |
