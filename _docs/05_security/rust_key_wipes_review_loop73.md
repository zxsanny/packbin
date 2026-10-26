# Security review: Rust key wipes (loop 73)

Scope: commit `a1c456a` against `72beacb` (`git diff 72beacb a1c456a -- rust`), task AZ-3275. Reviewer: an independent read-only agent. It read the code at `a1c456a`, the spec, the acceptance criteria, `pack-session.md` 2.0.0 and the batch report's code-read list. It ran no build or test in the repository; it ran one Python check in the session scratchpad. Line numbers are at `a1c456a`.

**Verdict: PASS_WITH_WARNINGS.** One Low finding and three Info findings. Every finding is handled in batch 2 (`batch_02_loop73_report.md`).

## Findings and dispositions

| # | Severity | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | Low | `compress` (`session_core/sha256.rs`) leaves its 16-word schedule window on the stack. Run backwards, the schedule recurrence `w[t-16] = w[t] - σ1(w[t-2]) - w[t-7] - σ0(w[t-15])` gives back the whole input block. At key load (`midstate(&opad)` in `Pads::new`, reached from `DirKeys::fill` and `MacKey::derive`) that block is the MAC key XOR the outer pad, and in HKDF it can be `prk` XOR a pad. So the wipes of `opad`, `mac` and `derived` did not remove every copy. The reviewer's script recovered a random 32-byte key from the window; the parent re-ran it (`recovered key: True`). | **Fixed.** Owner, 2026-10-26: wipe the window at the end of every compression. This replaced the first answer ("leave the schedule"), which rested on the parent's wrong description of the window ("256 B", "key-derived words"). `compress` now ends with `wipe(&mut w)`. Cost: +16 B of flash per set, no stack change; `MacKey::tag` 0.99 times the claim commit |
| 2 | Info | `Sha256::finish(&mut self)` can now be called twice, or followed by `update`, and give a wrong digest silently; every caller uses a hasher once today | **Fixed** by a doc line on `finish`: call it once per hasher |
| 3 | Info | The code-read list missed three by-value cases: heap-free `Session::load` (`owned`), `Session::load_frame` (returns the session with its keys by value; `load_frame_in_place` exists) and `MacKey::derive` (64 B of pad states by value) | **Fixed**: rows added to the code-read list (batch 2), all L73-1 |
| 4 | Info | `SlotKeys::fill` cleared an unloaded direction with `*keys = DirKeys::empty()`, plain stores, against AC-4.1 "nothing else clears them" | **Fixed**: `keys.wipe()` |

## Checked and found clean

- The `unsafe` block (`wipe.rs`) is sound for every `T: Copy + Default`: a `&mut T` gives a non-null, aligned, unique pointer, `T::default()` is a valid value, and `write_volatile` never drops the old value. It is the only `unsafe` in `rust/src`; `frame` keeps `#![forbid(unsafe_code)]`. Volatile stores are not removed as dead stores; `compiler_fence(SeqCst)` is the same scheme as `zeroize`.
- Every wipe comes after its last use, so no output byte changes (tag before the HKDF wipes, `previous` copied before the exit wipe, `output` written before `state` and `work` are wiped, `first` and `second` copied before `both` is wiped, midstates computed before `ipad` and `opad` are wiped).
- `derive`: `break` in place of `return` gives the same output; the `get_mut` miss cannot happen.
- Heap-free `open`: refusal order and kinds unchanged (nonce length, keys present, no seed), every refusal before any write; the seed is wiped in place, then `None`; `take` had left the payload in the `Option`. Std `open`: identical truth table, `start` still checks the seed before reading `/dev/urandom`, the `.unwrap()` is gone.
- No panic path or heap added (only `iter_mut`, `zip`, `as_mut`, `ok_or_else`, `let ... else`); the embedded link checks and `rust-mutants` pass.
- `ct_eq` untouched; no wire or vector code changed; the M33F re-pins match the measured figures; zero dependencies; builds on Rust 1.79 and 1.98.
- Intended residue: the `Pads::mac` hashers after `finish` hold only the inner digest and the tag; `le_word` and `quarter` values stay in registers; the std `PackSession` has no `Drop`, so neither its keys nor a seed that was never opened are wiped at drop (known, out of scope).
