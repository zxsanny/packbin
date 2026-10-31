# Feature acceptance criteria — loop 92

Inherited baseline: project `_docs/00_problem/acceptance_criteria.md` has no AVR or ChaCha20 row; the Uno build rows of `cpp/embedded/arm.sh` (AC-1 0 warnings, flash 32,256 B, static RAM 2,048 B) stay as they are.

## AVR runtime check (AZ-A)
- AC-1: The arm stage of `cpp/embedded/run.sh` runs one AVR image on `simavr` (ATmega328P, 16 MHz) that calls `chacha20_xor`, and the image reports `sizeof(size_t)` = 2 and `sizeof(int)` = 2 from the emulated CPU (2 of 2 sizes read, 0 assumed).
- AC-2: The RFC 8439 §2.4.2 vector (key `00..1f`, nonce `000000000000004a00000000`, counter 1, 114-byte plaintext) gives a 114-byte ciphertext with 114 of 114 bytes equal to the RFC ciphertext.
- AC-3: For each of 9 lengths (0, 1, 63, 64, 65, 127, 128, 129 and 114 from AC-2), `chacha20_xor` equals the stream built block by block from `chacha20_block` (9 of 9 equal), and a second `chacha20_xor` restores the plaintext (9 of 9 restored).
- AC-4: At the 32-bit counter edge, 5 of 5 cases behave as the host test `block_counter_edge` expects: counter `0xffffffff` with 64 bytes returns true and equals that block; `0xfffffffe` with 128 bytes returns true and equals the two blocks; `0xffffffff` with 65 bytes and `0xfffffffe` with 129 bytes return false and leave all bytes unchanged (0 bytes changed); `0xffffffff` with 0 bytes returns true.
- AC-5: The gate fails the `cpp-avr-uno` row (exit code 1) when the image prints any failing check, a pass count other than the expected total, no output, or does not finish within 30 s of host time; and the stage fails (not skips) when `simavr` is missing from the image. Shown on the real path with one injected defect (one changed expected byte or one changed line in `chacha20_xor`), reverted at once: row failed, set named.
- AC-6: The image and the harness compile and link with 0 warnings under the existing `-Wall -Wextra -Werror` core flags, the harness image stays within the Uno budgets (flash ≤ 32,256 B, static RAM ≤ 2,048 B), and no file under `cpp/src` or `cpp/include` changes.
- AC-7: The stale statements "no AVR image is run" (`README.md:462`) and "Build only: no AVR emulator runs the image" (`cpp/embedded/arm.sh`) say that one image runs on `simavr` and what it checks (0 of the 2 stale sentences left).
