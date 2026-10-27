// SHA-256, HMAC-SHA256, HKDF-SHA256 (RFC 5869) and ChaCha20 (RFC 8439), kept for the frame mode port (AZ-3295,
// ADR-009, owner decision D2). Internal: not exported from index.ts, and package.json `exports` names only the entry.
// SHA-256, HMAC and HKDF come from @noble/hashes, the package's one dependency. Every function is checked on the rows
// of fixtures/crypto/vectors.txt (tests/crypto-vectors.test.ts).
import { extract, hkdf } from "@noble/hashes/hkdf.js"
import { hmac } from "@noble/hashes/hmac.js"
import { sha256 as nobleSha256 } from "@noble/hashes/sha2.js"

export const DIGEST_SIZE = 32
export const KEY_SIZE = 32
export const NONCE_SIZE = 12
export const BLOCK_SIZE = 64
const MAX_COUNTER = 0xffff_ffff
const MAX_OKM = 255 * DIGEST_SIZE

export function sha256(data: Uint8Array): Uint8Array {
  return nobleSha256(data)
}

export function hmacSha256(key: Uint8Array, data: Uint8Array): Uint8Array {
  return hmac(nobleSha256, key, data)
}

// The pseudorandom key; an empty salt is the RFC's string of 32 zero bytes.
export function hkdfExtract(salt: Uint8Array, ikm: Uint8Array): Uint8Array {
  return extract(nobleSha256, ikm, salt)
}

// Extract then expand: `length` bytes, at most 255 blocks of 32 (8160 bytes).
export function hkdfSha256(ikm: Uint8Array, salt: Uint8Array, info: Uint8Array, length: number): Uint8Array {
  if (!Number.isSafeInteger(length) || length < 0 || length > MAX_OKM) {
    throw new RangeError(`HKDF-SHA256 output length must be 0 to ${MAX_OKM}, got ${length}`)
  }
  return hkdf(nobleSha256, ikm, salt, info, length)
}

function rot(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0
}

function quarter(w: Uint32Array, a: number, b: number, c: number, d: number): void {
  w[a] = (w[a]! + w[b]!) >>> 0
  w[d] = rot(w[d]! ^ w[a]!, 16)
  w[c] = (w[c]! + w[d]!) >>> 0
  w[b] = rot(w[b]! ^ w[c]!, 12)
  w[a] = (w[a]! + w[b]!) >>> 0
  w[d] = rot(w[d]! ^ w[a]!, 8)
  w[c] = (w[c]! + w[d]!) >>> 0
  w[b] = rot(w[b]! ^ w[c]!, 7)
}

function readU32LE(buf: Uint8Array, offset: number): number {
  return (buf[offset]! | (buf[offset + 1]! << 8) | (buf[offset + 2]! << 16) | (buf[offset + 3]! << 24)) >>> 0
}

function writeU32LE(buf: Uint8Array, offset: number, value: number): void {
  buf[offset] = value & 0xff
  buf[offset + 1] = (value >>> 8) & 0xff
  buf[offset + 2] = (value >>> 16) & 0xff
  buf[offset + 3] = (value >>> 24) & 0xff
}

function checkKeyAndNonce(key: Uint8Array, nonce: Uint8Array): void {
  if (key.length !== KEY_SIZE) throw new RangeError(`ChaCha20 key must be ${KEY_SIZE} bytes, got ${key.length}`)
  if (nonce.length !== NONCE_SIZE) throw new RangeError(`ChaCha20 nonce must be ${NONCE_SIZE} bytes, got ${nonce.length}`)
}

function checkCounter(counter: number): void {
  if (!Number.isSafeInteger(counter) || counter < 0 || counter > MAX_COUNTER) {
    throw new RangeError(`ChaCha20 block counter must be 0 to ${MAX_COUNTER}, got ${counter}`)
  }
}

// The block of a checked key, nonce and counter, written to `output` (64 bytes).
function blockInto(key: Uint8Array, nonce: Uint8Array, counter: number, output: Uint8Array): void {
  const state = new Uint32Array(16)
  state[0] = 0x61707865
  state[1] = 0x3320646e
  state[2] = 0x79622d32
  state[3] = 0x6b206574
  for (let i = 0; i < 8; i++) {
    state[4 + i] = readU32LE(key, i * 4)
  }
  state[12] = counter
  state[13] = readU32LE(nonce, 0)
  state[14] = readU32LE(nonce, 4)
  state[15] = readU32LE(nonce, 8)

  const work = new Uint32Array(state)
  for (let i = 0; i < 10; i++) {
    quarter(work, 0, 4, 8, 12)
    quarter(work, 1, 5, 9, 13)
    quarter(work, 2, 6, 10, 14)
    quarter(work, 3, 7, 11, 15)
    quarter(work, 0, 5, 10, 15)
    quarter(work, 1, 6, 11, 12)
    quarter(work, 2, 7, 8, 13)
    quarter(work, 3, 4, 9, 14)
  }

  for (let i = 0; i < 16; i++) {
    writeU32LE(output, i * 4, (work[i]! + state[i]!) >>> 0)
  }
}

// The 64-byte block of a 32-byte key, a 12-byte nonce and a 32-bit block counter.
export function chacha20Block(key: Uint8Array, nonce: Uint8Array, counter: number): Uint8Array {
  checkKeyAndNonce(key, nonce)
  checkCounter(counter)
  const out = new Uint8Array(BLOCK_SIZE)
  blockInto(key, nonce, counter, out)
  return out
}

// A copy of `data` XOR the key stream that starts at block `counter` (it encrypts and decrypts); `data` is not
// written. A stream that would pass the last block counter is refused: a wrapped counter would repeat key stream.
export function chacha20Xor(key: Uint8Array, nonce: Uint8Array, counter: number, data: Uint8Array): Uint8Array {
  checkKeyAndNonce(key, nonce)
  checkCounter(counter)
  const blocks = Math.ceil(data.length / BLOCK_SIZE)
  if (counter + Math.max(blocks, 1) - 1 > MAX_COUNTER) {
    throw new RangeError(`ChaCha20 stream of ${blocks} blocks from counter ${counter} passes counter ${MAX_COUNTER}`)
  }
  const out = Uint8Array.from(data)
  const pad = new Uint8Array(BLOCK_SIZE)
  for (let index = 0; index < blocks; index++) {
    const at = index * BLOCK_SIZE
    blockInto(key, nonce, counter + index, pad)
    const n = Math.min(BLOCK_SIZE, out.length - at)
    for (let i = 0; i < n; i++) {
      out[at + i]! ^= pad[i]!
    }
  }
  return out
}
