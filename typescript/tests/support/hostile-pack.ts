import { BinaryPacker, bool, bytes, eq, flagByte, flags, repeat, scheme, times, u32, u8, u16, when } from "../../src/index.ts"

type Row = Record<string, unknown>

// fixtures/hostile/cases.txt, pack stage: the scheme and row each case id names, written from
// fixtures/hostile/README.md. Each entry packs the row; the case file says whether bytes or a refusal is expected.
const timesScheme = () => scheme<Row>(1, u8(0, (x) => x.a), times(1, 0, [u8(1, (x) => x.x)]))

const splitWhenSource = () => {
  const fb = flagByte("fb")
  return scheme<Row>(
    1,
    fb,
    u8(0, (x) => x.mode),
    fb.bit(when(1, eq(0, 1), [u8(1, (x) => x.speed)])),
  )
}

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
  pack_times_count_over_limit: () => BinaryPacker.pack(
    scheme<Row>(1, u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.x)])),
    { n: 65536, x: 7 },
  ),
  pack_times_zero_with_values: () => BinaryPacker.pack(timesScheme(), { a: 0, x: [5] }),
  pack_split_when_source_after_byte: () => BinaryPacker.pack(splitWhenSource(), { mode: 1, speed: 7 }),
  pack_split_times_count_after_byte: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(1, fb, u8(0, (x) => x.n), fb.bit(times(1, 0, [u8(1, (x) => x.pt)]))),
      { n: 2, pt: [5, 6] },
    )
  },
  pack_split_times_count_skipped: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        u8(0, (x) => x.sel),
        fb,
        when(1, eq(0, 1), [u8(1, (x) => x.n)]),
        fb.bit(times(2, 1, [u8(2, (x) => x.pt)])),
      ),
      { sel: 0, pt: [5] },
    )
  },
  pack_lone_bytes_in_round: () => BinaryPacker.pack(
    scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [bytes(1, (x) => x.d, 2)])),
    { n: 2, d: Uint8Array.from([1, 2]) },
  ),
  pack_split_false_condition_silent: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        u8(0, (x) => x.mode),
        fb,
        fb.bit(when(1, eq(0, 1), [u8(1, (x) => x.speed)])),
        fb.bit(u16(2, (x) => x.heading)),
      ),
      { mode: 0, speed: 7, heading: 90 },
    )
  },
}
