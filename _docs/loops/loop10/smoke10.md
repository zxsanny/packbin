# Loop 10 smoke — proposed checks

LOCAL_URL: none (library; no UI and no service)
Branch: loop/10-cpp-microcontroller

## Perform these checks in a terminal at the worktree root

- [ ] Host C++ suite (AZ-2078, AZ-2081, hostile runner): on Linux `make -C cpp test`; on a Mac `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) make -C cpp test CXX=clang++`. Expect 11 `compile-fail: … rejected` lines and `all tests passed`. Delete `cpp/build` first if a container ran before.
- [ ] Hostile case file (AZ-2070): `bash fixtures/hostile/cases.test.sh`. Expect `hostile cases ok: 17`, four `rejected` lines and `hostile case tests passed`.
- [ ] Embedded targets (feature AC-1 to AC-5, AZ-2106): `docker compose -f docker-compose.test.yml run --rm cpp-embedded`. Expect four `PASS` rows: M0+, M3 QEMU with `vectors run 214 asserted 214`, M4F with flash ≤ 8192 B and stack ≤ 512 B, s390x with 214/214.
- [ ] Same bytes in six languages: `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) bash .github/workflows/language-pair.sh`. Expect `language pairs passed`.
- [ ] Refused schemes (AZ-2081): read the README note under the C++ migration table and `cpp/tests/compile-fail/bool_outside_flags.cpp`; the note names the bool, empty-group and `u2` rules.
- [ ] Tickets: AZ-2069 shows 36 children AZ-2070 to AZ-2105; AZ-2070, AZ-2078, AZ-2081 and AZ-2106 are In Testing.

## Notes

No credentials needed. The security audit (`_docs/05_security/security_report.md`) lists one High finding (F0) found and fixed in this loop, and three open Low findings.

## Agent walk

Run by the agent on 2026-10-05 before asking (no browser; terminal only):

| Check | Observed |
|-------|----------|
| Host C++ suite | `all tests passed` on Apple clang 21 and on gcc:16 (container); 11 compile-fail cases rejected |
| Hostile case file | `hostile cases ok: 17`, four corruptions rejected, `hostile case tests passed` on bash 3.2 and Ubuntu 24.04 |
| Embedded targets | M0+ PASS; M3 QEMU PASS, vectors 214 = 214; M4F PASS, flash 7728 B, stack 488 B; s390x PASS, 214/214 |
| Six languages | C# 52, TypeScript 44, Python 44, Rust 32+6+10, Java all printed passes, C++ passes; `language pairs passed` |
| Tickets | 36 children AZ-2070 to AZ-2105 created; AZ-2070, AZ-2078, AZ-2081, AZ-2106 transitioned to In Testing (tool read-back) |
