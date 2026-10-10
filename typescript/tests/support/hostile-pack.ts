import { BinaryPacker, bool, flags, repeat, scheme, times, u8 } from "../../src/index.ts"

type Row = Record<string, unknown>

// fixtures/hostile/cases.txt, pack stage: the scheme and row each case id names, written from
// fixtures/hostile/README.md. Each entry packs the row; the case file says whether bytes or a refusal is expected.
const timesScheme = () => scheme<Row>(1, u8(0, (x) => x.a), times(1, 0, [u8(1, (x) => x.x)]))

export const PACK: Record<string, () => Uint8Array> = {
  pack_out_of_range_integer: () => BinaryPacker.pack(scheme<Row>(1, u8(0, (x) => x.a)), { a: 300 }),
  pack_missing_required_value: () => BinaryPacker.pack(
    scheme<Row>(1, u8(0, (x) => x.a), u8(1, (x) => x.b)),
    { a: 1 },
  ),
  pack_times_list_too_long: () => BinaryPacker.pack(timesScheme(), { a: 2, x: [1, 2, 3] }),
  pack_times_list_too_short: () => BinaryPacker.pack(timesScheme(), { a: 2, x: [1] }),
  pack_aligned_round_row: () => BinaryPacker.pack(
    scheme<Row>(1, repeat(0, [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.n)])])),
    { on: [true, false, true], n: [1, 2, 3] },
  ),
}
