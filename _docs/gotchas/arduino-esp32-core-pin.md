---
title: "The Arduino-ESP32 core of the ESP core stage is the arduino-esp32 line of tool-pins.txt: move it there, then run the stage"
applies_when: "a new Arduino-ESP32 release is wanted, the cpp-example-esp32-arduino row fails on the core version, or the ESP core stage got slow or changed with no repository change"
source: "loop 113 (AZ-4219: the newest core, 3.3.12, installed unpinned, 525 s), loop 121 (AZ-4261: pinned)"
---

The Arduino-ESP32 core of `cpp/embedded/examples.sh` (`arduino_esp32_core`, the row `cpp-example-esp32-arduino` of `bash cpp/embedded/run.sh host esp core` and of CI job `embedded-esp-core`) is installed as `esp32:esp32@<pin>`, where the pin is the one `arduino-esp32==<version>` line of `.github/workflows/tool-pins.txt` (3.3.12, pinned 2026-11-13). Before loop 121 the newest core was installed on every cold run, so a release changed the build and its time (525 s on 2026-11-12) with no change here.

The row prints `Arduino-ESP32 core <version> (pin <version>)` and fails when the installed core differs from the pin (a cache that holds another version, or an install that did not take).

To move the pin:

1. Edit that one line (and nothing else: the Mac run and CI both read it through `.github/workflows/tool-pin.sh arduino-esp32`).
2. Run `bash cpp/embedded/run.sh host esp core` on the Mac (about 3 minutes warm, 525 s cold; the core is cached in `.cache/embedded/arduino-data`, so a new pin downloads once), then wait for a green `embedded-esp-core`.
3. Keep the source count of `esp.sh` (`expected N packbin sources`) as it is: the pin does not touch it.

The pins file is checked by `publish-pins.test.sh` (`PINS_NAMES` there lists every pinned tool: a new line needs its name added).
