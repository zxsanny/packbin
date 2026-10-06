import {
  flatten,
  flattenValues,
  validateFieldIds,
  type Field,
} from "./fields.ts"
import { unpackBody, type UnpackErr } from "./walker.ts"
import { newScope, packFields } from "./pack-fields.ts"
import { bindFlagBits, validatePresenceMarks } from "./flag-scope.ts"
import { validateMemberNames } from "./member-names.ts"
import { validateRoundNesting } from "./rounds.ts"
import { bindReferences } from "./ref-scope.ts"
import { validateElementKinds } from "./element-kinds.ts"
import type { Value } from "./kinds.ts"
import { hkdf } from "@noble/hashes/hkdf.js"
import { sha256 } from "@noble/hashes/sha2.js"
import { xorPad } from "./session-pad.ts"

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

export type DispatchResult = { ok: true } | UnpackErr

export type SchemeHandler<T> = {
  typeNumber: number
  scheme: Scheme<T>
  handler: (row: T) => void
}

export type SchemeLimits = { maxRounds?: number; maxSlots?: number }

function checkedLimit(name: string, value: number | undefined, fallback: number): number {
  if (value === undefined) return fallback
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new RangeError(`${name}: expected a positive integer up to ${Number.MAX_SAFE_INTEGER}`)
  }
  return value
}

export class Scheme<T> {
  static readonly DefaultMaxRounds = 65_535
  static readonly DefaultMaxSlots = 4_194_304

  declare private readonly __row: T
  readonly typeNumber: number
  readonly fields: Field[]
  // An unpack refuses a repeat or times field past `maxRounds` rounds, and rounds that together
  // would hold more than `maxSlots` entries, so a packet's length does not set its memory cost.
  readonly maxRounds: number
  readonly maxSlots: number

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
    this.maxRounds = checkedLimit("maxRounds", limits.maxRounds, Scheme.DefaultMaxRounds)
    this.maxSlots = checkedLimit("maxSlots", limits.maxSlots, Scheme.DefaultMaxSlots)
    this.typeNumber = typeNumber
    this.fields = bindReferences(flat)
    validateElementKinds(this.fields)
  }

  // A member left out takes the default, not this scheme's value; this scheme is unchanged.
  withLimits(limits: SchemeLimits = {}): Scheme<T> {
    return new Scheme<T>(this.typeNumber, this.fields, limits)
  }

  on(handler: (row: T) => void): SchemeHandler<T> {
    return { typeNumber: this.typeNumber, scheme: this, handler }
  }
}

export function scheme<T>(typeNumber: number, ...fields: Field[]): Scheme<T> {
  return new Scheme(typeNumber, fields)
}

export class BinaryPacker {
  static pack<T extends object>(s: Scheme<T>, row: T): Uint8Array {
    const out: number[] = [s.typeNumber & 0xff]
    const flagBytes = new Map<symbol, number>()
    packFields(s.fields, s.fields, flattenValues(row, s.fields), out, flagBytes, newScope())
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
  const body = unpackBody(match.scheme.fields, buf, 1, match.scheme.maxRounds, match.scheme.maxSlots)
  if (!body.ok) return body
  match.handler(body.values as object)
  return { ok: true }
}

export type UnpackOk = { ok: true } & Value
export type UnpackResult = UnpackOk | UnpackErr

const SESSION_INFO = new TextEncoder().encode("packbin")

// The brand, not instanceof: a Uint8Array made in another realm (node:vm, a Jest
// environment, an iframe) has another prototype. isView runs first so no caller code runs.
function isUint8Array(v: unknown): v is Uint8Array {
  return ArrayBuffer.isView(v) && Object.prototype.toString.call(v) === "[object Uint8Array]"
}

export class PackSession {
  static readonly SeedSize = 32
  static readonly NonceSize = 16

  #seed: Uint8Array | null
  #send: Uint8Array | null = null
  #recv: Uint8Array | null = null
  #sendCount = 0n
  #recvCount = 0n

  private constructor(seed: Uint8Array) {
    this.#seed = seed
  }

  static load(seed: Uint8Array): PackSession | null {
    if (!isUint8Array(seed) || seed.length !== PackSession.SeedSize) return null
    return new PackSession(Uint8Array.from(seed))
  }

  start(nonce?: Uint8Array): Uint8Array | null {
    if (nonce === undefined) {
      if (this.#send !== null || this.#seed === null) return null
      const drawn = new Uint8Array(PackSession.NonceSize)
      globalThis.crypto.getRandomValues(drawn)
      if (!this.#open(drawn, true)) return null
      return drawn
    }
    if (!this.#open(nonce, true)) return null
    return Uint8Array.from(nonce)
  }

  join(nonce: Uint8Array): boolean {
    return this.#open(nonce, false)
  }

  pack<T extends object>(s: Scheme<T>, row: T): Uint8Array | null {
    if (this.#send === null) return null
    const clear = BinaryPacker.pack(s, row)
    xorPad(this.#send, this.#sendCount, clear)
    this.#sendCount++
    return clear
  }

  unpack(
    bytes: Uint8Array | ArrayBuffer,
    first: SchemeHandler<object>,
    ...rest: SchemeHandler<object>[]
  ): DispatchResult {
    if (this.#recv === null) return { ok: false, field: "", needed: 1, left: 0 }
    const src = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
    const clear = Uint8Array.from(src)
    xorPad(this.#recv, this.#recvCount, clear)
    this.#recvCount++
    return BinaryPacker.unpack(clear, first, ...rest)
  }

  #open(nonce: Uint8Array, initiator: boolean): boolean {
    if (
      this.#seed === null ||
      this.#send !== null ||
      nonce.length !== PackSession.NonceSize
    ) {
      return false
    }
    const both = hkdf(sha256, this.#seed, nonce, SESSION_INFO, PackSession.SeedSize * 2)
    const first = both.subarray(0, PackSession.SeedSize)
    const second = both.subarray(PackSession.SeedSize)
    this.#send = Uint8Array.from(initiator ? first : second)
    this.#recv = Uint8Array.from(initiator ? second : first)
    both.fill(0)
    this.#seed.fill(0)
    this.#seed = null
    return true
  }
}
