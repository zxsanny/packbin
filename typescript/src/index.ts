import {
  flatten,
  flattenValues,
  validateFieldIds,
  type Field,
} from "./fields.ts"
import {
  packFields,
  unpackBody,
  type UnpackErr,
} from "./walker.ts"
import type { Value } from "./kinds.ts"

export type { Field, Acc } from "./fields.ts"
export {
  u8,
  u16,
  u32,
  u64,
  i8,
  i16,
  i32,
  i64,
  f32,
  f64,
  bytes,
  bool,
  be,
  flags,
  flagByte,
  eq,
  when,
  repeat,
  group,
  sized,
  u2,
  bits,
  utf8,
  list,
  dict,
} from "./fields.ts"
export type { Value, ShortErr, TypeMismatchErr } from "./kinds.ts"
export type { UnpackErr } from "./walker.ts"

export type DispatchResult = { ok: true } | UnpackErr

export type SchemeHandler<T> = {
  typeNumber: number
  scheme: Scheme<T>
  handler: (row: T) => void
}

export class Scheme<T> {
  declare private readonly __row: T
  readonly typeNumber: number
  readonly fields: Field[]

  constructor(typeNumber: number, fields: Field[]) {
    this.typeNumber = typeNumber
    this.fields = fields
  }

  on(handler: (row: T) => void): SchemeHandler<T> {
    return { typeNumber: this.typeNumber, scheme: this, handler }
  }
}

export function scheme<T>(typeNumber: number, ...fields: Field[]): Scheme<T> {
  if (!Number.isInteger(typeNumber) || typeNumber < 0 || typeNumber > 255) {
    throw new RangeError("type number: expected 0..255")
  }
  const flat = flatten(fields)
  validateFieldIds(flat)
  return new Scheme(typeNumber, flat)
}

export class BinaryPacker {
  static pack<T extends object>(s: Scheme<T>, row: T): Uint8Array {
    const out: number[] = [s.typeNumber & 0xff]
    const flagBytes = new Map<symbol, number>()
    packFields(s.fields, s.fields, flattenValues(row), out, flagBytes)
    return Uint8Array.from(out)
  }

  static unpack(
    bytes: Uint8Array | ArrayBuffer,
    first: SchemeHandler<object>,
    ...rest: SchemeHandler<object>[]
  ): DispatchResult {
    return unpackDispatch(toBuf(bytes), [first, ...rest])
  }
}

function toBuf(bytes: Uint8Array | ArrayBuffer): Uint8Array {
  return bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
}

function unpackDispatch(
  buf: Uint8Array,
  handlers: SchemeHandler<object>[],
): DispatchResult {
  const seen = new Set<number>()
  for (const h of handlers) {
    if (seen.has(h.typeNumber)) {
      throw new RangeError(`duplicate type number ${h.typeNumber}`)
    }
    seen.add(h.typeNumber)
  }
  if (buf.length < 1) return { ok: false, field: "", needed: 1, left: 0 }
  const actual = buf[0]!
  const match = handlers.find((h) => h.typeNumber === actual)
  if (!match) return { ok: false, actual }
  const body = unpackBody(match.scheme.fields, buf, 1)
  if (!body.ok) return body
  match.handler(body.values as object)
  return { ok: true }
}

export type UnpackOk = { ok: true } & Value
export type UnpackResult = UnpackOk | UnpackErr
