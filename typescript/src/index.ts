import {
  flatten,
  flattenValues,
  validateFieldIds,
  type Field,
} from "./fields.ts"
import { unpackBody, type UnpackErr } from "./walker.ts"
import type { PackedFlagByte } from "./flag-bits.ts"
import { newScope, packFields, type PackState } from "./pack-fields.ts"
import { PackOut } from "./pack-out.ts"
import { bindFlagBits, validatePresenceMarks } from "./flag-scope.ts"
import { validateMemberNames } from "./member-names.ts"
import { validateRepeatLast, validateRoundBodies, validateRoundNesting } from "./rounds.ts"
import { bindReferences } from "./ref-scope.ts"
import { validateElementKinds } from "./element-kinds.ts"
import type { Value } from "./kinds.ts"
import {
  checkLimit,
  checkParity,
  checkPercent,
  checkPercentLimit,
  protect,
  protectPercent,
  repair,
  repairPercent,
  type EccErr,
} from "./ecc.ts"

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
  packed,
  times,
  utf8,
  list,
  dict,
} from "./fields.ts"
export type { Value, ShortErr, TypeMismatchErr } from "./kinds.ts"
export type { UnpackErr } from "./walker.ts"
export type { EccErr, TooLongErr, UncorrectableErr } from "./ecc.ts"

// Frame mode (contract pack-session 3.0.0): sealed, authenticated frames, a replay window the caller owns, the MAC-only call.
export { FrameSession } from "./frame-session.ts"
export { MacKey, type MacTag } from "./mac-key.ts"
export { ReplayWindow } from "./replay-window.ts"
export {
  FrameConfig,
  FrameDirection,
  FrameDirections,
  FrameOpened,
  FrameSlot,
  Freshness,
  MsgContext,
  type FrameSealed,
} from "./frame-types.ts"
export type {
  BadValueErr,
  BufferFullErr,
  DuplicateErr,
  FrameErr,
  TagMismatchErr,
  TooOldErr,
} from "./frame-errors.ts"

// `repaired` is the count of bytes repaired, set when the schemes declare parity bytes (0 when intact);
// a scheme without them returns `{ ok: true }` as before. A protected unpack can also be refused as
// `uncorrectable` (more wrong bytes than the limit allows) or `too_long` (above 254 bytes).
export type DispatchResult = { ok: true; repaired?: number } | UnpackErr | EccErr

export type SchemeHandler<T> = {
  typeNumber: number
  scheme: Scheme<T>
  handler: (row: T) => void
}

// `parity` is the number of parity bytes pack appends, 0 to 32 (default 0, nothing appended). `parityPercent`
// (0 to 100) derives the count from the message length instead; a count and a percentage together are refused.
export type SchemeLimits = { maxRounds?: number; maxSlots?: number; maxBytes?: number; parity?: number; parityPercent?: number }

function checkedLimit(name: string, value: number | undefined, fallback: number): number {
  if (value === undefined) return fallback
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new RangeError(`${name}: expected a positive integer up to ${Number.MAX_SAFE_INTEGER}`)
  }
  return value
}

export class Scheme<T> {
  static readonly DefaultMaxRounds = 65_535
  static readonly DefaultMaxSlots = 1_048_576
  static readonly DefaultMaxBytes = 16_777_216

  declare private readonly __row: T
  readonly typeNumber: number
  readonly fields: Field[]
  // An unpack refuses a repeat or times field past `maxRounds` rounds, and rounds that together
  // would hold more than `maxSlots` entries, so a packet's length does not set its memory cost.
  // Pack refuses the same rounds and slots, and a packet longer than `maxBytes` (type byte included),
  // so a row's counts do not set the cost of packing it either.
  readonly maxRounds: number
  readonly maxSlots: number
  readonly maxBytes: number
  // Parity bytes pack appends and unpack checks (message-ecc contract); both sides share the number.
  readonly parity: number
  readonly parityPercent: number

  // Every check runs here, so `new Scheme(...)` refuses what `scheme(...)` refuses.
  constructor(typeNumber: number, fields: Field[], limits: SchemeLimits = {}) {
    if (!Number.isInteger(typeNumber) || typeNumber < 0 || typeNumber > 255) {
      throw new RangeError("type number: expected 0..255")
    }
    validateFieldIds(fields)
    const flat = bindFlagBits(flatten(fields))
    validatePresenceMarks(flat)
    validateMemberNames(flat)
    validateRoundNesting(flat)
    validateRoundBodies(flat)
    validateRepeatLast(flat)
    this.maxRounds = checkedLimit("maxRounds", limits.maxRounds, Scheme.DefaultMaxRounds)
    this.maxSlots = checkedLimit("maxSlots", limits.maxSlots, Scheme.DefaultMaxSlots)
    this.maxBytes = checkedLimit("maxBytes", limits.maxBytes, Scheme.DefaultMaxBytes)
    this.parity = limits.parity ?? 0
    checkParity(this.parity)
    this.parityPercent = limits.parityPercent ?? 0
    checkPercent(this.parityPercent)
    if (this.parityPercent > 0 && this.parity > 0) {
      throw new RangeError(`parity: a percentage (${this.parityPercent}, 0..100) and ${this.parity} parity bytes cannot both be declared`)
    }
    this.typeNumber = typeNumber
    this.fields = bindReferences(flat)
    validateElementKinds(this.fields)
  }

  // A limit left out takes the default, not this scheme's value; the parity setting left out keeps this scheme's
  // count or percentage, so setting a limit never drops protection. Setting one of the two replaces the other
  // (the last setter wins). This scheme is unchanged.
  withLimits(limits: SchemeLimits = {}): Scheme<T> {
    const keep = limits.parity === undefined && limits.parityPercent === undefined
    return new Scheme<T>(this.typeNumber, this.fields, {
      ...limits,
      parity: limits.parity ?? (keep ? this.parity : 0),
      parityPercent: limits.parityPercent ?? (keep ? this.parityPercent : 0),
    })
  }

  on(handler: (row: T) => void): SchemeHandler<T> {
    return { typeNumber: this.typeNumber, scheme: this, handler }
  }
}

export function scheme<T>(typeNumber: number, ...fields: Field[]): Scheme<T> {
  return new Scheme(typeNumber, fields)
}

// The packed fields alone, parity not yet appended.
function packClear<T extends object>(s: Scheme<T>, row: T): Uint8Array {
  const out = new PackOut(s.maxBytes, s.typeNumber & 0xff)
  const state: PackState = {
    flagBytes: new Map<symbol, PackedFlagByte>(),
    maxRounds: s.maxRounds,
    maxSlots: s.maxSlots,
    slots: 0,
  }
  packFields(s.fields, s.fields, flattenValues(row, s.fields), out, state, newScope())
  return out.bytes()
}

export class BinaryPacker {
  static pack<T extends object>(s: Scheme<T>, row: T): Uint8Array {
    return s.parityPercent > 0 ? protectPercent(packClear(s, row), s.parityPercent) : protect(packClear(s, row), s.parity)
  }

  // Detect only: a protected message with any wrong byte is refused as `uncorrectable`.
  static unpack(
    bytes: Uint8Array | ArrayBuffer,
    first: SchemeHandler<object>,
    ...rest: SchemeHandler<object>[]
  ): DispatchResult {
    return BinaryPacker.unpackRepair(bytes, 0, first, ...rest)
  }

  // Repairs up to `limit` wrong bytes (0 to parity / 2) before the type byte picks the handler. All
  // handlers declare the same parity; a mix, or a limit out of range, throws before any byte is read.
  static unpackRepair(
    bytes: Uint8Array | ArrayBuffer,
    limit: number,
    first: SchemeHandler<object>,
    ...rest: SchemeHandler<object>[]
  ): DispatchResult {
    const handlers = [first, ...rest]
    requireDistinct(handlers)
    const { n, p } = sharedParity(handlers, limit)
    const fixed = p > 0 ? repairPercent(toBuf(bytes), p, limit) : repair(toBuf(bytes), n, limit)
    if (!fixed.ok) return fixed
    return unpackDispatch(fixed.clear, handlers, n > 0 || p > 0 ? fixed.repaired : undefined)
  }
}

// A payload of any other type is refused, never coerced: a string would become an empty buffer and a
// number a zero-filled one of that length.
function toBuf(bytes: Uint8Array | ArrayBuffer): Uint8Array {
  if (bytes instanceof Uint8Array) return bytes
  if (isUint8Array(bytes) || isArrayBuffer(bytes)) return new Uint8Array(bytes)
  throw new TypeError("payload must be a Uint8Array or an ArrayBuffer")
}

// The byteLength getter checks the internal brand, so an ArrayBuffer of another realm passes and an
// object that only claims the tag does not.
const bufferLength = Object.getOwnPropertyDescriptor(ArrayBuffer.prototype, "byteLength")!.get!
function isArrayBuffer(v: unknown): v is ArrayBuffer {
  try {
    bufferLength.call(v)
    return true
  } catch (e) {
    if (e instanceof TypeError) return false
    throw e
  }
}

// A duplicate type number is refused before any byte is read.
function requireDistinct(handlers: SchemeHandler<object>[]): void {
  const seen = new Set<number>()
  for (const h of handlers) {
    if (seen.has(h.typeNumber)) {
      throw new RangeError(`duplicate type number ${h.typeNumber}`)
    }
    seen.add(h.typeNumber)
  }
}

// The parity setting every handler declares. Handlers with different counts or percentages could not share one repair.
function sharedParity(handlers: SchemeHandler<object>[], limit: number): { n: number; p: number } {
  const n = handlers[0]!.scheme.parity
  const p = handlers[0]!.scheme.parityPercent
  for (const h of handlers) {
    if (h.scheme.parity !== n || h.scheme.parityPercent !== p) {
      throw new RangeError(
        `handlers declare ${n} parity bytes and ${p} percent, and ${h.scheme.parity} parity bytes and ${h.scheme.parityPercent} percent; they must declare the same count`,
      )
    }
  }
  if (p > 0) checkPercentLimit(limit)
  else checkLimit(limit, n)
  return { n, p }
}

function unpackDispatch(
  buf: Uint8Array,
  handlers: SchemeHandler<object>[],
  repaired: number | undefined,
): DispatchResult {
  if (buf.length < 1) return { ok: false, field: "", needed: 1, left: 0 }
  const actual = buf[0]!
  const match = handlers.find((h) => h.typeNumber === actual)
  if (!match) return { ok: false, actual }
  const body = unpackBody(match.scheme.fields, buf, 1, match.scheme.maxRounds, match.scheme.maxSlots)
  if (!body.ok) return body
  match.handler(body.values as object)
  return repaired === undefined ? { ok: true } : { ok: true, repaired }
}

export type UnpackOk = { ok: true } & Value
export type UnpackResult = UnpackOk | UnpackErr

// The brand, not instanceof: a Uint8Array made in another realm (a vm context, a Jest
// environment, an iframe) has another prototype. isView runs first so no caller code runs.
function isUint8Array(v: unknown): v is Uint8Array {
  return ArrayBuffer.isView(v) && Object.prototype.toString.call(v) === "[object Uint8Array]"
}
