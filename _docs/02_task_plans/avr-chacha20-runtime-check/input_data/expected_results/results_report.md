# Expected results — loop 92

| Input | Expected |
|-------|----------|
| AVR image run on `simavr -m atmega328p -f 16000000` | exit code 0 within 30 s; the report names `size_t` 2 and `int` 2 |
| RFC 8439 §2.4.2: key `00..1f`, nonce `000000000000004a00000000`, counter 1, 114-byte "Ladies and Gentlemen of the class of '99…" | the RFC ciphertext, 114 of 114 bytes equal (the RFC text is the source of the vector; the harness holds it as bytes) |
| key `00..1f`, zero nonce, counter 1, 130-byte zero buffer, first 8 bytes | `18b84231ade6a6d1` (computed independently of the C++ code, 2026-10-31) |
| lengths 0, 1, 63, 64, 65, 127, 128, 129, 114 | each equals the `chacha20_block` stream; xor twice restores the input |
| counter `0xffffffff`, 64 bytes | true, equals `chacha20_block(0xffffffff)` |
| counter `0xfffffffe`, 128 bytes | true, equals blocks `0xfffffffe` and `0xffffffff` |
| counter `0xffffffff`, 65 bytes; counter `0xfffffffe`, 129 bytes | false, data unchanged |
| counter `0xffffffff`, 0 bytes | true |
| one expected byte changed, or a defect injected in `chacha20_xor` | the `cpp-avr-uno` row fails |
