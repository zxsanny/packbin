#pragma once

// Load-aware wall-clock bounds for the host tests (AZ-2723). A host that other work loads makes a fixed
// bound fail, so a bound is its nominal seconds times the load factor: how many times slower than an
// idle host a fixed integer loop runs right now, in this process, never below 1 and never above 8. The
// nominal bound and the work stay as the spec fixed them; a real slowdown of the timed code still fails,
// because the reference loop does not change with it. Host tests only: the firmware runner does not
// build this header, and it is used from the main thread alone.

#include "check.hpp"

#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>

namespace load_factor {

// The smallest of 40 runs of reference_loop() on the owner's Mac (Apple M-series, 10 cores, Apple clang
// -O2): other work and preemption only add time, so the smallest run is the idle one.
constexpr double kReferenceSeconds = 0.0300;
constexpr double kMaxFactor = 8.0;
constexpr std::uint64_t kIterations = 15000000;

using Clock = std::chrono::steady_clock;

inline volatile std::uint64_t sink = 0;

// Integer work the optimizer cannot remove or fold: a xorshift chain seeded from the clock, its sum
// stored in a volatile.
inline double reference_loop() {
  auto start = Clock::now();
  std::uint64_t x = static_cast<std::uint64_t>(start.time_since_epoch().count()) | 1u;
  std::uint64_t sum = 0;
  for (std::uint64_t i = 0; i < kIterations; ++i) {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    sum += x;
  }
  sink = sum;
  return std::chrono::duration<double>(Clock::now() - start).count();
}

// The seconds the fastest of three reference loops takes now.
inline double reference_seconds() {
  double best = reference_loop();
  best = std::min(best, reference_loop());
  return std::min(best, reference_loop());
}

// The load factor, measured now. A caller that times many short calls passes `max_age` (seconds) to
// reuse a factor measured that recently; the default measures anew, right before the timed section.
inline double factor(double max_age = 0) {
  static double cached = 1.0;
  static Clock::time_point measured_at{};
  if (measured_at != Clock::time_point{} &&
      std::chrono::duration<double>(Clock::now() - measured_at).count() <= max_age)
    return cached;
  cached = std::min(kMaxFactor, std::max(1.0, reference_seconds() / kReferenceSeconds));
  measured_at = Clock::now();
  return cached;
}

// A wall-clock bound: `nominal` seconds times the load factor taken when the bound was made.
struct Bound {
  double nominal;
  double factor;

  double seconds() const { return nominal * factor; }
  bool holds(double elapsed) const { return elapsed <= seconds(); }
};

// The bound with the larger of its factor and a factor taken now: after the timed section the load may
// have risen, and the reference loop before it may have caught a quiet slice.
inline Bound recheck(Bound const& limit) { return Bound{limit.nominal, std::max(limit.factor, factor())}; }

// The bound for `nominal` seconds: call it right before the timed section.
inline Bound bound(double nominal, double max_age = 0) { return Bound{nominal, factor(max_age)}; }

// Asserts `elapsed` is within `limit`; the failure text names the nominal bound, the factor and the
// elapsed time.
inline void expect_within(double elapsed, Bound limit, char const* what,
                          char const* file = __builtin_FILE(), int line = __builtin_LINE()) {
  if (!limit.holds(elapsed))
    limit = recheck(limit);
  char msg[256];
  std::snprintf(msg, sizeof(msg), "%.100s: took %.3f s, bound %.3f s (nominal %.3f s x load factor %.2f)",
                what, elapsed, limit.seconds(), limit.nominal, limit.factor);
  check::expect(limit.holds(elapsed), msg, file, line);
}

}  // namespace load_factor
