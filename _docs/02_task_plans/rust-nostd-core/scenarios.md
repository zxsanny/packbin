# Scenarios — rust-nostd-core

Source of rows: `intake` (new-task Step 4.7 at the 13-point handoff). Status: confirmed / out-of-scope / deferred. Rows as in `feature-description.md` § Scenarios; the AC ref column was written by `decompose --feature` (2026-10-20).

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| R1 | relay seals a status report into a 64-byte buffer | confirmed | bytes equal std `pack` | AZ-2749 AC-2 | intake |
| R2 | output buffer too small | confirmed | `BufferFull` with bytes needed | AZ-2749 AC-3 | intake |
| R3 | untrusted bytes: empty, short, trailing, big counts | confirmed | error kinds, never a panic | AZ-2749 AC-4 | intake |
| R4 | hostile corpus | confirmed | each case returns its refusal | AZ-2757 AC-1 | intake |
| R5 | scheme invalid at construction | confirmed | `SchemeInvalid` before any byte | AZ-2749 AC-5 | intake |
| R6 | string longer than scratch | confirmed | `ScratchTooSmall` naming the field | AZ-2754 AC-2 | intake |
| R7 | `text` off | confirmed | `Packed` forwarded; string member refused | AZ-2754 AC-3 | intake |
| R8 | `ecc` off, parity scheme | confirmed | refused at validate | AZ-2755 AC-3 | intake |
| R9 | protected message with wrong bytes / above 254 | confirmed | repaired, `Uncorrectable`, `TooLong` | AZ-2755 AC-1, AC-2 | intake |
| R10 | session seal and open, caller nonce | confirmed | same bytes as std `PackSession` | AZ-2756 AC-1 | intake |
| R11 | default features, whole existing suite and ring | confirmed | all rows pass, bytes unchanged | AZ-2749 AC-7 | intake |
| R12 | NaN bits, 64-bit field, lengths near 65,535, 32-bit device | confirmed | bits kept; golden fixture decodes under QEMU | AZ-2751 AC-1 (device), AZ-2749 AC-6 | intake |
| R13 | build over the owner's size limits | confirmed | CI job fails with figure and limit | AZ-2751 AC-3 | intake |
| R14 | frame mode, MAC-only call, cycle counts, Swift frame mode | out-of-scope | meshbell PB-04, PB-10, PB-06b | — | intake |

## Assessment round 1 (loop 50)

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| D1 | a row refuses a value on unpack | confirmed | `BadValue` naming the field | AZ-2749 (test added after batch 1) | assess-round-1 |
| D2 | link checks catch real defects | confirmed | seeded panic and heap defects fail the checks | AZ-2751 AC-4, AC-5 | assess-round-1 |
| D3 | dictionary keys and their order | confirmed | moved with the `dict` kind to AZ-2754 (keys are strings, order compared decoded) | AZ-2754 AC-5 | assess-round-1 (loop 51) |
| D4 | a `times` inside a `repeat` passes 65,535 rounds in total, not in one place | confirmed | the core limits rounds per container where it stands, plus slots and storage; std refuses | AZ-2753 AC-2 (documented on `Scheme::max_rounds`) | assess-round-1 (loop 51) |
| D5 | a `when` whose source sits in a `when` that does not hold | confirmed | not a match (source not written), as std; the C++ core differs (its own unpack refuses its packet) | AZ-2752; C++ fix outside the epic | assess-round-1 (loop 51) |
| D6 | stack of a nested scheme on the device | deferred | flat probe 472 of 512 B; a nested probe and the stack look go with the hostile and docs slice | AZ-2757 | assess-round-1 (loop 51) |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | row access without pointer-to-member | A — `Row` trait by field id | yes |
| 2 | replaying `cases.txt` on const schemes | A — `&[Field]` slice built at runtime in host tests | yes |
| 3 | stack measurement of a Rust image | A — static library linked into the existing QEMU image | yes |
| 4 | second walker in one crate | A — differential tests over golden, text, ecc, hostile data | yes |

## Not walked

- Two threads sealing with one session (the session is `&mut`; the caller owns exclusion).
- A target other than Cortex-M4F (ESP32 is built by meshbell; `xtensa` has no stable Rust target here).

## Assessment round 2 (loop 52)

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| X1 | strings in every presence context (flags, flag bit, `when`, group, rounds, list, dict) | confirmed | same bytes and values as std in 20 layouts | AZ-2754 AC-1 | assess-round-1 (loop 52) |
| X2 | a wire string as a list element, a flags member, under a flag bit | confirmed | payload forwarded as it is | AZ-2754 AC-3 | assess-round-1 (loop 52) |
| X3 | std ECC on the shared core | confirmed | std suite and vectors unchanged | AZ-2755 | assess-round-1 (loop 52) |
| X4 | size limits of `text`, `ecc`, `session` | deferred | owner input | — | assess-round-1 (loop 52) |
| X5 | a repeat of long raw strings (the C++ memo is not ported) | deferred | AZ-2757 measures it | AZ-2757 | assess-round-1 (loop 52) |
