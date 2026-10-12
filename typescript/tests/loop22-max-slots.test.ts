import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { describe, it } from "node:test"
import { fileURLToPath } from "node:url"
import { Scheme, u8, u32, times } from "../src/index.ts"

// Loop 22 U17 (AZ-2415): the default maxSlots is 1 048 576, a quarter of 4 194 304, so a 4.3 MB packet
// costs at most a quarter of the unpack memory it did. The memory method is section 2 of
// `_docs/03_implementation/reference_loop22.md`.

type Row = Record<string, unknown>

type Outcome = {
  shape: string
  maxSlots: number
  result: { ok: boolean; field?: string }
  rows: number
  peakMB: number
  unpackPeakMB: number
}

function measure(shape: string, maxSlots?: number): Outcome {
  const child = fileURLToPath(new URL("./support/unpack-memory.ts", import.meta.url))
  const args = maxSlots === undefined ? [child, shape] : [child, shape, String(maxSlots)]
  const run = spawnSync(process.execPath, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60_000 })
  assert.equal(run.status, 0, run.stderr)
  return JSON.parse(run.stdout) as Outcome
}

describe("AZ-2415 U17 the default maxSlots is 1 048 576", () => {
  it("AC-1 a scheme built with no limits reads 65 535 rounds and 1 048 576 slots", () => {
    // Act
    const layout = new Scheme<Row>(1, [u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)])])

    // Assert
    assert.deepEqual(
      [layout.maxRounds, layout.maxSlots, Scheme.DefaultMaxRounds, Scheme.DefaultMaxSlots],
      [65_535, 1_048_576, 65_535, 1_048_576],
    )
  })

  it("AC-2 the F10 packet (4.3 MB, 4 194 240 slots) is refused at the default and peaks under 400 MB", () => {
    // Act
    const outcome = measure("f10")

    // Assert
    assert.equal(outcome.maxSlots, 1_048_576)
    assert.equal(outcome.result.ok, false)
    assert.equal(outcome.rows, 0)
    assert.ok(outcome.peakMB < 400, `peak ${outcome.peakMB} MB`)
  })

  it("AC-3 with maxSlots raised to 4 194 304 the same packet unpacks", () => {
    // Act
    const outcome = measure("f10", 4_194_304)

    // Assert
    assert.deepEqual(outcome.result, { ok: true })
    assert.equal(outcome.rows, 1)
  })
})
