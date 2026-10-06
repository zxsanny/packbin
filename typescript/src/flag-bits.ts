import type { Field } from "./fields.ts"
import { present, type Value } from "./kinds.ts"

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
// an empty group is a mark with no bytes of its own, and only `true` sets its bit. A `when`, `repeat`
// or `times` is given no presence here: it never sets a bit.
export function bitOn(field: Field, values: Value): boolean {
  switch (field.kind) {
    case "bool":
      return values[field.name] === true
    case "u2":
      return field.slots.some((slot) => present(values[slot.name]))
    case "group":
      if (field.fields.length === 0) return values[field.name] === true
      return present(values[field.name]) || field.fields.some((child) => bitOn(child, values))
    case "flags":
      return field.fields.some((child) => bitOn(child, values))
    case "flagBit":
      return bitOn(field.field, values)
    case "when":
    case "repeat":
    case "times":
    case "flagByte":
      return false
    default:
      return present(values[field.name])
  }
}

export function flagValueFor(fields: Field[], id: symbol, values: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (bitOn(field, values)) flags |= 1 << bit
  }
  return flags
}
