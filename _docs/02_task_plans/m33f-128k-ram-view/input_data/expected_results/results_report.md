# Expected results - m33f-128k-ram-view

| id | input | expected output | AC |
|----|-------|-----------------|----|
| E1 | script RAM `LENGTH = 128K`; `cpp-m33f` image `ac2.elf` | `nm`: `__stack_top` = 0x38020000; row PASS; `vectors run 315 asserted 315`; flash 25760 B; stack 724 B | AC-1, AC-2 |
| E2 | same script; `frame.elf` | `__stack_top` = 0x38020000; flash 8416 B; stack 912 B | AC-1, AC-2 |
| E3 | same script; `rust-m33f` sets base, text, ecc, frame | `__stack_top` = 0x38020000; flash/stack equal `limits-m33f.txt` (15132/456, 27268/2736, 18764/744, 20404/1728) | AC-1, AC-2 |
| E4 | 130 KiB zero-initialised array in the all-kinds image | link fails with a "region `RAM' overflowed" message; row FAIL | AC-3 |
| E5 | script RAM `LENGTH = 4M` | `cpp-m33f` FAIL and `rust-m33f` FAIL, message names 0x38020000 and 0x38400000 | AC-4 |
