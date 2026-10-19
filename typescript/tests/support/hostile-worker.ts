import { isMainThread, parentPort, workerData } from "node:worker_threads"
import { runCase, runSession } from "./hostile-cases.ts"

export type Job = { key: string; id?: string; hex?: string; session?: boolean }

// Runs the jobs in order and reports each one as it finishes, so a hang names the case (support/hostile-runner.ts).
// The imports above are loaded before this body runs, so `ready` ends the start-up (thread, module load, type
// stripping) and the per-case guard starts only now.
if (!isMainThread && parentPort) {
  parentPort.postMessage({ ready: true })
  for (const job of workerData as Job[]) {
    const outcome = job.session ? runSession() : runCase(job.id!, job.hex!)
    parentPort.postMessage({ key: job.key, outcome })
  }
}
