# Handoff to loop 74

From the loop 73 record (`record73.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 73

Rust key wipes (AZ-3275; epic AZ-3199):
- One wipe helper, `rust/src/session_core/wipe.rs`: a volatile write per element plus `compiler_fence(SeqCst)`, the crate's only `unsafe` block. Every Rust wipe calls it; `core::hint::black_box` is left only in the timing support and the constant-time compare.
- Cleared now: the HKDF temporaries on every way out, both hashers, the 16-word SHA-256 schedule window after every compression, the ChaCha20 `state`, `work` and keystream, `split_keys`' output, the seed in place at both `open`s.
- Not cleared (documented): by-value copies and compiler spills (L73-1), the per-message HMAC output and inner digest (owner: not key material), the std `PackSession` keys at drop.

Wire bytes are unchanged. Embedded: M33F `session` and `frame` re-pinned (+32 B and +168 B of flash, -24 B of stack); the M4F `frame` set has 148 B left under 20,480 B.

## First actions of loop 74

0. CI of the loop 73 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; the `embedded-arm` job holds the new M33F pins. Read any red job's log before calling it a flake.
1. Check `uptime` and `ps -Ao pcpu,command -r | head` before any total run.
2. Retro: the last one covered loops 70 to 73; next due after loop 78.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row.
- Frame mode: the order for Python, TypeScript, C++, Go; PB-02 vector tests there; a cross-language frame ring; F69-2 (a contract change); whether `frame` is on with `std`.

## Candidates (not specs yet)

- A `Drop` wipe for the std Rust `PackSession` (send and receive keys, and a seed that was never opened), and the same in the managed stream sessions.
- Frame mode in Python and TypeScript, then Go and C++.
- A cross-language frame ring (`fixtures/frame/ring-cases.txt`).
- Unchanged: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L73-1**: a volatile wipe reaches only the memory it is given; Rust moves and by-value returns can leave copies, and the M4F `frame` set has 148 B of flash left.
- **L72-1** (unchanged): a Swift test hook must be `package`.
- **L71-1, L71-2** (unchanged): constant-time compare and wipe are best effort in managed runtimes; `setPrevious`, `clearPrevious`, `close` must not run beside `seal` or `open`.
