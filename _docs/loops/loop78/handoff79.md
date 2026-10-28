# Handoff to loop 79

From the loop 78 record (`record78.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 78

AZ-3354 and AZ-3355 (8 points, no epic): the frame ring holds the 22 refusal cases of `vectors.txt` by name (`refuse-seal`, `refuse-open`, `refuse-mac` rows with `dirs` and `out_len`), 38 refusal rows per language (was 16); no driver aborts on a direction outside 1 to 3 and each takes its buffer size from the row; two exact-fit rows; all 8 drivers refuse a bad hex digit, odd token, missing field or bad number with a non-zero exit and `frame line N`; Go checks every parse; Python answers `skip`; `ring_frame.py` blames a writer that prints a word and gives its readers skip lines; new `ring-frame-drivers.test.sh` (44 runs on the real drivers) in the CI `ring` job and in step 11, which now also runs `ring-frame.sh` and its self-test.

## First actions of loop 79

0. CI of the loop 78 push (`dev`, then `main`): `gh run list --repo zxsanny/packbin --branch dev`; read any red job's log with `gh api` before calling it a flake. Put the result into the first commit of loop 79 (do not push a record-only commit; LESSONS, loop 63).
1. `uptime` and `ps -Ao pcpu,command -r | head`; a total run is not a result above load 60.
2. Pick the work: the owner input below, or the candidates. No spec is ready. Retro is due after loop 79 (last: loop 74).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows (needs a Windows build and test first).
- A public-key pairing step (loop 74 intake, not decided).

## Candidates (not specs yet)

- Ring leftovers: the refusal display shows five lines a reader; a direction above 255 wraps in the C#, C++ and Go drivers; a huge `out_len` aborts a driver; multi-part MAC messages (new driver line format). All Low; probe each on HEAD before writing a spec (LESSONS, loop 76).
- Four dead-code warnings in the `frame` and `text,ecc,frame` Rust test builds (`cfg(test)` items), `swift/Sources/Packbin/PackbinError.swift` comment check, DocC link resolution, `cargo test --all-features --no-run` in the matrix.
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L78-1**: step 11 now runs the frame ring and its driver script; the first CI run of `ring-frame-drivers.test.sh` on Linux (GCC 16 container for C++, Swift 6 on Linux, Go in the runner) is unread when this is written; the Mac run and a gcc:16 `-Werror` compile were green.
- **L78-2**: the two vcpkg checks print NOT RUN on this Mac (no vcpkg tool); CI runs them.
- **L76-1**: the cause of the timing-selftest flake (L75-2) is unproven; the selftest prints the text it matched against.
- **L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff76.md` and `handoff75.md`.
