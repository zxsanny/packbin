import {
  fieldName,
  flagValueFor,
  flatten,
  isPlainObject,
  type Field,
} from "./fields.ts"
import { refName } from "./ref-scope.ts"
import {
  present,
  sameValue,
  validCount,
  writeBits,
  writeFloat,
  writeInt,
  writePacked,
  writeSized,
  writeU2,
  writeUtf8,
  type Value,
} from "./kinds.ts"

function borrowedCount(ref: string, bias: number, label: string, values: Value): number {
  const raw = values[ref]
  const count = validCount(raw, bias)
  if (count === null) {
    // Pack keeps throwing; the message tells a missing count from a negative one.
    throw new RangeError(
      typeof raw === "number" && Number.isInteger(raw)
        ? `${label}: item count ${raw + bias}`
        : `${label}: count missing`,
    )
  }
  return count
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
        writeInt(out, f.name, values[f.name], f.size, f.signed, f.littleEndian)
        break
      }
      case "float": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeFloat(out, f.name, values[f.name], f.size, f.littleEndian)
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
      case "bool":
        break
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
        if (sameValue(values[refName(f)], f.value)) {
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
        writeSized(out, f.name, values[refName(f)], values[f.name])
        break
      case "u2":
        writeU2(out, f.slots, (n) => values[n])
        break
      case "bits":
        writeBits(
          out,
          f.name,
          Number(values[refName(f)]),
          values[f.name],
        )
        break
      case "packed": {
        const count = borrowedCount(refName(f), f.bias, f.name, values)
        writePacked(out, f.name, f.width, count, values[f.name])
        break
      }
      case "times": {
        const count = borrowedCount(refName(f), 0, "times", values)
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
