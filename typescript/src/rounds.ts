import { isObjectLike, type Field } from "./fields.ts"
import { present, type Value } from "./kinds.ts"

// A repeat or times round is addressed by index. Pack reads each value list at the round's index;
// unpack gives every name a round can hold one entry per round, `undefined` where the round
// skipped it, so a repack gives the same bytes.

// A round packs item i of each value list, so a repeat or times inside it would read every inner
// round from the same item. Refused wherever it sits in the round (directly, or under when, flags,
// flag bits and groups). A list or dict element is a row of its own and starts outside any round.
export function validateRoundNesting(fields: Field[], inRound = false): void {
  for (const f of fields) {
    switch (f.kind) {
      case "repeat":
      case "times":
        if (inRound) {
          throw new RangeError(
            `${f.kind} ${f.anchor} is inside a repeat or times round; a round cannot hold another repeat or times`,
          )
        }
        validateRoundNesting(f.fields, true)
        break
      case "when":
      case "flags":
      case "group":
        validateRoundNesting(f.fields, inRound)
        break
      case "flagBit":
        validateRoundNesting([f.field], inRound)
        break
      case "list":
      case "dict":
        validateRoundNesting([f.element])
        break
    }
  }
}

// A round of a body with no member charges no slot and writes no byte, so a count of 65 535 would loop
// 65 535 times for no output and neither `maxSlots` nor `maxBytes` could stop it. Refused when the scheme
// is built, wherever the repeat or times stands. A member is any field but a container (`when`, group)
// that holds none, so a body of only empty containers is empty too. A zero-width `bytes`, a flag byte or a
// `flags` without members is a member: it names a slot or writes a byte, so the budgets still bound it.
export function validateRoundBodies(fields: Field[]): void {
  for (const f of fields) {
    switch (f.kind) {
      case "repeat":
      case "times":
        if (!holdsMember(f.fields)) {
          throw new RangeError(
            `${f.kind} ${f.anchor}: the body holds no member; a round of it would charge no slot and write nothing`,
          )
        }
        validateRoundBodies(f.fields)
        break
      case "when":
      case "flags":
      case "group":
        validateRoundBodies(f.fields)
        break
      case "flagBit":
        validateRoundBodies([f.field])
        break
      case "list":
      case "dict":
        validateRoundBodies([f.element])
        break
    }
  }
}

function holdsMember(fields: Field[]): boolean {
  return fields.some((f) => {
    switch (f.kind) {
      case "when":
      case "group":
      case "repeat":
      case "times":
        return holdsMember(f.fields)
      case "flagBit":
        return holdsMember([f.field])
      default:
        return true
    }
  })
}

// The names a round can hold: its own fields and the ones under when, flags, flag bits and groups.
// A list or dict element keeps values of its own, so it is not looked into. `packing`: a group's
// own member is read on pack (it can turn the group's flag bit on); unpack stores it only for an
// empty group.
export function roundNames(fields: Field[], packing: boolean): Set<string> {
  const names = new Set<string>()
  for (const f of fields) addNames(f, packing, names)
  return names
}

// What a repeat or times asks of its values on every pack, worked out once when the scheme binds it.
// `width` is the slots a round charges against `maxSlots`: the names unpack gives an entry per round.
// `optionalNames` are the names a flag bit can leave absent in a round (under `flags` or a flag bit).
export type RoundShape = {
  names: Set<string>
  dictNames: string[]
  bufferNames: string[]
  optionalNames: string[]
  width: number
}

export function makeRoundShape(fields: Field[]): RoundShape {
  const dictNames: string[] = []
  const bufferNames: string[] = []
  collectCollectionNames(fields, dictNames, bufferNames)
  const optionalNames = [...collectOptionalNames(fields, false, new Set())]
  return {
    names: roundNames(fields, true),
    dictNames,
    bufferNames,
    optionalNames,
    width: roundNames(fields, false).size,
  }
}

// The shape `bindReferences` filled in; a repeat or times no Scheme bound has none.
export function roundShape(f: Extract<Field, { kind: "repeat" | "times" }>): RoundShape {
  const { shape } = f as typeof f & { shape?: RoundShape }
  if (shape === undefined) throw new RangeError(`${f.kind}: round shape is not bound`)
  return shape
}

// The names reached through `flags` or a flag bit, also through a `when` or group below them: a flag
// bit can leave them absent in a round.
function collectOptionalNames(fields: Field[], underFlag: boolean, names: Set<string>): Set<string> {
  for (const f of fields) {
    switch (f.kind) {
      case "flagBit":
        collectOptionalNames([f.field], true, names)
        break
      case "flags":
        collectOptionalNames(f.fields, true, names)
        break
      case "when":
        collectOptionalNames(f.fields, underFlag, names)
        break
      case "group":
        if (underFlag && f.fields.length === 0) names.add(f.name)
        collectOptionalNames(f.fields, underFlag, names)
        break
      case "u2":
        if (underFlag) for (const slot of f.slots) names.add(slot.name)
        break
      case "repeat":
      case "times":
      case "flagByte":
        break
      default:
        if (underFlag) names.add(f.name)
    }
  }
  return names
}

// The dict names and the byte-buffer names (`bytes`, `sized`) a round holds one of per round.
function collectCollectionNames(fields: Field[], dicts: string[], buffers: string[]): void {
  for (const f of fields) {
    switch (f.kind) {
      case "dict":
        dicts.push(f.name)
        break
      case "bytes":
      case "sized":
        buffers.push(f.name)
        break
      case "when":
      case "flags":
      case "group":
        collectCollectionNames(f.fields, dicts, buffers)
        break
      case "flagBit":
        collectCollectionNames([f.field], dicts, buffers)
        break
    }
  }
}

// One dictionary given for a dict name of a round would reach every round, so it is refused: a
// dictionary per round goes in a list. Any object counts, a Map included: it would be broadcast too.
export function refuseLoneDicts(dictNames: string[], values: Value): void {
  for (const name of dictNames) {
    if (isObjectLike(values[name])) {
      throw new RangeError(
        `${name}: a dictionary in a repeat or times round needs a list with one dictionary per round`,
      )
    }
  }
}

// One byte buffer given for a bytes or sized name of a round would reach every round, so it is refused:
// a buffer per round goes in a list, as for a dictionary.
export function refuseLoneBuffers(bufferNames: string[], values: Value): void {
  for (const name of bufferNames) {
    const v = values[name]
    if (v instanceof Uint8Array || v instanceof ArrayBuffer) {
      throw new RangeError(
        `${name}: a byte buffer in a repeat or times round needs a list with one buffer per round`,
      )
    }
  }
}

// The member a refused times count or round slot charge is named by: the first name its round holds.
export function roundMember(f: Extract<Field, { kind: "repeat" | "times" }>, names: Set<string>): string {
  const first = names.values().next()
  return first.done ? `${f.kind} ${f.anchor}` : first.value
}

// Unpack refuses a round past the scheme's `maxRounds`, so pack refuses a times count past it before
// it writes any round: a lone scalar goes to every round, and a huge count would loop that many times.
export function refuseRoundsOverLimit(
  f: Extract<Field, { kind: "times" }>,
  names: Set<string>,
  count: number,
  limit: number,
): void {
  if (count <= limit) return
  throw new RangeError(
    `${roundMember(f, names)}: the times count is ${count}, above the limit of ${limit} rounds`,
  )
}

// A repeat writes a round per entry of its longest list, so pack refuses, before any round, the first
// list among the round's names with more entries than `maxRounds`, named by its own member.
export function refuseRepeatOverLimit(names: Set<string>, values: Value, limit: number): void {
  for (const name of names) {
    const v = values[name]
    if (Array.isArray(v) && v.length > limit) {
      throw new RangeError(`${name}: the repeat count is ${v.length}, above the limit of ${limit} rounds`)
    }
  }
}

// A repeat writes a round per entry of its longest list, and a flag bit leaves a member absent in a round
// only by an `undefined` entry. A non-empty list shorter than the rounds under a member a flag bit can leave
// absent does not say which rounds it belongs to, so pack refuses it, named by the member. An empty list
// leaves the member absent in every round.
export function refuseShortOptional(optionalNames: string[], values: Value, count: number): void {
  for (const name of optionalNames) {
    const v = values[name]
    if (Array.isArray(v) && v.length > 0 && v.length < count) {
      throw new RangeError(
        `${name}: ${v.length} items, repeat count ${count}; give one entry per round, undefined where the member is absent`,
      )
    }
  }
}

function addNames(f: Field, packing: boolean, names: Set<string>): void {
  switch (f.kind) {
    // A repeat or times never sits in a round (refused at construction); the case only narrows the union.
    case "repeat":
    case "times":
    case "flagByte":
      break
    case "when":
    case "flags":
      for (const child of f.fields) addNames(child, packing, names)
      break
    case "flagBit":
      addNames(f.field, packing, names)
      break
    case "group":
      if (packing || f.fields.length === 0) names.add(f.name)
      for (const child of f.fields) addNames(child, packing, names)
      break
    case "u2":
      for (const slot of f.slots) names.add(slot.name)
      break
    default:
      names.add(f.name)
  }
}

// The longest list among the round's values; a value that is not a list is one round.
export function roundCount(names: Set<string>, values: Value): number {
  let count = 0
  for (const name of names) {
    const v = values[name]
    if (Array.isArray(v)) count = Math.max(count, v.length)
    else if (present(v)) count = Math.max(count, 1)
  }
  return count
}

// A times writes exactly `count` rounds, so a list that holds more entries would lose its tail.
export function refuseLongLists(names: Set<string>, count: number, values: Value): void {
  for (const name of names) {
    const v = values[name]
    if (Array.isArray(v) && v.length > count) {
      throw new RangeError(`${name}: ${v.length} items, times count ${count}`)
    }
  }
}

// A view of `values` for round `index`: each list among the round's names read at that index, a value
// that is not a list as it is. The view reads through to `values`, so a round costs the names it holds
// and not every field of the enclosing scope.
export function sliceRound(values: Value, names: Set<string>, index: number): Value {
  const slice: Value = Object.create(values) as Value
  for (const name of names) {
    const v = values[name]
    if (Array.isArray(v)) defineOwn(slice, name, v[index])
  }
  return slice
}

// A view of `values` that reads `name` as `value`, as for one list or dict item.
export function overlay(values: Value, name: string, value: unknown): Value {
  const view: Value = Object.create(values) as Value
  defineOwn(view, name, value)
  return view
}

// Defined, not assigned, so a member named "__proto__" is an entry and not the view's prototype.
function defineOwn(view: Value, name: string, value: unknown): void {
  Object.defineProperty(view, name, { value, enumerable: true, writable: true, configurable: true })
}

function padTo(list: unknown[], length: number): void {
  const from = list.length
  if (from >= length) return
  list.length = length
  list.fill(undefined, from)
}

// The lists a repeat or times builds from its rounds. A name the round can hold is padded with
// `undefined` when a round sets it after skipping others, and once more when the rounds end, so the
// cost follows the values a round sets and not every name it could hold.
export class RoundLists {
  readonly #lists = new Map<string, unknown[]>()
  readonly #names: Set<string>
  #rounds = 0

  constructor(names: Set<string>) {
    this.#names = names
  }

  add(round: Value): void {
    for (const key in round) {
      let list = this.#lists.get(key)
      if (list === undefined) {
        list = []
        this.#lists.set(key, list)
      }
      if (this.#names.has(key)) padTo(list, this.#rounds)
      list.push(round[key])
    }
    this.#rounds++
  }

  // A list for every name the round can hold when there was a round, each with one entry per round.
  finish(): Map<string, unknown[]> {
    if (this.#rounds === 0) return this.#lists
    for (const name of this.#names) {
      let list = this.#lists.get(name)
      if (list === undefined) {
        list = []
        this.#lists.set(name, list)
      }
      padTo(list, this.#rounds)
    }
    return this.#lists
  }
}

// The list a repeat built joins what the scope already holds under that name.
export function appendList(into: Value, name: string, list: unknown[]): void {
  const prev = into[name]
  if (Array.isArray(prev)) for (const v of list) prev.push(v)
  else if (present(prev)) into[name] = [prev, ...list]
  else into[name] = list
}
