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
export type RoundShape = { names: Set<string>; dictNames: string[]; bufferNames: string[]; width: number }

export function makeRoundShape(fields: Field[]): RoundShape {
  const dictNames: string[] = []
  const bufferNames: string[] = []
  collectCollectionNames(fields, dictNames, bufferNames)
  return { names: roundNames(fields, true), dictNames, bufferNames, width: roundNames(fields, false).size }
}

// The shape `bindReferences` filled in; a repeat or times no Scheme bound has none.
export function roundShape(f: Extract<Field, { kind: "repeat" | "times" }>): RoundShape {
  const { shape } = f as typeof f & { shape?: RoundShape }
  if (shape === undefined) throw new RangeError(`${f.kind}: round shape is not bound`)
  return shape
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

// `values` with each list among the round's names read at `index`; a value that is not a list
// stays as it is.
export function sliceRound(values: Value, names: Set<string>, index: number): Value {
  const slice: Value = { ...values }
  for (const name of names) {
    const v = values[name]
    if (Array.isArray(v)) slice[name] = v[index]
  }
  return slice
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
