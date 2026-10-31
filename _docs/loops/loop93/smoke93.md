# Loop 93 smoke — proposed checks

LOCAL_URL: none (no app; the `cpp-embedded` and `rust-embedded` compose services are the run)
Branch: dev

## Perform these checks

- [ ] `grep -n LENGTH cpp/embedded/arm/mps2-an505.ld` shows `RAM ... LENGTH = 128K` and `grep -n m33f_ram_end cpp/embedded/lib.sh` shows `0x38020000` (AC-1, AC-6)
- [ ] `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded` prints `RESULT 2 passed, 0 failed`; the `cpp-m33f` line still reads 315 asserted, 25760 B, 724 B (AC-2, AC-5)
- [ ] In a scratch copy, set the script's RAM `LENGTH` to `4M` and run the same command: `cpp-m33f` and `rust-m33f` FAIL with "stack top 38400000 is not the RAM window end 38020000" (AC-4)
- [ ] In a scratch copy, add `volatile unsigned char ram_hog[130 * 1024];` to `cpp/embedded/arm/ac2_main.cpp` and use it in `main`: `cpp-m33f` FAIL with "region `RAM' overflowed" (AC-3)
- [ ] `git diff HEAD~1 --stat -- cpp/src cpp/include rust/src` is empty (AC-5)
- [ ] The three texts say the window is in the secure alias, not a TrustZone non-secure image (AC-6)

## Notes
No credentials. The embedded image is built locally (`packbin-embedded:local`).

## Agent walk
No browser; the agent re-read each check against the runs of this loop.

| check | observed | matches |
|-------|----------|---------|
| 1 | `LENGTH = 128K` on the RAM line; `m33f_ram_end=0x38020000` | yes |
| 2 | loop-tests `RESULT 3 passed, 0 failed, 186 s` (with scaffold); `cpp-m33f: PASS vectors run 315 asserted 315 ... 25760 B ... 724 B` | yes |
| 3 | scratch run: 4 `cpp-m33f` images and 5 `rust-m33f` images FAIL "stack top 38400000 is not the RAM window end 38020000" | yes |
| 4 | scratch run: ``ld: region `RAM' overflowed by 3264 bytes``, `cpp-m33f` FAIL | yes |
| 5 | `git diff dac8d6f..HEAD -- cpp/src cpp/include rust/src` empty (checked from the stat of the commit) | yes |
| 6 | script header, `lib.sh` comment and `rust/embedded/README.md` carry the sentence | yes |
