import { readFileSync } from "node:fs"

// The rows of fixtures/text/vectors.txt (row syntax at the top of that file). A text is the hex of its
// UTF-8 bytes, "-" is the empty text; a buffer may be empty.
export type VectorRow =
  | { kind: "enc" | "alt"; id: string; text: string; field: Uint8Array }
  | { kind: "bad"; id: string; refusal: string; buffer: Uint8Array }
  | { kind: "ref"; id: string; packet: Uint8Array }
  | { kind: "flip"; id: string; target: string }

const bytesOf = (hex: string): Uint8Array => new Uint8Array(Buffer.from(hex, "hex"))

export const vectorRows: VectorRow[] = readFileSync(new URL("../../../fixtures/text/vectors.txt", import.meta.url), "utf8")
  .split("\n")
  .filter((line) => line.trim() !== "" && !line.startsWith("#"))
  .map((line): VectorRow => {
    const f = line.split(" ")
    const kind = f[0]
    if (kind === "enc" || kind === "alt") {
      const text = f[2] === "-" ? "" : Buffer.from(f[2]!, "hex").toString("utf8")
      return { kind, id: f[1]!, text, field: bytesOf(f[3]!) }
    }
    if (kind === "bad") return { kind, id: f[1]!, refusal: f[2]!, buffer: bytesOf(f[3] ?? "") }
    if (kind === "ref") return { kind, id: f[1]!, packet: bytesOf(f[2]!) }
    if (kind === "flip") return { kind, id: f[1]!, target: f[2]! }
    throw new Error(`vectors.txt: unknown row kind ${String(kind)}`)
  })

export function rowOf<K extends VectorRow["kind"]>(kind: K, id: string): Extract<VectorRow, { kind: K }> {
  const row = vectorRows.find((r) => r.kind === kind && r.id === id)
  if (!row) throw new Error(`vectors.txt has no ${kind} row ${id}`)
  return row as Extract<VectorRow, { kind: K }>
}

export const hexOf = (b: Uint8Array): string => Buffer.from(b).toString("hex")

// The field bytes (count and payload) the vectors file gives for a text.
export function fieldOf(id: string): string {
  return hexOf(rowOf("enc", id).field)
}

export const refPacketHex = (id: string): string => hexOf(rowOf("ref", id).packet)
