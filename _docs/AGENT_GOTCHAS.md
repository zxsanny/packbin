# Agent gotchas

Session-start don’ts. One line each. Under one page. Do not duplicate `_docs/LESSONS.md`.

## Gotchas

- The auditor's fuzz corpora, per-language drivers, `cmp.py` and amplification probes live in a session scratchpad. Commit them under `fixtures/hostile/fuzz/` or the next unpack-changing loop rebuilds them from an old temp dir (recommended in loop 11, ignored, repeated in loop 13).
- On this arm64 Mac a green run needs three host recipes written nowhere else (repeated from loop 13, tripped again in loop 14): `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"` for `language-pair.sh` (else `'cstddef' file not found`); `typescript/node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions typescript/src/index.ts` for the strict check; and the Pico example needs a `--platform linux/amd64` container with its own cache under `.cache/embedded/amd64` (PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0`; the ESP stage of `cpp/embedded/run.sh` shows `cpp-example-pico` failed on this host by design).
- A worker in the shared tree never runs `git stash`, `git checkout`, `git reset` or `git clean`: in loop 15 the AZ-2214 worker stashed and popped once for a shellcheck baseline while three other workers were writing (the tree survived, by luck). Use `git worktree` or a tree copy under the scratchpad for baselines.
