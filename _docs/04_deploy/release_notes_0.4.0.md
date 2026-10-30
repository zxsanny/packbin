# Release notes 0.4.0 (draft)

Draft written in loop 88 (AZ-3435) from HEAD and the loop records since `v0.3.0` (2026-10-16). The body between the two rules is meant to be pasted as the body of the GitHub release for the tag `v0.4.0`. The section after it is for the publisher and is not part of the release. Nothing here tags, publishes or uploads.

---

## packbin 0.4.0

The first release since 0.3.0 (2026-10-16). Packbin still has eight language implementations with the same bytes for the same data: C#, TypeScript, Python, Rust, C++, Java, Go and Swift. This release changes how strings are written, adds optional error correction and one authenticated session, and makes the Rust core usable on a microcontroller without a heap.

**This release breaks compatibility in three places** (see [Breaking changes](#breaking-changes)): the stream session is removed, every string is written in a new compact form, and a dictionary with keys out of order is refused.

### New

- **Compact text.** Every string field, list element, dictionary key and dictionary value is written as a varint length and a bit stream coded with a table per mode (Ukrainian, Russian, English, numbers), with a raw UTF-8 fallback. On the 1,000-message test sets of `fixtures/text/tables.report.md` the result is, for lowercase text, 35.5 % of the old size for Ukrainian, 34.5 % for Russian and 57.1 % for English; for text as written (capitals kept) 37.7 %, 36.2 % and 59.8 %; for numbers 50.7 %. A string is never larger than before up to 126 UTF-8 bytes and at most 2 bytes larger above that. A flipped bit damages only the characters of its own string. Contract: `compact-text` 1.0.0, ADR-006.
- **Message error correction (opt in).** A scheme can declare 0 to 32 parity bytes (default 0). Unpack detects up to that many wrong bytes and, if the receiver asks, repairs up to half of them. The code is Reed-Solomon over GF(256), in all eight languages, for messages of at most 254 bytes. With 0 parity bytes the bytes and the errors are those of 0.3.0. Contract: `message-ecc` 1.0.1, ADR-007.
- **Frame session, in all eight languages.** For links that lose, reorder and duplicate messages and that anyone can write to, such as a radio. Each message carries a caller-supplied 8-byte `msg_id`; keys come from a 32-byte key and a 24-bit epoch with nothing sent first; the tag is a truncated HMAC-SHA256 of 4, 8 or 16 bytes, checked before any plaintext is written. A MAC-only call gives a 4-byte network check over a message in parts. The names match everywhere: `FrameSession` and its companions. **Never seal two different messages with the same `msg_id` under one key, epoch and direction**: packbin cannot check it and the reuse breaks the confidentiality of both. Contract: `pack-session` 3.0.0, ADR-008 and ADR-009.
- **Rust without a heap.** `packbin::nostd` is a buffer-based API that builds with `#![no_std]` and no allocator. The Cargo features `text`, `ecc` and `frame` switch on the compact text, the error correction and the frame session; the default feature `std` keeps the allocating API (without the stream session). CI builds it for Cortex-M4F and Cortex-M33F, runs it under QEMU and holds the flash and stack of each feature set to a pin.
- **Microcontroller targets.** The target part is the nRF54L15 (Cortex-M33F): the C++ core with the codec and error correction on is held to 64 KB of flash and 8 KB of stack, and the Rust sets have their own pins. The Cortex-M4F bar of 0.3.0 is kept. The C++ core also compiles and links for the Arduino Uno (ATmega328P, avr-gcc 7.3); no AVR image is run.
- **TypeScript package.** The npm package ships compiled ES-module JavaScript and `.d.ts` files, so plain Node 22+ and `tsc` projects import `packbin` without flags. Only the `packbin` entry point is exported.

### Breaking changes

- **The stream session is removed** (ADR-009). `PackSession` is gone in C#, TypeScript, Python, Rust, C++, Java, Go and Swift, together with the Rust `session` Cargo feature, the Rust heap-free stream calls (`Session::load`, `start`, `join`, `pack`, `unpack` on a seed) and the C++ `RandomFn` and `os_random`. A caller of them gets a compile or import error. Frame mode is the one session; move to `FrameSession`. The stream session did not authenticate and needed lossless, ordered delivery; over `wss` it added nothing.
- **Strings are written differently.** There is no version byte, so a packet written by 0.3.0 reads as an error or as other text in 0.4.0, and the reverse. Peers on either side of a string field must upgrade together. Packets with no string field are unchanged: the golden bytes (`4001000065cd1d00a3e1110100`) are the same. The code-length tables are part of the format and frozen.
- **A dictionary is refused if its keys are not strictly ascending** by UTF-8 byte order on unpack, in all eight languages. Every encoder already writes keys in that order, so only hand-made or hostile packets are affected.

### Build and CI

- A cross-language ring packs in one language and unpacks in each of the eight (64 pairs), for clear and for error-corrected packets. A frame ring does the same for sealed frames: every language seals every row, every language opens what every language sealed (64 pairs), every MAC is computed and verified across languages, and tampered input is refused alike by all eight.
- The golden bytes are checked in all eight languages before any registry write, as in 0.3.0.

### Install

| Language | How |
|----------|-----|
| C# | NuGet `Packbin` 0.4.0 |
| TypeScript | npm `packbin@0.4.0` |
| Python | PyPI `packbin==0.4.0` |
| Rust | crates.io `packbin` 0.4.0 |
| Java | Maven Central `io.github.zxsanny:packbin:0.4.0` |
| C++ | the vcpkg registry of this project (`packbin` port) |
| Go | `go get github.com/zxsanny/packbin/go@v0.4.0` (tag `go/v0.4.0`) |
| Swift | `.package(url: "https://github.com/zxsanny/packbin", from: "0.4.0")` |

Details: `_docs/04_deploy/packages.md`.

---

## For the publisher (not part of the release)

- **The version comes from the tag.** The manifests carry a placeholder (`rust/Cargo.toml` says `0.1.0`); the `v*` tag push publishes the registries and pushes `go/v0.4.0` (ADR-002, ADR-004).
- **CS-D5 is decided: the tables stay (owner, 2026-10-30).** The compact text tables are frozen as part of the format and ship as trained on Tatoeba sentences. The owner gathers statistics from real usage first; retraining them afterwards is another wire break for every string field.
- **F44, steps for the owner (repository admin).** The repository has no tag ruleset on `v*` (the rulesets API returns none on 2026-10-30), so a moved or deleted tag is not guarded outside the publish workflow. Apply it before the `v0.4.0` tag. The agent applies nothing, and the command below was not run by the agent.
  1. In the GitHub UI: Settings, Rules, Rulesets, New tag ruleset. Name `protect-release-tags`, enforcement Active, target `refs/tags/v*`, rules Restrict updates, Restrict deletions and Block force pushes. Leave Restrict creations off (you push the tag) and add no bypass actor. Or run, with a `gh` logged in as admin:

     ```bash
     gh api -X POST repos/zxsanny/packbin/rulesets --input - <<'EOF'
     {
       "name": "protect-release-tags",
       "target": "tag",
       "enforcement": "active",
       "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
       "rules": [{"type": "update"}, {"type": "deletion"}, {"type": "non_fast_forward"}]
     }
     EOF
     ```

  2. Check it: `curl -s https://api.github.com/repos/zxsanny/packbin/rulesets` (the repository is public) lists `protect-release-tags` as active. Do not test the block by pushing a throwaway `v*` tag: any `v*` push starts the publish run. The listing, with the three rules, is the check.
  3. Cautions. The ruleset covers the four existing `v*` tags too (`v0.1.9`, `v0.2.1`, `v0.2.2`, `v0.3.0`). With no bypass actor a mistaken tag cannot be deleted until you disable the ruleset in Settings. `go/v0.4.0` is outside `refs/tags/v*`: the publish workflow creates it with its own token (`publish-go.sh`), and no workflow script creates, moves or deletes a `v*` tag, so the publish run is not blocked. Protecting `go/v*` as well would need the Actions app as a bypass actor on a creation rule: not recommended.
- **Check before pasting.** The claims were read from the README, the ADRs and the loop records, not from a fresh run of every suite. Read the CI of the commit you tag.
