#pragma once

// Message error correction on a target (AZ-2688, EC-12): the position fixture packed under 4
// parity bytes must equal the vector bytes of the results report (row 4), and two wrong bytes
// must be repaired in place. Built for the ESP-IDF targets, which are build-only; the same
// checks run on QEMU Cortex-M3 and big-endian s390x in tests/core/ecc_api_tests.cpp.

#include <cstddef>
#include <cstdint>

namespace ecc_probe {

// Packs the fixture with 4 parity bytes into `out` (cap >= 17); returns the packet length, 0
// when the pack failed.
std::size_t pack_position(std::uint8_t* out, std::size_t cap);

// 0 when the packed bytes equal the vector and two wrong bytes are repaired back to the row;
// otherwise the number of failed checks.
int failed_checks();

}  // namespace ecc_probe
