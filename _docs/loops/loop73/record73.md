# Autodev loop record — loop 73

loop: 73
branch: dev
plan_artifact: _docs/loops/loop73/plan73.md
tasks_shipped: [AZ-3275_rust_key_wipes]
decisions:
  - owner (2026-10-26, AskQuestion at loop start, recommended option): Rust HKDF wipes, the loop 72 hardening for the Rust package
  - owner (2026-10-26, "Wipe method", recommended): one volatile wipe helper in `session_core` (`write_volatile` + `compiler_fence`, one documented `unsafe` block) for every Rust wipe, in place of `core::hint::black_box`; no `zeroize`
  - owner (2026-10-26, feature-assess clarify, recommended): the full 32-byte HMAC outputs are left (not key material)
  - owner (2026-10-26, "SHA schedule", recommended, after the security review): wipe the 16-word SHA-256 schedule window at the end of every compression. This replaced the second answer's "leave the round schedule", which rested on the agent's wrong description of the window ("256 B", "key-derived words"); the window gives back the whole block hashed, the key XOR a pad at key load
  - agent: the stream pad (`pad.rs` `state`, `work`, keystream) in scope as loop 72 item 6; the seed wiped in place at both `open`s (`take` left it in the slot); the helper kept out of line (measured against forced inline)
measurements:
  - embedded on HEAD 72beacb and on 9f118c9 (Rust 1.98.1): M4F `session` 18,812 / 1,528 to 18,844 / 1,504, `frame` 20,164 / 1,752 to 20,332 / 1,728 (bound 20,480); M33F re-pinned `session` 18,916 / 1,504, `frame` 20,404 / 1,728; `base`, `text`, `ecc` unchanged
  - forced inline (batch 1): `session` +128 B, `frame` +96 B against out of line +16 B / +152 B; out of line kept (168 B in total against 224 B, 24 B less frame stack)
  - host release, claim commit beside this tree, smallest of 3: `pad::xor` over 1 MiB 2.792 / 2.915 ms (1.044); `MacKey::tag` 583.1 / 578.4 ns (0.99)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row
  - owner (unchanged): frame mode in Python, TypeScript, C++ and Go and their order; a cross-language frame ring; a replay window per key slot (F69-2); whether `frame` is on with `std`
  - candidate (new): a `Drop` wipe for the std `PackSession` keys and an unopened seed (the managed stream sessions have none either)
  - open: CI of the loop 73 push
  - Jira: AZ-3275 In Testing (comment with the decisions and figures)
lessons:
  - Before offering the owner "leave X, it only holds derived data" for a crypto temporary, check whether X can be inverted: the SHA-256 schedule window gives back its block. The independent review caught the wrong premise after the owner had answered on it.
  - `Option::take` on a secret can leave its bytes in the slot; wipe in place, then `None`.
step11: "`scripts/loop-tests.sh` at a1c456a: rust 38 s, rust-embedded 3 s, ring 61 s, publish-gate 317 s, all PASS (419 s; 10 skipped as unchanged); at 9f118c9: rust 40 s, rust-embedded 3 s, ring 67 s, publish-gate 389 s, all PASS (499 s); full Rust CI step list in Docker twice, 972 passed, 0 failed, 1 ignored"
review: "independent read-only security review of a1c456a against 72beacb: PASS_WITH_WARNINGS, one Low (SHA-256 schedule window) and three Info, all fixed in 9f118c9 (`_docs/05_security/rust_key_wipes_review_loop73.md`); feature-assess CLARIFY then COMPLETE (`assessment73.md`); no per-batch code review (owner preference)"
retro: _docs/06_metrics/retro_2026-10-26_loop73.md (loops 70 to 73)
smoke: PASS
smoke_artifact: _docs/loops/loop73/smoke73.md
assessment_artifact: _docs/loops/loop73/assessment73.md
loop_end_merge: main
