#pragma once

// Shared by the parity percentage host tests: the test row and scheme, the reference rule written
// again in plain integers, and seeded messages and corruption.
#include "packbin/codec.hpp"

#include "ecc_support_host.hpp"

#include <cstdint>
#include <cstring>
#include <vector>

namespace ecc_percent {

using ecc_test::Bytes;
using ecc_test::Rng;


namespace pd = packbin::detail;

struct Msg {
  std::uint16_t n = 0;
  packbin::Blob<260> payload;
};

template <int Type>
constexpr auto msg_scheme() {
  return packbin::scheme<Msg>(Type, packbin::u16<&Msg::n>(0), packbin::sized<&Msg::payload>(1, 0));
}

constexpr auto base = msg_scheme<0x40>();

// The clear message of the scheme: type byte, u16 count, then the payload.
constexpr std::size_t kHead = 3;

// The reference rule, in plain integers.
inline int ref_count(int p, int len) {
  int n = (p * len + 99) / 100;
  return n > 32 ? 32 : n;
}

inline int ref_largest(int p) {
  if (p == 0)
    return 254;
  int len = 0;
  while (len + 1 + ref_count(p, len + 1) <= 254)
    ++len;
  return len;
}

// The clear length whose message is `sent` bytes, or -1.
inline int ref_clear(int p, int sent) {
  if (p == 0)
    return sent;
  for (int len = 0; len <= sent && len <= 254; ++len)
    if (len + ref_count(p, len) == sent)
      return len;
  return -1;
}

inline int setting_of(int p) { return p == 0 ? 0 : pd::kPercentBase + p; }

inline Msg msg_of_length(std::size_t clear, Rng& rng) {
  Msg m;
  std::size_t k = clear - kHead;
  m.n = static_cast<std::uint16_t>(k);
  m.payload.len = static_cast<std::uint16_t>(k);
  for (std::size_t i = 0; i < k; ++i)
    m.payload.data[i] = rng.byte();
  return m;
}

inline bool same_msg(Msg const& a, Msg const& b) {
  return a.n == b.n && a.payload.len == b.payload.len &&
         std::memcmp(a.payload.data, b.payload.data, a.payload.len) == 0;
}

template <typename S>
inline Bytes protect_msg(S const& s, Msg const& m) {
  std::uint8_t out[400];
  auto r = packbin::pack(s, m, out, sizeof(out));
  return Bytes(out, out + r.offset);
}

// A copy of `packed` with `count` seeded positions xor-ed with a nonzero byte.
inline Bytes corrupt(Bytes packed, int count, Rng& rng) {
  std::vector<bool> hit(packed.size(), false);
  for (int done = 0; done < count;) {
    std::size_t at = rng.below(packed.size());
    if (hit[at])
      continue;
    hit[at] = true;
    packed[at] = static_cast<std::uint8_t>(packed[at] ^ (1 + rng.below(255)));
    ++done;
  }
  return packed;
}

}  // namespace ecc_percent
