export type Value = Record<string, unknown>

export type ShortErr = { ok: false; field: string; needed: number; left: number }

export type TypeMismatchErr = { ok: false; expected?: number; actual: number }

export type Cursor = { buf: Uint8Array; offset: number }

export function present(v: unknown): boolean {
  return v !== undefined && v !== null
}

// A `when` value and a field value are the same when equal; a number and a bigint compare by
// value, so `1`, `1n` and an unpacked `1n` all match.
export function sameValue(seen: unknown, want: unknown): boolean {
  const numeric = (v: unknown): v is number | bigint => typeof v === "number" || typeof v === "bigint"
  return numeric(seen) && numeric(want) ? seen == want : seen === want
}

export function groupOn(
  values: Value,
  name: string,
  childNames: string[],
): boolean {
  if (present(values[name])) return true
  for (const n of childNames) {
    if (present(values[n])) return true
  }
  return false
}

export function scalarChildNames(
  fields: { kind: string; name?: string }[],
): string[] {
  const names: string[] = []
  for (const f of fields) {
    if (
      (f.kind === "int" ||
        f.kind === "float" ||
        f.kind === "bytes" ||
        f.kind === "utf8" ||
        f.kind === "list" ||
        f.kind === "dict") &&
      typeof f.name === "string"
    ) {
      names.push(f.name)
    }
  }
  return names
}

export function writeU2(
  out: number[],
  slots: { name: string }[],
  take: (name: string) => unknown,
): void {
  const nbytes = (slots.length + 3) >> 2
  const raw = new Array<number>(nbytes).fill(0)
  for (let i = 0; i < slots.length; i++) {
    const name = slots[i]!.name
    const value = take(name)
    if (
      typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < 0 ||
      value > 3
    ) {
      throw new RangeError(`${name}: expected 2-bit int`)
    }
    raw[i >> 2]! |= value << ((i & 3) * 2)
  }
  for (const b of raw) out.push(b)
}

export function readU2(
  cur: Cursor,
  slots: { name: string }[],
): { ok: true; values: number[] } | ShortErr {
  const nbytes = (slots.length + 3) >> 2
  const left = cur.buf.length - cur.offset
  if (left < nbytes) {
    return { ok: false, field: slots[0]!.name, needed: nbytes, left }
  }
  const values: number[] = []
  for (let i = 0; i < slots.length; i++) {
    values.push((cur.buf[cur.offset + (i >> 2)]! >> ((i & 3) * 2)) & 3)
  }
  cur.offset += nbytes
  return { ok: true, values }
}

export function writeBits(
  out: number[],
  name: string,
  count: number,
  raw: unknown,
): void {
  if (!Array.isArray(raw) || raw.length !== count) {
    throw new RangeError(`${name}: expected ${count} bits`)
  }
  const nbytes = (count + 7) >> 3
  const packed = new Array<number>(nbytes).fill(0)
  for (let i = 0; i < count; i++) {
    const bit = raw[i]
    if (bit !== 0 && bit !== 1) {
      throw new RangeError(`${name}: expected 0 or 1`)
    }
    packed[i >> 3]! |= Number(bit) << (i & 7)
  }
  for (const b of packed) out.push(b)
}

// A count is a non-negative integer number; anything else (absent, negative, fractional,
// bigint) cannot be read. `bias` is added before the sign check.
export function validCount(raw: unknown, bias = 0): number | null {
  if (typeof raw !== "number" || !Number.isInteger(raw)) return null
  const count = raw + bias
  return count < 0 ? null : count
}

export function readBits(
  cur: Cursor,
  name: string,
  count: number,
): { ok: true; values: number[] } | ShortErr {
  const nbytes = Math.ceil(count / 8)
  const left = cur.buf.length - cur.offset
  if (left < nbytes) return { ok: false, field: name, needed: nbytes, left }
  const values: number[] = []
  for (let i = 0; i < count; i++) {
    values.push((cur.buf[cur.offset + (i >> 3)]! >> (i & 7)) & 1)
  }
  cur.offset += nbytes
  return { ok: true, values }
}

export function packedBytes(width: 1 | 2, count: number): number {
  return Math.ceil((count * width) / 8)
}

export function writePacked(
  out: number[],
  name: string,
  width: 1 | 2,
  count: number,
  raw: unknown,
): void {
  if (!Array.isArray(raw) || raw.length !== count) {
    throw new RangeError(`${name}: expected ${count} items`)
  }
  const max = width === 2 ? 3 : 1
  const shift = width === 2 ? 2 : 1
  const per = width === 2 ? 4 : 8
  const packed = new Array<number>(packedBytes(width, count)).fill(0)
  for (let i = 0; i < count; i++) {
    const n = raw[i]
    if (typeof n !== "number" || !Number.isInteger(n) || n < 0 || n > max) {
      throw new RangeError(`${name}: expected 0..${max}`)
    }
    packed[(i / per) | 0]! |= n << ((i % per) * shift)
  }
  for (const b of packed) out.push(b)
}

export function readPacked(
  cur: Cursor,
  name: string,
  width: 1 | 2,
  count: number,
): { ok: true; values: number[] } | ShortErr {
  const nbytes = packedBytes(width, count)
  const left = cur.buf.length - cur.offset
  if (left < nbytes) return { ok: false, field: name, needed: nbytes, left }
  const mask = width === 2 ? 3 : 1
  const shift = width === 2 ? 2 : 1
  const per = width === 2 ? 4 : 8
  const values: number[] = []
  for (let i = 0; i < count; i++) {
    values.push(
      (cur.buf[cur.offset + ((i / per) | 0)]! >> ((i % per) * shift)) & mask,
    )
  }
  cur.offset += nbytes
  return { ok: true, values }
}

export function writeSized(
  out: number[],
  name: string,
  count: unknown,
  raw: unknown,
): void {
  if (typeof count !== "number" || !Number.isInteger(count)) {
    throw new RangeError(`${name}: bad count`)
  }
  const arr =
    raw instanceof Uint8Array
      ? raw
      : raw instanceof ArrayBuffer
        ? new Uint8Array(raw)
        : null
  if (!arr) throw new RangeError(`${name}: expected bytes`)
  if (arr.length !== count) {
    throw new RangeError(`${name}: expected ${count} bytes, got ${arr.length}`)
  }
  for (let i = 0; i < arr.length; i++) out.push(arr[i]!)
}

export function readSized(
  cur: Cursor,
  name: string,
  count: number,
): { ok: true; value: Uint8Array } | ShortErr {
  const left = cur.buf.length - cur.offset
  if (left < count) return { ok: false, field: name, needed: count, left }
  const value = new Uint8Array(cur.buf.subarray(cur.offset, cur.offset + count))
  cur.offset += count
  return { ok: true, value }
}

function intKind(size: 1 | 2 | 4 | 8, signed: boolean): string {
  return `${signed ? "i" : "u"}${size * 8}`
}

function notNumber(name: string, kind: string, value: unknown): RangeError {
  return new RangeError(`${name}: expected a number for ${kind}, got ${typeof value}`)
}

// A number is taken only as a safe integer: past 2^53 it may already have lost digits, so it
// is refused even where the width could hold it. A bigint is exact at every width.
function fitsInt(value: number | bigint, size: 1 | 2 | 4 | 8, signed: boolean): boolean {
  const bits = size * 8
  if (typeof value === "bigint") {
    const min = signed ? -(1n << BigInt(bits - 1)) : 0n
    const max = (1n << BigInt(signed ? bits - 1 : bits)) - 1n
    return value >= min && value <= max
  }
  if (!Number.isSafeInteger(value)) return false
  if (size === 8) return signed || value >= 0
  const min = signed ? -(2 ** (bits - 1)) : 0
  const max = 2 ** (signed ? bits - 1 : bits) - 1
  return value >= min && value <= max
}

function intRefused(name: string, value: unknown, size: 1 | 2 | 4 | 8, signed: boolean): RangeError {
  const kind = intKind(size, signed)
  if (typeof value !== "number" && typeof value !== "bigint") return notNumber(name, kind, value)
  const exact = typeof value === "number" && Number.isInteger(value) && fitsInt(BigInt(value), size, signed)
  return new RangeError(`${name}: ${value} does not fit in ${kind}${exact ? "; pass a bigint" : ""}`)
}

export function writeInt(
  out: number[],
  name: string,
  value: unknown,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
  le: boolean,
): void {
  if ((typeof value !== "number" && typeof value !== "bigint") || !fitsInt(value, size, signed)) {
    throw intRefused(name, value, size, signed)
  }
  const buf = new ArrayBuffer(size)
  const view = new DataView(buf)
  if (size === 1) {
    if (signed) view.setInt8(0, Number(value))
    else view.setUint8(0, Number(value))
  } else if (size === 2) {
    if (signed) view.setInt16(0, Number(value), le)
    else view.setUint16(0, Number(value), le)
  } else if (size === 4) {
    if (signed) view.setInt32(0, Number(value), le)
    else view.setUint32(0, Number(value), le)
  } else {
    if (signed) view.setBigInt64(0, BigInt(value), le)
    else view.setBigUint64(0, BigInt(value), le)
  }
  const bytes = new Uint8Array(buf)
  for (let i = 0; i < size; i++) out.push(bytes[i]!)
}

// NaN and the infinities are written as given; a finite value is refused only where the
// narrower width would turn it into an infinity.
export function writeFloat(out: number[], name: string, value: unknown, size: 4 | 8, le: boolean): void {
  const kind = `f${size * 8}`
  if (typeof value !== "number") throw notNumber(name, kind, value)
  if (size === 4 && Number.isFinite(value) && !Number.isFinite(Math.fround(value))) {
    throw new RangeError(`${name}: ${value} does not fit in ${kind}`)
  }
  const buf = new ArrayBuffer(size)
  const view = new DataView(buf)
  if (size === 4) view.setFloat32(0, value, le)
  else view.setFloat64(0, value, le)
  const bytes = new Uint8Array(buf)
  for (let i = 0; i < size; i++) out.push(bytes[i]!)
}

// `slots` counts the entries every round of this unpack call has made so far, against the
// scheme's `maxSlots`; `maxRounds` bounds the rounds of one repeat or times field.
export type ViewCursor = {
  buf: Uint8Array
  view: DataView
  offset: number
  maxRounds: number
  maxSlots: number
  slots: number
}

export function readInt(
  cur: ViewCursor,
  name: string,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
  le: boolean,
): { ok: true; value: number | bigint } | ShortErr {
  const left = cur.buf.length - cur.offset
  if (left < size) return { ok: false, field: name, needed: size, left }
  const o = cur.offset
  let value: number | bigint
  if (size === 1) {
    value = signed ? cur.view.getInt8(o) : cur.view.getUint8(o)
  } else if (size === 2) {
    value = signed ? cur.view.getInt16(o, le) : cur.view.getUint16(o, le)
  } else if (size === 4) {
    value = signed ? cur.view.getInt32(o, le) : cur.view.getUint32(o, le)
  } else {
    value = signed ? cur.view.getBigInt64(o, le) : cur.view.getBigUint64(o, le)
  }
  cur.offset += size
  return { ok: true, value }
}

export function writeUtf8(out: number[], name: string, value: unknown): void {
  if (typeof value !== "string") throw new RangeError(`${name}: expected string`)
  const raw = new TextEncoder().encode(value)
  if (raw.length > 65535) throw new RangeError(`${name}: utf-8 length ${raw.length}`)
  out.push(raw.length & 0xff, (raw.length >> 8) & 0xff)
  for (let i = 0; i < raw.length; i++) out.push(raw[i]!)
}

export function readUtf8(
  cur: ViewCursor,
  name: string,
): { ok: true; value: string } | ShortErr {
  const leftCount = cur.buf.length - cur.offset
  if (leftCount < 2) return { ok: false, field: name, needed: 2, left: leftCount }
  const count = cur.view.getUint16(cur.offset, true)
  cur.offset += 2
  const left = cur.buf.length - cur.offset
  if (left < count) return { ok: false, field: name, needed: count, left }
  const raw = cur.buf.subarray(cur.offset, cur.offset + count)
  cur.offset += count
  try {
    return { ok: true, value: new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(raw) }
  } catch (e) {
    // The fatal decoder reports invalid UTF-8 with a TypeError; anything else is not ours.
    if (e instanceof TypeError) return { ok: false, field: name, needed: 0, left: leftCount }
    throw e
  }
}

export function readFloat(
  cur: ViewCursor,
  name: string,
  size: 4 | 8,
  le: boolean,
): { ok: true; value: number } | ShortErr {
  const left = cur.buf.length - cur.offset
  if (left < size) return { ok: false, field: name, needed: size, left }
  const value =
    size === 4
      ? cur.view.getFloat32(cur.offset, le)
      : cur.view.getFloat64(cur.offset, le)
  cur.offset += size
  return { ok: true, value }
}
