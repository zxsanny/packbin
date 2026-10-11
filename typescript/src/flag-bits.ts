import type { Field } from "./fields.ts"
import { present, sameValue, type Value } from "./kinds.ts"
import { refName } from "./ref-scope.ts"
import { refuseLoneDicts, refuseLongLists, roundCount, roundShape } from "./rounds.ts"
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
        const { names, dictNames } = roundShape(field)
        refuseLongLists(names, 0, values)
        refuseLoneDicts(dictNames, values)
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

export function flagValueFor(fields: Field[], id: symbol, values: Value, wrote: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (bitOn(field, values, wrote)) flags |= 1 << bit
  }
  return flags
}
