# Feature assessment — loop 77

loop: 77
feature: frame-ring (AZ-3338)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-27
**Implement pass**: commits 1e2bb45 (ring) and d0b8525 (CI fix); no batch report and no implementation report for loop 77 were given or found
**Verdict**: CLARIFY — 8 covered / 2 out-of-scope / 9 gap-clear / 1 gap-unclear

Read-only review. Nothing was run (ring, suites, docker, cargo, dotnet, gradle, swift). Every statement below comes from reading the code at HEAD d0b8525.

### Answers to the four questions (short form)

1. Every one of the 8 drivers calls its own package's real frame API (table below). None shells out to `framefmt.py`, none receives the expected value (the `seal`, `open`, `mac`, `verify` input lines are built by `ring_frame.py` without any expected field), and none returns a constant. The one weak spot is `verify`: with no negative row, a `verify` that returns "valid" without computing would pass (see Q2 and G1).
2. The checker is independent of the packages (imports only `framefmt.py` and `scripts/crypto/chacha20.py`; `python3 -I`). A wrong, tampered, short or crashing output from any one language ends in exit 1. The self-test covers seven injected faults and three corrupted-fixture faults (list below). It does not cover a driver that is too permissive, because the ring has no negative row.
3. `ring-cases.txt` has 8 seal rows and 4 mac rows, positive path only. Coverage table below. The biggest holes: no tamper or refusal row, no body above 46 bytes, only epochs below 256, only kinds 3 to 6, AD always 11 bytes.
4. No defect that makes the ring pass wrongly today. Latent defects and weak spots are in "Code findings" (TS ShortPacket name, lenient hex in 4 drivers, a writer's non-hex line crashes the readers instead of being reported on the writer, drivers that cannot express some refusals, Go discards parse errors, AC-7 comment inexact).

### Q1. Real API call per driver

| Lang | seal | open | mac | verify | file:line |
|------|------|------|-----|--------|-----------|
| python | `FrameSession.load(...)` then `session.seal(d, MsgContext(...), ad, clear, plain, buf)` | `session.open(d, MsgContext, ad, body, clear_len, buf)` | `MacKey.derive(...)` then `mac.tag([message], n)` | `mac.verify([message], tag)` | handoff_frame.py:41-45, 54-58, 66-69, 76-78 |
| typescript | `FrameSession.load(key, epoch, new FrameConfig(...))` then `session.seal(...)` | `session.open(...)` | `MacKey.derive` then `mk.tag([message], n)` | `mk.verify([message], tag)` | handoff-frame.ts:42-45, 53-56, 66-68, 75-77 |
| csharp | `FrameSession.Load` then `session.Seal(..., out written)` | `session.Open(..., out opened)` | `MacKey.Derive` then `mk.Tag(message, tag)` | `mk.Verify(message, tag)` | HandoffFrame.cs:38-42, 56-60, 72-75, 88-90 |
| java | `FrameSession.load` then `session.seal(...)` | `session.open(..., null, 0, out)` | `MacKey.derive` then `mk.tag(out, message)` | `mk.verify(tag, message)` | HandoffFrame.java:58-62, 75-79, 90-93, 103-105 |
| go | `packbin.LoadFrameSession` then `session.Seal(...)` | `session.Open(..., nil, 0)` | `packbin.DeriveMacKey` then `mk.Tag(tag, message)` | `mk.Verify(tag, message)` | frame.go:72-78, 95-101, 114-119, 132-136 |
| rust | `FrameSession::load_frame` then `seal_frame` (packbin::nostd) | `open_frame(..., None, &mut out)` | `MacKey::derive` then `mk.tag(&[&message], &mut out)` | `mk.verify(&[&message], &tag)` | frame.rs:61-80, 98-118, 130-135, 148-152 |
| swift | `FrameSession.load` then `session.seal(direction:context:ad:clear:plain:into:)` | `session.open(direction:context:ad:body:clearLength:into:)` | `MacKey.derive` then `mk.tag([message], length: n)` | `mk.verify([message], tag:)` | Frame.swift:40-50, 69-79, 96-103, 121-127 |
| cpp | `packbin::FrameSession::load` then `session.seal(...)` | `session.open(..., opened)` | `packbin::MacKey::derive` then `mk.tag(&part, 1, {out, n})` | `mk.verify(&part, 1, tag)` | handoff.cpp:435-442, 456-465, 476-481, 496 |

Checks: `grep` for `framefmt|subprocess|popen|system(|exec.|ring-cases|vectors.txt` in all eight driver files and in `handoff.cpp` gives no hit. Rust uses the heap-free `packbin::nostd` frame API (the only frame API of the Rust crate), which is the package's real one. All eight print "-" for an empty result and lowercase hex otherwise.

### Q2. Checker independence and fault detection

Independence: `ring_frame.py` imports `framefmt` (the reference) only. At load it re-derives every fixture row with `ff.seal` / `ff.mac_tag` and stops with exit 1 if the fixture disagrees (lines 79-90). Expected values for the comparison are therefore the reference's.

What makes the ring fail (code): per writer, the seal and mac lines are compared one by one with the reference value and the line count is checked (ring_frame.py:153-179); per reader, the open lines must equal the plaintext hex and the verify lines must equal `valid` (lines 184-221); a wrong count marks every pair of that reader unusable (lines 187-190, 194-197, 204-205, 213-214); a non-zero exit of a driver stops the script in `phase` (ring-frame.sh:55-62, under `set -e`). The last line of the script is the checker, so its status is the script's status.

Faults injected by `ring-frame.test.sh` (stand-in driver `fake.py` that answers with the reference):

| Test | Fault | Needle |
|------|-------|--------|
| honest | none; exit 0, "64 pairs", "mismatched: 0" | ring-frame.test.sh:102-106 |
| seal-lies | java flips the last hex digit of its first sealed body (also breaks the 8 java-to-reader open pairs) | "seal gave" |
| open-lies | go answers TagMismatch for its first open row | "open gave" |
| mac-lies | rust flips a tag digit | "mac gave" |
| verify-lies | swift answers invalid for the first verify | "verify gave" |
| reader-prints-too-few | csharp drops its last line in every phase | "printed" |
| driver-crashes | typescript exits 1 in the first phase (seal) | "frame-batch (seal) failed" |
| one-language | RING_FRAME_LANGS=python, 1 pair | "1 pairs" |
| seal-body-changed / mac-tag-changed | fixture row edited | "disagree with the reference" |
| duplicate-id | fixture row repeated | "duplicate id" |

Not covered by the self-test (code paths exist, no test):
- A driver that is too permissive: one whose `open` skips the tag compare, or whose `verify` always says `valid`. The ring never sends a tampered body or a wrong tag, and the fake driver is the reference itself, so no test can show this either. This is G1 below and is the largest hole.
- A driver that prints more lines than asked, or none with exit 0 (the count check handles both; only "one line too few" is tested).
- A crash in a later phase (open, mac, verify); same `phase` code as the tested one.
- A writer that prints a non-hex word (an error kind) in a seal or mac line: the strict readers then crash in the next phase and the script blames the readers (finding C-3).
- Real-driver tampering. By design the self-test needs no toolchain, so it never exercises a real driver; the real drivers are exercised only by the `ring` job.
- The `sed` extraction of `run_lang` from `ring-lib.sh` (ring-frame.sh:38-43) is bypassed by RING_FRAME_RUN in the self-test. If `ring-lib.sh` changes shape, only the real ring job notices.

Note on the matrix: the seal is deterministic and every writer must equal the reference bytes before its pairs can pass, so the 64 open pairs are in effect 8 readers opening the same 8 byte strings. That satisfies the AC text (every seal output is opened by every language) and loses nothing, but the cross-language value is "each language opens the reference bytes", not independent writer-reader interplay. Info only.

### Coverage matrix

Intent baseline: `_docs/02_task_plans/frame-ring/problem.md`, `_docs/02_tasks/todo/AZ-3338_frame_ring.md`, `_docs/loops/loop77/plan77.md`. `scenarios.md` absent for this loop (no `_docs/02_task_plans/frame-ring/scenarios.md`); rows come from the ACs, the Behavior section, and the walk of the code.

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Seal in directions 1, 2, 3 and open by every language | covered | AC-2; ring-cases rows E1/plain0/t8/t16 (dir 1), E2/clear3 (dir 2), E3/E3t16 (dir 3); checker cmd_check; the eight driver calls in Q1 | intake |
| S2 | Seal with tag length 4, 8, 16 | covered | AC-2; rows E1 (4), t8 (8), t16 and E3t16 (16); same code paths | intake |
| S3 | Clear part absent and present (3 bytes) | covered | AC-2; E1/E2/plain0 (none), E3/clear3/t8/t16 (3 bytes); open lines carry `len(clear)` (ring_frame.py:121) | intake |
| S4 | Plaintext of 0 bytes and of 12, 20, 42 bytes | covered | AC-2; plain0 (0), E1 (12), E3 (20), E2 (42); `-` empty token handled by all eight (Q1) | intake |
| S5 | MAC compute by every language and verify by every language, E4/E5, n = 8 and 16 | covered | AC-3; rows E4, E5, n8, n16; cmd_mac_in/cmd_verify_in/cmd_check; the mac and verify calls in Q1 | intake |
| S6 | A wrong, tampered, short or crashing output of one language fails the ring | covered | AC-4, AC-5; ring-frame.test.sh seal-lies/open-lies/mac-lies/verify-lies/reader-prints-too-few/driver-crashes; ring_frame.py:153-221, ring-frame.sh:46-63 | intake |
| S7 | A fixture row that the reference does not confirm stops the run before any driver output is read | covered | AC-4; ring-frame.test.sh seal-body-changed, mac-tag-changed, duplicate-id; ring_frame.py:71-93 | intake |
| S8 | Ring wired in CI after the ECC ring; self-test wired; `cargo test --all-features` in the Rust suite | covered | AC-6, AC-8; test.yml `frame ring` step after `message ECC ring`, self-test step in scaffold; run-suite.sh:312-313; run-suite.test.sh count 14 and "all-features" grep; publish-jobs.test.sh static list and `ring-frame.sh` only-in-ring check | intake |
| O1 | Replay window (Duplicate, TooOld, counter) | out-of-scope | problem.md "## Out of scope": "Replay-window ring (the replay counter is local state, not cross-language wire format)." | intake |
| O2 | Key rotation (previous key opens an older frame) | out-of-scope | problem.md "## Out of scope": "Key-rotation ring (epoch changes are local decisions)." | intake |
| G1 | A tampered body must be refused (TagMismatch) and a wrong tag must be `invalid` in all eight languages | gap-clear | quote below | assess-round-1 |
| G2 | Refusals that today's drivers can express: TooLong, ShortPacket, BadValue | gap-clear | quote below | assess-round-1 |
| G3 | Refusals the drivers cannot express yet: direction not loaded or bad, BufferFull | gap-clear | quote below | assess-round-1 |
| G4 | Body sizes across the 64-byte block edges and up to the 255-byte limit | gap-clear | quote below | assess-round-1 |
| G5 | Epochs 0, 0xFFFF, 0xFFFFFF (multi-byte little-endian in salt and nonce) | gap-clear | quote below | assess-round-1 |
| G6 | Kinds 0 and 8 to 15, msg_id edge values | gap-clear | quote below | assess-round-1 |
| G7 | Associated data empty and 255 bytes; clear part of 40 bytes | gap-clear | quote below | assess-round-1 |
| G8 | MAC: n = 32, labels of 1 and 32 bytes, empty message, block-edge message lengths, message in several parts | gap-clear | quote below | assess-round-1 |
| G9 | AC-7: the Swift `PackbinError.Kind` comment says which raw values are hostile-vector terms and which are frame kinds | gap-clear | quote below | assess-round-1 |
| U1 | Refusals that a typed API cannot receive (key not 32 bytes in Rust; msg_id not 8 bytes in Rust and C++) | gap-unclear | question below | assess-round-1 |

Scenario facts behind G4 to G8, from the fixture (`fixtures/frame/ring-cases.txt`): seal epochs are 1, 5, 7; mac epochs 7, 8, 9; seal kinds 3, 4, 5, 6; AD is 11 bytes in all 8 seal rows (lines 7-28); the largest sealed body is 46 bytes (E2, line 10); the only mac label is `net` (6e6574); mac messages are 24, 5, 20, 20 bytes, each in one part; mac n is 4, 8, 16. None of the vectors.txt seal rows uses an epoch above 7 either (only `keys` rows reach 0xFFFFFF).

### Gaps that need a decision (gap-unclear)

#### U1: Refusals the package cannot be asked

**What is not decided**
Some refusals the contract lists cannot reach the package in Rust and C++ because their frame API takes a fixed-size value: Rust `load_frame` and `MacKey::derive` take `&[u8; 32]` for the key, and Rust and C++ `MsgContext` hold `msg_id` as 8 bytes (`msg_id: [u8; 8]`, `std::uint8_t msg_id[8]`). The other six packages take a byte string and answer BadValue for a key that is not 32 bytes or an id that is not 8 bytes. The Rust driver today panics on a short or long key (frame.rs:45-47) and zero-pads or panics on the id (frame.rs:59-60); the C++ driver pads or cuts the id silently (handoff.cpp:439, 460). A ring row "key of 31 bytes must give BadValue" or "msg_id of 7 bytes must give BadValue" therefore cannot be a real check for those two languages. problem.md and the ACs do not say how such a row is to be treated.

**Options**
- **A — Leave them out of the ring (only refusals every package can receive)**: the ring covers TooLong, ShortPacket, BadValue for kind, epoch, tag length, mac n and label, direction; key length and id length stay in the per-package tests. Trade-off: no cross-language statement about key or id length.
- **B — Row with a "not run by" list, as the hostile vectors do**: the row lists Rust (and C++ for the id) as not run, with the reason; six languages must answer BadValue. Trade-off: the file needs a skip field and the checker must honour it; a silent skip risk, so the list must be checked for every language named exactly once.
- **C — The Rust and C++ drivers answer BadValue themselves when the length is wrong**: all eight print BadValue. Trade-off: for those two languages the driver, not the package, produces the answer, which is the stand-in the project rules forbid; not recommended.

**Recommendation**: A for this task (it needs no decision from the code side and loses little), B later if the owner wants the key and id length rows in the ring.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| G1 | Given a sealed body of E1, E3 and clear3 with one flipped byte in the clear part, the ciphertext and the tag (and a fixture row with a wrong clear_len); When each of the 8 languages opens it; Then all 8 print `TagMismatch` (or `ShortPacket` for a clear_len that is too large). Given a MAC row whose tag has one flipped byte; When each language verifies it; Then all 8 print `invalid`. The checker takes an expected result (`TagMismatch`, `invalid`, ...) from the reference codec, and `ring-frame.test.sh` gets a fake that is too permissive (`open` returns plain for a bad tag, `verify` always `valid`) and expects exit 1. | plan77.md D4: "Ring-cases.txt uses the 5 worked examples (E1–E5) plus length-variation and tamper cases from vectors.txt." problem.md Expected I/O: "`<plain hex>` or `<error kind>` on failure." and "`valid` or `invalid`." | new task on the ring (extend AZ-3338) |
| G2 | Given a seal row with a body of 256 bytes, one with AD of 256 bytes, an open row with a body shorter than clear_len + tag, a seal row with kind 16, epoch 0x1000000, tag_len 5, and a mac row with n = 5 and with a label of 0 and of 33 bytes; When each language runs it; Then each prints the reference error kind (`TooLong`, `ShortPacket`, `BadValue`). The TS driver must first print `ShortPacket` (finding C-1). | problem.md Behavior 2: "On error it prints the error kind." framefmt.py docstring: "Results are the error kind names of the contract: BadValue, TooLong, BufferFull, ShortPacket, TagMismatch, Duplicate, TooOld." vectors README "Coverage": "seal refusals (epoch 0x1000000, direction 0 and 4, `kind` 16, an unloaded direction, `tag_len` 0, 5, 32, `ad` of 256 bytes, a body of 256 bytes ...)" | same |
| G3 | Given a seal or open row for a direction the session did not load, a direction of 0 or 4, and an output buffer one byte too short; When each language runs it; Then each prints `BadValue` (direction) or `BufferFull`. The row syntax needs `dirs` and `out_len` as in vectors.txt, and the drivers must stop aborting on a direction outside 1 to 3 (Java/C# throw, Go/Rust/Swift abort, C++ maps it to Up) and take the buffer size from the row (today a fixed 300 bytes). | vectors README: "`dirs` (default `123`) names the directions the session loaded; `out_len` is the caller's output buffer." and the refusal list quoted at G2 | same |
| G4 | Given plaintext of 63, 64, 65, 128, 192, 251 bytes and a body of exactly 255 bytes; When sealed and opened by all 8; Then bodies equal the reference. | vectors README "Coverage": "plaintext lengths 0, 1, 12, 42, 63, 64, 65, 128, 192, 236, 251"; framefmt.py: `MAX_BODY = 255` | same |
| G5 | Given epochs 0, 256, 0xFFFF, 0xFFFFFF for seal and mac; When all 8 run them; Then outputs equal the reference (the epoch is 4 little-endian bytes in the salt and 3 in the nonce). | framefmt.py: `_salt = LABEL_PREFIX + struct.pack("<I", epoch)` and `nonce = msg_id + bytes([(kind << 4) \| d]) + struct.pack("<I", epoch)[:3]`; `MAX_EPOCH = 0xFFFFFF`; vectors README: "epochs 0, 1, 7, 0xFFFF and 0xFFFFFF" | same |
| G6 | Given kinds 0, 8, 15 (nonce byte 0x80 and above) and msg_id values 0000000000000000 and ffffffffffffffff; When all 8 seal and open them; Then bodies equal the reference. | framefmt.py `nonce` as above; `_args`: "kind > 15 or kind < 0 ... BadValue" (so 0 to 15 are the valid kinds) | same |
| G7 | Given AD empty (`-`), AD of 255 bytes and a clear part of 40 bytes; When all 8 seal and open; Then equal to the reference. | vectors README: "clear parts of 0, 3, 40 bytes; `ad` of 0, 11, 255 bytes"; fixture header: "\"-\" is empty." | same |
| G8 | Given a mac row with n = 32, labels of 1 and of 32 bytes, an empty message, messages of 55, 56, 63, 64, 119, 120, 255 bytes and a row that gives the message in two or three parts; When all 8 compute and verify; Then tags equal the reference and do not depend on the split. | pack-session text in the packages: "`n` of 4, 8, 16 or 32" and "the tag does not depend on how it is split" (python/src/packbin/_mac_key.py docstring, cpp frame.hpp MacKey comment); vectors README: "labels of 1 and 32 bytes ... `n` of 4, 8, 16, 32 ... messages of 0, 5, 55, 56, 63, 64, 119, 120 and 255 bytes each in one, two and three parts" | same |
| G9 | Given the Swift `PackbinError.Kind` doc comment; When read; Then it names which raw values are hostile-vector terms (`short_packet`, `trailing_bytes`, `bad_value`, `too_many`, `type_mismatch`, `scheme_error`, `pack_error`), which are message-ECC kinds (`uncorrectable`, `too_long`) and which are frame kinds (`tag_mismatch`, `duplicate`, `too_old`, `buffer_full`), and does not say the frame raw values "match `fixtures/frame/`" (that file spells `TagMismatch`, `Duplicate`, `TooOld`, `BufferFull`). | AC-7: "The Swift `PackbinError.Kind` doc comment accurately describes which raw values are hostile-vector terms and which are frame-mode kinds." fixtures/frame/README.md: "Error kinds: `BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`." fixtures/hostile/README.md line 23 lists the hostile terms | AZ-3338 (finish AC-7) |

### Code findings (ranked)

**Critical**: none.

**High**: none. Nothing in the diff lets the ring pass when a language gives a wrong seal, open, mac or verify result for the 12 rows (each writer output and each reader output is compared with the reference). The High-impact item is a coverage hole, G1: a permissive `open` or `verify` passes. It is recorded as a gap, not as a defect, because the ACs ask only for the positive matrix.

**Medium**
- M-1 (latent, proven). TypeScript driver prints `error` instead of `ShortPacket`. `handoff-frame.ts:21-24` reads the name from `result.kind`, and `KIND_MAP` (lines 26-32) maps the key `short`. The TS short-body result is `{ ok: false, field: "body", needed, left }` (typescript/src/frame-session.ts open, `if (body.length < framing) return { ok: false, field: "body", ... }`; `ShortErr` in kinds.ts:6 has no `kind`), so `errKind` returns "error". Failing input once a refusal row exists: `open <32-byte key> 1 1 4 00301005e8030000 4 - 0 aabb` (2-byte body, tag 4): reference `ShortPacket`, other 7 print `ShortPacket`, TS prints `error`. Also `duplicate` and `too_old` would print in snake case (`KIND_MAP` has no entry), unreachable until the replay window enters the ring. No effect on the 12 current rows.

**Low**
- L-1 hex and empty-token rule differs between drivers. Strict (reject bad hex, process exits non-zero): python `bytes.fromhex` (handoff_frame.py:23), csharp `Convert.FromHexString` (HandoffFrame.cs:6), go (frame.go:18-21 panic), rust (frame.rs:12 panic). Lenient: typescript `Buffer.from(token, "hex")` (handoff-frame.ts:14) cuts at the first bad digit or odd digit; swift `hexBytes(token) ?? []` (Frame.swift:5) turns any bad token into an empty array; cpp `ecc_bytes` (handoff.cpp:306-313) drops an odd last digit and `stoul` stops at the first non-hex character of a pair (`dV` gives 0x0d); java `Handoff.parse` (Handoff.java:352-358) drops an odd last digit. Failing input: `open <key> 1 1 4 <id> 4 - 0 abc` gives an exception in python, a 1-byte body in ts, cpp and java, an empty body in swift. It cannot produce a false pass today (each writer's output is compared with the reference first, so a bad token fails there), but it breaks the "one rule" the header of `ring-cases.txt` states and the swift `?? []` is a silent discard (coderule: "discarded error returns are forbidden").
- L-2 a writer that prints a non-hex word makes the readers crash instead of being reported. `ring_frame.py:114-121` (open-in) and `137-143` (verify-in) check only the line count, not that each line is hex. Failing input: a writer whose first seal answer is `TooLong`: `open.in` then holds `open ... TooLong` for that writer, python raises ValueError in `bytes.fromhex`, `phase open` fails with "python frame-batch (open) failed" (and csharp, go, rust, java the same), the checker never runs, and the message names the readers, not the writer. Exit is non-zero, so the ring still fails; only the diagnosis is wrong. Fix: write `open-skip` / `verify-skip` for a line that is not hex (the checker already reports the writer's bad line in `bad_seal_writers`). Not covered by the self-test.
- L-3 Go driver discards parse errors: `epoch, _ := strconv.Atoi(w[1])` and 11 more (12 in all: frame.go:64-68, 87-93, 111-113). A malformed epoch becomes 0 and the row runs on; a malformed direction panics (negative shift). Also `scan.Err()` is not read (frame.go:167-175): a line over 1 MiB ends the loop with exit 0 (caught later by the line count). Coderule: never discard error returns.
- L-4 drivers cannot express some refusals, so G3/U1 rows will need driver work first: `frame_dir` returns Up for a direction outside 1 to 3 (handoff.cpp:419-427) and `1 << (d - 1)` is undefined for d = 0 (lines 436, 457); Java and C# throw, Go, Rust and Swift abort (`fatalError`), python raises for d = 0; Rust zero-pads a short `msg_id` and panics on a long one and on a key that is not 32 bytes (frame.rs:45-47, 59-60, 96-97); C++ pads or cuts the id (handoff.cpp:439, 460). Fixed 300-byte buffers (all drivers) make `BufferFull` unreachable.
- L-5 AC-7 comment is inexact (PackbinError.swift:4-5): "frame-mode kinds match `fixtures/frame/`" is not true by spelling (`tag_mismatch` against `TagMismatch`), it does not say which raw values are which, and the ECC raw values `uncorrectable` and `too_long` are not hostile-vector terms either (they come from fixtures/ecc/vectors.txt). Better than before, not what AC-7 asks.
- L-6 problem.md Expected I/O says the driver lines start with `<case>`; the lines the checker writes omit it (ring_frame.py:105, 120, 129, 143) and the drivers read from the key. Harmless; the spec text is stale.

**Info**
- I-1 the 64 open pairs are 8 openings of the same bytes (see Q2 note).
- I-2 `ring-frame.test.sh` proves the script and the checker, not the drivers (by design); the real drivers are exercised only by the `ring` job.
- I-3 O2 reason: "epoch changes are local decisions" is true for the choice to rotate, but the nonce built when the previous slot opens a frame uses the previous epoch (framefmt.py open_frame, `nonce(msg_id, kind, d, e)` with the slot's own epoch), a cross-language rule. The owner declared the ring out of scope; noted only so the decision is made knowing this. It stays `out-of-scope`.
- I-4 Files checked clean: no unquoted expansion in ring-frame.sh and ring-frame.test.sh, `$io` and `$tmp` are removed by `trap ... EXIT`, no stderr silencing (`2>` goes to files that `phase` prints on failure), `__pycache__` is git-ignored. Both scripts keep bash 3.2 syntax (`read -r -a`, no `mapfile`). File modes 100755.
- I-5 the commit message of d0b8525 says the real ring ran on the Mac with 64 pairs, 0 mismatched. Not re-run here.

### Not walked

- Several directions loaded at once (session loaded with all three) against the single-direction load the drivers use: per-package tests cover it, no interop effect.
- Concurrent use of one session by several threads: package-local.
- The `ring` job container variants (gcc image, Swift image) beyond what d0b8525 reports.
- Rows from `vectors.txt` replay-window and previous-slot sections (O1, O2).

### Harness gaps

- No `scenarios.md` for this loop (pre-4.7 style task): rows were taken from the ACs and Behavior list.
- No batch report or implementation report for loop 77 was present, so Step 1 (`## Discovered during implementation`) had no input; the discoveries of d0b8525 (C++ link, TS FrameDirections class, Java private constructor, Swift stderr, run-suite counts, self-test wiring) were taken from its commit message only.

## Round 2

**Date**: 2026-10-27
**Implement pass**: commit aecb76d (AZ-3341) on top of 1e2bb45 and d0b8525; no batch report or implementation report for loop 77 was given or found (same harness gap as round 1)
**Verdict**: CLARIFY — 17 covered / 6 out-of-scope / 2 gap-clear / 1 gap-unclear

Read-only review of `git diff d0b8525..aecb76d` and the files it touches. Nothing was run (ring, suites, docker, cargo, dotnet, gradle, swift). Row facts below come from `awk` and `grep` over `fixtures/frame/ring-cases.txt`. Evidence that the real ring passes is the parent's own log in the scratchpad (`smoke-trial.log`, step 3: "64 pairs and 8 x 16 refusals, 0 mismatched"; `ring-frame.log`, an earlier run, shows `refusals typescript: 16 rows, 1 mismatched` before the TypeScript fix). I did not re-run either.

Accepted by the owner on 2026-10-27, counted as out-of-scope and not as gaps: G2 (TooLong, ShortPacket by row, BadValue refusal rows), G3 (direction not loaded, BufferFull), U1 (key and msg_id length refusals), multi-part MAC messages. Still open and not in AZ-3341, not counted: L-1 (lenient hex in ts/swift/cpp/java), L-2 (a writer's non-hex line crashes the readers instead of being blamed), L-3 (Go discards parse errors).

### Answers (short form)

1. Nine of the eleven ACs hold from the code. AC-4 holds for seal rows only: no MAC row uses epoch 0, 65535 or 16777215 (gap G5m). AC-8 holds for "exit 1" and for the refusal path being reached, but the self-test needles do not contain a row id, so "names the row" is true in the code and not asserted (gap N1). AC-11 is a run, not a code line; the parent's log says it passed on the Mac, the CI `ring` job has not been seen.
2. No vacuous pass for a non-empty row set. One vacuity exists for an empty one: the loader does not require an `open` or a `verify` row (see Q2 below).
3. Yes for a reader that accepts a tampered body and for a verify that always says valid. No for the `refusals <lang>: N rows, M mismatched` line, which no CI script asserts. A reader with the right count and wrong names is covered by the same equality test; the specific swap "TagMismatch for the ShortPacket row" is not isolated.
4. New angles are in the matrix: N1 (gap-clear), N2 and N3 (covered), G8e (gap-unclear).
5. No defect of the kind "the ring passes while a package is wrong". Provable weak points are listed under "Code findings".

### Q1. Per AC: what makes it hold

| AC | Rows / test / code | Holds? |
|----|--------------------|--------|
| AC-1 tampered bodies | `fixtures/frame/ring-cases.txt` open rows: E1.ct (97), E1.tag (99), E1.ad (101), E1.id (103), E1.epoch (105), E3.clear (107), E3.ct (109), E3.clearlen (111), clear3.tag (113), t16.tag (115), E3.short (117, body 6 bytes < clear 3 + tag 4, expected ShortPacket). Compared by name at `scripts/frame/ring_frame.py:264-267`; `got != want` ends in `total_wrong` (line 275) and exit 1 (line 283). Each position has a row: clear part (E3.clear), ciphertext (E1.ct, E3.ct), tag (E1.tag, clear3.tag, t16.tag). Not every one of E1, E3, clear3 has all three; the AC wording is met per position. | yes |
| AC-2 wrong tags | verify rows E4.first (119), E4.last (121), n16.first (123), n16.last (125), plus E4.msg (127). First/last byte changes checked by eye against E4 `56db9bec` and n16 `9f44...aa7d`. Compared at `ring_frame.py:271-274` against the constant `invalid`. | yes |
| AC-3 body sizes | seal rows p63, p64, p65, p128, p192, p251 (49-59; plaintext 63, 64, 65, 128, 192, 251; the last gives body = 255) and c40p211 (61, body = 255). Pass through the writer-reader matrix: writer compare `ring_frame.py:193-195`, reader plaintext compare `240-243`. | yes |
| AC-4 epochs | Seal: ep0, ep65535, epmax (63, 65, 67). MAC: the 11 mac rows have epochs 7, 8, 9, 9, 4, 4, 4, 4, 4, 4, 4 (lines 35-44, 79-91). No MAC row with epoch 0, 65535 or 16777215. The AC says "seal and MAC rows". | half: G5m |
| AC-5 kinds, ids | k0 (69, kind 0, id all 00), k8 (71), k15 (73, kind 15, id all ff). | yes |
| AC-6 AD, clear | ad0 (75, AD `-`), ad255 (77, AD 255 bytes), c40p211 (61, clear 40 bytes). | yes |
| AC-7 MAC variants | mac32 (79, n = 32), lab1 (81), lab32 (83), msg0 (85, message `-`), m63, m64, m65 (87-91). Writer compare `ring_frame.py:207-209`; verify chunk `248-251` expects `valid`. | yes |
| AC-8 permissive driver fails the self-test | `ring-frame.test.sh:62-63` (open-permissive turns TagMismatch/ShortPacket into `00`), `74-75` (verify-permissive), cases `118-119`, `run` asserts the exit code (line 94) and a needle (line 98). Needles are `wanted TagMismatch` and `wanted invalid`; the failure line does carry the row id (`ring_frame.py:267`, `274`: `go: E1.ct open gave 00, wanted TagMismatch`) but no test asserts it. | exit 1: yes; "names the row": not asserted (N1) |
| AC-9 TypeScript short packet | `handoff-frame.ts:23` (`"field" in result` returns `short`, mapped to `ShortPacket` at line 30); row E3.short (117). Real TS result for a short body is `{ ok: false, field: "body", ... }` (`typescript/src/frame-session.ts:191`). Parent's earlier log shows the row failing without the fix. | yes |
| AC-10 Swift comment | `swift/Sources/Packbin/PackbinError.swift:4-8` names `short_packet`, `bad_value`, `too_long`, `buffer_full`, `tag_mismatch`, `duplicate`, `too_old` and the Pascal spellings. Matches the AC text. Wording note in "Code findings" (F-6). | yes (literal) |
| AC-11 ring passes for real | `test.yml:94-95` (ring job step). Parent's `smoke-trial.log` step 3 PASS on the Mac. CI not observed. | not re-run here |

### Q2. Can the refusal comparison pass vacuously?

Slicing, read from `ring_frame.py`:

- `cmd_open_in` (135-151) writes, per writer in `writers` order, exactly `len(rows.seal)` lines: the open lines of a usable writer, or `len(rows.seal)` lines of `open-skip` for an unusable one (140-143). The refusal lines come after the loop (147-149; same indent as `for writer`). So `open.in` = `S * W` writer lines, then `R` refusal lines. Skip lines shift nothing. `verify.in` has the same shape (162-176).
- A driver prints one line per input line (header of `ring-frame.sh`, lines 8-10). `cmd_check` requires `len(open_lines) == S * W + R` (218-221) and `len(verify_lines) == M * W + R'` (225-228), else it sets the list to `None`, adds a note, and both the pair lines and the refusal block report "no usable ... output" (236-237, 245-246, 261-262, 268-269). Too few and too many lines both fail; a blank line from a driver is dropped by `read_lines` (line 43, `if line.strip()`), which shortens the list and fails the count.
- With the count exact, `tail = open_lines[S * W:]` has exactly `R` lines and `zip(rows.refuse_open, tail)` loses nothing (264-265, 271-272). The names are compared with `!=` against the name from the file, which the loader has already matched to the reference (101-107).

I could not construct a vacuous pass with a non-empty row set. What exists:

- **Empty set.** The loader requires seal and mac rows (70-73) but no `open` or `verify` row. Concrete input: `ring-cases.txt` with the 11 open and 5 verify rows deleted (or a `RING_FRAME_CASES` file without them). `ring-frame.sh` then prints `refusals <lang>: 0 rows, 0 mismatched` for all eight readers and exits 0 with real drivers. The only guard is `ring-frame.test.sh` cases `open-permissive` and `verify-permissive` (118-119), which run on the real file and would report "exit 0, wanted 1"; that self-test runs in the `scaffold` job (`test.yml:381`), not in `ring`. A partial deletion (one open row and one verify row left) is caught by nothing. Recorded as N1.
- **Display only.** `refused[:5]` (277-278) shows five lines per reader and the open failures come first, so a reader that is wrong on 5 or more open rows never names a failing verify row. The count in `refusals <lang>: 16 rows, N mismatched` is right.
- **Latent loader crash, not a vacuity.** `ff.mac_verify(...)` at `ring_frame.py:113` sits outside a `try`; for a verify row whose tag is not 4, 8, 16 or 32 bytes the reference raises `Fault("BadValue")` (`framefmt.py:177-179`, `185-186`), which is not a `FileError`, so the run ends in a Python traceback (exit 1). No current row does this.

### Q3. Does the self-test prove the permissive cases?

| Case | Result |
|------|--------|
| Reader accepts tampered body (`open-permissive`, go) | Proves it: `00` instead of the error name on every refusal open row, exit 1, needle `wanted TagMismatch` only appears in the refusal block. |
| Verify always valid (`verify-permissive`, swift) | Proves it: needle `wanted invalid` only appears in the refusal block. |
| Right count, wrong names | Covered by the same `!=` (a swap to `00` has the right count). The swap of one name for the other (TagMismatch on the ShortPacket row) is not isolated; no test. Loop-local `smoke77.sh` step 4 covers one real case (TypeScript `error` for E3.short). |
| Too many lines | Not tested; same `!=` as the tested "too few" case (`ring_frame.py:219`). |
| `refusals <lang>: N rows, M mismatched` line | Not asserted. The honest case checks only `ring-frame: 64 pairs, ` and `mismatched: 0$` (107-111). Deleting the refusal block from `cmd_check` is caught indirectly (open-permissive would exit 0); changing the printed text is not. |
| Corrupted new rows | `open-name-changed` (136-137) and `verify-tag-made-valid` (138-139) check that the loader stops with "disagree with the reference". Each `corrupt` call checks that the copy changed (127-130). |

### Coverage matrix (round 2; all rows re-classified)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Seal in directions 1, 2, 3 and open by every language | covered | AZ-3338 AC-2; rows E1, E2, E3, clear3 (dir 1, 2, 3); `ring_frame.py:193-195, 240-243`; 8 drivers | intake |
| S2 | Tag length 4, 8, 16 | covered | AZ-3338 AC-2; E1, t8, t16, E3t16, p128 (8), p192 (16) | intake |
| S3 | Clear part absent and present | covered | AZ-3338 AC-2; E3, clear3, t8, t16, c40p211 | intake |
| S4 | Plaintext of 0, 12, 20, 42 bytes | covered | AZ-3338 AC-2; plain0, E1, E3, E2 | intake |
| S5 | MAC compute and verify, n = 8 and 16 | covered | AZ-3338 AC-3; E4, E5, n8, n16; `ring_frame.py:207-209, 248-251` | intake |
| S6 | A wrong, tampered, short or crashing output fails the ring | covered | AZ-3338 AC-4, AC-5; `ring-frame.test.sh:112-121`; `ring_frame.py:153-221` | intake |
| S7 | A fixture row the reference does not confirm stops the run | covered | AZ-3338 AC-4; `ring-frame.test.sh:132-141`; `ring_frame.py:83-116` | intake |
| S8 | Ring and self-test wired in CI | covered | AZ-3338 AC-8; `test.yml:94-95, 380-381`; `publish-jobs.test.sh:193, 204` | intake |
| O1 | Replay window | out-of-scope | problem.md "Out of scope": "Replay-window ring (the replay counter is local state, not cross-language wire format)." | intake |
| O2 | Key rotation | out-of-scope | problem.md "Out of scope": "Key-rotation ring (epoch changes are local decisions)." | intake |
| G1 | Tampered body refused alike; wrong tag `invalid` (all 8) | covered | AZ-3341 AC-1, AC-2, AC-8, AC-9; rows 97-127; `ring_frame.py:96-116, 259-278`; `ring-frame.test.sh:118-119, 136-139`; `handoff-frame.ts:23` | assess-round-1 |
| G2 | Refusal rows TooLong, ShortPacket by row, BadValue | out-of-scope | accepted by the owner 2026-10-27 (deferred to a later loop; `vectors.txt` holds the rows and all 8 packages read it); AZ-3341 `### Excluded` first bullet | assess-round-1 |
| G3 | Direction not loaded or bad, BufferFull | out-of-scope | same line: "they need `dirs` and `out_len` columns in the rows and drivers that stop aborting on a bad direction" | assess-round-1 |
| G4 | Body sizes across 64-byte edges and up to 255 | covered | AZ-3341 AC-3; rows p63..p251, c40p211 (49-61) | assess-round-1 |
| G5 | Epochs 0, 65535, 16777215 in seal | covered | AZ-3341 AC-4 (seal half); rows ep0, ep65535, epmax (63-67) | assess-round-1 |
| G5m | The same epochs in MAC rows | gap-clear | table below | assess-round-2 |
| G6 | Kinds 0, 8, 15; ids all 00 and all ff | covered | AZ-3341 AC-5; rows k0, k8, k15 (69-73) | assess-round-1 |
| G7 | AD empty and 255 bytes; clear part of 40 | covered | AZ-3341 AC-6; rows ad0, ad255, c40p211 | assess-round-1 |
| G8 | MAC n = 32, labels 1 and 32, empty message, 63/64/65 bytes | covered | AZ-3341 AC-7; rows 79-91 | assess-round-1 |
| G8m | MAC message in several parts | out-of-scope | AZ-3341 `### Excluded`: "MAC messages in several parts (needs a new driver line format)" | assess-round-1 |
| G8e | MAC message lengths 55, 56, 119, 120, 255 (SHA-256 padding edges) | gap-unclear | question below | assess-round-2 |
| G9 | Swift `PackbinError.Kind` comment | covered | AZ-3341 AC-10; `PackbinError.swift:4-8` | assess-round-1 |
| U1 | Key or msg_id of the wrong length | out-of-scope | owner 2026-10-27, option A; AZ-3341 `### Excluded` second bullet | assess-round-1 |
| N1 | The self-test pins what AZ-3341 promises: the `refusals` line, the row id in a failure line, a minimum of refusal rows | gap-clear | table below | assess-round-2 |
| N2 | Readers of the ring output (`pair`, `refusals`, total line) | covered | AZ-3341 Constraints ("The checker line ... keeps its shape"); `ring_frame.py:255, 276, 282`; `ring-frame.test.sh:107-111`; `_docs/loops/loop77/smoke77.sh` step 3 greps `^pair .*, 0 mismatched$` (64) and `^refusals [a-z]*: 16 rows, 0 mismatched$` (8): formats match. `test.yml` and `publish-jobs.test.sh` only run the script and parse nothing. | assess-round-2 |
| N3 | The two new row kinds in the cases file | covered | AZ-3341 Unit Tests (AC-1, AC-2); `ring_frame.py:96-116`; `ring-frame.test.sh:136-139`; header lines 4-5 of `ring-cases.txt` | assess-round-2 |

### Gaps that need a decision (gap-unclear)

#### G8e: MAC message lengths at the SHA-256 padding edges

**What is not decided**
Round 1 (G8) listed the MAC message lengths of `vectors.txt` as 0, 5, 55, 56, 63, 64, 119, 120 and 255. AZ-3341 AC-7 took 63, 64 and 65 and dropped the rest without an `### Excluded` line. 63, 64 and 65 are the edges of the 64-byte ChaCha20 block (which the seal rows use). The MAC is HMAC-SHA256 (`scripts/frame/framefmt.py:26-27, 177-182`), whose padding edge for the message is 55/56 and 119/120 (the inner hash starts with a 64-byte key block). No row sits there: MAC messages are 0, 5, 20, 24, 63, 64, 65 bytes, and the seal tag input (`12 + 1 + ad + 1 + clear + ciphertext`, `framefmt.py:76-78`) is 25 to 289 bytes in the current rows, none at 55, 56, 119, 120, 183, 184, 247 or 248. Whether any package hand-rolls SHA-256 was not checked. The per-package tests already read these lengths from `vectors.txt`.

**Options**
- **A — Add rows for 55, 56, 119, 120 (and 255)**: four to five one-line mac rows, no driver work, `ring_frame.py` unchanged. Trade-off: five more lines in the fixture.
- **B — Leave as is**: the ring keeps 63/64/65; the edges stay a per-package test. Trade-off: a padding bug in one package is seen only by that package's own tests, not by the cross-language ring.

**Recommendation**: A — it costs a few lines and the ring is where a disagreement between two packages would show.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| G5m | Given MAC rows with epochs 0, 65535 and 16777215 (for example `mac ep0`, `mac ep65535`, `mac epmax`, any key, label `net`, n = 8); When every language computes the tag and every language verifies it; Then all tags equal the reference and verify to `valid`. | AZ-3341 AC-4: "Given seal and MAC rows with epochs 0, 65535 and 16777215 / When each language runs them / Then all outputs equal the reference". The MAC key salt is `LABEL_PREFIX + struct.pack("<I", epoch)` (`framefmt.py:40-41`, used by `label_key`, 60-65); each package derives it in its own `MacKey.derive`, so a MAC-only epoch bug is invisible to the seal rows. | AZ-3341 (finish AC-4) |
| N1 | Given the honest run of `ring-frame.test.sh`; When it ends; Then the output has eight lines `refusals <lang>: N rows, 0 mismatched` with N equal to the number of `open` plus `verify` rows in the cases file (counted with `grep -c`, as `smoke77.sh` step 3 does). Given a failing permissive case; When it fails; Then the output also contains a row id (`E1.ct` for open-permissive, `E4.first` for verify-permissive). Optionally: the loader stops with "no open rows" / "no verify rows" as it does for "no seal rows" (`ring_frame.py:70-73`). | AZ-3341 Scope Included: "prints one line per reader for them"; AC-8: "the ring exits 1 and names the row"; Unit Tests table: "exit 1, output names the row". | AZ-3341 (finish AC-8) |

### Code findings

**Critical, High**: none. Nothing in aecb76d lets the ring pass while a package gives a wrong seal, open, mac or verify result for the 34 positive rows (23 seal, 11 mac), or accepts one of the 16 tampered rows (11 open, 5 verify).

**Medium**
- F-1. AC-4 stated, not checked for MAC (G5m above). `grep` over `ring-cases.txt`: MAC epochs 7, 8, 9, 4 only.

**Low**
- F-2. Empty refusal set passes the ring job (Q2, "Empty set"): `ring_frame.py:70-73` requires only seal and mac rows. Guarded only by the self-test in another CI job, and only against deleting all rows of a kind.
- F-3. `refused[:5]` (`ring_frame.py:277-278`) hides verify failures behind open failures. Display only.
- F-4. Self-test needles (`ring-frame.test.sh:118-119`) do not contain a row id or the `refusals` line (N1).
- F-5. Latent loader crash: `ring_frame.py:113` calls `ff.mac_verify` outside a `try`; a verify row with a tag of 3 or 5 bytes ends in a traceback, not a `FileError`. Also the file's expected word for a verify row is dropped (`refuse_verify` has no expected field, line 116) and the check hard-codes `invalid` (line 273): a row written `... valid` is accepted by the loader and then makes every reader fail with "wanted invalid". Loud, not vacuous; no current row.
- F-6. Swift comment wording (`PackbinError.swift:4-5`): "The pack and unpack kinds match the shared hostile vectors" is read as covering every pack and unpack kind, but `uncorrectable` and `too_long` (thrown by `unpackRepair`, `Ecc.swift:172-186`, `Unpack.swift:18-19`) are not hostile-vector terms (`fixtures/hostile/README.md`, outcome terms). AC-10 as written is met; the original AZ-3338 AC-7 asked for an accurate split, which is still slightly loose.

**Info**
- I-1. Still open and not in AZ-3341: L-1 (lenient hex), L-2 (a writer's non-hex line crashes the readers). One more fact for L-2: seven drivers answer `open-skip` / `verify-skip` with `skip` (C++ `handoff.cpp:504`, TS `handoff-frame.ts:88`, Java `HandoffFrame.java:114`, C# `HandoffFrame.cs:99`, Go `frame.go:152`, Rust `frame.rs:165`, Swift `Frame.swift:136`); the Python driver does not and raises `ValueError("frame line: open-skip")` (`handoff_frame.py`, `_line`, last `raise`). L-3 (Go discards parse errors).
- I-2. The pair line now says `34 rows` (23 seal + 11 mac), was 12; nothing parses the number.
- I-3. The self-test still proves the script and the checker, not the drivers (round 1 I-2); a real permissive package is caught only by the `ring` job.

### Not walked

- Tampered `kind`, tampered direction, tampered `tag_len` on an open row (the writer compare already pins the nonce byte `(kind << 4) | d`, so only an `open` that ignores them would slip through; no spec line asks for them).
- A verify row with a changed label or epoch.
- Tampering the clear part or ciphertext of clear3 and the tag of the 4-byte E3 (E3.clear, E3.ct and clear3.tag, t16.tag cover each position once).

### Harness gaps

- No batch report or implementation report for loop 77 (same as round 1).
- `scenarios.md` rows G2 and G3 are `deferred` and G5 / G8 read as confirmed in full; if the parent wants the file to match this matrix: G2, G3 `out-of-scope (owner 2026-10-27)`, G5 split into seal (confirmed) and MAC (new row G5m), G8 note "63/64/65 only", new rows G8e and N1. Not edited here (read-only run).
