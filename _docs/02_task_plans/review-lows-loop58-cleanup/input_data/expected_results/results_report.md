# Expected results — loop 59

| Input | Expected output |
|-------|-----------------|
| Rust nostd corpus test on the real `corpus.txt` | passes; `listed_inputs()` = 33 = loader count |
| `corpus.txt` copy with a three-field comment `# note abcd` | passes, count unchanged |
| `corpus.txt` copy with one extra input line | passes, both counts +1 |
| Loader copy that also drops lines starting with a letter | fails naming expected and loaded counts |
| C++ `put_key` called with n = 5 on a `Text<4>` | test failure with the guard's message, no copy |
| C++ seven key pairs through the `Error`-returning helper | ordered pairs `Ok`, refused pairs `BadValue`, each with its own message |
| Scratch copy with one pair's expectation flipped | failure names that pair's message |
| Cortex-M4F arm figures, no edit under `cpp/src` or `cpp/include` | flash 8,032 B, stacks as in loop 57 |
