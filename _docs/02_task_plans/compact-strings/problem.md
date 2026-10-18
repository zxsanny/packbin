---
loop: 35
branch: dev
---

# Compact strings

Every string packbin writes is encoded by one compact text scheme instead of 2-byte count plus UTF-8 bytes (owner, 2026-10-18: "encode every string with that"). The goal is to send Ukrainian text, Russian text, English text, digits and a small set of punctuation in as few bytes as possible.

Today `utf8` costs a 2-byte count plus 2 bytes per Cyrillic letter, so a 20-letter Ukrainian word is about 42 bytes. The scheme is open: the research compares Unishox2 (Meshtastic), static Huffman with a language switch (UA / EN / RU), a fixed-width 6-bit table with bigram slots, and a predictive bigram matrix.

## Owner constraints (2026-10-18)

- Alphabets: Ukrainian, Russian (cheap to add), English, digits.
- No uppercase, no emoji.
- Punctuation limited to `, . - : ! ?` and space.
- A small built-in dictionary of specific things, like a language switch (`UA`, `EN`), plus a few other fixed tokens (to be listed in the research).
- A flipped bit IS a concern, so a scheme where one wrong bit ruins the rest of the packet (the predictive bigram matrix) is probably out. A CRC for the whole message is a separate, later task and is NOT part of this feature.

## Code sections / UI locations for this loop

Owner: "encode every string with that". The string field itself, in every package: the `utf8` kind and the string/list/dict element paths (C#, TypeScript, Python, Rust, C++, Java, Go, Swift), the wire spec in `_docs/01_solution/schema.md`, the golden bytes in `fixtures/`, and the README string sections. No new field kind.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Encoding every string changes the wire bytes of every string field in every language, and all golden fixtures. No `v*` tag has been published yet. | Owner decision: accept the break; update schema, fixtures and README in this loop | open | Medium |
| Text outside the alphabet (uppercase, emoji, other scripts) must not be lost or refused. | Research: an escape to raw UTF-8 inside the scheme (recommended) vs an error naming the field | open | High |
| Flipped bits: the scheme must not turn one wrong bit into a corrupt rest-of-packet beyond the string it hit. CRC is out of scope. | Owner: bigram-predictive scheme probably excluded; research measures damage per flipped bit | open | Medium |
| C++ core allocates nothing and the Cortex-M4F flash margin is 32 B; tables and code must fit or the budget is raised by the owner. | `_docs/AGENT_GOTCHAS.md`; research sizes each scheme | open | High |
| The old project problem statement lists compression as out of scope. | `_docs/00_problem/problem.md`; this feature supersedes it for strings | open | Low |
