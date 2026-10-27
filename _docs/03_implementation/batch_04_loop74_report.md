# Batch Report

**Batch**: 4
**Tasks**: AZ-3291_docs_stream_removal
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3291_docs_stream_removal | Done | parent (in b86d468): README, `pack-session.md` 3.0.0, `rust/tests/nostd_docs_tests.rs`, `scripts/frame/readme-examples.sh`; docs worker (this batch): 51 files under `_docs/00_problem`, `_docs/02_document`, `_docs/AGENT_GOTCHAS.md`, `fixtures/crypto/README.md`, `fixtures/hostile/fuzz/README.md` | `nostd_docs_tests` 1 passed; `readme-examples.sh` 4 of 4 PASS (C#, Java, Swift, Rust) | None |

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop (step 14).

## AC evidence

| AC | Evidence |
|----|----------|
| AC-1 | the brief's grep (`PackSession`, `stream session`, `Encrypted session`, session test and file names, `os_random`, `RandomFn`, `split_keys`, `MessageContext`, `MsgCtx`) over `_docs/02_document` (minus ADRs, the contract, ripple logs, `epics.md`), `_docs/00_problem` and the two fixture READMEs: every hit is marked retired or removed, or is history |
| AC-2 | `pack-session.md` 3.0.0: Purpose and Configuration frame-only, 0 stream sections, Change Log row; the Frame mode and MAC-only sections equal 2.0.0 apart from the intro's stream sentence and the Security note's wipe comparison (named in the Change Log) |
| AC-3 | `scripts/frame/readme-examples.sh`: PASS C#, Java, Swift, Rust; `cargo test --test nostd_docs_tests`: 1 passed |
| AC-4 | every source file added in b6a0f73, 0df534e and b86d468 is named in `module-layout.md`; deleted files appear only on "Deleted:" lines of the Loop 74 bullets (the file's own convention) |

## Main changes

- `architecture.md`: the Security section says frame mode is the only session, with the D1 names and the D2 modules; `> See ADR 008, ADR 009`.
- `system-flows.md`: Flow F4 Session retired; new Flow F5 Frame session (there was no frame flow).
- `message-ecc.md` 1.0.1: the Session row and the session clauses of the Dispatch row removed (editorial; ECC bytes and rules unchanged).
- Components: the `PackSession` interfaces replaced by a "removed in loop 74" note; the four packages without frame mode gain an "Internal: crypto module" section; test docs mark 33 session rows retired; `test-data.md` lists the crypto and frame vector readers.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Clarity |
|---|----------|---------|-------------------|---------|
| 1 | AZ-3291 AC-4 | "0 deleted files are listed" read literally conflicts with `module-layout.md`'s "Deleted:" convention | kept the convention (one "Deleted:" line per package bullet) | clear |
| 2 | C++ publish | the vcpkg `supports: linux \| osx` line was justified by `os_random` having no Windows branch; that reason is gone | noted in the C++ description; the line is in `publish-embedded.sh` (candidate) | unclear |
| 3 | Swift | the DocC catalog's "whole API" list has none of the frame types (pre-existing) | noted in the Swift description; candidate | unclear |
| 4 | history | `_docs/04_refactoring/02-whole-project-assessment/**` still names `PackSession` | history, left | clear |
