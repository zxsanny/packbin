# Loop 31 notes — CI speed 2 (AZ-2607)

## Batch 1: structure and timing

- `readonly` gate group → three groups (`publish-gate.test.sh` `gate_groups` 14 → 16): `readonly` (`ro_symlink_check`, `ro_static_checks`, `ro_probe_checks`, `ro_out_checks`, `ro_host_path_check`), `readonly-gate` (`ro_gate_checks`, the three real gate runs), `readonly-full` (`ro_full_run_check`, the full build-only run). No check function changed.
- `test.yml` gate jobs 3 → 5 (first estimate; batch 2 moves groups by the measured seconds): `publish-gate-readonly` (readonly, gate), `publish-gate-readonly-gate` (readonly-gate, pins), `publish-gate-readonly-full` (readonly-full), `publish-gate-phases` (phases), `publish-gate-rest` (the ten groups that start no container, no pull). CI jobs 15 → 17; `run:` steps 24 → 30 (two more jobs, three steps each); 9 matrix entries unchanged.
- Guards: `publish-jobs.test.sh` takes the gate jobs as every `publish-gate-*` job (no fixed list) and holds the container groups (`gate phases readonly readonly-gate readonly-full`); mutants 45 → 50 (all rejected). `publish-timing.selftest.sh`: the 16 groups and their functions, and `ro_split`: each read-only check (a `ro_*_check(s)` function, 7) runs exactly once, as a line of `readonly_checks` or as a `group` function; 4 mutants rejected (a check dropped, a check in two groups, a group line removed, a new check in no group). One mutant survived the first version (a one-line `ro_extra_check() { :; }`, which the definition pattern does not match); the mutant is now a multi-line function, the form every check has.

## review28 #4 audit: host delete before a container binds the path (AC-6)

The loop 28 effect (AZ-2565): on Docker Desktop a container still sees the old entries of a path for about a second after a host `rm -rf`, when the VM has cached that path from an earlier container. Every delete in `scripts/`, `.github/workflows/` and `cpp/embedded/`:

| Site | Container binds the path after it? | Verdict |
|------|------------------------------------|---------|
| `publish-build.sh:28` `rm -rf "$artifacts"`, then `mkdir` and a bind of `artifacts/<lang>` | yes | harmless: every scenario has its own `PACKBIN_OUT` (no repeated `ph_publish` name in the phases, rerun, pins and read-only tests), the real publish runs on Linux (no lag), and the host-side check reads the host view, so a stale entry could only fail a run, never pass it |
| `publish-embedded.sh:39`, `:57`, `:129`; `publish-sign.sh:56`; `publish-swift.sh:86`, `:103`; `publish-position.sh:35`, `:108`; `stage-arduino.sh:13`; `publish-upload.sh`, `crates-token.sh`, `publish-lib.sh:214` (temp files) | no: host tools only (`ro_static_checks` allows a docker call only in `publish-lib.sh`) | harmless |
| `ring-swift.sh:68` `rm -f "$stamp"`, then `docker run` binds the scratch dir | the stamp is read by the host only | harmless |
| `cpp/embedded/arm.sh:38`, `:234`; `esp.sh:12`; `examples.sh:40`, `:67`, `:89` | the delete runs inside the container stage (`run.sh arm`/`esp`) | harmless: the AZ-2565 pattern (clean inside the container) |
| `scripts/loop-tests.sh:172` | cleaned inside the container | the AZ-2565 fix |
| test files: `ro_tree` (`publish-readonly.test.sh`), `ro_full_run_check:382`, `publish-vcpkg.test.sh:355`, `publish-go.test.sh:150` | the read-only ones bind a fresh copy made just before (`copy_tree`), that no container has seen; vcpkg and go are host tools | harmless |

0 harmful sites; nothing to fix.
