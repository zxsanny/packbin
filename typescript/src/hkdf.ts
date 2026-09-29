import { createHmac } from "node:crypto"

const HASH_LEN = 32

export function hkdfSha256(
  ikm: Uint8Array,
  salt: Uint8Array,
  info: Uint8Array,
  length: number,
): Uint8Array {
  const prk = extract(salt, ikm)
  return expand(prk, info, length)
}

function extract(salt: Uint8Array, ikm: Uint8Array): Buffer {
  return createHmac("sha256", salt).update(ikm).digest()
}

function expand(prk: Buffer, info: Uint8Array, length: number): Uint8Array {
  const n = Math.ceil(length / HASH_LEN)
  const out = new Uint8Array(n * HASH_LEN)
  let prev = Buffer.alloc(0)
  for (let i = 1; i <= n; i++) {
    const t = createHmac("sha256", prk)
      .update(prev)
      .update(info)
      .update(Buffer.from([i]))
      .digest()
    out.set(t, (i - 1) * HASH_LEN)
    prev = t
  }
  return out.subarray(0, length)
}
