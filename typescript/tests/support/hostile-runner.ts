import { Worker } from "node:worker_threads"
import { bound, type Bound } from "./timing.ts"

// Runs jobs in a worker so a hang or an out-of-memory loop ends the worker, not the test run. The worker gets the
// jobs as workerData, posts `{ ready: true }` once its imports are loaded, then one result per job in job order.
// The case that hangs is reported and the rest restart in a fresh worker.
export type WorkerMessage<O> = { ready: true } | { key: string; outcome: O }

/** Nominal guards in seconds, written for an idle host; both are scaled by the load factor before each batch. */
export type HangGuards = { caseSeconds: number; startupSeconds: number }

function within(limit: Bound): string {
  return `${limit.seconds.toFixed(1)} s (nominal ${limit.nominalSeconds} s x load factor ${limit.factor.toFixed(2)})`
}

function runBatch<J extends { key: string }, O>(
  url: URL,
  jobs: J[],
  guards: HangGuards,
  done: Map<string, O | Error>,
): Promise<void> {
  // Measured in this thread before the worker exists, so the worker's start-up does not slow the reference loop.
  const startup = bound(guards.startupSeconds)
  const perCase = bound(guards.caseSeconds)
  return new Promise((resolve) => {
    const worker = new Worker(url, { workerData: jobs, resourceLimits: { maxOldGenerationSizeMb: 256 } })
    let timer: NodeJS.Timeout | undefined
    let ended = false
    const pending = () => jobs.find((j) => !done.has(j.key))
    const finish = (stuck?: J, reason?: unknown) => {
      if (ended) return
      ended = true
      clearTimeout(timer)
      void worker.terminate()
      if (stuck !== undefined) done.set(stuck.key, new Error(`${stuck.key}: ${String(reason)}`))
      resolve()
    }
    const arm = (limit: Bound, reason: string) => {
      clearTimeout(timer)
      const next = pending()
      if (!next) return finish()
      timer = setTimeout(() => finish(next, `${reason} ${within(limit)}`), limit.seconds * 1000)
    }
    worker.on("message", (m: WorkerMessage<O>) => {
      if (ended) return
      if ("key" in m) done.set(m.key, m.outcome)
      arm(perCase, "hang: no result within")
    })
    worker.once("error", (e) => finish(pending(), e))
    arm(startup, "start-up: the worker did not post ready within")
  })
}

/** Runs every job, one worker per batch, and returns the outcome of each key or the Error that ended it. */
export async function runJobs<J extends { key: string }, O>(
  url: URL,
  jobs: J[],
  guards: HangGuards,
): Promise<Map<string, O | Error>> {
  const done = new Map<string, O | Error>()
  while (jobs.some((j) => !done.has(j.key))) {
    await runBatch(url, jobs.filter((j) => !done.has(j.key)), guards, done)
  }
  return done
}
