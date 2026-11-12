import { group, repeat, u8, type Field } from "../../src/index.ts"

// The pieces the hostile loader and repeat-last.test.ts share: the two refusal texts of the contract
// repeat-last (_docs/02_document/contracts/library/repeat-last.md), whole, and the schemes of its cases.

type Row = Record<string, unknown>

// The refusal of a repeat that the field named `field` follows.
export const followedText = (anchor: number, field: string): string =>
  `repeat ${anchor}: ${field} follows it; a repeat reads to the end of the packet, so nothing can follow it; use times`

// The refusal of a repeat inside a list or dict element.
export const inElementText = (anchor: number): string =>
  `repeat ${anchor} is inside a list or dict element; a repeat reads to the end of the packet, so another element cannot follow it; use times`

// repeat { u8 v }, with the id the place gives it.
export const rounds = (id: number): Field => repeat(id, [u8(id, (x: Row) => x.v)])

// The element row of the list and dict cases: u8 mode; repeat { u8 v }.
export const modeThenRepeat = (): Field =>
  group((x: Row) => x.item, [u8(0, (x: Row) => x.mode), rounds(1)])
