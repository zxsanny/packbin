# Autodev loop record — loop 31

loop: 31
branch: dev
plan_artifact: _docs/loops/loop31/plan31.md
tasks_shipped: [AZ-2607]
leftovers:
  - AC-1 met on the median of two runs: 344 s (run 39014663944) and 369 s (run 39018150736, the close push), median 356.5 s against 360 s; thin margin, the wall is set by `publish-gate-readonly-gate` (139, 200, 278 s on three runs)
  - next long poles of test.yml (344 s): `publish-gate-readonly-gate` 341 s (the three real gate runs of `readonly-gate` vary 139 to 200 s; candidates: three jobs, `pins` out), `publish-gate-phases` 285 s (222 s plus the pull; two groups), Swift `gates` 282 s (strict release build 95 + sanitizer build 97 s), `ring` 265 s; image pull of 85 to 90 s in four gate jobs; caches (C3) not done
  - the Arduino-ESP32 target installs PlatformIO that only the Pico example uses (`examples_tools`): unmeasured; the embedded notices show the target seconds
  - a group that prints only at its end (`readonly-full`, `ro_gate_checks`) keeps the Mac heartbeat flat: a "started" line from `timed` would show it alive; not asked
  - Mac timing-bound failures under load again (typescript NFR 1.4 s and times(65535), go `TestAC3RaisedSlotLimit...`, rust `nfr_round_trips_under_one_second`): the serial retry passes them; the Mac carries another project's containers (load 25 to 100 in the pool)
  - 20 jobs per push use the whole free-plan concurrency; a `dev` + `main` push is 40: queueing not measured
  - AC-4 ratio is printed and read by hand (0.32 at step 11), not asserted by the script
  - from loop 30 and earlier: T3 (Go proxy wait) and T1 (tag run skips the repeated test) unproven until the next `v*` / `go/v*` tag (owner's go); T2 option B closed by the owner's batch of 2026-10-17; F44 (tag ruleset) and the first tags owner only; review28 #3 (skipped, no second trap exists); AZ-2068 in `todo/`
smoke: PASS (agent run 8/8, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop31/smoke31.md
assessment_artifact: _docs/loops/loop31/assessment31.md
loop_end_merge: main (not executed this loop: the owner said no push of `main`)
