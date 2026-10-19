import { isMainThread, parentPort, workerData } from "node:worker_threads"

// A worker for hostile-guard.test.ts that speaks the protocol of support/hostile-runner.ts. A `spin` job never
// returns (a hang). `readyAfterMs` on a pending job holds `ready` back that long, standing in for a slow start-up;
// Infinity never posts it. Every other job answers `ran <key>`.
export type ProbeJob = { key: string; spin?: boolean; readyAfterMs?: number }

if (!isMainThread && parentPort) {
  const jobs = workerData as ProbeJob[]
  const wait = Math.max(0, ...jobs.map((j) => j.readyAfterMs ?? 0))
  // Blocks this thread like a slow module load; terminate() still ends it.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, wait)
  parentPort.postMessage({ ready: true })
  for (const job of jobs) {
    if (job.spin) for (;;);
    parentPort.postMessage({ key: job.key, outcome: `ran ${job.key}` })
  }
}
