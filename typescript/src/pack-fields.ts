import {
  fieldName,
  flatten,
  flattenValues,
  isObjectLike,
  isPlainObject,
  itemGroup,
  type Field,
} from "./fields.ts"
import { bitOn, droppedBody, flagValueFor, type PackedFlagByte } from "./flag-bits.ts"
import { refName } from "./ref-scope.ts"
import {
  refuseLoneBuffers,
  refuseLoneDicts,
  refuseLongLists,
  refuseRoundsOverLimit,
  roundCount,
  roundShape,
  sliceRound,
} from "./rounds.ts"
import {
  present,
  sameValue,
  writeBits,
  writeFloat,
  writeInt,
  writePacked,
  writeSized,
  writeU2,
  writeUtf8,
  type Value,
} from "./kinds.ts"
import { borrowedCount, seen, writtenCount } from "./written.ts"

// What one pack call carries: the flag bytes written so far, and the scheme's `maxRounds`, which
// bounds the rounds a times writes as it bounds the rounds an unpack reads.
export type PackState = { flagBytes: Map<symbol, PackedFlagByte>; maxRounds: number }

// One list or dict item. A group or flags element packs from the members of the item; any other
// element is one value, read under the element's own name.
function packItem(
  f: Extract<Field, { kind: "list" | "dict" }>,
  item: unknown,
  values: Value,
  allFields: Field[],
  out: number[],
  state: PackState,
): void {
  const group = itemGroup(f.element)
  if (group === null) {
    const slice: Value = { ...values, [fieldName(f.element)]: item }
    packFields([f.element], allFields, slice, out, state, newScope())
    return
  }
  if (!isObjectLike(item)) throw new RangeError(`${f.name}: expected an object for each item`)
  packFields(group.fields, group.fields, flattenValues(item, group.fields), out, state, newScope())
}

function packRounds(
  fields: Field[],
  names: Set<string>,
  count: number,
  allFields: Field[],
  values: Value,
  out: number[],
  state: PackState,
): void {
  for (let i = 0; i < count; i++) {
    packFields(fields, allFields, sliceRound(values, names, i), out, state, newScope())
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
  state: PackState,
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
        // A combined `flags` decides each bit in order, as its member is reached, and patches the byte at
        // the end; a split flag byte is decided where it is read.
        const flags = f.inOrder ? 0 : flagValueFor(allFields, f.id, values, wrote)
        state.flagBytes.set(f.id, { at: out.length, flags, inOrder: f.inOrder === true })
        out.push(flags & 0xff)
        break
      }
      case "flagBit": {
        const byte = state.flagBytes.get(f.flagId)
        if (byte === undefined) break
        if (byte.inOrder) {
          if (!bitOn(f.field, values, wrote)) break
          byte.flags |= 1 << f.bit
          out[byte.at] = byte.flags
        } else if ((byte.flags & (1 << f.bit)) === 0) {
          // The bit was decided where the byte sits. A body whose condition or count is not written
          // by then would be dropped without a word, and its own unpack reads no bit for it.
          const dropped = droppedBody(f.field, values, wrote)
          if (dropped !== null) {
            throw new RangeError(
              `${dropped}: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte`,
            )
          }
          break
        }
        if (f.field.kind === "group") {
          packFields(f.field.fields, allFields, values, out, state, wrote)
        } else {
          packFields([f.field], allFields, values, out, state, wrote)
        }
        break
      }
      case "when": {
        if (sameValue(seen(wrote, refName(f)), f.value)) {
          packFields(f.fields, allFields, values, out, state, wrote)
        }
        break
      }
      case "repeat": {
        const { names, dictNames, bufferNames } = roundShape(f)
        refuseLoneDicts(dictNames, values)
        refuseLoneBuffers(bufferNames, values)
        packRounds(f.fields, names, roundCount(names, values), allFields, values, out, state)
        break
      }
      case "group":
        packFields(f.fields, allFields, values, out, state, wrote)
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
        const { names, dictNames, bufferNames } = roundShape(f)
        refuseRoundsOverLimit(f, names, count, state.maxRounds)
        refuseLongLists(names, count, values)
        refuseLoneDicts(dictNames, values)
        refuseLoneBuffers(bufferNames, values)
        packRounds(f.fields, names, count, allFields, values, out, state)
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
        for (const item of items) packItem(f, item, values, allFields, out, state)
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
          packItem(f, record[key], values, allFields, out, state)
        }
        break
      }
      case "flags": {
        // Its flag byte is made here, so its bits are looked up among the fields made with it.
        const flat = flatten([f])
        packFields(flat, flat, values, out, state, wrote)
        break
      }
    }
  }
}
