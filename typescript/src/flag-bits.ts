import type { Field } from "./fields.ts"
import { present, sameValue, type Value } from "./kinds.ts"
import { refName } from "./ref-scope.ts"
import { refuseLoneBuffers, refuseLoneDicts, refuseLongLists, roundCount, roundShape } from "./rounds.ts"
import { borrowedCount, seen } from "./written.ts"

// A flag byte pack has written: where it sits in the output, the bits set so far, and whether its
// bits are decided one by one as their members are reached (a combined `flags`).
export type PackedFlagByte = { at: number; flags: number; inOrder: boolean }

export function collectFlagBits(
  fields: Field[],
  id: symbol,
): { bit: number; field: Field }[] {
  const bits: { bit: number; field: Field }[] = []
  for (const f of fields) {
    if (f.kind === "flagBit") {
      if (f.flagId === id) bits.push({ bit: f.bit, field: f.field })
      bits.push(...collectFlagBits([f.field], id))
    } else if (
      f.kind === "when" ||
      f.kind === "repeat" ||
      f.kind === "times" ||
      f.kind === "group"
    ) {
      bits.push(...collectFlagBits(f.fields, id))
    }
  }
  return bits
}

// A flag bit is on when its field holds a value at any depth, whatever the kind of its members: a
// group is on for its own name or any member inside it, nested groups and flags included. A bool or
// an empty group is a mark with no bytes of its own, and only `true` sets its bit. A `when` is on when
// its condition holds on what pack has written so far (`wrote`) and its body holds a value; a `times`
// when its count is above 0 (a count that was skipped is no round); a `repeat` when a round holds a
// value. A member that is on and cannot be written in full fails when it is packed.
export function bitOn(field: Field, values: Value, wrote: Value): boolean {
  switch (field.kind) {
    case "bool":
      return values[field.name] === true
    case "u2":
      return field.slots.some((slot) => present(values[slot.name]))
    case "group":
      if (field.fields.length === 0) return values[field.name] === true
      return (
        present(values[field.name]) || field.fields.some((child) => bitOn(child, values, wrote))
      )
    case "flags":
      return field.fields.some((child) => bitOn(child, values, wrote))
    case "flagBit":
      return bitOn(field.field, values, wrote)
    case "when":
      return (
        sameValue(seen(wrote, refName(field)), field.value) &&
        field.fields.some((child) => bitOn(child, values, wrote))
      )
    case "times": {
      const ref = refName(field)
      if (!Object.hasOwn(wrote, ref)) return false
      const count = borrowedCount(ref, 0, "times", wrote)
      if (count === 0) {
        const { names, dictNames, bufferNames } = roundShape(field)
        refuseLongLists(names, 0, values)
        refuseLoneDicts(dictNames, values)
        refuseLoneBuffers(bufferNames, values)
      }
      return count > 0
    }
    case "repeat":
      return roundCount(roundShape(field).names, values) > 0
    case "flagByte":
      return false
    default:
      return present(values[field.name])
  }
}

// The name of the first value `field` holds, at any depth; null when it holds none.
function heldName(field: Field, values: Value): string | null {
  switch (field.kind) {
    case "bool":
      return values[field.name] === true ? field.name : null
    case "u2":
      return field.slots.find((slot) => present(values[slot.name]))?.name ?? null
    case "group":
      if (field.fields.length === 0) return values[field.name] === true ? field.name : null
      if (present(values[field.name])) return field.name
      return firstHeld(field.fields, values)
    case "flags":
    case "when":
    case "repeat":
    case "times":
      return firstHeld(field.fields, values)
    case "flagBit":
      return heldName(field.field, values)
    case "flagByte":
      return null
    default:
      return present(values[field.name]) ? field.name : null
  }
}

function firstHeld(fields: Field[], values: Value): string | null {
  for (const f of fields) {
    const name = heldName(f, values)
    if (name !== null) return name
  }
  return null
}

// Whether a times in the scope of `field` (itself, or under groups, flags and flag bits) holds a value
// although its count was never written.
function countNeverWritten(field: Field, values: Value, wrote: Value): boolean {
  switch (field.kind) {
    case "times":
      return !Object.hasOwn(wrote, refName(field)) && heldName(field, values) !== null
    case "group":
    case "flags":
      return field.fields.some((child) => countNeverWritten(child, values, wrote))
    case "flagBit":
      return countNeverWritten(field.field, values, wrote)
    default:
      return false
  }
}

// A split flag byte decides its bits where it is read. When the bit came out clear but the member holds a
// value that a later look at what was written would write (its `when` condition now holds, its `times`
// count is now known), or that waits for a count that no field ever wrote, the value would be dropped:
// returns the name of that value, else null. A `when` whose condition is false stays a silent skip.
export function droppedBody(field: Field, values: Value, wrote: Value): string | null {
  const held = heldName(field, values)
  if (held === null) return null
  return bitOn(field, values, wrote) || countNeverWritten(field, values, wrote) ? held : null
}

export function flagValueFor(fields: Field[], id: symbol, values: Value, wrote: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (bitOn(field, values, wrote)) flags |= 1 << bit
  }
  return flags
}
