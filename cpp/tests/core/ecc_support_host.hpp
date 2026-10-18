#pragma once

// Shared by the message ECC host tests: hex, a seeded generator and the position fixture.
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace ecc_test {

using Bytes = std::vector<std::uint8_t>;

// The 13-byte position fixture of the results report (rows 2 to 6).
inline char const* const kPositionHex = "4001000065cd1d00a3e1110100";

inline int nibble(char c) { return c <= '9' ? c - '0' : c - 'a' + 10; }

// "-" is the empty buffer.
inline Bytes from_hex(std::string const& hex) {
  Bytes out;
  if (hex == "-")
    return out;
  for (std::size_t i = 0; i + 1 < hex.size(); i += 2)
    out.push_back(static_cast<std::uint8_t>(nibble(hex[i]) * 16 + nibble(hex[i + 1])));
  return out;
}

// splitmix64: the same stream on every host, so a failing case can be rerun.
class Rng {
 public:
  explicit Rng(std::uint64_t seed) : state_(seed) {}

  std::uint64_t next() {
    std::uint64_t z = (state_ += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
  }

  // 0 .. bound - 1.
  std::size_t below(std::size_t bound) { return static_cast<std::size_t>(next() % bound); }

  std::uint8_t byte() { return static_cast<std::uint8_t>(next() >> 56); }

 private:
  std::uint64_t state_;
};

}  // namespace ecc_test
