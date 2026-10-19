#pragma once

// Shared helpers, rows and schemes of the AZ-2666 loop 41 audit probe; the build and the modes are
// described in audit41_probe.cpp. Every mode lives in a file of its own:
//   probe_text_fuzz.cpp   text-fuzz          probe_ecc_fuzz.cpp   ecc-fuzz (plain and session)
//   probe_edge.cpp        edge               probe_timing.cpp     ecc-worst, text-amp, text-long, dict-quad

#include "packbin/codec.hpp"
#include "packbin/session.hpp"
#include "text.hpp"

#include <sys/resource.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::Packed;
using packbin::PackSession;
using packbin::Text;
namespace txt = packbin::detail::txt;
namespace ecc = packbin::ecc;
using Bytes = std::vector<std::uint8_t>;
using Clock = std::chrono::steady_clock;

namespace probe {

// Failed expectations of the running mode.
inline int g_fail = 0;

inline void fail_note(char const* what, Bytes const& input) {
  ++g_fail;
  if (g_fail > 20)
    return;
  std::printf("FAIL %s input=", what);
  for (auto b : input)
    std::printf("%02x", b);
  std::printf("\n");
}

struct Rng {
  std::uint64_t s;
  explicit Rng(std::uint64_t seed) : s(seed * 0x9E3779B97F4A7C15ull + 1) {}
  std::uint64_t next() {
    s ^= s >> 12;
    s ^= s << 25;
    s ^= s >> 27;
    return s * 2685821657736338717ull;
  }
  std::size_t below(std::size_t n) { return n == 0 ? 0 : static_cast<std::size_t>(next() % n); }
  std::uint8_t byte() { return static_cast<std::uint8_t>(next() >> 24); }
  bool chance(unsigned pct) { return below(100) < pct; }
};

inline double seconds_since(Clock::time_point t0) {
  return std::chrono::duration<double>(Clock::now() - t0).count();
}

inline long peak_rss_kb() {
  struct rusage u;
  getrusage(RUSAGE_SELF, &u);
#ifdef __APPLE__
  return u.ru_maxrss / 1024;  // bytes on macOS
#else
  return u.ru_maxrss;  // KiB on Linux
#endif
}

inline Bytes hex(std::string const& h) {
  Bytes out;
  if (h == "-")
    return out;
  for (std::size_t i = 0; i + 1 < h.size(); i += 2)
    out.push_back(static_cast<std::uint8_t>(std::stoul(h.substr(i, 2), nullptr, 16)));
  return out;
}

inline std::vector<std::vector<std::string>> rows(std::string const& path) {
  std::vector<std::vector<std::string>> out;
  std::ifstream in(path);
  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#')
      continue;
    std::istringstream ss(line);
    std::vector<std::string> cols;
    std::string c;
    while (ss >> c)
      cols.push_back(c);
    out.push_back(cols);
  }
  return out;
}

// A heap copy of exactly `b.size()` bytes (at least one allocation so data() is never reused).
struct Exact {
  std::uint8_t* p;
  std::size_t n;
  explicit Exact(Bytes const& b) : p(new std::uint8_t[b.empty() ? 1 : b.size()]), n(b.size()) {
    if (!b.empty())
      std::memcpy(p, b.data(), b.size());
    if (b.empty())
      p[0] = 0xA5;
  }
  ~Exact() { delete[] p; }
  Exact(Exact const&) = delete;
  Exact& operator=(Exact const&) = delete;
  // For an empty input, hand out a pointer one past a 1-byte block shifted so any read faults.
  std::uint8_t* data() { return n == 0 ? p + 1 : p; }
};

inline void put_varint(Bytes& out, std::size_t n) {
  while (n >= 128) {
    out.push_back(static_cast<std::uint8_t>(n | 0x80));
    n >>= 7;
  }
  out.push_back(static_cast<std::uint8_t>(n));
}

inline void mutate(Rng& r, Bytes& b) {
  unsigned k = 1 + static_cast<unsigned>(r.below(6));
  for (unsigned i = 0; i < k; ++i) {
    switch (r.below(8)) {
      case 0:
        if (!b.empty())
          b[r.below(b.size())] ^= static_cast<std::uint8_t>(1u << r.below(8));
        break;
      case 1:
        if (!b.empty())
          b[r.below(b.size())] = r.byte();
        break;
      case 2:
        b.insert(b.begin() + static_cast<long>(r.below(b.size() + 1)), r.byte());
        break;
      case 3:
        if (!b.empty())
          b.erase(b.begin() + static_cast<long>(r.below(b.size())));
        break;
      case 4:
        b.resize(r.below(b.size() + 1));
        break;
      case 5:
        for (std::size_t j = r.below(16); j > 0; --j)
          b.push_back(r.chance(50) ? 0xFF : r.byte());
        break;
      case 6:
        if (!b.empty())
          b[r.below(b.size())] = static_cast<std::uint8_t>(r.chance(50) ? 0x00 : 0xFF);
        break;
      default:
        if (b.size() > 1)
          b[1] = r.byte();  // the header byte of a 1-byte-count field
        break;
    }
  }
}

struct Slowest {
  double t = 0;
  Bytes input;
  void see(double dt, Bytes const& in) {
    if (dt > t) {
      t = dt;
      input = in;
    }
  }
};

struct Stats {
  std::vector<double> t;
  void add(double x) { t.push_back(x); }
  void print(char const* name) {
    std::sort(t.begin(), t.end());
    std::printf("%s calls=%zu min_us=%.2f median_us=%.2f p99_us=%.2f max_us=%.2f\n", name, t.size(),
                t.front() * 1e6, t[t.size() / 2] * 1e6, t[t.size() * 99 / 100] * 1e6,
                t.back() * 1e6);
  }
};

// ---------------------------------------------------------------- rows and schemes shared by the modes

struct R1 {
  Text<65535> s;
};
struct R2 {
  Packed p;
  std::uint8_t k = 0;
};
struct R3 {
  std::uint8_t unused = 0;
};
struct R4 {
  Array<Text<16>, 8> l;
};
struct R5 {
  Array<Entry<std::uint8_t, Text<32>>, 8> d;
};

inline constexpr auto s1 = packbin::scheme<R1>(1, packbin::utf8<&R1::s>(0));
inline constexpr auto s2 = packbin::scheme<R2>(2, packbin::utf8<&R2::p>(0), packbin::u8<&R2::k>(1));
inline constexpr auto s3 = packbin::scheme<R3>(3, packbin::utf8(0));
inline constexpr auto s4 = packbin::scheme<R4>(4, packbin::list<&R4::l>(packbin::utf8(0)));
inline constexpr auto s5 = packbin::scheme<R5>(5, packbin::dict<&R5::d>(packbin::u8(0)));
inline constexpr auto s6 = packbin::scheme<R3>(6, packbin::dict(packbin::u8(0)));

struct ERow {
  std::uint8_t a = 0;
  Text<64> s;
};

inline auto const ebase40 =
    packbin::scheme<ERow>(0x40, packbin::u8<&ERow::a>(0), packbin::utf8<&ERow::s>(1));
inline auto const ebase41 =
    packbin::scheme<ERow>(0x41, packbin::u8<&ERow::a>(0), packbin::utf8<&ERow::s>(1));

inline Bytes protect_clear(Bytes const& clear, int n) {
  Bytes out = clear;
  out.resize(clear.size() + static_cast<std::size_t>(n));
  ecc::Kind k = ecc::protect(clear.data(), clear.size(), n, out.data() + clear.size());
  if (k != ecc::Kind::Ok)
    out.clear();
  return out;
}

inline void open_pair(PackSession& a, PackSession& b) {
  std::uint8_t seed[32];
  for (int i = 0; i < 32; ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  std::uint8_t nonce[16] = {1};
  a.load(seed, 32);
  b.load(seed, 32);
  a.start(nonce, 16);
  b.join(nonce, 16);
}

// ---------------------------------------------------------------- the modes

int text_fuzz(std::string const& fix, std::uint64_t seed, double budget);
int ecc_fuzz(std::string const& fix, std::uint64_t seed, double budget);
int edge(std::string const& fix);
int ecc_worst(std::size_t iters);
int text_amp();
int text_long();
int dict_quad(std::size_t entries);

}  // namespace probe
