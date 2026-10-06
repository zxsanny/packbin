import type { Field } from "./fields.ts"
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
