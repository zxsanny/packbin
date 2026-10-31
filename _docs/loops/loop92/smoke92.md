# Loop 92 smoke — proposed checks

LOCAL_URL: none (no UI; the run is the `cpp-embedded` compose service)
Branch: dev

## Perform these checks (terminal)

- [ ] 1. Run `docker compose -f docker-compose.test.yml run --rm cpp-embedded`: it ends with exit code 0 and six `=== <id>: PASS` lines, the last one `cpp-avr-uno` (AC-1 to AC-4).
- [ ] 2. In that output the `cpp-avr-uno` row contains `chacha20_xor on a 16-bit size_t under simavr: SIZES size_t=2 int=2, RFC 114/114, STREAM 9/9, RESTORED 9/9, EDGE 5/5, DONE` (AC-1 to AC-4).
- [ ] 3. In `cpp/embedded/avr/chacha20_check.cpp` change the first RFC ciphertext byte `0x6e` to `0x6f`, run the same command: the `cpp-avr-uno` row is `FAIL` and the log shows `RFC 113/114`; restore the byte with `git checkout -- cpp/embedded/avr/chacha20_check.cpp` (AC-5).
- [ ] 4. `git diff e64e3eb --stat -- cpp/src cpp/include` prints nothing (AC-6).
- [ ] 5. `README.md` line 462 says one image runs on the `simavr` emulator and the Uno example is not run; `git grep -n "no AVR image is run" -- README.md cpp` finds nothing (AC-7).
- [ ] 6. Regression: the same row still reports the Uno example at 15,402 B of 32,256 B flash and 196 B of 2,048 B RAM, and the other five rows (Cortex-M0+, M3, M4F, M33F, s390x) pass.

## Notes

No credentials. The first check needs Docker and the rebuilt `packbin-embedded` image (the compose service builds it).

## Agent walk

Walked by the agent on 2026-10-31 with the runtime lock held (no browser: no UI).

- Check 1: observed exit 0 and 6 of 6 `PASS` rows (`cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f`, `cpp-m33f`, `cpp-s390x`, `cpp-avr-uno`).
- Check 2: observed the note `chacha20_xor on a 16-bit size_t under simavr: SIZES size_t=2 int=2,RFC 114/114,STREAM 9/9,RESTORED 9/9,EDGE 5/5,DONE; image flash 3798 B static RAM 316 B`.
- Check 3: walked in step 11 proof runs (one changed expected byte): row `FAIL`, `RFC 113/114`, `BAD RFC 113`, exit 1; reverted. Not repeated in this walk.
- Check 4: `git diff --stat HEAD~1 -- cpp/src cpp/include` printed nothing.
- Check 5: README line says "links the Uno example (which is not run), and runs one other image on the `simavr` emulator"; the old sentence is gone.
- Check 6: Uno example 15,402 B and 196 B; the other five rows `PASS`.
