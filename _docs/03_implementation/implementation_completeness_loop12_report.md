# Implementation completeness

**Loop**: 12
**Date**: 2026-10-05
**Verdict**: PASS

| Task | Outcome | Result |
|------|---------|--------|
| AZ-2079 | C#: `bool` / empty group sets its bit only for `true`, only directly under `Flags` or a flag-byte bit; ninth bit fails construction; a group bit sees every child kind (AC-7) | PASS |
| AZ-2080 | TypeScript: the same rule in both flag forms; ninth bit fails at declaration | PASS |
| AZ-2082 | Rust: flag-bit positions from field order per flag-byte read; 8-bit limit; `bool` only inside flags | PASS |
| AZ-2083 | Python: `bool` only as a direct flag bit; ninth `flags` child fails at declaration | PASS |
| AZ-2089 | Java: later and outer references refused per scope; `bool` / empty group only as a flag bit; split-form bool unpacks `true`; repeat round count from value fields | PASS |
| AZ-2129 | TypeScript `new Scheme(...)` runs every `scheme()` check; non-`true` values pinned; `bitwhen` driver | PASS |
| AZ-2130 | C# empty group on a non-`bool` member refused in the `Field.Group` factory; pins; `bitwhen` driver | PASS |
| AZ-2131 | Java accessor-less empty group refused everywhere; empty nested row keeps presence (Map rows; typed rows wait on AZ-2101, accepted); pins; `bitwhen` driver | PASS |
| AZ-2132 | Python empty `group(anchor)` refused everywhere; meets `empty_group_outside_flags`; pins | PASS |
| AZ-2133 | Rust and C++ pin `bitwhen`; Rust exports map `pack` / `unpack` (fail loudly; data-losing nested rounds refused); both drivers in the ring | PASS |
| AZ-2147 | C++ empty group with no member refused inside `flags` / as a flag bit | PASS |

No scaffold, stub or placeholder was added (scan of the changed files: the only `todo` is the TypeScript `it.todo` for three construct vectors owned by AZ-2090). Every rule runs in the real scheme construction and the real pack/unpack walkers; tests call the public pack and unpack.

Review fixes that go past the specs (owner decisions, batch 1 report): C# pack fails loudly on a set group with a missing value; Java keeps flag bits, values and references per `repeat`/`times` round, stores per-round aligned lists, and refuses nested rounds until AZ-2127; Rust binds flag bits per flag-byte read and errors on a map bool other than 0/1. Batch 2 / 3 owner decisions: the TS constructor runs every check; empty groups that can never set their bit are refused (C#, Java, Python, C++); Rust exports map `pack` / `unpack` and fails loudly. Known gaps carried as tickets: AZ-2126, AZ-2127, AZ-2128, AZ-2134, AZ-2135.

## System Pipeline Audit

One pipeline per package: scheme construction checks placement and limits, then pack and unpack walk the same field list. WIRED in all six packages (C++ changed only its shape check, batch 3). Cross-language: `language-pair.sh` `boolflag` (`0100`) and `booltrue` (`0101`) rings pass producer → consumer across all six languages, and `bitwhen` (`010001`) across C#, TypeScript, Rust, Java and C++, through the real drivers.
