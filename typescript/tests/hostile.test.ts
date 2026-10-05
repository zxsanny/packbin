import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"
import { Worker } from "node:worker_threads"
import { BinaryPacker, bits, i32, repeat, scheme, u64, type DispatchResult } from "../src/index.ts"
import type { Outcome, SessionOutcome } from "./support/hostile-cases.ts"

// A hang or an out-of-memory loop ends the worker, not the test run. The cases share one
// worker; the case that hangs is reported and the rest restart in a fresh worker.
const KILL_AFTER_MS = 5000

type Job = { key: string; id?: string; hex?: string; session?: boolean }
type Settled = Outcome | SessionOutcome | Error

function runBatch(jobs: Job[], done: Map<string, Settled>): Promise<void> {
  return new Promise((resolve) => {
    const worker = new Worker(new URL("./support/hostile-worker.ts", import.meta.url), {
      workerData: jobs,
      resourceLimits: { maxOldGenerationSizeMb: 256 },
    })
    let timer: NodeJS.Timeout
    const finish = (stuck?: string, reason?: unknown) => {
      clearTimeout(timer)
      void worker.terminate()
      if (stuck !== undefined) done.set(stuck, new Error(`${stuck}: ${String(reason)}`))
      resolve()
    }
    const arm = () => {
      clearTimeout(timer)
      const next = jobs.find((j) => !done.has(j.key))
      if (!next) return finish()
      timer = setTimeout(
        () => finish(next.key, `no result within ${KILL_AFTER_MS} ms (hang)`),
        KILL_AFTER_MS,
      )
    }
    worker.on("message", (m: { key: string; outcome: Outcome | SessionOutcome }) => {
      done.set(m.key, m.outcome)
      arm()
    })
    worker.once("error", (e) => {
      const next = jobs.find((j) => !done.has(j.key))
      finish(next?.key, e)
    })
    arm()
  })
}

async function runAll(jobs: Job[]): Promise<Map<string, Settled>> {
  const done = new Map<string, Settled>()
  while (jobs.some((j) => !done.has(j.key))) {
    await runBatch(jobs.filter((j) => !done.has(j.key)), done)
  }
  return done
}

const cases = readFileSync(new URL("../../fixtures/hostile/cases.txt", import.meta.url), "utf8")
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line !== "" && !line.startsWith("#"))
  .map((line) => {
    const [id, stage, expected, hex] = line.split(/\s+/)
    return { id: id!, stage: stage!, expected: expected!.split("|"), hex: hex! }
  })
  .filter((c) => c.stage === "unpack")

const SPEC: Record<string, string> = {
  row1_zero_progress_repeat: "010005",
  row2a_sized_negative: "01fd616263",
  row2b_bits_negative: "01fd",
  row2c_packed_negative: "01fd",
  row2c_times_negative: "01fd",
  row2d_packed_negative_bias: "0100",
  row3_invalid_utf8_string: "010100ff",
  row3_invalid_utf8_dict_key: "0101000100ff05",
  row4_sized_behind_clear_flag: "0100",
  row4_bits_behind_clear_flag: "0100",
  row4_packed_behind_clear_flag: "0100",
  row4_times_behind_clear_flag: "0100",
  row6_times_zero_width_oversize: "01ffffffff",
  row6_times_zero_width_small: "0103",
  row5_list_oversize: "01ffff0100",
  row5_utf8_oversize: "01ffff61",
  row5_times_oversize: "01ff0102",
  row5_sized_oversize: "01ff0102",
  row5_dict_oversize: "01ffff",
  row5_bits_oversize: "01ffffffff00",
  row5_packed_oversize: "01ffffffff00",
}

const jobs: Job[] = [
  ...Object.entries(SPEC).map(([id, hex]) => ({ key: id, id, hex })),
  ...cases.map((c) => ({ key: `vector:${c.id}`, id: c.id, hex: c.hex })),
  { key: "session", session: true },
]

let results: Promise<Map<string, Settled>> | undefined

async function outcome(key: string): Promise<Outcome> {
  results ??= runAll(jobs)
  const got = (await results).get(key)
  if (got instanceof Error) throw got
  return got as Outcome
}

const run = (id: string) => outcome(id)

// Interim error mapping (until C15): trailing bytes, short packet, or a value that cannot be read.
function kindOf(result: DispatchResult | undefined): string {
  if (!result || result.ok || !("field" in result)) return "other"
  if (result.field === "" && result.needed === 0) return "trailing_bytes"
  if (result.needed > 0) return "short_packet"
  return "bad_value"
}

function assertRejected(out: Outcome, ms = 1000): void {
  assert.equal(out.threw, undefined, `unpack threw: ${out.threw}`)
  assert.equal(out.called, false, "handler must not be called")
  assert.ok(out.result && out.result.ok === false, `expected ok:false, got ${JSON.stringify(out.result)}`)
  assert.ok(out.ms < ms, `unpack took ${out.ms} ms`)
}

function assertError(out: Outcome, field: string, left: number): void {
  assertRejected(out)
  assert.deepEqual(out.result, { ok: false, field, needed: 0, left })
}

describe("hostile packets", () => {
  it("zero-progress repeat ends with trailing error", async () => {
    assertError(await run("row1_zero_progress_repeat"), "", 1)
  })

  it("negative sized count is an error", async () => {
    assertError(await run("row2a_sized_negative"), "p", 3)
  })

  it("negative bits count is an error", async () => {
    assertError(await run("row2b_bits_negative"), "b", 0)
  })

  it("negative packed/times count does not throw", async () => {
    assertError(await run("row2c_packed_negative"), "k", 0)
    assertError(await run("row2c_times_negative"), "v", 0)
    assertError(await run("row2d_packed_negative_bias"), "legs", 0)
  })

  it("invalid utf8 string is an error", async () => {
    assertError(await run("row3_invalid_utf8_string"), "s", 3)
  })

  it("invalid utf8 dictionary key is an error", async () => {
    assertError(await run("row3_invalid_utf8_dict_key"), "d", 4)
  })

  it("count behind a clear flag is an error", async () => {
    assertError(await run("row4_sized_behind_clear_flag"), "p", 0)
    assertError(await run("row4_bits_behind_clear_flag"), "b", 0)
    assertError(await run("row4_packed_behind_clear_flag"), "k", 0)
    assertError(await run("row4_times_behind_clear_flag"), "v", 0)
  })

  it("times round that reads nothing is an error", async () => {
    assertError(await run("row6_times_zero_width_oversize"), "v", 0)
    assertError(await run("row6_times_zero_width_small"), "v", 0)
  })

  it("oversize counts stay short packets", async () => {
    for (const id of Object.keys(SPEC).filter((k) => k.startsWith("row5_"))) {
      const out = await run(id)
      assertRejected(out)
      assert.equal(kindOf(out.result), "short_packet", id)
    }
  })

  it("session unpack of hostile payload", async () => {
    const out = (await outcome("session")) as SessionOutcome
    assert.equal(out.threw, undefined, `session threw: ${out.threw}`)
    assert.ok(out.ms < 1000, `session unpack took ${out.ms} ms`)
    assert.deepEqual(out.first, { ok: false, field: "", needed: 0, left: 1 })
    // The receive counter advanced by one, so the next pad still matches.
    assert.deepEqual(out.second, { ok: true })
  })

  it("bits count from a u64 field still round trips", () => {
    type Row = { n: bigint; b: number[] }
    const layout = scheme<Row>(
      1,
      u64(0, (r) => r.n),
      bits(1, (r) => r.b, 0),
    )
    const wire = BinaryPacker.pack(layout, { n: 3n, b: [1, 0, 1] })
    assert.equal(Buffer.from(wire).toString("hex"), "01030000000000000005")
    let got: Row | undefined
    const result = BinaryPacker.unpack(wire, layout.on((row) => {
      got = row as Row
    }))
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(got!.b, [1, 0, 1])
  })

  it("bits count above the safe integer range is an error", () => {
    type Row = { n: bigint; b: number[] }
    const layout = scheme<Row>(
      1,
      u64(0, (r) => r.n),
      bits(1, (r) => r.b, 0),
    )
    for (const hex of ["01ffffffffffffffff", "010000000000002000"]) {
      let ran = false
      const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), layout.on(() => {
        ran = true
      }))
      assert.deepEqual(result, { ok: false, field: "b", needed: 0, left: 0 }, hex)
      assert.equal(ran, false)
    }
  })

  it("progressing repeat is unchanged", () => {
    type Points = { lat: number[]; lon: number[] }
    const points = scheme<Points>(
      1,
      repeat(0, [i32(0, (r) => r.lat), i32(1, (r) => r.lon)]),
    )
    const two = Uint8Array.from([1, 10, 0, 0, 0, 20, 0, 0, 0, 30, 0, 0, 0, 40, 0, 0, 0])
    let got: Points | undefined
    const ok = BinaryPacker.unpack(two, points.on((row) => {
      got = row as Points
    }))
    assert.equal(ok.ok, true)
    assert.deepEqual(got!.lat, [10, 30])
    assert.deepEqual(got!.lon, [20, 40])
    let ran = false
    const extra = BinaryPacker.unpack(Uint8Array.from([...two, 0]), points.on(() => {
      ran = true
    }))
    assert.equal(extra.ok, false)
    assert.equal(ran, false)
  })
})

describe("shared hostile vectors (fixtures/hostile/cases.txt)", () => {
  it("reads at least one unpack vector", () => {
    assert.ok(cases.length > 0)
  })

  for (const c of cases) {
    it(`${c.id} returns an error value`, async () => {
      const out = await run(`vector:${c.id}`)
      assertRejected(out)
      const kind = kindOf(out.result)
      assert.ok(
        c.expected.includes(kind),
        `${c.id}: returned ${kind} ${JSON.stringify(out.result)}, vector accepts ${c.expected.join("|")}`,
      )
    })
  }
})
