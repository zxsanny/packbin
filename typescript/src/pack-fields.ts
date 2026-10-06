import {
  fieldName,
  flatten,
  flattenValues,
  isPlainObject,
  itemGroup,
  type Field,
} from "./fields.ts"
import { flagValueFor } from "./flag-bits.ts"
import { refName } from "./ref-scope.ts"
import { refuseLongLists, roundCount, roundNames, sliceRound } from "./rounds.ts"
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

// What a `when` or a count reads is what pack wrote in the scope, as unpack reads what it has read: a
// field that was skipped or absent was not written, and a `when` sees it as `undefined`, as unpack does.
function seen(wrote: Value, ref: string): unknown {
  return Object.hasOwn(wrote, ref) ? wrote[ref] : undefined
}

function writtenCount(ref: string, label: string, wrote: Value): unknown {
  if (!Object.hasOwn(wrote, ref)) throw new RangeError(`${label}: count ${ref} was not written`)
  return wrote[ref]
}

function borrowedCount(ref: string, bias: number, label: string, wrote: Value): number {
  const raw = writtenCount(ref, label, wrote)
  const count = validCount(raw, bias)
  if (count === null) {
    // Pack keeps throwing; the message tells a missing count from a negative one.
    throw new RangeError(
      typeof raw === "bigint"
        ? `${label}: item count ${raw + BigInt(bias)}`
        : typeof raw === "number" && Number.isInteger(raw)
          ? `${label}: item count ${raw + bias}`
          : `${label}: count missing`,
    )
  }
  return count
}

// One list or dict item. A group or flags element packs from the members of the item; any other
// element is one value, read under the element's own name.
function packItem(
  f: Extract<Field, { kind: "list" | "dict" }>,
  item: unknown,
  values: Value,
  allFields: Field[],
  out: number[],
  flagBytes: Map<symbol, number>,
): void {
  const group = itemGroup(f.element)
  if (group === null) {
    const slice: Value = { ...values, [fieldName(f.element)]: item }
    packFields([f.element], allFields, slice, out, flagBytes, newScope())
    return
  }
  if (!isPlainObject(item)) throw new RangeError(`${f.name}: expected an object for each item`)
  packFields(group.fields, group.fields, flattenValues(item, group.fields), out, flagBytes, newScope())
}

function packRounds(
  fields: Field[],
  names: Set<string>,
  count: number,
  allFields: Field[],
  values: Value,
  out: number[],
  flagBytes: Map<symbol, number>,
): void {
  for (let i = 0; i < count; i++) {
    packFields(fields, allFields, sliceRound(values, names, i), out, flagBytes, newScope())
  }
}

// The values pack has written in one scope: the top level, a round, or a list or dict item.
export function newScope(): Value {
  return {}
}

export function packFields(
  fields: Field[],
  allFields: Field[],
  values: Value,
  out: number[],
  flagBytes: Map<symbol, number>,
  wrote: Value,
): void {
  for (const f of fields) {
    switch (f.kind) {
      case "int": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeInt(out, f.name, values[f.name], f.size, f.signed, f.littleEndian)
        wrote[f.name] = values[f.name]
        break
      }
      case "float": {
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeFloat(out, f.name, values[f.name], f.size, f.littleEndian)
        // A reader sees an f32 as it was rounded to 32 bits.
        wrote[f.name] = f.size === 4 ? Math.fround(values[f.name] as number) : values[f.name]
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
        wrote[f.name] = values[f.name]
        break
      }
      case "bool":
        // Reached only through a set flag bit: a clear bit writes nothing, so the bool is not written.
        wrote[f.name] = true
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
          packFields(f.field.fields, allFields, values, out, flagBytes, wrote)
        } else {
          packFields([f.field], allFields, values, out, flagBytes, wrote)
        }
        break
      }
      case "when": {
        if (sameValue(seen(wrote, refName(f)), f.value)) {
          packFields(f.fields, allFields, values, out, flagBytes, wrote)
        }
        break
      }
      case "repeat": {
        const names = roundNames(f.fields, true)
        packRounds(f.fields, names, roundCount(names, values), allFields, values, out, flagBytes)
        break
      }
      case "group":
        packFields(f.fields, allFields, values, out, flagBytes, wrote)
        break
      case "sized":
        writeSized(out, f.name, writtenCount(refName(f), f.name, wrote), values[f.name])
        wrote[f.name] = values[f.name]
        break
      case "u2":
        writeU2(out, f.slots, (n) => values[n])
        for (const slot of f.slots) wrote[slot.name] = values[slot.name]
        break
      case "bits":
        writeBits(out, f.name, Number(writtenCount(refName(f), f.name, wrote)), values[f.name])
        wrote[f.name] = values[f.name]
        break
      case "packed": {
        const count = borrowedCount(refName(f), f.bias, f.name, wrote)
        writePacked(out, f.name, f.width, count, values[f.name])
        wrote[f.name] = values[f.name]
        break
      }
      case "times": {
        const count = borrowedCount(refName(f), 0, "times", wrote)
        const names = roundNames(f.fields, true)
        refuseLongLists(names, count, values)
        packRounds(f.fields, names, count, allFields, values, out, flagBytes)
        break
      }
      case "utf8":
        if (!present(values[f.name])) throw new RangeError(`missing ${f.name}`)
        writeUtf8(out, f.name, values[f.name])
        wrote[f.name] = values[f.name]
        break
      case "list": {
        const items = values[f.name]
        if (!Array.isArray(items)) throw new RangeError(`${f.name}: expected list`)
        if (items.length > 65535) throw new RangeError(`${f.name}: length ${items.length}`)
        out.push(items.length & 0xff, (items.length >> 8) & 0xff)
        for (const item of items) packItem(f, item, values, allFields, out, flagBytes)
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
        const record = items as Value
        for (const key of keys) {
          writeUtf8(out, f.name, key)
          packItem(f, record[key], values, allFields, out, flagBytes)
        }
        break
      }
      case "flags": {
        // Its flag byte is made here, so its bits are looked up among the fields made with it.
        const flat = flatten([f])
        packFields(flat, flat, values, out, flagBytes, wrote)
        break
      }
    }
  }
}
