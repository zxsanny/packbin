---
loop: 35
branch: dev
---

# Compact strings

Every string packbin writes is encoded by one compact text scheme instead of 2-byte count plus UTF-8 bytes (owner, 2026-10-18: "encode every string with that"). The goal is to send Ukrainian text, Russian text, English text, digits and a small set of punctuation in as few bytes as possible.

Today `utf8` costs a 2-byte count plus 2 bytes per Cyrillic letter, so a 20-letter Ukrainian word is about 42 bytes. The scheme is open: the research compares Unishox2 (Meshtastic), static Huffman with a language switch (UA / EN / RU), a fixed-width 6-bit table with bigram slots, and a predictive bigram matrix.

## Owner constraints (2026-10-18)

- Alphabets: Ukrainian, Russian (cheap to add), English, digits. Real encode/decode devices: Raspberry Pi, Android phone, web server. LoRa, ESP32 and similar devices only carry the bytes.
- Baseline scheme B (owner, 2026-10-18): lowercase core, a capital shift symbol and caps-lock, about 15 extra punctuation marks in the table (`, . - : ! ?` and space first), everything else through an escape to raw UTF-8. The research compares A (lowercase only + escape), B and C (every capital and printable ASCII in the table).
- A small built-in dictionary of specific things, like a language switch (`UA`, `EN`), plus a few other fixed tokens (to be listed in the research).
- A flipped bit IS a concern, so a scheme where one wrong bit ruins the rest of the packet (the predictive bigram matrix) is probably out. A CRC for the whole message is a separate, later task and is NOT part of this feature.

## Code sections / UI locations for this loop

Owner: "encode every string with that". The string field itself, in every package: the `utf8` kind and the string/list/dict element paths (C#, TypeScript, Python, Rust, C++, Java, Go, Swift), the wire spec in `_docs/01_solution/schema.md`, the golden bytes in `fixtures/`, and the README string sections. No new field kind.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Encoding every string changes the wire bytes of every string field in every language, and all golden fixtures. No `v*` tag has been published yet. | Owner decision: accept the break; update schema, fixtures and README in this loop | resolved | Medium |
| Text outside the alphabet (uppercase, emoji, other scripts) must not be lost or refused. | Owner 2026-10-18: escape to raw UTF-8 inside the scheme | resolved | High |
| Flipped bits: the scheme must not turn one wrong bit into a corrupt rest-of-packet beyond the string it hit. CRC is out of scope. | Owner 2026-10-18: a flipped bit may ruin only its own string; a flip in the count is as today; research measures damage per candidate | accepted-risk | Medium |
| C++ core allocates nothing and the Cortex-M4F flash margin is 32 B. | Owner 2026-10-18: LoRa/ESP32/Cortex-M4F devices only carry the packet and do not encode or decode strings; the codec is a separate C++ header that firmware without strings does not use (CS-12) | resolved | Low |
| The old project problem statement lists compression as out of scope. | `_docs/00_problem/problem.md`; this feature supersedes it for strings | resolved | Low |
