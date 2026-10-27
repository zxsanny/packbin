import type { TooLongErr } from "./ecc.ts"
import type { ShortErr } from "./kinds.ts"

// The error values of frame mode (contract pack-session 3.0.0). Seal, open, the MAC-only call and the replay window
// return one of these, never throw for a refusal. `TooLongErr` (kind "too_long") is the one the ECC code already has and
// `ShortErr` (field, needed, left) is the existing short-packet value; the other five kinds are new. The kind strings are
// the package's snake_case spelling of the contract's names: BadValue, BufferFull, TagMismatch, Duplicate, TooOld.

/** A configuration or argument is out of range (epoch above 0xFFFFFF, direction not loaded, kind above 15, a label or tag length that is not allowed, a call after close). */
export type BadValueErr = { ok: false; kind: "bad_value"; reason: string }
/** The caller's output buffer is shorter than the bytes the call needs to write. */
export type BufferFullErr = { ok: false; kind: "buffer_full"; needed: number }
/** The tag does not match with the current key, nor with the previous key when one is loaded. Nothing was decrypted. */
export type TagMismatchErr = { ok: false; kind: "tag_mismatch" }
/** The replay window has already committed this counter. No tag was computed. */
export type DuplicateErr = { ok: false; kind: "duplicate" }
/** The counter is 64 or more behind the highest committed counter of the replay window. No tag was computed. */
export type TooOldErr = { ok: false; kind: "too_old" }

export type FrameErr = BadValueErr | TooLongErr | BufferFullErr | ShortErr | TagMismatchErr | DuplicateErr | TooOldErr

export const MAX_BODY = 255

export function badValue(reason: string): BadValueErr {
  return { ok: false, kind: "bad_value", reason }
}

export function tooLong(length: number): TooLongErr {
  return { ok: false, kind: "too_long", length, limit: MAX_BODY }
}

export function bufferFull(needed: number): BufferFullErr {
  return { ok: false, kind: "buffer_full", needed }
}

export const tagMismatch = (): TagMismatchErr => ({ ok: false, kind: "tag_mismatch" })
export const duplicate = (): DuplicateErr => ({ ok: false, kind: "duplicate" })
export const tooOld = (): TooOldErr => ({ ok: false, kind: "too_old" })
