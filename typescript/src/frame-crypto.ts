import { hmac } from "@noble/hashes/hmac.js"
import { sha256 } from "@noble/hashes/sha2.js"

// The pieces of frame mode that sit on top of crypto.ts: the HMAC over parts, the key schedule's salt, the tag compare
// and the wipe. Internal: not exported from index.ts.

export const MAX_EPOCH = 0xff_ffff
export const KEY_SIZE = 32
export const HASH_SIZE = 32

const SALT_LABEL = new TextEncoder().encode("packbin-frame")

/** "packbin-frame" followed by the epoch as a 32-bit little-endian integer (17 bytes). */
export function salt(epoch: number): Uint8Array {
  const out = new Uint8Array(17)
  out.set(SALT_LABEL)
  out[13] = epoch & 0xff
  out[14] = (epoch >>> 8) & 0xff
  out[15] = (epoch >>> 16) & 0xff
  out[16] = (epoch >>> 24) & 0xff
  return out
}

export function epochOk(epoch: unknown): epoch is number {
  return typeof epoch === "number" && Number.isInteger(epoch) && epoch >= 0 && epoch <= MAX_EPOCH
}

export function isBytes(value: unknown): value is Uint8Array {
  return value instanceof Uint8Array
}

/** The full HMAC-SHA256 of the parts in order, hashed piece by piece with no joined copy. */
export function hmacParts(key: Uint8Array, parts: readonly Uint8Array[]): Uint8Array {
  const mac = hmac.create(sha256, key)
  for (const part of parts) mac.update(part)
  return mac.digest()
}

/**
 * The tag compare: folds every byte of both arrays into one value and decides only at the end. A different length is
 * public (the tag length is fixed per key), so it is the one early exit. Best effort on a JavaScript engine: the language
 * promises no timing, but the loop has no data-dependent branch and no early return.
 */
export function tagsEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false
  let difference = 0
  for (let i = 0; i < left.length; i++) difference |= left[i]! ^ right[i]!
  return difference === 0
}

/** Overwrites the bytes with zeros (best effort, see the doc comment of FrameSession). */
export function wipe(bytes: Uint8Array): void {
  bytes.fill(0)
}
