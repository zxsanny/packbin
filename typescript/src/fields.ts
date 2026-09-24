import { groupOn, present, scalarChildNames, type Value } from "./kinds.ts"

type EndianField = { littleEndian: boolean }

export type Field =
  | ({ kind: "int"; name: string; size: 1 | 2 | 4 | 8; signed: boolean } & EndianField)
  | ({ kind: "float"; name: string; size: 4 | 8 } & EndianField)
  | { kind: "bytes"; name: string; size: number }
  | { kind: "flags"; name: string; fields: Field[] }
  | { kind: "flagByte"; name: string; id: symbol }
  | { kind: "flagBit"; flagId: symbol; bit: number; field: Field }
  | { kind: "when"; field: string; value: unknown; fields: Field[] }
  | { kind: "repeat"; fields: Field[] }
  | { kind: "group"; name: string; fields: Field[] }
  | { kind: "sized"; name: string; count: string }
  | { kind: "u2"; names: string[] }
  | { kind: "bits"; name: string; count: string }
  | { kind: "utf8"; name: string }
  | { kind: "list"; name: string; element: Field }
  | { kind: "dict"; name: string; element: Field }

type FlagByteHandle = Field & {
  kind: "flagByte"
  bit(field: Field): Field
}

function intField(
  name: string,
  size: 1 | 2 | 4 | 8,
  signed: boolean,
): Field {
  return { kind: "int", name, size, signed, littleEndian: true }
}

export function u8(name: string): Field {
  return intField(name, 1, false)
}
export function u16(name: string): Field {
  return intField(name, 2, false)
}
export function u32(name: string): Field {
  return intField(name, 4, false)
}
export function u64(name: string): Field {
  return intField(name, 8, false)
}
export function i8(name: string): Field {
  return intField(name, 1, true)
}
export function i16(name: string): Field {
  return intField(name, 2, true)
}
export function i32(name: string): Field {
  return intField(name, 4, true)
}
export function i64(name: string): Field {
  return intField(name, 8, true)
}
export function f32(name: string): Field {
  return { kind: "float", name, size: 4, littleEndian: true }
}
export function f64(name: string): Field {
  return { kind: "float", name, size: 8, littleEndian: true }
}
export function bytes(name: string, size: number): Field {
  return { kind: "bytes", name, size }
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
      const fb = flagByte(f.name)
      out.push(fb)
      for (const child of f.fields) out.push(fb.bit(child))
    } else out.push(f)
  }
  return out
}

export function flags(name: string, fields: Field[]): Field {
  return { kind: "flags", name, fields }
}

export function flagByte(name: string): FlagByteHandle {
  const id = Symbol(name)
  let next = 0
  const handle = {
    kind: "flagByte" as const,
    name,
    id,
    bit(field: Field): Field {
      const bit = next++
      return { kind: "flagBit", flagId: id, bit, field }
    },
  }
  return handle
}

export function eq(field: string, value: unknown): { field: string; value: unknown } {
  return { field, value }
}

export function when(
  cond: { field: string; value: unknown },
  fields: Field[],
): Field {
  return { kind: "when", field: cond.field, value: cond.value, fields: flatten(fields) }
}

export function repeat(fields: Field[]): Field {
  return { kind: "repeat", fields: flatten(fields) }
}

export function group(name: string, fields: Field[]): Field {
  return { kind: "group", name, fields }
}

export function sized(name: string, countField: string): Field {
  return { kind: "sized", name, count: countField }
}

export function u2(...names: string[]): Field {
  if (names.length === 0) throw new RangeError("u2 needs at least one name")
  return { kind: "u2", names }
}

export function bits(name: string, countField: string): Field {
  return { kind: "bits", name, count: countField }
}

export function utf8(name: string): Field {
  return { kind: "utf8", name }
}

export function list(name: string, element: Field): Field {
  const flat = flatten([element])
  if (flat.length !== 1 || flat[0]!.kind === "repeat") {
    throw new RangeError("list element must be one field")
  }
  return { kind: "list", name, element: flat[0]! }
}

export function dict(name: string, element: Field): Field {
  const flat = flatten([element])
  if (flat.length !== 1) {
    throw new RangeError("dictionary element must be one field")
  }
  if (flat[0]!.kind === "repeat") {
    throw new RangeError("repeat is not a dictionary element")
  }
  return { kind: "dict", name, element: flat[0]! }
}

export function collectFlagBits(
  fields: Field[],
  id: symbol,
): { bit: number; field: Field }[] {
  const bits: { bit: number; field: Field }[] = []
  for (const f of fields) {
    if (f.kind === "flagBit" && f.flagId === id) bits.push({ bit: f.bit, field: f.field })
    if (f.kind === "when") bits.push(...collectFlagBits(f.fields, id))
    if (f.kind === "repeat") bits.push(...collectFlagBits(f.fields, id))
  }
  return bits
}

export function bitOn(field: Field, values: Value): boolean {
  if (field.kind === "group") {
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
    field.kind === "flags" ||
    field.kind === "flagByte" ||
    field.kind === "group" ||
    field.kind === "sized" ||
    field.kind === "bits" ||
    field.kind === "utf8" ||
    field.kind === "list" ||
    field.kind === "dict"
  ) {
    return field.name
  }
  if (field.kind === "flagBit") return fieldName(field.field)
  if (field.kind === "u2") return field.names[0] ?? ""
  return ""
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
