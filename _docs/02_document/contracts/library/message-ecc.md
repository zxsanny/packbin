# Contract: message-ecc

**Component**: library (all 8 packages)
**Producer task**: AZ-2678 — AZ-2678_ecc_format_spec.md
**Consumer tasks**: AZ-2679, AZ-2680, AZ-2681, AZ-2682, AZ-2683, AZ-2684, AZ-2685, AZ-2686, AZ-2687, AZ-2688, AZ-2689, AZ-2690
**Version**: 1.0.0
**Status**: current
**Last Updated**: 2026-10-18
**Reference**: `scripts/ecc/eccfmt.py`; vectors `fixtures/ecc/vectors.txt`; position rows `_docs/02_task_plans/message-error-correction/input_data/expected_results/results_report.md`

## Purpose

An optional protection layer over a whole packed message. A scheme declares `n` parity bytes (0 to 32, default 0). Pack appends `n` parity bytes. Unpack detects corruption and repairs up to `t` wrong bytes, `t` from 0 to `n / 2`; beyond that it returns an error and never a wrong row. A wrong byte counts once however many of its bits differ. With `n` = 0 nothing changes: the bytes, the errors and the speed are those of the package before this contract.

## Shape

### Wire

```
protected = clear parity
clear     = the packed fields, exactly as unprotected pack writes them
parity    = n bytes, none when n = 0
```

- `n` is not on the wire. Both sides share the scheme, as they share the field list.
- The sent length is `len(clear) + n`, at most **254** bytes. `len(clear)` is at most `254 - n`.

### Code

- Field GF(256) with the field polynomial 0x11D. `alpha = 2`. `EXP[0] = 1`, `EXP[i + 1] = EXP[i] * 2`, and when the product passes 255 it is XORed with 0x11D; `LOG` is the inverse; `mul(a, b) = 0` if either is 0, else `EXP[(LOG[a] + LOG[b]) % 255]`.
- Generator `g(x) = (x - alpha^0)(x - alpha^1) ... (x - alpha^(n-1))`, monic, written highest degree first (`g[0] = 1`). In this field subtraction is XOR.
- The code word is **one byte longer than what is sent**: its first byte is `len(clear)`, which is covered by the code and not sent; then the clear bytes; then the parity. Covering the length makes a message with one byte more or less (for example a trailing `00`) fail the check; a plain systematic code accepts it.
- Encode: `R = [len(clear)] + clear + n zeros`; for `i` from 0 to `len(clear)` (inclusive): `c = R[i]`; if `c != 0`, for `j` from 1 to `n`: `R[i + j] ^= mul(g[j], c)`. The parity is `R[len(clear) + 1 ..]`.
- Check: with `L = N - n` (N = received length), the syndromes are `S_i = Horner(alpha^i)` over `[L] + received`, for `i` from 0 to `n - 1`. All zero means the message is intact.
- Repair (only when `t` > 0 and a syndrome is not zero), in this order, any failure being *uncorrectable*:
  1. Berlekamp-Massey on the syndromes gives the locator `Lambda`; its degree must be between 1 and `t`.
  2. A position `p` (0 is the first sent byte) has locator `X = alpha^(N - 1 - p)`; `p` is wrong when `Lambda(X^-1) = 0`. The number of such positions in 0 to `N - 1` must equal the degree. (The unsent length byte cannot be wrong: a root there makes the count differ.)
  3. `Omega = (S * Lambda) mod x^n`. The error value at `p` is `X * Omega(X^-1) / Lambda'(X^-1)`, where `Lambda'` is the formal derivative (odd-degree terms only); a zero derivative is uncorrectable.
  4. XOR the values in, recompute all syndromes; any nonzero one is uncorrectable.
- The count of repaired bytes is the locator degree.

### Operations and rules

| Rule | Behavior |
|------|----------|
| Scheme setting | An integer 0 to 32; the spelling follows that package's way of setting its other scheme numbers (limits). Above 32, or below 0, the scheme is not built: the package's invalid-scheme error naming `n` and 32 (`bad_parity`). A setter of the other scheme limits keeps an existing count unless it is given one. C++ sets \`SchemeInvalid\` with \`needed\` 32 (a compile error for a \`constexpr\` scheme). |
| Pack | Appends the parity. A clear message above `254 - n` bytes: the package's too-many/too-large error naming the clear length and the limit, 0 bytes written (`too_long`). |
| Unpack input | The caller may pass a correction limit `t`, an integer 0 to `n / 2`. **Default 0 (detect only).** A `t` above `n / 2` or below 0 is an error before any byte is read (`bad_limit`). Where the plain unpack call has no limit argument (variadic or read-only buffers), the package adds a sibling call for repair, named \`unpackRepair\` / \`unpack_repair\` in its own case; the plain call is detect-only. |
| Unpack, intact | Returns the row and a repaired count of 0. The row is read from the first `N - n` bytes with the package's unprotected rules (so a short or trailing byte is the same error as before). |
| Unpack, repaired | Returns the row and the repaired count (1 to `t`). |
| Unpack, beyond the limit | The new error kind **Uncorrectable**, 0 values, naming no field. In C++ `Result.error` gains `Uncorrectable`. |
| Unpack, shorter than `n` | The package's short-packet error naming the field `parity`, the bytes needed (`n`) and present, 0 values (`short`). |
| Unpack, longer than 254 | The \`too_long\` error where the package has a distinct one, otherwise its too-many error; 0 values. |
| Repaired count | A non-negative integer next to the row in the package's style (result field, out parameter or second return value). C++: `Result.repaired`. For a scheme without parity a package may leave the count out (TypeScript, Java and Rust do on their plain unpack), since there is nothing to repair. |
| Session | The code covers the **padded** bytes: pack = clear pack, pad, then parity; the payload is the clear length + `n`. Unpack = repair, drop the parity, remove the pad, then read. The receive index advances as it does for any payload. A scheme with `n` = 0 keeps the payload the same length as clear pack (`pack-session.md`). The receive index advances for every payload that reaches the repair step, including an uncorrectable one, so the next payload from the same sender is still read; a bad limit or a mix of counts is refused before it advances. |
| Dispatch | A call that picks the scheme from the type byte (C++ `on(...)`, TypeScript `SchemeHandler`, Rust `unpack_with`, and any other package with such a call) accepts handlers only when all declare the same `n`; a mix is refused when the call is built, naming both counts. With a shared `n` the message is repaired first, then dispatched. Where a package has no build step for the call, the mix is refused at the call, before any byte is read. |
| C++ buffer | \`unpack_repair\` takes a writable buffer and repairs it in place; after a successful call the buffer equals the protected message, and a refused call writes nothing. The read-only \`unpack\` stays and, for a protected scheme, only checks (Uncorrectable on a wrong byte). A scheme with \`n\` = 0 is unchanged. |
| Compact text | A string in a protected message is read after the repair; the compact-text refusals are unchanged. |
| Hostile bytes | Unpack never throws or traps; its work is at most 255 x 32 field operations plus the unprotected walk; it allocates nothing proportional to `n` beyond a few arrays of `n + 1` bytes. |
| Build flag | C++ `PACKBIN_NO_ECC` removes repair (and the encoder where the target selects it). Cortex-M4F builds with it set. |

Refusal names (`kind`), used by `fixtures/ecc/vectors.txt`: `uncorrectable`, `short`, `too_long`, `bad_parity`, `bad_limit`.

### Detection and the correction limit

With `n` parity bytes the code detects any corruption of up to `n` wrong bytes. If a caller allows repair of `t` bytes, it gives up detection: any corruption of `t + 1` to `n - t` bytes is still refused, but a larger corruption may be repaired to a *different* message. The chance that random bytes of the fixture's length (13 clear bytes + `n`) are accepted:

| n | t | chance a random 13 + n byte buffer is accepted | about 1 in |
|---|---|---|---|
| 1 | 0 | 3.906e-03 | 256 |
| 2 | 0 | 1.526e-05 | 65,536 |
| 2 | 1 | 5.838e-02 | 17 |
| 4 | 0 | 2.328e-10 | 4.29e+09 |
| 4 | 1 | 1.010e-06 | 990,537 |
| 4 | 2 | 2.060e-03 | 485 |
| 8 | 0 | 5.421e-20 | 1.84e+19 |
| 8 | 1 | 2.903e-16 | 3.44e+15 |
| 8 | 2 | 7.405e-13 | 1.35e+12 |
| 8 | 3 | 1.196e-09 | 835,946,733 |
| 8 | 4 | 1.373e-06 | 728,310 |
| 16 | 0 | 2.939e-39 | 3.40e+38 |
| 16 | 1 | 2.173e-35 | 4.60e+34 |
| 16 | 2 | 7.760e-32 | 1.29e+31 |
| 16 | 3 | 1.781e-28 | 5.61e+27 |
| 16 | 4 | 2.953e-25 | 3.39e+24 |
| 16 | 5 | 3.766e-22 | 2.66e+21 |
| 16 | 6 | 3.842e-19 | 2.60e+18 |
| 16 | 7 | 3.220e-16 | 3.11e+15 |
| 16 | 8 | 2.258e-13 | 4.43e+12 |

`t = 0` gives the full strength of `n` bytes. A caller who repairs picks `t` knowing this table.

## Versioning

Any change to the field polynomial, the roots, the length byte, the position of the parity or the limits is a wire break for protected schemes and a new contract version.

## Change Log

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-18 | First version (loop 38, AZ-2678). |
