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

## First CI run of batch 1 (run 39012012655, `29c0ab6`, `dev` push, 17 jobs, all green)

Wall 375 s (created 07:00:25, last job done 07:06:40); baseline 418 and 382 s (median 400 s). Per job, with the group or step seconds from the new timing notices (read without a token with the check-run annotations):

| Job | s | What the notice shows |
|-----|--:|-----------------------|
| `suites (swift, gates)` | 371 | resolve 4, thread-sanitizer build 102, list 2, sanitized run 49, `swift_speed` 178 (a full release build with tests plus the speed run), deps 0 |
| `embedded` | 360 | one 353 s step: `run.sh` builds the arm image, runs the arm stage (about 10 s of targets on the Mac), then the ESP stage in `espressif/idf:v5.3.2` (Mac: s3 46, c3 28, ESP-IDF example 102, Arduino example 54 s, plus the Pico example) |
| `publish-gate-rest` | 306 | static 0, crates-token 0, registry 1, vcpkg 25, go 12, **swift 215**, manifest 0, npm 9, position 1, workflow 37 |
| `publish-gate-phases` | 278 | image pull 90, phases 182 |
| `suites (swift, tests)` | 278 | resolve 4, strict release build 64, debug test build 63, tests 28, list 2, fuzz 69 |
| `ring` | 271 | driver builds 101, toolchain versions 41, ring 48 |
| `publish-gate-readonly-gate` | 242 | readonly-gate 139, pins 15, pull about 85 |
| `publish-gate-readonly` | 181 | pull 89, gate 69, readonly 18 |
| `suites (go)` | 158 | vet 10, test -race 45, fuzz 77 |
| `publish-gate-readonly-full` | 130 | readonly-full 32, pull and checkout about 98 |
| other suites | 25 to 70 | python 47, csharp 36, rust 32, cpp 31, typescript 16, java 9 |

The old `readonly` group was 247 s; split in three it is 18 + 139 + 32 s. The image pull (85 to 90 s) now costs more than the group in two of the three jobs. Finding: with the suites and the gate regrouped the floor of the wall is `embedded` (317, 337 and 360 s on three runs), so the target of 360 s as the median needs the embedded job split (C4) as well; the loop 31 intake had left C4 out because embedded was not the long pole before this regrouping.

## CI run of batch 2 + C4 (run 39014663944, `0fc35f8`, `dev` push, 20 jobs, all green)

Wall 344 s (created 07:42:58, last job done 07:48:42), against 375 s for the batch 1 run and 418 / 382 s before loop 31 (median 400 s). Jobs by seconds, with what the notices show:

| Job | s | Notice |
|-----|--:|--------|
| `publish-gate-readonly-gate` | 341 | readonly-gate **200** (139 on the batch 1 run), pins 26, pull about 85 |
| `publish-gate-phases` | 285 | phases 222 (182 before), pull about 60 |
| `suites (swift, gates)` | 282 | resolve 3, strict release build 95, sanitizer build 97, list 3, sanitized run 49, deps 0 |
| `ring` | 265 | unchanged job |
| `suites (swift, tests)` | 249 | resolve 4, debug build 96, tests 35, list 2, fuzz 72 |
| `suites (swift, speed)` | 227 | resolve 4, `swift_speed` 187 (the real `swift test list -c release --skip-build` is accepted on CI) |
| `embedded-esp-core` | 209 | esp32s3 27, esp32c3 24, Arduino-ESP32 example 71; total 202 s, so about 80 s of image pull and setup |
| `publish-gate-rest` | 192 | readonly-full 38, vcpkg 24, workflow 38, npm 11, go 12, the rest 0 to 1; pull about 65 |
| `publish-gate-readonly` | 169 | gate 68, readonly 18, pull about 80 |
| `embedded-esp-packages` | 157 | ESP-IDF example 66, Pico example 35; total 153 s |
| `publish-gate-swift` | 157 | swift 153 (215 on the batch 1 run: the same code varies by 1.4x) |
| `suites (go)` | 156 | vet 10, test -race 45, fuzz 77 |
| other | 29 to 91 | csharp 91 (72), python 73 (50), scaffold 68, rust 57, cpp 54, `embedded-arm` 52 (49: four targets 1 to 4 s, so the arm job is the image build), typescript 42, java 29 |

What the numbers say:
- C4 worked: the old 360 s `embedded` job is 209 / 157 / 52 s. Nothing in the wall is embedded any more.
- The wall is now `publish-gate-readonly-gate`: the three real gate runs inside `ro_gate_checks` run at the same time on the runner and their sum varies (139 to 200 s on two runs). Next cuts, if the owner wants them: `ro_gate_checks` as three jobs (good, bad, nojava; each gate run about 70 s plus the pull), `pins` (26 s) out of that job, `phases` (222 s) in two groups (success scenarios, failure scenarios; each pays the setup).
- Swift: the three parts are 282, 249, 227 s; `gates` is still the longest (two builds, 95 + 97 s).
- Jobs per push: 20 (the free plan runs 20 at the same time); a `dev` + `main` push would be 40.
- AC-1 needs two runs: this is the first (344 s); the second is the close push of `dev` (same code, docs only).
