import assert from "node:assert/strict"
import { describe, it } from "node:test"
import type { ProbeJob } from "./support/hang-probe-worker.ts"
import { runJobs, type HangGuards } from "./support/hostile-runner.ts"
import { bound } from "./support/timing.ts"

// Short nominal guards so the probes end fast; the runner scales them by the load factor as it does the real ones.
const GUARDS: HangGuards = { caseSeconds: 0.3, startupSeconds: 3 }
const PROBE = new URL("./support/hang-probe-worker.ts", import.meta.url)

const run = (jobs: ProbeJob[], guards = GUARDS) => runJobs<ProbeJob, string>(PROBE, jobs, guards)

describe("hostile worker hang guard (AZ-2728)", () => {
  it("a job that never returns is reported as a hang naming its key, and the next job still runs", async () => {
    // Arrange
    const jobs = [{ key: "before" }, { key: "spins", spin: true }, { key: "after" }]

    // Act
    const settled = await run(jobs)

    // Assert
    assert.equal(settled.get("before"), "ran before")
    const hang = settled.get("spins")
    assert.ok(hang instanceof Error, `expected a hang, got ${String(hang)}`)
    assert.match(hang.message, /^spins: hang: no result within /)
    assert.equal(settled.get("after"), "ran after")
  })

  it("a start-up longer than the case guard is not charged to the first case", async () => {
    // Arrange: ready comes three case guards late, measured as the runner measures it. The start-up guard is 30 s
    // nominal so that a load factor read here up to 8 times the runner's (0.9 s x 8) still ends inside it.
    const caseGuard = bound(GUARDS.caseSeconds)
    const jobs = [{ key: "first", readyAfterMs: 3 * caseGuard.seconds * 1000 }, { key: "second" }]

    // Act
    const settled = await run(jobs, { ...GUARDS, startupSeconds: 30 })

    // Assert
    assert.deepEqual([...settled], [["first", "ran first"], ["second", "ran second"]])
  })

  it("a start-up that never finishes ends the batch naming the first case, and the next job still runs", async () => {
    // Arrange
    const jobs = [{ key: "first", readyAfterMs: Infinity }, { key: "second" }]

    // Act
    const settled = await run(jobs, { ...GUARDS, startupSeconds: 1 })

    // Assert
    const stuck = settled.get("first")
    assert.ok(stuck instanceof Error, `expected a start-up failure, got ${String(stuck)}`)
    assert.match(stuck.message, /^first: start-up: the worker did not post ready within /)
    assert.equal(settled.get("second"), "ran second")
  })
})
