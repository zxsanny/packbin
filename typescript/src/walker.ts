import { fieldName, flatten, nameById, type Field } from "./fields.ts"
import {
  present,
  readBits,
  readFloat,
  readInt,
  readPacked,
  readSized,
  readU2,
  readUtf8,
  validCount,
  type ShortErr,
  type TypeMismatchErr,
  type Value,
  type ViewCursor,
} from "./kinds.ts"

export type UnpackErr = ShortErr | TypeMismatchErr

function short(field: string, needed: number, left: number): ShortErr {
  return { ok: false, field, needed, left }
}

// A negative or absent count is reported with the duplicate-key shape: the counted field,
// nothing more needed, the bytes left where it starts.
function unreadable(field: string, cur: ViewCursor): ShortErr {
  return short(field, 0, cur.buf.length - cur.offset)
}

function firstName(fields: Field[]): string {
  for (const f of fields) {
    const n = fieldName(f)
    if (n) return n
    if (f.kind === "when" || f.kind === "repeat" || f.kind === "times") {
      const inner = firstName(f.fields)
      if (inner) return inner
    }
  }
  return ""
}

function appendRepeat(values: Value, name: string, value: unknown): void {
  const prev = values[name]
  if (Array.isArray(prev)) prev.push(value)
  else if (present(prev)) values[name] = [prev, value]
  else values[name] = [value]
}

export function unpackFields(
  fields: Field[],
  allFields: Field[],
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
      case "bool":
        if (repeating) appendRepeat(values, f.name, true)
        else values[f.name] = true
        break
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
          const err = unpackFields(
            f.field.fields,
            allFields,
            cur,
            values,
            flagBytes,
            repeating,
          )
          if (err) return err
        } else {
          const err = unpackFields(
            [f.field],
            allFields,
            cur,
            values,
            flagBytes,
            repeating,
          )
          if (err) return err
        }
        break
      }
      case "when": {
        if (values[nameById(allFields, f.fieldId)] === f.value) {
          const err = unpackFields(
            f.fields,
            allFields,
            cur,
            values,
            flagBytes,
            repeating,
          )
          if (err) return err
        }
        break
      }
      case "repeat": {
        while (cur.offset < cur.buf.length) {
          const before = cur.offset
          const err = unpackFields(f.fields, allFields, cur, values, flagBytes, true)
          if (err) return err
          // A round that reads nothing would repeat forever; the unread bytes are trailing.
          if (cur.offset === before) break
        }
        break
      }
      case "group": {
        if (f.fields.length === 0) values[f.name] = true
        const err = unpackFields(f.fields, allFields, cur, values, flagBytes, repeating)
        if (err) return err
        break
      }
      case "sized": {
        const count = validCount(values[nameById(allFields, f.countId)])
        if (count === null) return unreadable(f.name, cur)
        const r = readSized(cur, f.name, count)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.value)
        else values[f.name] = r.value
        break
      }
      case "u2": {
        const r = readU2(cur, f.slots)
        if (!r.ok) return r
        for (let i = 0; i < f.slots.length; i++) {
          const name = f.slots[i]!.name
          if (repeating) appendRepeat(values, name, r.values[i])
          else values[name] = r.values[i]
        }
        break
      }
      case "bits": {
        // bits has always taken a bigint count (u64 source); past 2^53 it cannot be exact.
        const raw = values[nameById(allFields, f.countId)]
        const count = validCount(
          typeof raw === "bigint" && raw <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(raw) : raw,
        )
        if (count === null) return unreadable(f.name, cur)
        const r = readBits(cur, f.name, count)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.values)
        else values[f.name] = r.values
        break
      }
      case "packed": {
        const count = validCount(values[nameById(allFields, f.countId)], f.bias)
        if (count === null) return unreadable(f.name, cur)
        const r = readPacked(cur, f.name, f.width, count)
        if (!r.ok) return r
        if (repeating) appendRepeat(values, f.name, r.values)
        else values[f.name] = r.values
        break
      }
      case "times": {
        const count = validCount(values[nameById(allFields, f.countId)])
        if (count === null) return unreadable(firstName(f.fields), cur)
        const built: Record<string, unknown[]> = {}
        for (let i = 0; i < count; i++) {
          const group: Value = {}
          const before = cur.offset
          const err = unpackFields(f.fields, allFields, cur, group, flagBytes, false)
          if (err) return err
          // A round that reads nothing would repeat up to `count` times for no input.
          if (cur.offset === before) return unreadable(firstName(f.fields), cur)
          for (const [key, value] of Object.entries(group)) {
            const list = built[key]
            if (list) list.push(value)
            else built[key] = [value]
          }
        }
        for (const [key, list] of Object.entries(built)) values[key] = list
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
        if (cur.offset + 2 > cur.buf.length) {
          return short(f.name, 2, cur.buf.length - cur.offset)
        }
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: unknown[] = []
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const one: Value = {}
          const before = cur.offset
          const err = unpackFields([f.element], allFields, cur, one, flagBytes, false)
          if (err) return err
          // An element that reads nothing would be repeated up to 65535 times for no input.
          if (cur.offset === before) return unreadable(f.name, cur)
          items.push(one[child])
        }
        if (repeating) appendRepeat(values, f.name, items)
        else values[f.name] = items
        break
      }
      case "dict": {
        if (cur.offset + 2 > cur.buf.length) {
          return short(f.name, 2, cur.buf.length - cur.offset)
        }
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: Value = {}
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const key = readUtf8(cur, f.name)
          if (!key.ok) return key
          const one: Value = {}
          const before = cur.offset
          const err = unpackFields([f.element], allFields, cur, one, flagBytes, false)
          if (err) return err
          if (cur.offset === before) return unreadable(f.name, cur)
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
        const err = unpackFields(
          flatten([f]),
          allFields,
          cur,
          values,
          flagBytes,
          repeating,
        )
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
  const err = unpackFields(fields, fields, cur, values, flagBytes, false)
  if (err) return err
  if (cur.offset < buf.length) {
    return short("", 0, buf.length - cur.offset)
  }
  return { ok: true, values, offset: cur.offset }
}
