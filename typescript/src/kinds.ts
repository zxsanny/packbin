export type Value = Record<string, unknown>

export type ShortErr = { ok: false; field: string; needed: number; left: number }

export type Cursor = { buf: Uint8Array; offset: number }

export function present(v: unknown): boolean {
  return v !== undefined && v !== null
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
      (f.kind === "int" || f.kind === "float" || f.kind === "bytes") &&
      typeof f.name === "string"
    ) {
      names.push(f.name)
    }
  }
  return names
}

export function writeU2(
  out: number[],
  names: string[],
  take: (name: string) => unknown,
): void {
  const nbytes = (names.length + 3) >> 2
  const raw = new Array<number>(nbytes).fill(0)
  for (let i = 0; i < names.length; i++) {
    const name = names[i]!
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
  names: string[],
): { ok: true; values: number[] } | ShortErr {
  const nbytes = (names.length + 3) >> 2
  const left = cur.buf.length - cur.offset
  if (left < nbytes) return { ok: false, field: names[0]!, needed: nbytes, left }
  const values: number[] = []
  for (let i = 0; i < names.length; i++) {
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

export function readBits(
  cur: Cursor,
  name: string,
  count: number,
): { ok: true; values: number[] } | ShortErr {
  const nbytes = (count + 7) >> 3
  const left = cur.buf.length - cur.offset
  if (left < nbytes) return { ok: false, field: name, needed: nbytes, left }
  const values: number[] = []
  for (let i = 0; i < count; i++) {
    values.push((cur.buf[cur.offset + (i >> 3)]! >> (i & 7)) & 1)
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
  count: unknown,
): { ok: true; value: Uint8Array } | ShortErr {
  if (typeof count !== "number" || !Number.isInteger(count)) {
    throw new RangeError(`${name}: count missing`)
  }
  const left = cur.buf.length - cur.offset
  if (left < count) return { ok: false, field: name, needed: count, left }
  const value = new Uint8Array(cur.buf.subarray(cur.offset, cur.offset + count))
  cur.offset += count
  return { ok: true, value }
}

export function asNumber(v: unknown): number | bigint {
  if (typeof v === "bigint") return v
  if (typeof v === "number") return v
  throw new RangeError("expected number")
}

export function writeInt(
  out: number[],
  value: number | bigint,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
  le: boolean,
): void {
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

export function writeFloat(out: number[], value: number, size: 4 | 8, le: boolean): void {
  const buf = new ArrayBuffer(size)
  const view = new DataView(buf)
  if (size === 4) view.setFloat32(0, value, le)
  else view.setFloat64(0, value, le)
  const bytes = new Uint8Array(buf)
  for (let i = 0; i < size; i++) out.push(bytes[i]!)
}

export type ViewCursor = { buf: Uint8Array; view: DataView; offset: number }

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
