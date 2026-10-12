import {
  fieldName,
  flatten,
  flattenValues,
  isObjectLike,
  isPlainObject,
  itemGroup,
  type Field,
} from "./fields.ts"
import { bitOn, droppedBody, flagValueFor, refuseUnwrittenCount, type PackedFlagByte } from "./flag-bits.ts"
import type { PackOut } from "./pack-out.ts"
import { refName } from "./ref-scope.ts"
import {
  refuseLoneBuffers,
  refuseLoneDicts,
  refuseLongLists,
  refuseRepeatOverLimit,
  refuseRoundsOverLimit,
  refuseShortOptional,
  roundCount,
  roundMember,
  overlay,
  roundShape,
  sliceRound,
  type RoundShape,
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

// What one pack call carries: the flag bytes written so far, the scheme's `maxRounds`, which bounds the
// rounds a repeat or times writes as it bounds the rounds an unpack reads, and `maxSlots` with the slots
// the rounds of this call have charged so far, as one unpack charges them.
export type PackState = {
  flagBytes: Map<symbol, PackedFlagByte>
  maxRounds: number
  maxSlots: number
  slots: number
}

// One list or dict item. A group or flags element packs from the members of the item; any other
// element is one value, read under the element's own name.
function packItem(
  f: Extract<Field, { kind: "list" | "dict" }>,
  item: unknown,
  values: Value,
  allFields: Field[],
  out: PackOut,
  state: PackState,
): void {
  const group = itemGroup(f.element)
  if (group === null) {
    packFields([f.element], allFields, overlay(values, fieldName(f.element), item), out, state, newScope())
    return
  }
  if (!isObjectLike(item)) throw new RangeError(`${f.name}: expected an object for each item`)
  packFields(group.fields, group.fields, flattenValues(item, group.fields), out, state, newScope())
}

// Each round is charged its width against `maxSlots` as it starts, before its bytes, as unpack charges
// it, so pack refuses at the round where the same scheme's unpack would.
function packRounds(
  f: Extract<Field, { kind: "repeat" | "times" }>,
  shape: RoundShape,
  count: number,
  allFields: Field[],
  values: Value,
  out: PackOut,
  state: PackState,
): void {
  for (let i = 0; i < count; i++) {
    const slots = state.slots + shape.width
    if (slots > state.maxSlots) {
      throw new RangeError(
        `${roundMember(f, shape.names)}: the rounds would hold ${slots} slots, above the limit of ${state.maxSlots} slots`,
      )
    }
    state.slots = slots
    packFields(f.fields, allFields, sliceRound(values, shape.names, i), out, state, newScope())
  }
}

// A combined flags' byte has no name of its own: it is named by the first name its members declare.
function firstBitName(fields: Field[], id: symbol): string {
  const bit = fields.find((f) => f.kind === "flagBit" && f.flagId === id)
  return bit === undefined ? "" : declaredName(bit)
}

// The first name `field` declares, looking into a when, repeat, times, flags or nameless group.
function declaredName(field: Field): string {
  if (field.kind === "flagBit") return declaredName(field.field)
  const own = fieldName(field)
  if (own !== "" || !("fields" in field)) return own
  for (const child of field.fields) {
    const name = declaredName(child)
    if (name !== "") return name
  }
  return ""
}

// The values pack has written in one scope: the top level, a round, or a list or dict item.
export function newScope(): Value {
  return {}
}

export function packFields(
  fields: Field[],
  allFields: Field[],
  values: Value,
  out: PackOut,
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
        out.append(f.name, arr)
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
        out.byte(f.name || firstBitName(fields, f.id), flags & 0xff)
        break
      }
      case "flagBit": {
        const byte = state.flagBytes.get(f.flagId)
        if (byte === undefined) break
        if (byte.inOrder) {
          if (!bitOn(f.field, values, wrote)) {
            // A times whose count was not written (skipped, or under a clear bit) writes no round, so the
            // values given for it would be dropped without a word.
            const dropped = droppedBody(f.field, values, wrote)
            if (dropped !== null) {
              throw new RangeError(
                `${dropped}: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times`,
              )
            }
            refuseUnwrittenCount(f.field, values, wrote)
            break
          }
          byte.flags |= 1 << f.bit
          out.patch(byte.at, byte.flags)
        } else if ((byte.flags & (1 << f.bit)) === 0) {
          // The bit was decided where the byte sits. A body whose condition or count is not written
          // by then would be dropped without a word, and its own unpack reads no bit for it.
          const dropped = droppedBody(f.field, values, wrote)
          if (dropped !== null) {
            throw new RangeError(
              `${dropped}: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte`,
            )
          }
          refuseUnwrittenCount(f.field, values, wrote)
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
        const shape = roundShape(f)
        refuseRepeatOverLimit(shape.names, values, state.maxRounds)
        const count = roundCount(shape.names, values)
        refuseShortOptional(shape.optionalNames, values, count)
        refuseLoneDicts(shape.dictNames, values)
        refuseLoneBuffers(shape.bufferNames, values)
        packRounds(f, shape, count, allFields, values, out, state)
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
        const shape = roundShape(f)
        refuseRoundsOverLimit(f, shape.names, count, state.maxRounds)
        refuseLongLists(shape.names, count, values)
        refuseLoneDicts(shape.dictNames, values)
        refuseLoneBuffers(shape.bufferNames, values)
        packRounds(f, shape, count, allFields, values, out, state)
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
        out.append(f.name, [items.length & 0xff, (items.length >> 8) & 0xff])
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
        out.append(f.name, [keys.length & 0xff, (keys.length >> 8) & 0xff])
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
