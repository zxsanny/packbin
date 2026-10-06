import { groupOn, present, scalarChildNames, type Value } from "./kinds.ts"

type EndianField = { littleEndian: boolean }

export type Acc<T = unknown, V = unknown> = (row: T) => V

export type Field =
  | ({ kind: "int"; id: number; name: string; size: 1 | 2 | 4 | 8; signed: boolean } & EndianField)
  | ({ kind: "float"; id: number; name: string; size: 4 | 8 } & EndianField)
  | { kind: "bytes"; id: number; name: string; size: number }
  | { kind: "bool"; id: number; name: string }
  | { kind: "flags"; anchor: number; fields: Field[] }
  | { kind: "flagByte"; name: string; id: symbol }
  | { kind: "flagBit"; flagId: symbol; bit: number; field: Field }
  | { kind: "when"; anchor: number; fieldId: number; value: unknown; fields: Field[] }
  | { kind: "repeat"; anchor: number; fields: Field[] }
  | { kind: "group"; name: string; fields: Field[]; anchor?: number }
  | { kind: "sized"; id: number; name: string; countId: number }
  | { kind: "u2"; slots: { id: number; name: string }[] }
  | { kind: "bits"; id: number; name: string; countId: number }
  | { kind: "packed"; id: number; name: string; width: 1 | 2; countId: number; bias: 0 | -1 }
  | { kind: "times"; anchor: number; countId: number; fields: Field[] }
  | { kind: "utf8"; id: number; name: string }
  | { kind: "list"; name: string; element: Field }
  | { kind: "dict"; name: string; element: Field }

type FlagByteHandle = Field & {
  kind: "flagByte"
  bit(field: Field): Field
}

export function memberName(acc: (...args: never[]) => unknown): string {
  const compact = acc
    .toString()
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "")
    .replace(/\s+/g, "")
  if (/^(?:\(?([A-Za-z_$][\w$]*)\)?)=>\1$/.test(compact)) return "$"
  const m =
    compact.match(/=>[A-Za-z_$][\w$]*\.([A-Za-z_$][\w$]*)$/) ||
    compact.match(/\.([A-Za-z_$][\w$]*);?\}$/) ||
    compact.match(/\[(?:\"([^\"]+)\"|'([^']+)')\]/)
  if (m) return (m[1] ?? m[2])!
  throw new RangeError("accessor must be a member access")
}

function intField(
  id: number,
  name: string,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
): Field {
  return { kind: "int", id, name, size, signed, littleEndian: true }
}

export function u8<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 1, false)
}
export function u16<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 2, false)
}
export function u32<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 4, false)
}
export function u64<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 8, false)
}
export function i8<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 1, true)
}
export function i16<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 2, true)
}
export function i32<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 4, true)
}
export function i64<T>(id: number, acc: Acc<T>): Field {
  return intField(id, memberName(acc), 8, true)
}
export function f32<T>(id: number, acc: Acc<T>): Field {
  return { kind: "float", id, name: memberName(acc), size: 4, littleEndian: true }
}
export function f64<T>(id: number, acc: Acc<T>): Field {
  return { kind: "float", id, name: memberName(acc), size: 8, littleEndian: true }
}
export function bytes<T>(id: number, acc: Acc<T>, size: number): Field {
  return { kind: "bytes", id, name: memberName(acc), size }
}
export function bool<T>(id: number, acc: Acc<T>): Field {
  return { kind: "bool", id, name: memberName(acc) }
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

export function flatten(fields: Field[]): Field[] {
  const out: Field[] = []
  for (const f of fields) {
    if (f.kind === "flags") {
      const fb = flagByte("")
      out.push(fb)
      // A member that holds flags of its own is flattened too, or its bits would get a new flag
      // byte on every walk and pack could not find them.
      for (const child of f.fields) {
        out.push(fb.bit(child.kind === "flags" ? child : flatten([child])[0]!))
      }
    } else if (
      f.kind === "when" ||
      f.kind === "repeat" ||
      f.kind === "times" ||
      f.kind === "group"
    ) {
      out.push({ ...f, fields: flatten(f.fields) })
    } else if (f.kind === "list" || f.kind === "dict") {
      const flat = flatten([f.element])
      out.push({ ...f, element: flat[0]! })
    } else out.push(f)
  }
  return out
}

// One flag byte holds 8 bits.
const FLAG_BITS = 8

export function flags(anchor: number, fields: Field[]): Field {
  if (fields.length > FLAG_BITS) {
    throw new RangeError(
      `flags: ninth bit (${fieldName(fields[FLAG_BITS]!)}); a flag byte holds ${FLAG_BITS} bits`,
    )
  }
  return { kind: "flags", anchor, fields }
}

export function flagByte(name: string): FlagByteHandle {
  const id = Symbol(name)
  let next = 0
  const handle = {
    kind: "flagByte" as const,
    name,
    id,
    bit(field: Field): Field {
      if (next === FLAG_BITS) {
        throw new RangeError(
          `flag byte "${name}": ninth bit (${fieldName(field)}); a flag byte holds ${FLAG_BITS} bits`,
        )
      }
      const bit = next++
      return { kind: "flagBit", flagId: id, bit, field }
    },
  }
  return handle
}

export function eq(fieldId: number, value: unknown): { fieldId: number; value: unknown } {
  return { fieldId, value }
}

export function when(
  anchor: number,
  cond: { fieldId: number; value: unknown },
  fields: Field[],
): Field {
  return {
    kind: "when",
    anchor,
    fieldId: cond.fieldId,
    value: cond.value,
    fields,
  }
}

export function repeat(anchor: number, fields: Field[]): Field {
  return { kind: "repeat", anchor, fields }
}

export function group<T>(acc: Acc<T>, fields?: Field[]): Field
export function group<T>(anchor: number, acc: Acc<T>, fields?: Field[]): Field
export function group<T>(
  anchorOrAcc: number | Acc<T>,
  accOrFields?: Acc<T> | Field[],
  maybeFields: Field[] = [],
): Field {
  if (typeof anchorOrAcc === "number") {
    const acc = accOrFields as Acc<T>
    return {
      kind: "group",
      anchor: anchorOrAcc,
      name: memberName(acc),
      fields: maybeFields,
    }
  }
  return {
    kind: "group",
    name: memberName(anchorOrAcc),
    fields: Array.isArray(accOrFields) ? accOrFields : [],
  }
}

export function sized<T>(id: number, acc: Acc<T>, countId: number): Field {
  return { kind: "sized", id, name: memberName(acc), countId }
}

export function u2(...args: unknown[]): Field {
  if (args.length === 0 || args.length % 2 !== 0) {
    throw new RangeError("u2 needs id/accessor pairs")
  }
  const slots: { id: number; name: string }[] = []
  for (let i = 0; i < args.length; i += 2) {
    const id = args[i]
    const acc = args[i + 1]
    if (typeof id !== "number" || typeof acc !== "function") {
      throw new RangeError("u2 needs id/accessor pairs")
    }
    slots.push({ id, name: memberName(acc as Acc) })
  }
  return { kind: "u2", slots }
}

export function bits<T>(id: number, acc: Acc<T>, countId: number): Field {
  return { kind: "bits", id, name: memberName(acc), countId }
}

export function packed<T>(
  width: number,
  id: number,
  acc: Acc<T>,
  countId: number,
  bias = 0,
): Field {
  if (width !== 1 && width !== 2) {
    throw new RangeError("packed width must be 1 or 2")
  }
  if (bias !== 0 && bias !== -1) {
    throw new RangeError("packed bias must be 0 or -1")
  }
  return {
    kind: "packed",
    id,
    name: memberName(acc),
    width,
    countId,
    bias,
  }
}

export function times(anchor: number, countId: number, fields: Field[]): Field {
  return { kind: "times", anchor, countId, fields }
}

export function utf8<T>(id: number, acc: Acc<T>): Field {
  return { kind: "utf8", id, name: memberName(acc) }
}

// A flags element is a flag byte and its bits, not one field, so it is held as an unanchored group of
// its own: like a group element it packs from and unpacks to one object per item.
function elementOf(element: Field): Field {
  if (element.kind === "flags") return { kind: "group", name: "", fields: [element] }
  return flatten([element])[0]!
}

// The group that holds the members of each item, for a group or flags element; any other element
// is one value per item.
export function itemGroup(element: Field): Extract<Field, { kind: "group" }> | null {
  return element.kind === "group" && element.anchor === undefined ? element : null
}

export function list<T>(acc: Acc<T>, element: Field): Field {
  const one = elementOf(element)
  if (one.kind === "repeat") {
    throw new RangeError("list element must be one field")
  }
  return { kind: "list", name: memberName(acc), element: one }
}

export function dict<T>(acc: Acc<T>, element: Field): Field {
  const one = elementOf(element)
  if (one.kind === "repeat") {
    throw new RangeError("repeat is not a dictionary element")
  }
  return { kind: "dict", name: memberName(acc), element: one }
}

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

// A bool or an empty group is a mark with no bytes of its own: only `true` sets its bit.
export function bitOn(field: Field, values: Value): boolean {
  if (field.kind === "bool") return values[field.name] === true
  if (field.kind === "group") {
    if (field.fields.length === 0) return values[field.name] === true
    return groupOn(values, field.name, scalarChildNames(field.fields))
  }
  return present(values[fieldName(field)])
}

export function flagValueFor(fields: Field[], id: symbol, values: Value): number {
  let flags = 0
  for (const { bit, field } of collectFlagBits(fields, id)) {
    if (bitOn(field, values)) flags |= 1 << bit
  }
  return flags
}

export function fieldName(field: Field): string {
  if (
    field.kind === "int" ||
    field.kind === "float" ||
    field.kind === "bytes" ||
    field.kind === "bool" ||
    field.kind === "flagByte" ||
    field.kind === "group" ||
    field.kind === "sized" ||
    field.kind === "bits" ||
    field.kind === "packed" ||
    field.kind === "utf8" ||
    field.kind === "list" ||
    field.kind === "dict"
  ) {
    return field.name
  }
  if (field.kind === "flagBit") return fieldName(field.field)
  if (field.kind === "u2") return field.slots[0]?.name ?? ""
  return ""
}

export function validateFieldIds(fields: Field[], next = 0): number {
  for (const f of fields) {
    switch (f.kind) {
      case "int":
      case "float":
      case "bytes":
      case "bool":
      case "sized":
      case "bits":
      case "packed":
      case "utf8":
        if (f.id !== next) {
          throw new RangeError(`field id: expected ${next}, got ${f.id}`)
        }
        next++
        break
      case "u2":
        for (const slot of f.slots) {
          if (slot.id !== next) {
            throw new RangeError(`field id: expected ${next}, got ${slot.id}`)
          }
          next++
        }
        break
      case "flagBit":
        next = validateFieldIds([f.field], next)
        break
      case "when":
      case "repeat":
      case "times":
      case "flags":
        if (f.anchor !== next) {
          throw new RangeError(`field id: expected ${next}, got ${f.anchor}`)
        }
        next = validateFieldIds(f.fields, next)
        break
      case "group":
        if (f.anchor !== undefined) {
          if (f.anchor !== next) {
            throw new RangeError(`field id: expected ${next}, got ${f.anchor}`)
          }
          next = validateFieldIds(f.fields, next)
        } else {
          validateFieldIds(f.fields, 0)
        }
        break
      case "list":
      case "dict":
        validateFieldIds([f.element], 0)
        break
      case "flagByte":
        break
    }
  }
  return next
}

export function isPlainObject(raw: unknown): raw is object {
  return typeof raw === "object" && raw !== null && !Array.isArray(raw) && !ArrayBuffer.isView(raw)
}

export function flattenValues(values: object): Value {
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
