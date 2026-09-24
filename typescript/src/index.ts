import { flatten, flattenValues, type Field } from "./fields.ts"
import {
  fillEntity,
  packFields,
  unpackBody,
  type UnpackErr,
} from "./walker.ts"
import type { Value } from "./kinds.ts"

export type { Field } from "./fields.ts"
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

export type EntityResult<T> = { ok: true; value: T } | UnpackErr
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
  return new Scheme(typeNumber, flatten(fields))
}

export function pack<T extends object>(s: Scheme<T>, row: T): Uint8Array {
  const out: number[] = [s.typeNumber & 0xff]
  const flagBytes = new Map<symbol, number>()
  packFields(s.fields, s.fields, flattenValues(row), out, flagBytes)
  return Uint8Array.from(out)
}

export function unpack<T extends object>(
  s: Scheme<T>,
  bytes: Uint8Array | ArrayBuffer,
): EntityResult<T>
export function unpack<T extends object>(
  s: Scheme<T>,
  bytes: Uint8Array | ArrayBuffer,
  ctor: new () => T,
): EntityResult<T>
export function unpack(
  bytes: Uint8Array | ArrayBuffer,
  first: SchemeHandler<object>,
  ...rest: SchemeHandler<object>[]
): DispatchResult
export function unpack(
  first: Scheme<object> | Uint8Array | ArrayBuffer,
  second?: Uint8Array | ArrayBuffer | SchemeHandler<object>,
  third?: (new () => object) | SchemeHandler<object>,
  ...rest: SchemeHandler<object>[]
): EntityResult<object> | DispatchResult {
  if (first instanceof Scheme) {
    const buf = toBuf(second as Uint8Array | ArrayBuffer)
    const ctor =
      typeof third === "function" ? (third as new () => object) : undefined
    return unpackKnown(first, buf, ctor)
  }
  const buf = toBuf(first)
  const handlers: SchemeHandler<object>[] = []
  if (isHandler(second)) handlers.push(second)
  if (isHandler(third)) handlers.push(third)
  handlers.push(...rest)
  return unpackDispatch(buf, handlers)
}

function isHandler(v: unknown): v is SchemeHandler<object> {
  return (
    typeof v === "object" &&
    v !== null &&
    "typeNumber" in v &&
    "scheme" in v &&
    "handler" in v
  )
}

function toBuf(bytes: Uint8Array | ArrayBuffer): Uint8Array {
  return bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
}

function unpackKnown<T extends object>(
  s: Scheme<T>,
  buf: Uint8Array,
  ctor?: new () => T,
): EntityResult<T> {
  if (buf.length < 1) return { ok: false, field: "", needed: 1, left: 0 }
  const actual = buf[0]!
  if (actual !== s.typeNumber) {
    return { ok: false, expected: s.typeNumber, actual }
  }
  const body = unpackBody(s.fields, buf, 1)
  if (!body.ok) return body
  if (ctor) return { ok: true, value: fillEntity(ctor, body.values) }
  return { ok: true, value: body.values as T }
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
export type UnpackResult<T = never> = [T] extends [never]
  ? UnpackOk | UnpackErr
  : EntityResult<T>
