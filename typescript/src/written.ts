import { validCount, type Value } from "./kinds.ts"

// What a `when` or a count reads is what pack wrote in the scope, as unpack reads what it has read: a
// field that was skipped or absent was not written, and a `when` sees it as `undefined`, as unpack does.
export function seen(wrote: Value, ref: string): unknown {
  return Object.hasOwn(wrote, ref) ? wrote[ref] : undefined
}

export function writtenCount(ref: string, label: string, wrote: Value): unknown {
  if (!Object.hasOwn(wrote, ref)) throw new RangeError(`${label}: count ${ref} was not written`)
  return wrote[ref]
}

export function borrowedCount(ref: string, bias: number, label: string, wrote: Value): number {
  const raw = writtenCount(ref, label, wrote)
  const count = validCount(raw, bias)
  if (count === null) {
    // Pack keeps throwing; the message tells a missing count from a negative one.
    throw new RangeError(
      typeof raw === "bigint"
        ? `${label}: item count ${raw + BigInt(bias)}`
        : typeof raw === "number" && Number.isInteger(raw)
          ? `${label}: item count ${raw + bias}`
          : `${label}: count missing`,
    )
  }
  return count
}
