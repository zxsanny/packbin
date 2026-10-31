import { readFileSync } from "node:fs"
import type { EccRow } from "./ecc.ts"

// The rows of fixtures/ecc/percent-vectors.txt (row syntax at the top of that file).
export const percentRows: EccRow[] = readFileSync(new URL("../../../fixtures/ecc/percent-vectors.txt", import.meta.url), "utf8")
  .split("\n")
  .filter((line) => line.trim() !== "" && !line.startsWith("#"))
  .map((line) => {
    const f = line.split(" ")
    return { kind: f[0]!, id: f[1]!, args: f.slice(2) }
  })

// The independent formula of the contract, in integer arithmetic.
export const countOf = (p: number, length: number): number => Math.min(32, Math.floor((p * length + 99) / 100))

export function largestOf(p: number): number {
  let length = 0
  while (length + 1 + countOf(p, length + 1) <= 254) length++
  return length
}
