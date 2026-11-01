---
loop: 98
branch: dev
---
# Percentage setting: the last two docs and the device run

## Request (owner, 2026-11-01)

"Make these" from the loop 97 leftovers, five items. Triage by the agent:

| # | Item | Outcome |
|---|------|---------|
| 1 | Update the Swift DocC page `Packbin.md` and the Go `doc.go` for the percentage setting | In scope (A) |
| 2 | Run the percentage on a Cortex-M33F device or QEMU image | In scope (B) |
| 3 | Close the epic AZ-2750 | Nothing to do: Jira shows it Done (resolution Done, 2026-10-31); its 9 children are In Testing |
| 4 | U24 (C++ unbound `bits`/`packed`/`sized` member behind a clear `when`) | Not in scope: owner chose option B (README only) on 2026-10-13 and AZ-2479 shipped it. Needs the owner to say what is still open (below) |
| 5 | meshbell renames its Rust `Session` to `FrameSession` | Not in scope: the change is in the meshbell repository (workspace boundary). Packbin already documents it in the README change history (AZ-3291) |

## Problem

**A. Docs.** Loop 97 added a parity percentage (`n = min(32, ceil(p x L / 100))`) to all eight packages and wrote it in the README (section "A percentage instead of a count"). The Swift DocC page and the Go package doc still describe only the count, so a reader of either API reference never learns the setting exists.

**B. Device run.** The percentage is proven on the host and in the ring (64 pairs), and the embedded images only prove size, stack and link. The embedded runs execute no percentage code: the C++ vector runner on QEMU (Cortex-M3 `mps2-an385`, Cortex-M33F `mps2-an505`) runs only the `VECTOR_TESTS` list, which has no percentage test (the percent tests are in `HOST_TESTS`, which need files and an OS), and the Rust probe's ecc set (`rust/embedded/probe/src/ecc_extra.rs`) packs with a count of 4. So the rounding, the 32 cap and the repair-limit lowering are never run on a target with 32-bit integers and hard float.

## Change location

Source files named by the owner's leftover list, not a running app (packbin is a library):
- `swift/Sources/Packbin/Packbin.docc/Packbin.md` (the parity section near line 157 and the API list near line 226).
- `go/doc.go` (the parity section near line 183).
- `cpp/Makefile` `VECTOR_TESTS`, `cpp/tests/core/` (a new target-safe percentage test), `cpp/embedded/` (the M3 and M33F stages).
- `rust/embedded/probe/src/ecc_extra.rs` and `rust/embedded/` (the ecc set on M4F and M33F).

## Scope

In: the two doc pages (wording, symbols and rules as in the README, no new behavior); a percentage test that runs in the C++ vector runner on both QEMU machines; a percentage round trip in the Rust ecc probe on both Rust QEMU rows; the flash and stack pins that move because of it.

Out: any package behavior change; the README (already done); the Cortex-M33F physical device (no board here: QEMU `mps2-an505` is the Cortex-M33F image); U24; the meshbell repository; vcpkg `supports`; the public-key pairing step; the Swift/Go docs for anything but the percentage.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The new test and probe code may push a pinned embedded image over its flash pin (the C++ Cortex-M4F pin had 32 B of margin in loop 20) | Pins are the owner's; a re-pin needs the measured figure and the owner's yes | open | Medium |
| The QEMU `mps2-an505` image is a model of a Cortex-M33F, not the nRF54L15 silicon | Accepted: the existing M33F rows use the same machine | accepted-risk | Low |
| Docs written for two APIs without a docs build on this host (Swift DocC may be missing on Linux) | Check symbols by grep and `go doc`; say so in the result if DocC cannot run | open | Low |
