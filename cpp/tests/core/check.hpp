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

// Every distinct `expect(` call site that ran (file base name + line). The firmware runner
// compares the count per file with the `expect(` calls in that file: vectors run == asserted.
struct Site {
  char const* file;
  int line;
};

constexpr int kMaxSites = 1024;

inline Site* sites() {
  static Site s[kMaxSites];
  return s;
}

inline int& site_count() {
  static int n = 0;
  return n;
}

inline char const* base_name(char const* path) {
  char const* base = path;
  for (char const* p = path; *p != '\0'; ++p)
    if (*p == '/' || *p == '\\')
      base = p + 1;
  return base;
}

inline void note_site(char const* file, int line) {
  char const* base = base_name(file);
  for (int i = 0; i < site_count(); ++i)
    if (sites()[i].line == line && std::strcmp(sites()[i].file, base) == 0)
      return;
  if (site_count() < kMaxSites)
    sites()[site_count()++] = Site{base, line};
}

// Distinct call sites run in `file` (a base name such as "scalar_tests.cpp").
inline int sites_run(char const* file) {
  int n = 0;
  for (int i = 0; i < site_count(); ++i)
    if (std::strcmp(sites()[i].file, file) == 0)
      ++n;
  return n;
}

inline void expect(bool ok, char const* msg, char const* file = __builtin_FILE(),
                   int line = __builtin_LINE()) {
  note_site(file, line);
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
