#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

// What the parts of the C++ ring driver share (handoff.cpp, handoff_ecc.cpp, handoff_frame.cpp).

constexpr std::size_t kMax = 512;

inline std::string hex_of(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  return out;
}

// The ecc-* and frame-* commands (argv[1]); each returns the exit status.
int ecc_main(int argc, char** argv);
int frame_main(int argc, char** argv);
