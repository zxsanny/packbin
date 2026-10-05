import {
  BinaryPacker,
  PackSession,
  bits,
  bool,
  bytes,
  dict,
  eq,
  flags,
  i8,
  list,
  packed,
  repeat,
  scheme,
  sized,
  times,
  u32,
  u8,
  utf8,
  when,
  type DispatchResult,
  type Scheme,
} from "../../src/index.ts"

type Row = Record<string, unknown>

export type Outcome = {
  result?: DispatchResult
  called: boolean
  threw?: string
  ms: number
}

// Count 0 is the first value of the scheme; flag-guarded counts hide it behind a clear bit.
const clearFlag = () => flags(0, [u8(0, (x: Row) => x.n)])

const dictZeroWidthValue = scheme<Row>(1, dict((x) => x.d, bytes(0, (x) => x.v, 0)))

export const SCHEMES: Record<string, Scheme<Row>> = {
  // fixtures/hostile/cases.txt, unpack stage
  zero_progress_repeat_bool: scheme<Row>(1, repeat(0, [bool(0, (x) => x.on)])),
  zero_progress_repeat_when: scheme<Row>(
    1,
    u8(0, (x) => x.mode),
    repeat(1, [when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
  ),
  negative_count: scheme<Row>(
    1,
    i8(0, (x) => x.n),
    sized(1, (x) => x.payload, 0),
  ),
  oversize_count: scheme<Row>(
    1,
    u32(0, (x) => x.n),
    sized(1, (x) => x.payload, 0),
  ),
  oversize_count_times: scheme<Row>(
    1,
    u32(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  oversize_list_count: scheme<Row>(1, list((x) => x.xs, u8(0, (x) => x.x))),
  invalid_utf8: scheme<Row>(1, utf8(0, (x) => x.name)),
  invalid_utf8_dict_key: scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.v))),
  count_behind_clear_flag: scheme<Row>(1, clearFlag(), sized(1, (x) => x.payload, 0)),
  count_behind_clear_flag_bits: scheme<Row>(1, clearFlag(), bits(1, (x) => x.segs, 0)),

  // AZ-2072 problem table
  row1_zero_progress_repeat: scheme<Row>(
    1,
    u8(0, (x) => x.k),
    repeat(1, [when(1, eq(0, 9), [u8(1, (x) => x.v)])]),
  ),
  row2a_sized_negative: scheme<Row>(
    1,
    i8(0, (x) => x.n),
    sized(1, (x) => x.p, 0),
  ),
  row2b_bits_negative: scheme<Row>(
    1,
    i8(0, (x) => x.n),
    bits(1, (x) => x.b, 0),
  ),
  row2c_packed_negative: scheme<Row>(
    1,
    i8(0, (x) => x.n),
    packed(2, 1, (x) => x.k, 0),
  ),
  row2c_times_negative: scheme<Row>(
    1,
    i8(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row2d_packed_negative_bias: scheme<Row>(
    1,
    u8(0, (x) => x.n),
    packed(1, 1, (x) => x.legs, 0, -1),
  ),
  row3_invalid_utf8_string: scheme<Row>(1, utf8(0, (x) => x.s)),
  row3_invalid_utf8_dict_key: scheme<Row>(1, dict((x) => x.d, u8(0, (x) => x.v))),
  row4_sized_behind_clear_flag: scheme<Row>(1, clearFlag(), sized(1, (x) => x.p, 0)),
  row4_bits_behind_clear_flag: scheme<Row>(1, clearFlag(), bits(1, (x) => x.b, 0)),
  row4_packed_behind_clear_flag: scheme<Row>(1, clearFlag(), packed(2, 1, (x) => x.k, 0)),
  row4_times_behind_clear_flag: scheme<Row>(
    1,
    clearFlag(),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row5_list_oversize: scheme<Row>(1, list((x) => x.xs, u8(0, (x) => x.x))),
  row5_utf8_oversize: scheme<Row>(1, utf8(0, (x) => x.s)),
  row5_times_oversize: scheme<Row>(
    1,
    u8(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row5_sized_oversize: scheme<Row>(
    1,
    u8(0, (x) => x.n),
    sized(1, (x) => x.p, 0),
  ),
  row6_times_zero_width_oversize: scheme<Row>(
    1,
    u32(0, (x) => x.n),
    times(1, 0, [when(1, eq(0, 9), [u8(1, (x) => x.v)])]),
  ),
  row6_times_zero_width_small: scheme<Row>(
    1,
    u8(0, (x) => x.n),
    times(1, 0, [when(1, eq(0, 9), [u8(1, (x) => x.v)])]),
  ),
  row7_list_of_list_zero_width: scheme<Row>(
    1,
    list(
      (x) => x.outer,
      list((x) => x.inner, bytes(0, (x) => x.e, 0)),
    ),
  ),
  row7_dict_zero_width_value: dictZeroWidthValue,
  row7_dict_zero_width_value_one: dictZeroWidthValue,
  row7_never_matching_when_element: scheme<Row>(
    1,
    u8(0, (x) => x.mode),
    list((x) => x.xs, when(0, eq(0, 9), [u8(0, (x) => x.v)])),
  ),
  row5_bits_oversize: scheme<Row>(
    1,
    u32(0, (x) => x.n),
    bits(1, (x) => x.b, 0),
  ),
  row5_packed_oversize: scheme<Row>(
    1,
    u32(0, (x) => x.n),
    packed(2, 1, (x) => x.k, 0),
  ),
  row5_dict_oversize: scheme<Row>(1, dict((x) => x.d, u8(0, (x) => x.v))),
}

export function runCase(id: string, hex: string): Outcome {
  const layout = SCHEMES[id]
  if (!layout) throw new Error(`no scheme declared for hostile case ${id}`)
  const out: Outcome = { called: false, ms: 0 }
  const start = performance.now()
  try {
    out.result = BinaryPacker.unpack(
      Buffer.from(hex, "hex"),
      layout.on(() => {
        out.called = true
      }),
    )
  } catch (e) {
    out.threw = String(e)
  }
  out.ms = performance.now() - start
  return out
}

export type SessionOutcome = { first?: DispatchResult; second?: DispatchResult; threw?: string; ms: number }

const sessionSeed = () => Uint8Array.from({ length: 32 }, (_, i) => i + 1)
const sessionNonce = Uint8Array.from({ length: 16 }, (_, i) => i + 1)

// Clear bytes 01 00 05 (type 1, k = 0, trailing 05), then a valid type-2 message.
export function runSession(): SessionOutcome {
  const opener = PackSession.load(sessionSeed())!
  const waiter = PackSession.load(sessionSeed())!
  opener.start(sessionNonce)
  waiter.join(sessionNonce)
  const sender = scheme<Row>(
    1,
    u8(0, (x) => x.k),
    u8(1, (x) => x.extra),
  )
  const receiver = scheme<Row>(
    1,
    u8(0, (x) => x.k),
    repeat(1, [when(1, eq(0, 9), [u8(1, (x) => x.v)])]),
  )
  const next = scheme<Row>(2, u8(0, (x) => x.k))
  const out: SessionOutcome = { ms: 0 }
  const start = performance.now()
  try {
    const hostile = opener.pack(sender, { k: 0, extra: 5 })!
    out.first = waiter.unpack(hostile, receiver.on(() => {}))
    const fine = opener.pack(next, { k: 7 })!
    out.second = waiter.unpack(fine, next.on(() => {}))
  } catch (e) {
    out.threw = String(e)
  }
  out.ms = performance.now() - start
  return out
}
