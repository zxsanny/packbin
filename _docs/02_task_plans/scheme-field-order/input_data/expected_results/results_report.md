# Expected results

## Pairs

| Input | Expected | Comparison |
|-------|----------|------------|
| Value fields numbered 0 then 1 | scheme builds; bytes of a later pack are unchanged | exact; schemes failed: 0 |
| Second value field numbered 2 | construction fails; schemes built: 0; bytes written: 0 | exact |
| `repeat` anchor equal to the first child id, child ids continue 1 then 2 after a field 0 | scheme builds; the next child id is 2 | exact |
| `repeat` anchor not equal to the next value id | construction fails; schemes built: 0 | exact |
| `list` of one `u8` numbered 0, then a parent `u8` numbered 0 | scheme builds; both numbers are 0 | exact |
| Rust raw field list with a gap | construction fails; schemes built: 0 | exact |
| Rust `when` or borrowed count naming an id not yet walked | construction fails; schemes built: 0 | exact |
| A known packet, groups updated only with anchors | same hex in all six languages; mismatched bytes: 0 | exact |
