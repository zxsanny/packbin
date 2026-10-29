# Expected results - loop 83

Input -> expected output pairs. Figures are HEAD dbf9a57.

| # | Input (command) | Expected output |
|---|-----------------|-----------------|
| 1 | `wc -l .github/workflows/drivers/*.cpp` | every file <= 500 lines (HEAD: `handoff.cpp` 639, `position.cpp` below 500) |
| 2 | `bash .github/workflows/ring-frame.sh` after the split | same pair counts and `0 mismatched` as the run on HEAD pasted in the T1 spec |
| 3 | `grep -c -E '^(def (to_s|inspect|first_set|dig|steps_of|code_lines|runs)\b|(FLAGS|CACHE_USES|SHA_PIN|ASCII_SPACE|STRING_ESCAPES) =)' ring-wiring-check.py ring-wiring-swift-check.py` | HEAD: 12 and 12. After: 0 and 0; the same grep on the new module: 12 |
| 4 | `bash .github/workflows/ring-wiring.test.sh`, `ring-wiring-rows.test.sh`, `ring-wiring-swift.test.sh` | PASS with the label and mutant counts of HEAD (pasted in the T2 spec) |
| 5 | `python3 -I scripts/frame/framefmt.py` on each new row | `BadValue` (14 of 14) |
| 6 | `grep -c '^refuse-' fixtures/frame/ring-cases.txt` | HEAD: 42. After: 56 (refusal rows per language in ring-frame.sh: 58 -> 72) |
| 7 | `bash .github/workflows/ring-frame.sh` with the new rows | `0 mismatched`; C#, TypeScript, Python, Java, Go, Swift answer `BadValue` from the package; Rust and C++ print `BadValue` by construction |
| 8 | the same run with one package's length check moved after the second refusal (scratch copy) | at least 1 new row mismatches; exit 1 |
