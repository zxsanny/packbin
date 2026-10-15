# Swift peak memory of the max-slots unpack (loop 28, AZ-2567)

**Verdict**: no finding; the highest Swift figure is 731 MB (macOS) and 738 MB (Linux), below the 1 000 MB line (AC-2), and 1.17 times the Go figure for the F10 packet.

## Cases

- **F10**: the loop 21 worst packet, `list "items" of group { u8 n; times(n) { 64 u8 names } }`, 65 535 items, every byte 1, with `maxSlots` raised to 4 194 304 (the default refuses it). Same as `go/mem_test.go` `TestMemF10PeakAtRaisedMaxSlots` and `f10()` in Go and in `swift/Tests/PackbinTests/LimitHelpers.swift`.
- **Wide round**: `u32 n; times(n) { 65 u8 members }` with n = 16 128 (the Go `wideRoundNearOneMiB`, 1 048 576 slots minus 256), default limits. The Swift driver builds the packet with `pack`.
- API mapping: `Scheme(1, ...)`, `Field.list/.group/.times/.u8/.u32`, `withLimits(maxSlots:)`, `unpackMap`; no difference from the Go shape.

## Method

Throwaway driver `memdrv` (executable target in a copy of the package: `Package.swift` plus `swift/Sources/Packbin`, in the scratchpad `swift-mem/pkg`; the repository tree and `.build` were not touched). Built with `swift build -c release --scratch-path <scratchpad>/swift-mem/build`. The packet is written to a file once (`memdrv gen`), then each measured process reads the file and does one `unpackMap` (`memdrv run`), so the figure is the unpack plus process baseline, not the pack. Baseline: `memdrv base` (read the 4.26 MB file, build the scheme, no unpack) = 14.3 MB on macOS.

Go's figure is `runtime.MemStats.HeapAlloc` peak in MiB (`go/mem_test.go`, 500 us sampling), not resident set size, so the Go column is the same order but not the same counter. 1 MB below is 1 048 576 bytes (macOS bytes and Linux KiB converted).

## Figures

| Case | Packet bytes | Host | Command | Max resident MB, run 1 / 2 / 3 | min / median / max MB | Go figure |
|------|-------------:|------|---------|-------------------------------|-----------------------|-----------|
| F10, `maxSlots` 4 194 304 | 4 259 778 | macOS 26 (Darwin 25.6.0, arm64), release | `/usr/bin/time -l memdrv run f10 f10.bin` | 731.3 / 702.8 / 731.3 | 702.8 / 731.3 / 731.3 | 625 |
| Wide round, defaults | 1 048 325 | macOS, release | `/usr/bin/time -l memdrv run wide wide.bin` | 153.3 / 153.7 / 153.6 | 153.3 / 153.6 / 153.7 | 94 |
| F10, `maxSlots` 4 194 304 | 4 259 778 | `swift:6.3.3` container (aarch64, Docker Desktop VM, 7.8 GB), release | `/usr/bin/time -v memdrv run f10 f10-linux.bin` | 737.9 / 737.9 / 737.9 | 737.9 / 737.9 / 737.9 | 625 |
| Wide round, defaults | 1 048 325 | `swift:6.3.3` container, release | `/usr/bin/time -v memdrv run wide wide-linux.bin` | 146.9 / 147.0 / 147.0 | 146.9 / 147.0 / 147.0 | 94 |

Unpack time: F10 1.5 to 2.4 s on macOS (loaded host), 2.7 to 2.9 s in the container; wide round 0.25 s and 0.55 s. Each run checked the result (65 535 items; `m64` of 16 128 values) and exited 0.

## Host state

macOS: load average 7.9 to 13 (shared, loaded), swap 2 959 of 4 096 MB used before and after the runs, 4 800 free 16 KiB pages at the start. Peak resident is not changed by load and no run swapped out visibly (run times 1.5 to 2.4 s). The spread of the macOS F10 runs (703 to 731 MB) is the allocator and page-compression state of the shared host; the Linux figures were stable to 4 KiB. The container run was one Docker Desktop VM with `time` installed by `apt-get` and the dependency fetched by `swift build`; no container baseline process was measured.

## Reading

- F10 at the raised limit costs about 180 B per slot in Swift on macOS (731 MB less 14 MB over 4.19 million slots), in the 120 to 230 B per slot range the loop 22 table gives for the other packages; the wide round at defaults is about 150 MB, which is why the default `maxSlots` of 1 048 576 holds it near that.
- Swift is 17 % above the Go F10 figure and 63 % above the Go wide-round figure, partly because the Go figure is heap allocation, not resident size.
- No bound was added and nothing was fixed; a permanent bounded test is out of scope for this task.
