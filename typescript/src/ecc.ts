import type { ShortErr } from "./kinds.ts"

// Message error correction (contract message-ecc 1.0.0): a Reed-Solomon code over GF(256) with the field
// polynomial 0x11D, alpha = 2 and generator roots alpha^0 .. alpha^(n-1). The code covers one byte that is
// not sent, the clear length, placed before the clear message.

export const MaxParity = 32
// Sent bytes: the code word is 255, one byte of it (the clear length) is not sent.
export const MaxBlock = 254

export type UncorrectableErr = { ok: false; kind: "uncorrectable" }
export type TooLongErr = { ok: false; kind: "too_long"; length: number; limit: number }
export type EccErr = UncorrectableErr | TooLongErr

const EXP = new Uint8Array(512)
const LOG = new Uint8Array(256)
{
  let x = 1
  for (let i = 0; i < 255; i++) {
    EXP[i] = x
    LOG[x] = i
    x <<= 1
    if (x & 0x100) x ^= 0x11d
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255]!
}

function mul(a: number, b: number): number {
  return a === 0 || b === 0 ? 0 : EXP[LOG[a]! + LOG[b]!]!
}

function inv(a: number): number {
  return EXP[255 - LOG[a]!]!
}

export function checkParity(n: number): void {
  if (!Number.isInteger(n) || n < 0 || n > MaxParity) {
    throw new RangeError(`parity: expected 0..${MaxParity} parity bytes, got ${String(n)}`)
  }
}

export function checkLimit(t: number, n: number): void {
  if (!Number.isInteger(t) || t < 0 || t > n >> 1) {
    throw new RangeError(`correction limit: expected 0..${n >> 1} for ${n} parity bytes, got ${String(t)}`)
  }
}

const generators = new Map<number, Uint8Array>()

// Monic, highest degree first.
function generator(n: number): Uint8Array {
  const cached = generators.get(n)
  if (cached !== undefined) return cached
  let g = [1]
  for (let i = 0; i < n; i++) {
    const out = new Array<number>(g.length + 1).fill(0)
    g.forEach((c, j) => {
      out[j] = out[j]! ^ c
      out[j + 1] = out[j + 1]! ^ mul(c, EXP[i]!)
    })
    g = out
  }
  const fixed = Uint8Array.from(g)
  generators.set(n, fixed)
  return fixed
}

// A clear message above 254 - n bytes is refused, naming its length and the limit.
export function checkSize(length: number, n: number): void {
  if (n > 0 && length > MaxBlock - n) {
    throw new RangeError(`the packet would be ${length} bytes, above the limit of ${MaxBlock - n} bytes for ${n} parity bytes`)
  }
}

// The clear message followed by its n parity bytes.
export function protect(clear: Uint8Array, n: number): Uint8Array {
  if (n === 0) return clear
  checkSize(clear.length, n)
  const g = generator(n)
  const rem = new Uint8Array(clear.length + 1 + n)
  rem[0] = clear.length
  rem.set(clear, 1)
  for (let i = 0; i <= clear.length; i++) {
    const c = rem[i]!
    if (c === 0) continue
    const lc = LOG[c]!
    for (let j = 1; j <= n; j++) {
      const gj = g[j]!
      if (gj !== 0) rem[i + j] = rem[i + j]! ^ EXP[LOG[gj]! + lc]!
    }
  }
  const out = new Uint8Array(clear.length + n)
  out.set(clear)
  out.set(rem.subarray(clear.length + 1), clear.length)
  return out
}

// The syndromes of the code word: the clear length (word length minus n), then the word.
function syndromes(word: Uint8Array, n: number): number[] {
  const out: number[] = []
  const length = word.length - n
  for (let i = 0; i < n; i++) {
    let s = length
    for (let k = 0; k < word.length; k++) s = (s === 0 ? 0 : EXP[LOG[s]! + i]!) ^ word[k]!
    out.push(s)
  }
  return out
}

// p lowest degree first.
function evaluate(p: number[], x: number): number {
  let y = 0
  for (let i = p.length - 1; i >= 0; i--) y = mul(y, x) ^ p[i]!
  return y
}

// Berlekamp-Massey: the error locator, lowest degree first, trimmed.
function locator(synd: number[], n: number): number[] {
  let lam = [1]
  let prev = [1]
  let l = 0
  let m = 1
  let b = 1
  for (let r = 0; r < n; r++) {
    let d = synd[r]!
    for (let i = 1; i <= l; i++) {
      if (i < lam.length) d ^= mul(lam[i]!, synd[r - i]!)
    }
    if (d === 0) {
      m++
      continue
    }
    const before = lam.slice()
    const coef = mul(d, inv(b))
    const need = prev.length + m
    while (lam.length < need) lam.push(0)
    prev.forEach((c, i) => {
      lam[i + m] = lam[i + m]! ^ mul(coef, c)
    })
    if (2 * l <= r) {
      l = r + 1 - l
      prev = before
      b = d
      m = 1
    } else {
      m++
    }
  }
  while (lam.length > 1 && lam[lam.length - 1] === 0) lam = lam.slice(0, -1)
  return lam
}

export type Repaired = { ok: true; clear: Uint8Array; repaired: number }

const uncorrectable: UncorrectableErr = { ok: false, kind: "uncorrectable" }

// Checks `received` against n parity bytes and repairs up to t wrong bytes. `clear` is a view of the
// input when it is intact and a repaired copy otherwise; the input is never written. Never throws on
// hostile bytes; n and t are the caller's and are checked first (checkParity, checkLimit).
export function repair(received: Uint8Array, n: number, t: number): Repaired | ShortErr | EccErr {
  if (n === 0) return { ok: true, clear: received, repaired: 0 }
  const size = received.length
  if (size > MaxBlock) return { ok: false, kind: "too_long", length: size, limit: MaxBlock }
  if (size < n) return { ok: false, field: "parity", needed: n, left: size }
  const synd = syndromes(received, n)
  if (synd.every((s) => s === 0)) return { ok: true, clear: received.subarray(0, size - n), repaired: 0 }
  if (t === 0) return uncorrectable
  const lam = locator(synd, n)
  const deg = lam.length - 1
  if (deg === 0 || deg > t) return uncorrectable
  // Position p (0 = first byte sent) has locator X = alpha^(size-1-p); the unsent length byte is one place before it.
  const roots: number[] = []
  for (let p = 0; p < size; p++) {
    if (evaluate(lam, EXP[(255 - (size - 1 - p)) % 255]!) === 0) roots.push(p)
  }
  if (roots.length !== deg) return uncorrectable
  // The error evaluator omega = (synd * lam) mod x^n, lowest degree first.
  const omega = new Array<number>(n).fill(0)
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < lam.length; j++) {
      if (i + j < n) omega[i + j] = omega[i + j]! ^ mul(synd[i]!, lam[j]!)
    }
  }
  // The derivative in characteristic 2 keeps the odd-degree terms.
  const dlam: number[] = []
  for (let i = 1; i < lam.length; i++) dlam.push(i % 2 === 1 ? lam[i]! : 0)
  const word = Uint8Array.from(received)
  for (const p of roots) {
    const x = EXP[(size - 1 - p) % 255]!
    const xi = inv(x)
    const den = evaluate(dlam, xi)
    if (den === 0) return uncorrectable
    word[p] = word[p]! ^ mul(x, mul(evaluate(omega, xi), inv(den)))
  }
  if (syndromes(word, n).some((s) => s !== 0)) return uncorrectable
  return { ok: true, clear: word.subarray(0, size - n), repaired: deg }
}
