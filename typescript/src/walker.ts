import { fieldName, flatten, type Field } from "./fields.ts"
import { refName } from "./ref-scope.ts"
import { RoundLists, appendList, roundNames } from "./rounds.ts"
import {
  readBits,
  readFloat,
  readInt,
  readPacked,
  readSized,
  readU2,
  readUtf8,
  sameValue,
  validCount,
  type ShortErr,
  type TypeMismatchErr,
  type Value,
  type ViewCursor,
} from "./kinds.ts"

export type UnpackErr = ShortErr | TypeMismatchErr

function short(field: string, needed: number, left: number): ShortErr {
  return { ok: false, field, needed, left }
}

// A negative or absent count is reported with the duplicate-key shape: the counted field,
// nothing more needed, the bytes left where it starts.
function unreadable(field: string, cur: ViewCursor): ShortErr {
  return short(field, 0, cur.buf.length - cur.offset)
}

function firstName(fields: Field[]): string {
  for (const f of fields) {
    const n = fieldName(f)
    if (n) return n
    if (f.kind === "when" || f.kind === "repeat" || f.kind === "times") {
      const inner = firstName(f.fields)
      if (inner) return inner
    }
  }
  return ""
}

// Inside a repeat round a value waits in `round` until the round ends, so a name written twice in
// one round still has one entry for it.
function store(values: Value, round: Value | null, name: string, value: unknown): void {
  if (round) round[name] = value
  else values[name] = value
}

// What a `when` or a count reads: the value of the round being read, or of the scope.
function seen(values: Value, round: Value | null, name: string): unknown {
  const scope = round ?? values
  return Object.hasOwn(scope, name) ? scope[name] : undefined
}

export function unpackFields(
  fields: Field[],
  cur: ViewCursor,
  values: Value,
  flagBytes: Map<symbol, number>,
  round: Value | null,
): UnpackErr | null {
  for (const f of fields) {
    switch (f.kind) {
      case "int": {
        const r = readInt(cur, f.name, f.size, f.signed, f.littleEndian)
        if (!r.ok) return r
        store(values, round, f.name, r.value)
        break
      }
      case "float": {
        const r = readFloat(cur, f.name, f.size, f.littleEndian)
        if (!r.ok) return r
        store(values, round, f.name, r.value)
        break
      }
      case "bytes": {
        const left = cur.buf.length - cur.offset
        if (left < f.size) return short(f.name, f.size, left)
        const slice = cur.buf.subarray(cur.offset, cur.offset + f.size)
        cur.offset += f.size
        const copy = new Uint8Array(slice)
        store(values, round, f.name, copy)
        break
      }
      case "bool":
        // Reached only through a set flag bit: a bool anywhere else is refused by scheme().
        store(values, round, f.name, true)
        break
      case "flagByte": {
        const r = readInt(cur, f.name, 1, false, true)
        if (!r.ok) return r
        const v = Number(r.value)
        flagBytes.set(f.id, v)
        break
      }
      case "flagBit": {
        const flags = flagBytes.get(f.flagId) ?? 0
        if ((flags & (1 << f.bit)) === 0) break
        if (f.field.kind === "group") {
          if (f.field.fields.length === 0) store(values, round, f.field.name, true)
          const err = unpackFields(f.field.fields, cur, values, flagBytes, round)
          if (err) return err
        } else {
          const err = unpackFields([f.field], cur, values, flagBytes, round)
          if (err) return err
        }
        break
      }
      case "when": {
        if (sameValue(seen(values, round, refName(f)), f.value)) {
          const err = unpackFields(f.fields, cur, values, flagBytes, round)
          if (err) return err
        }
        break
      }
      case "repeat": {
        const names = roundNames(f.fields, false)
        const rounds = new RoundLists(names)
        while (cur.offset < cur.buf.length) {
          const before = cur.offset
          const one: Value = {}
          const err = unpackFields(f.fields, cur, values, flagBytes, one)
          if (err) return err
          rounds.add(one)
          // A round that reads nothing would repeat forever; the unread bytes are trailing.
          if (cur.offset === before) break
        }
        for (const [name, list] of rounds.finish()) appendList(values, name, list)
        break
      }
      case "group": {
        const err = unpackFields(f.fields, cur, values, flagBytes, round)
        if (err) return err
        break
      }
      case "sized": {
        const count = validCount(seen(values, round, refName(f)))
        if (count === null) return unreadable(f.name, cur)
        const r = readSized(cur, f.name, count)
        if (!r.ok) return r
        store(values, round, f.name, r.value)
        break
      }
      case "u2": {
        const r = readU2(cur, f.slots)
        if (!r.ok) return r
        for (let i = 0; i < f.slots.length; i++) {
          const name = f.slots[i]!.name
          store(values, round, name, r.values[i])
        }
        break
      }
      case "bits": {
        // bits has always taken a bigint count (u64 source); past 2^53 it cannot be exact.
        const raw = seen(values, round, refName(f))
        const count = validCount(
          typeof raw === "bigint" && raw <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(raw) : raw,
        )
        if (count === null) return unreadable(f.name, cur)
        const r = readBits(cur, f.name, count)
        if (!r.ok) return r
        store(values, round, f.name, r.values)
        break
      }
      case "packed": {
        const count = validCount(seen(values, round, refName(f)), f.bias)
        if (count === null) return unreadable(f.name, cur)
        const r = readPacked(cur, f.name, f.width, count)
        if (!r.ok) return r
        store(values, round, f.name, r.values)
        break
      }
      case "times": {
        const count = validCount(values[refName(f)])
        if (count === null) return unreadable(firstName(f.fields), cur)
        const rounds = new RoundLists(roundNames(f.fields, false))
        for (let i = 0; i < count; i++) {
          const one: Value = {}
          const before = cur.offset
          const err = unpackFields(f.fields, cur, one, flagBytes, null)
          if (err) return err
          // A round that reads nothing would repeat up to `count` times for no input.
          if (cur.offset === before) return unreadable(firstName(f.fields), cur)
          rounds.add(one)
        }
        for (const [name, list] of rounds.finish()) values[name] = list
        break
      }
      case "utf8": {
        const r = readUtf8(cur, f.name)
        if (!r.ok) return r
        store(values, round, f.name, r.value)
        break
      }
      case "list": {
        if (cur.offset + 2 > cur.buf.length) {
          return short(f.name, 2, cur.buf.length - cur.offset)
        }
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: unknown[] = []
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const one: Value = {}
          const before = cur.offset
          const err = unpackFields([f.element], cur, one, flagBytes, null)
          if (err) return err
          // An element that reads nothing would be repeated up to 65535 times for no input.
          if (cur.offset === before) return unreadable(f.name, cur)
          items.push(one[child])
        }
        store(values, round, f.name, items)
        break
      }
      case "dict": {
        if (cur.offset + 2 > cur.buf.length) {
          return short(f.name, 2, cur.buf.length - cur.offset)
        }
        const count = cur.view.getUint16(cur.offset, true)
        cur.offset += 2
        const items: Value = {}
        const child = fieldName(f.element)
        for (let i = 0; i < count; i++) {
          const key = readUtf8(cur, f.name)
          if (!key.ok) return key
          const one: Value = {}
          const before = cur.offset
          const err = unpackFields([f.element], cur, one, flagBytes, null)
          if (err) return err
          if (cur.offset === before) return unreadable(f.name, cur)
          if (Object.hasOwn(items, key.value)) {
            return short(f.name, 0, 0)
          }
          // Keys come from the wire: define them, so "__proto__" is an entry, not a prototype.
          Object.defineProperty(items, key.value, {
            value: one[child],
            enumerable: true,
            writable: true,
            configurable: true,
          })
        }
        store(values, round, f.name, items)
        break
      }
      case "flags": {
        const err = unpackFields(flatten([f]), cur, values, flagBytes, round)
        if (err) return err
        break
      }
    }
  }
  return null
}

export function unpackBody(
  fields: Field[],
  buf: Uint8Array,
  offset: number,
): { ok: true; values: Value; offset: number } | UnpackErr {
  const cur: ViewCursor = {
    buf,
    view: new DataView(buf.buffer, buf.byteOffset, buf.byteLength),
    offset,
  }
  const values: Value = {}
  const flagBytes = new Map<symbol, number>()
  const err = unpackFields(fields, cur, values, flagBytes, null)
  if (err) return err
  if (cur.offset < buf.length) {
    return short("", 0, buf.length - cur.offset)
  }
  return { ok: true, values, offset: cur.offset }
}
