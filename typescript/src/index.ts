import {
  asNumber,
  groupOn,
  present,
  readBits,
  readFloat,
  readInt,
  readSized,
  readU2,
  readUtf8,
  scalarChildNames,
  writeBits,
  writeFloat,
  writeInt,
  writeSized,
  writeU2,
  writeUtf8,
  type ShortErr,
  type TypeMismatchErr,
  type ViewCursor,
} from "./kinds.ts"

export type Value = Record<string, unknown>

export type UnpackOk = { ok: true } & Value
export type UnpackErr = ShortErr | TypeMismatchErr
export type UnpackResult = UnpackOk | UnpackErr
export type EntityResult<T> = { ok: true; value: T } | UnpackErr

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
  | { kind: "group"; name: string; fields: Field[] }
  | { kind: "sized"; name: string; count: string }
  | { kind: "u2"; names: string[] }
  | { kind: "bits"; name: string; count: string }
  | { kind: "utf8"; name: string }
  | { kind: "list"; name: string; element: Field }
  | { kind: "dict"; name: string; element: Field }
  | { kind: "typeNum"; value: number }

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

export function typeNum(value: number): Field {
  if (!Number.isInteger(value) || value < 0 || value > 255) {
    throw new RangeError("typeNum: expected 0..255")
  }
  return { kind: "typeNum", value }
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
  const flat = flatten(fields)
  assertTypeNumPlacement(flat)
  return { fields: flat }
}

function flatten(fields: Field[]): Field[] {
  const out: Field[] = []
  for (const f of fields) {
    if (f.kind === "flags") {
      const fb = flagByte(f.name)
      out.push(fb)
      for (const child of f.fields) out.push(fb.bit(child))
    } else out.push(f)
  }
  return out
}

function assertTypeNumPlacement(fields: Field[]): void {
  for (let i = 0; i < fields.length; i++) {
    const f = fields[i]!
    if (f.kind === "typeNum") {
      if (i !== 0) throw new RangeError("typeNum: must be the first top-level field")
      continue
    }
    assertNoNestedTypeNum(f)
  }
  if (fields.filter((f) => f.kind === "typeNum").length > 1) {
    throw new RangeError("typeNum: only once")
  }
}

function assertNoNestedTypeNum(f: Field): void {
  switch (f.kind) {
    case "typeNum":
      throw new RangeError("typeNum: cannot be nested")
    case "flags":
    case "when":
    case "repeat":
    case "group":
      for (const child of f.fields) assertNoNestedTypeNum(child)
      break
    case "flagBit":
      assertNoNestedTypeNum(f.field)
      break
    case "list":
    case "dict":
      assertNoNestedTypeNum(f.element)
      break
  }
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

export function group(name: string, fields: Field[]): Field {
  return { kind: "group", name, fields }
}

export function sized(name: string, countField: string): Field {
  return { kind: "sized", name, count: countField }
}

export function u2(...names: string[]): Field {
  if (names.length === 0) throw new RangeError("u2 needs at least one name")
  return { kind: "u2", names }
}

export function bits(name: string, countField: string): Field {
  return { kind: "bits", name, count: countField }
}

export function utf8(name: string): Field {
  return { kind: "utf8", name }
}

export function list(name: string, element: Field): Field {
  const flat = flatten([element])
  if (flat.length !== 1 || flat[0]!.kind === "repeat") {
    throw new RangeError("list element must be one field")
  }
  return { kind: "list", name, element: flat[0]! }
}

export function dict(name: string, element: Field): Field {
  const flat = flatten([element])
  if (flat.length !== 1) {
    throw new RangeError("dictionary element must be one field")
  }
  if (flat[0]!.kind === "repeat") {
    throw new RangeError("repeat is not a dictionary element")
  }
  return { kind: "dict", name, element: flat[0]! }
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

function bitOn(field: Field, values: Value): boolean {
  if (field.kind === "group") {
    return groupOn(values, field.name, scalarChildNames(field.fields))
  }
  return present(values[fieldName(field)])
}

function flagValueFor(fields: Field[], id: symbol, values: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (bitOn(field, values)) flags |= 1 << bit
  }
  return flags
}

function fieldName(field: Field): string {
  if (
    field.kind === "int" ||
    field.kind === "float" ||
    field.kind === "bytes" ||
    field.kind === "flags" ||
    field.kind === "flagByte" ||
    field.kind === "group" ||
    field.kind === "sized" ||
    field.kind === "bits" ||
    field.kind === "utf8" ||
    field.kind === "list" ||
    field.kind === "dict"
  ) {
    return field.name
  }
  if (field.kind === "flagBit") return fieldName(field.field)
  if (field.kind === "u2") return field.names[0] ?? ""
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
        if (f.field.kind === "group") {
          packFields(f.field.fields, allFields, values, out, flagBytes)
        } else {
          packFields([f.field], allFields, values, out, flagBytes)
        }
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
      case "group":
        packFields(f.fields, allFields, values, out, flagBytes)
        break
      case "sized":
        writeSized(out, f.name, values[f.count], values[f.name])
        break
      case "u2":
        writeU2(out, f.names, (n) => values[n])
        break
      case "bits":
        writeBits(out, f.name, Number(values[f.count]), values[f.name])
        break
      case "utf8":
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeUtf8(out, f.name, values[f.name])
        break
      case "list": {
        const items = values[f.name]
        if (!Array.isArray(items)) throw new RangeError(`${f.name}: expected list`)
        if (items.length > 65535) throw new RangeError(`${f.name}: length ${items.length}`)
        out.push(items.length & 0xff, (items.length >> 8) & 0xff)
        const child = fieldName(f.element)
        for (const item of items) {
          const slice: Value = { ...values, [child]: item }
          packFields([f.element], allFields, slice, out, flagBytes)
        }
        break
      }
      case "dict": {
        const items = values[f.name]
        if (!isPlainObject(items)) throw new RangeError(`${f.name}: expected dictionary`)
        const enc = new TextEncoder()
        const keys = Object.keys(items).sort((a, b) => {
          const ba = enc.encode(a)
          const bb = enc.encode(b)
          const n = Math.min(ba.length, bb.length)
          for (let i = 0; i < n; i++) {
            const d = ba[i]! - bb[i]!
            if (d !== 0) return d
          }
          return ba.length - bb.length
        })
        if (keys.length > 65535) throw new RangeError(`${f.name}: length ${keys.length}`)
        out.push(keys.length & 0xff, (keys.length >> 8) & 0xff)
        const child = fieldName(f.element)
        const record = items as Value
        for (const key of keys) {
          writeUtf8(out, f.name, key)
          const slice: Value = { ...values, [child]: record[key] }
          packFields([f.element], allFields, slice, out, flagBytes)
        }
        break
      }
      case "flags":
        packFields(flatten([f]), allFields, values, out, flagBytes)
        break
      case "typeNum":
        out.push(f.value & 0xff)
        break
    }
  }
}

export function pack(pkt: Packet, values: object): Uint8Array {
  const flat = flattenValues(values)
  const out: number[] = []
  const flagBytes = new Map<symbol, number>()
  packFields(pkt.fields, pkt.fields, flat, out, flagBytes)
  return Uint8Array.from(out)
}

function flattenValues(values: object): Value {
  const out: Value = {}
  for (const [key, raw] of Object.entries(values)) {
    if (raw === undefined || raw === null) continue
    if (isPlainObject(raw)) {
      out[key] = raw
      Object.assign(out, flattenValues(raw))
    } else out[key] = raw
  }
  return out
}

function isPlainObject(raw: unknown): raw is object {
  return typeof raw === "object" && raw !== null && !Array.isArray(raw) && !ArrayBuffer.isView(raw)
}

function short(field: string, needed: number, left: number): ShortErr {
  return { ok: false, field, needed, left }
}

function appendRepeat(values: Value, name: string, value: unknown): void {
  const prev = values[name]
  if (Array.isArray(prev)) prev.push(value)
  else if (present(prev)) values[name] = [prev, value]
  else values[name] = [value]
}

function unpackFields(
  fields: Field[],
  cur: ViewCursor,
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
        if (f.field.kind === "group") {
          if (f.field.fields.length === 0) values[f.field.name] = true
          const err = unpackFields(f.field.fields, cur, values, flagBytes, repeating)
          if (err) return err
        } else {
          const err = unpackFields([f.field], cur, values, flagBytes, repeating)
          if (err) return err
        }
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
      case "group": {
        if (f.fields.length === 0) values[f.name] = true
        const err = unpackFields(f.fields, cur, values, flagBytes, repeating)
        if (err) return err
        break
      }
      case "sized": {
        const r = readSized(cur, f.name, values[f.count])
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.value)
        else values[f.name] = r.value
        break
      }
      case "u2": {
        const r = readU2(cur, f.names)
        if (!r.ok) return r
        for (let i = 0; i < f.names.length; i++) {
          const name = f.names[i]!
          if (repeating) appendRepeat(values, name, r.values[i])
          else values[name] = r.values[i]
        }
        break
      }
      case "bits": {
        const r = readBits(cur, f.name, Number(values[f.count]))
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.values)
        else values[f.name] = r.values
        break
      }
      case "utf8": {
        const r = readUtf8(cur, f.name)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.value)
        else values[f.name] = r.value
        break
      }
      case "list": {
        if (cur.offset + 2 > cur.buf.length) return short(f.name, 2, cur.buf.length - cur.offset)
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: unknown[] = []
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const one: Value = {}
          const err = unpackFields([f.element], cur, one, flagBytes, false)
          if (err) return err
          items.push(one[child])
        }
        if (repeating) appendRepeat(values, f.name, items)
        else values[f.name] = items
        break
      }
      case "dict": {
        if (cur.offset + 2 > cur.buf.length) return short(f.name, 2, cur.buf.length - cur.offset)
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: Value = {}
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const key = readUtf8(cur, f.name)
          if (!key.ok) return key
          const one: Value = {}
          const err = unpackFields([f.element], cur, one, flagBytes, false)
          if (err) return err
          if (Object.prototype.hasOwnProperty.call(items, key.value)) {
            return short(f.name, 0, 0)
          }
          items[key.value] = one[child]
        }
        if (repeating) appendRepeat(values, f.name, items)
        else values[f.name] = items
        break
      }
      case "flags": {
        const err = unpackFields(flatten([f]), cur, values, flagBytes, repeating)
        if (err) return err
        break
      }
      case "typeNum": {
        const left = cur.buf.length - cur.offset
        if (left < 1) return short("", 1, left)
        const actual = cur.view.getUint8(cur.offset)
        cur.offset += 1
        if (actual !== f.value) {
          return { ok: false, expected: f.value, actual }
        }
        break
      }
    }
  }
  return null
}

export function unpack(pkt: Packet, bytes: Uint8Array | ArrayBuffer): UnpackResult
export function unpack<T extends object>(
  pkt: Packet,
  bytes: Uint8Array | ArrayBuffer,
  ctor: new () => T,
): EntityResult<T>
export function unpack<T extends object>(
  pkt: Packet,
  bytes: Uint8Array | ArrayBuffer,
  ctor?: new () => T,
): UnpackResult | EntityResult<T> {
  const buf =
    bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
  const cur: ViewCursor = {
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
  if (!ctor) return { ok: true, ...values }
  return { ok: true, value: fillEntity(ctor, values) }
}

function fillEntity<T extends object>(ctor: new () => T, values: Value): T {
  const entity = new ctor()
  assignEntity(entity, values)
  return entity
}

function assignEntity(target: object, values: Value): void {
  const record = target as Value
  for (const key of Object.keys(target)) {
    const current = record[key]
    if (isPlainObject(current)) {
      if (nestedPresent(current, values)) assignEntity(current, values)
      else record[key] = null
      continue
    }
    if (Object.prototype.hasOwnProperty.call(values, key) && values[key] != null)
      record[key] = values[key]
  }
}

function nestedPresent(sample: object, values: Value): boolean {
  const record = sample as Value
  for (const key of Object.keys(sample)) {
    const current = record[key]
    if (isPlainObject(current)) {
      if (nestedPresent(current, values)) return true
    } else if (Object.prototype.hasOwnProperty.call(values, key) && values[key] != null) {
      return true
    }
  }
  return false
}
