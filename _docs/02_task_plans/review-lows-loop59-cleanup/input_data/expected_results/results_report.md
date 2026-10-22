# Expected results — loop 60

| Input | Expected output |
|-------|-----------------|
| C++ seven key pairs through the `Error`-returning helper | ordered pairs `Ok`, refused pairs `BadValue`; each failure would print the pair, the `Error` returned, the one expected |
| Scratch copy with one pair's expectation flipped | failure line names that pair and both `Error` names |
| C++ `put_key` called with n = 5 on a `Text<4>` | test failure with the guard's message; the pair is not packed |
| Rust nostd corpus test on the real `corpus.txt` | passes; `listed_inputs()` = 34 = loader count |
| `corpus.txt` copies with an upper-case hex last field, a kind outside `[a-z0-9_]+`, or a `# note abcd` comment | pass, count unchanged |
| `corpus.txt` copy with one extra valid input line | passes, both counts +1 |
| Loader copy that also drops lines starting with a letter | fails naming expected and loaded counts |
| Cortex-M4F arm figures, no edit under `cpp/src` or `cpp/include` | flash 8,032 B, stacks as in loop 57 |
