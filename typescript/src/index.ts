export type Value = Record<string, unknown>

export type UnpackOk = { ok: true } & Value
export type UnpackErr = { ok: false; field: string; needed: number; left: number }
export type UnpackResult = UnpackOk | UnpackErr

type EndianField = { littleEndian: boolean }

export type Field =
  | ({ kind: "int"; name: string; size: 1 | 2 | 4 | 8; signed: boolean } & EndianField)
  | ({ kind: "float"; name: string; size: 4 | 8 } & EndianField)
  | { kind: "bytes"; name: string; size: number }
  | { kind: "flags"; name: string; fields: Field[] }
  | { kind: "flagByte"; name: string; id: symbol }
  | { kind: "flagBit"; flagId: symbol; bit: number; field: Field }
  | { kind: "when"; field: string; value: unknown; fields: Field[] }
  | { kind: "repeat"; fields: Field[] }
  | { kind: "group"; fields: Field[] }

export type Packet = { fields: Field[] }

type FlagByteHandle = Field & {
  kind: "flagByte"
  bit(field: Field): Field
}

function intField(
  name: string,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
): Field {
  return { kind: "int", name, size, signed, littleEndian: true }
}

export function u8(name: string): Field {
  return intField(name, 1, false)
}
export function u16(name: string): Field {
  return intField(name, 2, false)
}
export function u32(name: string): Field {
  return intField(name, 4, false)
}
export function u64(name: string): Field {
  return intField(name, 8, false)
}
export function i8(name: string): Field {
  return intField(name, 1, true)
}
export function i16(name: string): Field {
  return intField(name, 2, true)
}
export function i32(name: string): Field {
  return intField(name, 4, true)
}
export function i64(name: string): Field {
  return intField(name, 8, true)
}
export function f32(name: string): Field {
  return { kind: "float", name, size: 4, littleEndian: true }
}
export function f64(name: string): Field {
  return { kind: "float", name, size: 8, littleEndian: true }
}
export function bytes(name: string, size: number): Field {
  return { kind: "bytes", name, size }
}

export function be(field: Field): Field {
  if (field.kind === "int" || field.kind === "float") {
    return { ...field, littleEndian: false }
  }
  if (field.kind === "flagBit") {
    return { ...field, field: be(field.field) }
  }
  return field
}

export function packet(fields: Field[]): Packet {
  return { fields: flatten(fields) }
}

function flatten(fields: Field[]): Field[] {
  const out: Field[] = []
  for (const f of fields) {
    if (f.kind === "group") out.push(...flatten(f.fields))
    else if (f.kind === "flags") {
      const fb = flagByte(f.name)
      out.push(fb)
      for (const child of f.fields) out.push(fb.bit(child))
    } else out.push(f)
  }
  return out
}

export function flags(name: string, fields: Field[]): Field {
  return { kind: "flags", name, fields }
}

export function flagByte(name: string): FlagByteHandle {
  const id = Symbol(name)
  let next = 0
  const handle = {
    kind: "flagByte" as const,
    name,
    id,
    bit(field: Field): Field {
      const bit = next++
      return { kind: "flagBit", flagId: id, bit, field }
    },
  }
  return handle
}

export function eq(field: string, value: unknown): { field: string; value: unknown } {
  return { field, value }
}

export function when(
  cond: { field: string; value: unknown },
  fields: Field[],
): Field {
  return { kind: "when", field: cond.field, value: cond.value, fields: flatten(fields) }
}

export function repeat(fields: Field[]): Field {
  return { kind: "repeat", fields: flatten(fields) }
}

function present(v: unknown): boolean {
  return v !== undefined && v !== null
}

function asNumber(v: unknown): number | bigint {
  if (typeof v === "bigint") return v
  if (typeof v === "number") return v
  throw new RangeError("expected number")
}

function writeInt(
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

function writeFloat(out: number[], value: number, size: 4 | 8, le: boolean): void {
  const buf = new ArrayBuffer(size)
  const view = new DataView(buf)
  if (size === 4) view.setFloat32(0, value, le)
  else view.setFloat64(0, value, le)
  const bytes = new Uint8Array(buf)
  for (let i = 0; i < size; i++) out.push(bytes[i]!)
}

function collectFlagBits(fields: Field[], id: symbol): { bit: number; field: Field }[] {
  const bits: { bit: number; field: Field }[] = []
  for (const f of fields) {
    if (f.kind === "flagBit" && f.flagId === id) bits.push({ bit: f.bit, field: f.field })
    if (f.kind === "when") bits.push(...collectFlagBits(f.fields, id))
    if (f.kind === "repeat") bits.push(...collectFlagBits(f.fields, id))
  }
  return bits
}

function flagValueFor(fields: Field[], id: symbol, values: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (present(values[fieldName(field)])) flags |= 1 << bit
  }
  return flags
}

function fieldName(field: Field): string {
  if (
    field.kind === "int" ||
    field.kind === "float" ||
    field.kind === "bytes" ||
    field.kind === "flags" ||
    field.kind === "flagByte"
  ) {
    return field.name
  }
  if (field.kind === "flagBit") return fieldName(field.field)
  return ""
}

function packFields(
  fields: Field[],
  allFields: Field[],
  values: Value,
  out: number[],
  flagBytes: Map<symbol, number>,
): void {
  for (const f of fields) {
    switch (f.kind) {
      case "int": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeInt(out, asNumber(values[f.name]), f.size, f.signed, f.littleEndian)
        break
      }
      case "float": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeFloat(out, Number(values[f.name]), f.size, f.littleEndian)
        break
      }
      case "bytes": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        const raw = values[f.name]
        const arr =
          raw instanceof Uint8Array
            ? raw
            : raw instanceof ArrayBuffer
              ? new Uint8Array(raw)
              : null
        if (!arr || arr.length !== f.size) throw new RangeError(`bad bytes ${f.name}`)
        for (let i = 0; i < arr.length; i++) out.push(arr[i]!)
        break
      }
      case "flagByte": {
        const v = flagValueFor(allFields, f.id, values)
        flagBytes.set(f.id, v)
        out.push(v & 0xff)
        break
      }
      case "flagBit": {
        const flags = flagBytes.get(f.flagId) ?? 0
        if ((flags & (1 << f.bit)) === 0) break
        packFields([f.field], allFields, values, out, flagBytes)
        break
      }
      case "when": {
        if (values[f.field] === f.value) {
          packFields(f.fields, allFields, values, out, flagBytes)
        }
        break
      }
      case "repeat": {
        let count = 0
        for (const child of f.fields) {
          const n = fieldName(child)
          if (!n) continue
          const v = values[n]
          if (Array.isArray(v)) count = Math.max(count, v.length)
          else if (present(v)) count = Math.max(count, 1)
        }
        for (let i = 0; i < count; i++) {
          const slice: Value = { ...values }
          for (const child of f.fields) {
            const n = fieldName(child)
            if (!n) continue
            const v = values[n]
            slice[n] = Array.isArray(v) ? v[i] : v
          }
          packFields(f.fields, allFields, slice, out, flagBytes)
        }
        break
      }
      case "flags":
      case "group":
        packFields(flatten([f]), allFields, values, out, flagBytes)
        break
    }
  }
}

export function pack(pkt: Packet, values: Value): Uint8Array {
  const out: number[] = []
  const flagBytes = new Map<symbol, number>()
  packFields(pkt.fields, pkt.fields, values, out, flagBytes)
  return Uint8Array.from(out)
}

type Cursor = { buf: Uint8Array; view: DataView; offset: number }

function short(field: string, needed: number, left: number): UnpackErr {
  return { ok: false, field, needed, left }
}

function readInt(
  cur: Cursor,
  name: string,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
  le: boolean,
): { ok: true; value: number | bigint } | UnpackErr {
  const left = cur.buf.length - cur.offset
  if (left < size) return short(name, size, left)
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

function readFloat(
  cur: Cursor,
  name: string,
  size: 4 | 8,
  le: boolean,
): { ok: true; value: number } | UnpackErr {
  const left = cur.buf.length - cur.offset
  if (left < size) return short(name, size, left)
  const value =
    size === 4
      ? cur.view.getFloat32(cur.offset, le)
      : cur.view.getFloat64(cur.offset, le)
  cur.offset += size
  return { ok: true, value }
}

function appendRepeat(values: Value, name: string, value: unknown): void {
  const prev = values[name]
  if (Array.isArray(prev)) prev.push(value)
  else if (present(prev)) values[name] = [prev, value]
  else values[name] = [value]
}

function unpackFields(
  fields: Field[],
  cur: Cursor,
  values: Value,
  flagBytes: Map<symbol, number>,
  repeating: boolean,
): UnpackErr | null {
  for (const f of fields) {
    switch (f.kind) {
      case "int": {
        const r = readInt(cur, f.name, f.size, f.signed, f.littleEndian)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.value)
        else values[f.name] = r.value
        break
      }
      case "float": {
        const r = readFloat(cur, f.name, f.size, f.littleEndian)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.value)
        else values[f.name] = r.value
        break
      }
      case "bytes": {
        const left = cur.buf.length - cur.offset
        if (left < f.size) return short(f.name, f.size, left)
        const slice = cur.buf.subarray(cur.offset, cur.offset + f.size)
        cur.offset += f.size
        const copy = new Uint8Array(slice)
        if (repeating) appendRepeat(values, f.name, copy)
        else values[f.name] = copy
        break
      }
      case "flagByte": {
        const r = readInt(cur, f.name, 1, false, true)
        if (!r.ok) return r
        const v = Number(r.value)
        flagBytes.set(f.id, v)
        values[f.name] = v
        break
      }
      case "flagBit": {
        const flags = flagBytes.get(f.flagId) ?? 0
        if ((flags & (1 << f.bit)) === 0) break
        const err = unpackFields([f.field], cur, values, flagBytes, repeating)
        if (err) return err
        break
      }
      case "when": {
        if (values[f.field] === f.value) {
          const err = unpackFields(f.fields, cur, values, flagBytes, repeating)
          if (err) return err
        }
        break
      }
      case "repeat": {
        while (cur.offset < cur.buf.length) {
          const before = cur.offset
          const err = unpackFields(f.fields, cur, values, flagBytes, true)
          if (err) {
            if (cur.offset === before && err.left > 0) return err
            return err
          }
        }
        break
      }
      case "flags":
      case "group": {
        const err = unpackFields(flatten([f]), cur, values, flagBytes, repeating)
        if (err) return err
        break
      }
    }
  }
  return null
}

export function unpack(pkt: Packet, bytes: Uint8Array | ArrayBuffer): UnpackResult {
  const buf =
    bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
  const cur: Cursor = {
    buf,
    view: new DataView(buf.buffer, buf.byteOffset, buf.byteLength),
    offset: 0,
  }
  const values: Value = {}
  const flagBytes = new Map<symbol, number>()
  const err = unpackFields(pkt.fields, cur, values, flagBytes, false)
  if (err) return err
  if (cur.offset < buf.length) {
    return short("", 0, buf.length - cur.offset)
  }
  return { ok: true, ...values }
}
