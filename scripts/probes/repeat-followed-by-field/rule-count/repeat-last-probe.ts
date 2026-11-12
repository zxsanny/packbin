// Measurement only (AZ-4206). run.sh copies this file into a temporary copy of typescript/src and calls
// reportRepeatNotLast as the last line of the Scheme constructor, so only a scheme that builds is seen:
// it logs every scheme the candidate rule would refuse and changes nothing. A repeat is reported when it sits inside a list or dict element, or when anything
// that writes a byte follows it in its own place or in a place around it. A follower under a `when` on
// the same field with another value than the `when` that holds the repeat is marked `excused`.
import { appendFileSync } from "node:fs"
import type { Field } from "./fields.ts"

type Level = { followers: Field[]; guard?: { fieldId: number; value: unknown } }
type Follower = { what: string; excused: boolean }
type Finding = { kind: "element" | "followed"; anchor: number; followers: Follower[] }

function writes(f: Field): boolean {
  switch (f.kind) {
    case "bool":
      return false
    case "bytes":
      return f.size > 0
    case "when":
    case "group":
    case "repeat":
    case "times":
      return f.fields.some(writes)
    case "flagBit":
      return writes(f.field)
    default:
      return true
  }
}

// 1 and 1n name the same integer in an `eq`.
function sameValue(a: unknown, b: unknown): boolean {
  const integer = (v: unknown) => typeof v === "bigint" || (typeof v === "number" && Number.isInteger(v))
  return integer(a) && integer(b) ? BigInt(a as number | bigint) === BigInt(b as number | bigint) : Object.is(a, b)
}

function label(f: Field): string {
  switch (f.kind) {
    case "when":
      return `when(${f.fieldId}==${String(f.value)}){${f.fields.map(label).join(",")}}`
    case "repeat":
      return `repeat{${f.fields.map(label).join(",")}}`
    case "times":
      return `times(${f.countId}){${f.fields.map(label).join(",")}}`
    case "group":
      return `group${f.anchor === undefined ? "" : "#"} ${f.name}{${f.fields.map(label).join(",")}}`
    case "flags":
      return `flags{${f.fields.map(label).join(",")}}`
    case "flagByte":
      return "flagByte"
    case "flagBit":
      return `bit:${label(f.field)}`
    case "list":
    case "dict":
      return `${f.kind} ${f.name}[${label(f.element)}]`
    case "u2":
      return `u2(${f.slots.map((s) => s.name).join(",")})`
    case "int":
      return `${f.signed ? "i" : "u"}${f.size * 8} ${f.name}`
    default:
      return `${f.kind} ${f.name}`
  }
}

function walk(fields: Field[], outer: Level[], inElement: boolean, found: Finding[]): void {
  fields.forEach((f, i) => {
    const here: Level = { followers: fields.slice(i + 1) }
    switch (f.kind) {
      case "repeat": {
        const followers: Follower[] = []
        for (const level of [here, ...outer]) {
          for (const s of level.followers) {
            if (!writes(s)) continue
            const excused =
              level.guard !== undefined &&
              s.kind === "when" &&
              s.fieldId === level.guard.fieldId &&
              !sameValue(s.value, level.guard.value)
            followers.push({ what: label(s), excused })
          }
        }
        if (inElement) found.push({ kind: "element", anchor: f.anchor, followers })
        else if (followers.length > 0) found.push({ kind: "followed", anchor: f.anchor, followers })
        walk(f.fields, [], inElement, found)
        break
      }
      case "times":
        walk(f.fields, [], inElement, found)
        break
      case "when":
        walk(f.fields, [{ ...here, guard: { fieldId: f.fieldId, value: f.value } }, ...outer], inElement, found)
        break
      case "group":
      case "flags":
        walk(f.fields, [here, ...outer], inElement, found)
        break
      case "flagBit":
        walk([f.field], [here, ...outer], inElement, found)
        break
      case "list":
      case "dict":
        walk([f.element], [], true, found)
        break
    }
  })
}

const log = process.env.PACKBIN_RULE_LOG
const driver = (process.argv[1] ?? "").includes("/drivers/")

function caller(): string {
  const lines = (new Error().stack ?? "").split("\n").slice(1)
  for (const l of lines) {
    const m = l.match(/(?:file:\/\/)?(\/[^\s():]+\.(?:ts|mjs|js))/)
    if (m && !m[1]!.includes("/typescript/src/")) return m[1]!.replace(/^.*\/packbin\//, "")
  }
  return "?"
}

// One line per scheme that was built ("d" from a ring driver, "t" from anything else), written at once: a
// test worker that is terminated runs no exit hook. A scheme the rule would refuse gets a JSON line too;
// run.sh counts each (file, scheme) pair once, whatever process or thread built it.
export function reportRepeatNotLast(fields: Field[]): void {
  if (log === undefined) return
  appendFileSync(log, driver ? "d\n" : "t\n")
  const found: Finding[] = []
  walk(fields, [], false, found)
  if (found.length === 0) return
  appendFileSync(log, `${JSON.stringify({ file: caller(), scheme: fields.map(label).join(", "), found })}\n`)
}
