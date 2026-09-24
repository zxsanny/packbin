import {
  fieldName,
  flagValueFor,
  flatten,
  isPlainObject,
  type Field,
} from "./fields.ts"
import {
  asNumber,
  present,
  readBits,
  readFloat,
  readInt,
  readSized,
  readU2,
  readUtf8,
  writeBits,
  writeFloat,
  writeInt,
  writeSized,
  writeU2,
  writeUtf8,
  type ShortErr,
  type TypeMismatchErr,
  type Value,
  type ViewCursor,
} from "./kinds.ts"

export type UnpackErr = ShortErr | TypeMismatchErr

function short(field: string, needed: number, left: number): ShortErr {
  return { ok: false, field, needed, left }
}

function appendRepeat(values: Value, name: string, value: unknown): void {
  const prev = values[name]
  if (Array.isArray(prev)) prev.push(value)
  else if (present(prev)) values[name] = [prev, value]
  else values[name] = [value]
}

export function packFields(
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
    }
  }
}

export function unpackFields(
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
            if (cur.offset === before && "left" in err && err.left > 0) return err
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
    }
  }
  return null
}

export function unpackBody(
  fields: Field[],
  buf: Uint8Array,
  offset: number,
): { ok: true; values: Value; offset: number } | UnpackErr {
  const cur: ViewCursor = {
    buf,
    view: new DataView(buf.buffer, buf.byteOffset, buf.byteLength),
    offset,
  }
  const values: Value = {}
  const flagBytes = new Map<symbol, number>()
  const err = unpackFields(fields, cur, values, flagBytes, false)
  if (err) return err
  if (cur.offset < buf.length) {
    return short("", 0, buf.length - cur.offset)
  }
  return { ok: true, values, offset: cur.offset }
}

export function fillEntity<T extends object>(ctor: new () => T, values: Value): T {
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
