import {
  EN,
  EN_UPPER,
  LENGTHS_EN,
  LENGTHS_NUM,
  LENGTHS_RU,
  LENGTHS_UA,
  NUMSET,
  RU,
  RU_UPPER,
  SHARED,
  UA,
  UA_UPPER,
} from "./text-tables.ts"

// The compact text format (contract compact-text 1.0.0): a LEB128 count, then a payload of prefix
// codes in four modes (Ukrainian, Russian, English, number) or raw UTF-8. The encoder is the optimal
// parse with the contract's tie-break; the decoder is bounded by the payload length.

export type TextRefusal = "short" | "varint" | "mode" | "pad" | "code" | "cap" | "esc" | "utf8" | "raw" | "length"

export type TextFailure = { ok: false; kind: TextRefusal; needed: number; left: number }

export type TextRead = { ok: true; value: string; next: number } | TextFailure

export const MAX_TEXT_BYTES = 65535
const RAW_PREFIX = 0x10
const INF = 0x3fffffff
const TABLE_CHARS = 0x500

const ALPHA = [UA, RU, EN]
const UPPER = [UA_UPPER, RU_UPPER, EN_UPPER]
const LENGTHS = [LENGTHS_UA, LENGTHS_RU, LENGTHS_EN, LENGTHS_NUM]

// Symbol order of a mode: text modes have the letters, the 32 shared characters, three switches,
// CAP, LOCK, ESC; the number mode has the 15 number characters, three switches, ESC.
const SWITCH_AT = [0, 0, 0, 0]
const CAP_AT = [0, 0, 0, -1]
const LOCK_AT = [0, 0, 0, -1]
const ESC_AT = [0, 0, 0, 0]
for (let m = 0; m < 3; m++) {
  const letters = ALPHA[m]!.length
  SWITCH_AT[m] = letters + SHARED.length
  CAP_AT[m] = SWITCH_AT[m]! + 3
  LOCK_AT[m] = CAP_AT[m]! + 1
  ESC_AT[m] = LOCK_AT[m]! + 1
}
SWITCH_AT[3] = NUMSET.length
ESC_AT[3] = NUMSET.length + 3

const CODE: Uint16Array[] = []
const LEN: Uint8Array[] = []
// DECODE[m][next 16 bits] = (code length << 8) | symbol index. Every table is a complete code, so every
// pattern decodes.
const DECODE: Uint16Array[] = []
for (let m = 0; m < 4; m++) {
  const lengths = LENGTHS[m]!
  const order = Array.from(lengths.keys()).sort((a, b) => lengths[a]! - lengths[b]! || a - b)
  const codes = new Uint16Array(lengths.length)
  const table = new Uint16Array(65536)
  let code = 0
  let prev = 0
  for (const sym of order) {
    const len = lengths[sym]!
    code <<= len - prev
    codes[sym] = code
    const first = code << (16 - len)
    table.fill((len << 8) | sym, first, first + (1 << (16 - len)))
    code++
    prev = len
  }
  CODE.push(codes)
  LEN.push(Uint8Array.from(lengths))
  DECODE.push(table)
}

function indexTable(chars: readonly number[], size: number): Int16Array {
  const t = new Int16Array(size).fill(-1)
  chars.forEach((c, i) => {
    if (c !== 0) t[c] = i
  })
  return t
}
const LOWER_AT = ALPHA.map((a) => indexTable(a, TABLE_CHARS))
const UPPER_AT = UPPER.map((u) => indexTable(u, TABLE_CHARS))
const SHARED_AT = indexTable(SHARED, 128)
const NUM_AT = indexTable(NUMSET, 128)

// Control edges of a state (mode * 2 + lock): the switches to the other modes, then the lock toggle,
// as flat (symbol index, bits, target state) triples in symbol-index order.
const CTL_COUNT = new Int32Array(8)
const CTL = new Int32Array(8 * 4 * 3)
for (let s = 0; s < 8; s++) {
  const m = s >> 1
  const k = s & 1
  const list: number[][] = []
  for (let t = 0; t < 4; t++) {
    if (t === m) continue
    const sym = SWITCH_AT[m]! + (t < m ? t : t - 1)
    list.push([sym, LEN[m]![sym]!, t * 2 + k])
  }
  if (m < 3) list.push([LOCK_AT[m]!, LEN[m]![LOCK_AT[m]!]!, m * 2 + (1 - k)])
  list.sort((a, b) => a[0]! - b[0]!)
  CTL_COUNT[s] = list.length
  list.forEach((e, j) => CTL.set(e, s * 12 + j * 3))
}

function utf8Length(cp: number): number {
  return cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4
}

// The edges that consume one character in one state: first symbol index, bits, the symbols written
// (the second is -1 when there is one) and the UTF-8 length written after an ESC (0 for none).
let edgeCount = 0
const edgeFirst = new Int32Array(4)
const edgeBits = new Int32Array(4)
const edgeSecond = new Int32Array(4)
const edgeEsc = new Int32Array(4)

function addEdge(first: number, bits: number, second: number, esc: number): void {
  edgeFirst[edgeCount] = first
  edgeBits[edgeCount] = bits
  edgeSecond[edgeCount] = second
  edgeEsc[edgeCount] = esc
  edgeCount++
}

function edgesOf(m: number, cp: number, lock: number): void {
  edgeCount = 0
  const len = LEN[m]!
  if (m < 3) {
    const lower = cp < TABLE_CHARS ? LOWER_AT[m]![cp]! : -1
    if (lower >= 0) {
      if (lock === 0 || UPPER[m]![lower] === 0) addEdge(lower, len[lower]!, -1, 0)
    } else {
      const upper = cp < TABLE_CHARS ? UPPER_AT[m]![cp]! : -1
      if (upper >= 0) {
        if (lock === 1) addEdge(upper, len[upper]!, -1, 0)
        else addEdge(CAP_AT[m]!, len[CAP_AT[m]!]! + len[upper]!, upper, 0)
      } else {
        const shared = cp < 128 ? SHARED_AT[cp]! : -1
        if (shared >= 0) addEdge(ALPHA[m]!.length + shared, len[ALPHA[m]!.length + shared]!, -1, 0)
      }
    }
  } else {
    const num = cp < 128 ? NUM_AT[cp]! : -1
    if (num >= 0) addEdge(num, len[num]!, -1, 0)
  }
  const esc = utf8Length(cp)
  addEdge(ESC_AT[m]!, len[ESC_AT[m]!]! + 8 * esc, -1, esc)
}

// Output bits of the encoder.
let outBuf: Uint8Array = new Uint8Array(0)
let outPos = 0
let acc = 0
let accBits = 0

function putBits(value: number, bits: number): void {
  acc = (acc << bits) | value
  accBits += bits
  while (accBits >= 8) {
    outBuf[outPos++] = (acc >>> (accBits - 8)) & 0xff
    accBits -= 8
  }
  acc &= (1 << accBits) - 1
}

function putUtf8(cp: number): void {
  if (cp < 0x80) {
    putBits(cp, 8)
  } else if (cp < 0x800) {
    putBits(0xc0 | (cp >> 6), 8)
    putBits(0x80 | (cp & 0x3f), 8)
  } else if (cp < 0x10000) {
    putBits(0xe0 | (cp >> 12), 8)
    putBits(0x80 | ((cp >> 6) & 0x3f), 8)
    putBits(0x80 | (cp & 0x3f), 8)
  } else {
    putBits(0xf0 | (cp >> 18), 8)
    putBits(0x80 | ((cp >> 12) & 0x3f), 8)
    putBits(0x80 | ((cp >> 6) & 0x3f), 8)
    putBits(0x80 | (cp & 0x3f), 8)
  }
}

function putCount(count: number): void {
  if (count < 0x80) {
    outBuf[outPos++] = count
  } else if (count < 0x4000) {
    outBuf[outPos++] = (count & 0x7f) | 0x80
    outBuf[outPos++] = count >> 7
  } else {
    outBuf[outPos++] = (count & 0x7f) | 0x80
    outBuf[outPos++] = ((count >> 7) & 0x7f) | 0x80
    outBuf[outPos++] = count >> 14
  }
}

function countLength(count: number): number {
  return count < 0x80 ? 1 : count < 0x4000 ? 2 : 3
}

const SCRATCH_CHARS = 4096
const scratchPoints = new Int32Array(SCRATCH_CHARS)
const scratchCosts = new Int32Array((SCRATCH_CHARS + 1) * 8)

// The code points of the UTF-8 bytes TextEncoder writes for `text` (a lone surrogate is U+FFFD) and
// their UTF-8 length. Returns the number of code points; the length is left in `pointBytes`.
let pointBytes = 0

function codePoints(text: string, points: Int32Array): number {
  const size = text.length
  let n = 0
  let bytes = 0
  for (let j = 0; j < size; ) {
    let c = text.charCodeAt(j++)
    if (c >= 0xd800 && c <= 0xdfff) {
      const low = c < 0xdc00 && j < size ? text.charCodeAt(j) : 0
      if (low >= 0xdc00 && low <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (low - 0xdc00)
        j++
      } else {
        c = 0xfffd
      }
    }
    points[n++] = c
    bytes += utf8Length(c)
  }
  pointBytes = bytes
  return n
}

// The last text one pack call encoded and its field: a lone string under a times or repeat is written
// once a round, so the same text comes again and again. The cache belongs to one pack call (`PackOut`),
// so no text outlives the call or crosses to another. The array is never written after it is returned.
export class TextCache {
  text = ""
  field: Uint8Array = Uint8Array.of(0)
}

// The field bytes of one string: the count, then the payload. A text over 65,535 UTF-8 bytes is
// refused naming `name`.
export function encodeText(text: string, name: string, cache?: TextCache): Uint8Array {
  if (cache !== undefined && text === cache.text) return cache.field
  const field = encodeFresh(text, name)
  if (cache !== undefined) {
    cache.text = text
    cache.field = field
  }
  return field
}

function encodeFresh(text: string, name: string): Uint8Array {
  const size = text.length
  if (size === 0) return Uint8Array.of(0)
  // 65,535 UTF-8 bytes need at most 65,535 UTF-16 units; one unit is at least one byte.
  if (size > MAX_TEXT_BYTES) {
    const bytes = new TextEncoder().encode(text).length
    throw new RangeError(`${name}: utf-8 length ${bytes}`)
  }
  const points = size <= SCRATCH_CHARS ? scratchPoints : new Int32Array(size)
  const n = codePoints(text, points)
  const textBytes = pointBytes
  if (textBytes > MAX_TEXT_BYTES) throw new RangeError(`${name}: utf-8 length ${textBytes}`)

  const f = size <= SCRATCH_CHARS ? scratchCosts : new Int32Array((n + 1) * 8)
  for (let s = 0; s < 8; s++) f[n * 8 + s] = 0
  for (let i = n - 1; i >= 0; i--) {
    const base = i * 8
    const cp = points[i]!
    for (let s = 0; s < 8; s++) {
      edgesOf(s >> 1, cp, s & 1)
      let best = INF
      const after = f[base + 8 + s]!
      for (let e = 0; e < edgeCount; e++) {
        const v = edgeBits[e]! + after
        if (v < best) best = v
      }
      f[base + s] = best
    }
    let changed = true
    while (changed) {
      changed = false
      for (let s = 0; s < 8; s++) {
        for (let j = 0; j < CTL_COUNT[s]!; j++) {
          const v = CTL[s * 12 + j * 3 + 1]! + f[base + CTL[s * 12 + j * 3 + 2]!]!
          if (v < f[base + s]!) {
            f[base + s] = v
            changed = true
          }
        }
      }
    }
  }
  let start = 0
  for (let m = 1; m < 4; m++) if (f[m * 2]! < f[start * 2]!) start = m
  const symbolBits = f[start * 2]!
  const payloadBits = 6 + symbolBits
  const payloadBytes = (payloadBits + 7) >> 3
  const rawBytes = 1 + textBytes

  if (payloadBytes >= rawBytes) {
    outBuf = new Uint8Array(countLength(rawBytes) + rawBytes)
    outPos = 0
    putCount(rawBytes)
    outBuf[outPos++] = RAW_PREFIX
    acc = 0
    accBits = 0
    for (let i = 0; i < n; i++) putUtf8(points[i]!)
    return outBuf
  }

  outBuf = new Uint8Array(countLength(payloadBytes) + payloadBytes)
  outPos = 0
  acc = 0
  accBits = 0
  putCount(payloadBytes)
  putBits(8 * payloadBytes - payloadBits, 3)
  putBits(start, 3)
  let state = start * 2
  let i = 0
  while (i < n) {
    const m = state >> 1
    const want = f[i * 8 + state]!
    let bestFirst = INF
    let bestControl = -1
    let bestEdge = -1
    for (let j = 0; j < CTL_COUNT[state]!; j++) {
      const at = state * 12 + j * 3
      if (CTL[at]! < bestFirst && CTL[at + 1]! + f[i * 8 + CTL[at + 2]!]! === want) {
        bestFirst = CTL[at]!
        bestControl = at
      }
    }
    edgesOf(m, points[i]!, state & 1)
    for (let e = 0; e < edgeCount; e++) {
      if (edgeFirst[e]! < bestFirst && edgeBits[e]! + f[i * 8 + 8 + state]! === want) {
        bestFirst = edgeFirst[e]!
        bestControl = -1
        bestEdge = e
      }
    }
    if (bestControl >= 0) {
      putBits(CODE[m]![bestFirst]!, LEN[m]![bestFirst]!)
      state = CTL[bestControl + 2]!
    } else {
      putBits(CODE[m]![bestFirst]!, LEN[m]![bestFirst]!)
      const second = edgeSecond[bestEdge]!
      if (second >= 0) putBits(CODE[m]![second]!, LEN[m]![second]!)
      if (edgeEsc[bestEdge]! > 0) putUtf8(points[i]!)
      i++
    }
  }
  if (accBits > 0) outBuf[outPos++] = (acc << (8 - accBits)) & 0xff
  return outBuf
}

const strictUtf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true })

function refuse(kind: TextRefusal, left: number): TextFailure {
  return { ok: false, kind, needed: 0, left }
}

function textOf(points: number[]): string {
  if (points.length <= 4096) return String.fromCodePoint(...points)
  const parts: string[] = []
  for (let i = 0; i < points.length; i += 4096) parts.push(String.fromCodePoint(...points.slice(i, i + 4096)))
  return parts.join("")
}

// Decodes the string field at `off`. Time and memory follow the payload length: every symbol is at
// least one bit and writes at most 4 UTF-8 bytes, and the text stops growing at 65,535 UTF-8 bytes.
export function decodeText(buf: Uint8Array, off: number): TextRead {
  const size = buf.length
  const left = size - off
  let p = off
  let count = 0
  for (let k = 0; ; k++) {
    if (k === 3) return refuse("varint", left)
    if (p >= size) return { ok: false, kind: "short", needed: k + 1, left }
    const b = buf[p++]!
    count |= (b & 0x7f) << (7 * k)
    if ((b & 0x80) === 0) {
      if (k > 0 && b === 0) return refuse("varint", left)
      break
    }
  }
  if (count === 0) return { ok: true, value: "", next: p }
  if (count > size - p) return { ok: false, kind: "short", needed: count, left: size - p }
  const end = p + count
  const first = buf[p]!
  const start = (first >> 2) & 7
  if (start === 4) {
    if (first !== RAW_PREFIX) return refuse("raw", left)
    if (count - 1 > MAX_TEXT_BYTES) return refuse("length", left)
    try {
      return { ok: true, value: strictUtf8.decode(buf.subarray(p + 1, end)), next: end }
    } catch (e) {
      // The fatal decoder reports invalid UTF-8 with a TypeError; anything else is not ours.
      if (e instanceof TypeError) return refuse("utf8", left)
      throw e
    }
  }
  if (start > 4) return refuse("mode", left)
  const pad = first >> 5
  const total = 8 * count - pad
  if (total < 6) return refuse("pad", left)
  if ((buf[end - 1]! & ((1 << pad) - 1)) !== 0) return refuse("pad", left)

  let mode = start
  let lock = false
  let cap = false
  let bytes = 0
  let pos = 6
  const points: number[] = []
  while (pos < total) {
    const at = p + (pos >> 3)
    const window = (buf[at]! << 16) | ((at + 1 < end ? buf[at + 1]! : 0) << 8) | (at + 2 < end ? buf[at + 2]! : 0)
    const entry = DECODE[mode]![(window >>> (8 - (pos & 7))) & 0xffff]!
    const sym = entry & 0xff
    pos += entry >> 8
    if (pos > total) return refuse("code", left)
    const letters = mode === 3 ? 0 : ALPHA[mode]!.length
    let cp: number
    if (sym < letters) {
      const upper = UPPER[mode]![sym]!
      if (cap) {
        if (upper === 0) return refuse("cap", left)
        cp = upper
        cap = false
      } else {
        cp = lock && upper !== 0 ? upper : ALPHA[mode]![sym]!
      }
    } else if (mode === 3 ? sym < NUMSET.length : sym < letters + SHARED.length) {
      if (cap) return refuse("cap", left)
      cp = mode === 3 ? NUMSET[sym]! : SHARED[sym - letters]!
    } else if (sym < SWITCH_AT[mode]! + 3) {
      if (cap) return refuse("cap", left)
      const target = sym - SWITCH_AT[mode]!
      mode = target < mode ? target : target + 1
      continue
    } else if (sym === CAP_AT[mode]) {
      if (lock || cap) return refuse("cap", left)
      cap = true
      continue
    } else if (sym === ESC_AT[mode]) {
      if (cap) return refuse("cap", left)
      if (pos + 8 > total) return refuse("esc", left)
      const b0 = bitsByte(buf, p, end, pos)
      const n = b0 < 0x80 ? 1 : b0 >> 5 === 6 ? 2 : b0 >> 4 === 14 ? 3 : b0 >> 3 === 30 ? 4 : 0
      if (n === 0) return refuse("utf8", left)
      if (pos + 8 * n > total) return refuse("esc", left)
      cp = n === 1 ? b0 : b0 & (0xff >> (n + 1))
      for (let j = 1; j < n; j++) {
        const b = bitsByte(buf, p, end, pos + 8 * j)
        if ((b & 0xc0) !== 0x80) return refuse("utf8", left)
        cp = (cp << 6) | (b & 0x3f)
      }
      pos += 8 * n
      // Overlong forms, surrogates and values above U+10FFFF are not UTF-8.
      if (cp < (n === 1 ? 0 : n === 2 ? 0x80 : n === 3 ? 0x800 : 0x10000)) return refuse("utf8", left)
      if ((cp >= 0xd800 && cp <= 0xdfff) || cp > 0x10ffff) return refuse("utf8", left)
    } else {
      if (cap) return refuse("cap", left)
      lock = !lock
      continue
    }
    bytes += utf8Length(cp)
    if (bytes > MAX_TEXT_BYTES) return refuse("length", left)
    points.push(cp)
  }
  if (cap) return refuse("cap", left)
  return { ok: true, value: textOf(points), next: end }
}

// The 8 bits at bit `at` of the payload that starts at byte `p` and ends before `end`.
function bitsByte(buf: Uint8Array, p: number, end: number, at: number): number {
  const i = p + (at >> 3)
  const shift = at & 7
  const next = shift > 0 && i + 1 < end ? buf[i + 1]! : 0
  return (((buf[i]! << 8) | next) >> (8 - shift)) & 0xff
}
