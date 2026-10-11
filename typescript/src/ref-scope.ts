import type { Field } from "./fields.ts"
import { makeRoundShape } from "./rounds.ts"

type SourceKind = "integer" | "bool" | "other"
type Source = { name: string; kind: SourceKind }
type Scope = Map<number, Source>
type Referring = Extract<Field, { kind: "when" | "sized" | "bits" | "packed" | "times" }>

// The name `bindReferences` filled in. A field no Scheme bound has none, and must not read a
// value by a missing name.
export function refName(f: Referring): string {
  const { ref } = f as typeof f & { ref?: string }
  if (ref === undefined) throw new RangeError(`${f.kind}: reference is not bound`)
  return ref
}

// A value shown in an error: never calls the caller's toString.
function describe(v: unknown): string {
  if (typeof v === "string") return JSON.stringify(v)
  if (v === null || ["number", "boolean", "bigint", "undefined"].includes(typeof v)) return String(v)
  return `${typeof v === "object" ? "an" : "a"} ${typeof v}`
}

// A copy of `f` that carries the name; the exported `Field` type has no `ref`.
function bound<F extends Field>(f: F, ref: string): F {
  return { ...f, ref }
}

// A copy of a repeat or times with its round shape; the exported `Field` type has no `shape`.
function shaped<F extends Extract<Field, { kind: "repeat" | "times" }>>(f: F, fields: Field[]): F {
  return { ...f, fields, shape: makeRoundShape(fields) }
}

// An `eq` id, or the count id of `sized`, `bits`, `packed` and `times`, names a value field read
// earlier in the same scope: the top level, a `repeat` or `times` body, a list or dict element,
// or an unanchored group. `flags`, flag bits, an anchored group and `when` share the scope
// around them; a nested scope is closed in both directions. The scheme keeps a copy of each
// reference field with the name filled in, so pack and unpack never look an id up.
export function bindReferences(fields: Field[]): Field[] {
  return bindAll(fields, new Map())
}

function bindAll(fields: Field[], scope: Scope): Field[] {
  return fields.map((f) => bind(f, scope))
}

function declare(scope: Scope, id: number, name: string, kind: SourceKind = "other"): void {
  scope.set(id, { name, kind })
}

function resolve(
  scope: Scope,
  owner: string,
  ownerId: number,
  role: string,
  id: number,
  accepts: "integer" | "integer or bool",
): string {
  const source = scope.get(id)
  if (source === undefined) {
    throw new RangeError(
      `${owner} ${ownerId}: ${role} names field id ${id}, which is not declared earlier in the same scope`,
    )
  }
  const allowed = source.kind === "integer" || (accepts === "integer or bool" && source.kind === "bool")
  if (!allowed) {
    throw new RangeError(
      `${owner} ${ownerId}: ${role} names field id ${id} (${source.name}), which is not ${
        accepts === "integer" ? "an integer" : "an integer or a bool"
      }`,
    )
  }
  return source.name
}

function bind(f: Field, scope: Scope): Field {
  switch (f.kind) {
    case "int":
      declare(scope, f.id, f.name, "integer")
      return f
    case "bool":
      declare(scope, f.id, f.name, "bool")
      return f
    case "float":
    case "bytes":
    case "utf8":
      declare(scope, f.id, f.name)
      return f
    case "u2":
      for (const slot of f.slots) declare(scope, slot.id, slot.name, "integer")
      return f
    case "sized":
    case "bits":
    case "packed": {
      const ref = resolve(scope, f.kind, f.id, "count", f.countId, "integer")
      declare(scope, f.id, f.name)
      return bound(f, ref)
    }
    case "when": {
      const ref = resolve(scope, "when", f.anchor, "eq", f.fieldId, "integer or bool")
      if (scope.get(f.fieldId)?.kind === "bool" && f.value !== true) {
        throw new RangeError(
          `when ${f.anchor}: eq names bool field id ${f.fieldId} (${ref}) and accepts only true, not ${describe(f.value)}`,
        )
      }
      return bound({ ...f, fields: bindAll(f.fields, scope) }, ref)
    }
    case "times": {
      const ref = resolve(scope, "times", f.anchor, "count", f.countId, "integer")
      return bound(shaped(f, bindAll(f.fields, new Map())), ref)
    }
    case "repeat":
      return shaped(f, bindAll(f.fields, new Map()))
    case "group":
      return { ...f, fields: bindAll(f.fields, f.anchor === undefined ? new Map() : scope) }
    case "flags":
      return { ...f, fields: bindAll(f.fields, scope) }
    case "flagBit":
      return { ...f, field: bind(f.field, scope) }
    case "list":
    case "dict":
      return { ...f, element: bind(f.element, new Map()) }
    case "flagByte":
      return f
  }
}
