#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>

namespace check {

inline int& failures() {
  static int n = 0;
  return n;
}

inline void expect(bool ok, char const* msg) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", msg);
    ++failures();
  }
}

inline std::size_t parse_hex(char const* hex, std::uint8_t* out, std::size_t cap) {
  auto nibble = [](char c) -> int {
    if (c >= '0' && c <= '9')
      return c - '0';
    if (c >= 'a' && c <= 'f')
      return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
      return c - 'A' + 10;
    return -1;
  };
  std::size_t n = 0;
  while (hex[0] && hex[1] && n < cap) {
    int hi = nibble(hex[0]);
    int lo = nibble(hex[1]);
    if (hi < 0 || lo < 0)
      break;
    out[n++] = static_cast<std::uint8_t>((hi << 4) | lo);
    hex += 2;
  }
  return n;
}

inline bool same_hex(std::uint8_t const* data, std::size_t len, char const* hex) {
  std::uint8_t want[512];
  std::size_t n = parse_hex(hex, want, sizeof(want));
  return n == len && (len == 0 || std::memcmp(data, want, len) == 0);
}

}  // namespace check
