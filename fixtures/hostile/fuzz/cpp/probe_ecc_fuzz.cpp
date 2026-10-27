// AZ-2666 audit probe, mode ecc-fuzz: random and mutated protected messages through ecc::check,
// ecc::repair and the API (single scheme and on(...)) (see audit41_probe.cpp).

#include "probe_common.hpp"

namespace probe {

namespace {

int pick_n(Rng& r) {
  static int const common[] = {1, 2, 3, 4, 8, 16, 31, 32, 32, 32};
  return r.chance(60) ? common[r.below(10)] : 1 + static_cast<int>(r.below(32));
}

std::size_t pick_len(Rng& r, int n) {
  switch (r.below(8)) {
    case 0:
      return static_cast<std::size_t>(n) - 1;
    case 1:
      return static_cast<std::size_t>(n);
    case 2:
      return 254;
    case 3:
      return 255 + r.below(3);
    default:
      return static_cast<std::size_t>(n) + r.below(255 - static_cast<std::size_t>(n));
  }
}

struct EccSeeds {
  std::vector<std::pair<int, Bytes>> received;  // (n, received) of fix/bad rows
};

EccSeeds load_ecc_seeds(std::string const& fix) {
  EccSeeds s;
  for (auto const& r : rows(fix + "/ecc/vectors.txt")) {
    if ((r[0] == "fix" || r[0] == "bad") && r.size() >= 5)
      s.received.emplace_back(std::stoi(r[2]), hex(r[4]));
  }
  return s;
}

std::size_t differing(Bytes const& a, std::uint8_t const* b) {
  std::size_t d = 0;
  for (std::size_t i = 0; i < a.size(); ++i)
    d += a[i] != b[i];
  return d;
}

}  // namespace

int ecc_fuzz(std::string const& fix, std::uint64_t seed, double budget) {
  EccSeeds seeds = load_ecc_seeds(fix);
  Rng r(seed);
  std::size_t calls = 0, repaired_ok = 0, intact = 0, refused = 0, miscorrected = 0;
  std::size_t kinds[6] = {};
  Slowest slow;
  auto t0 = Clock::now();
  while (seconds_since(t0) < budget) {
    for (int burst = 0; burst < 64; ++burst) {
      int n = pick_n(r);
      int t = r.chance(70) ? n / 2 : static_cast<int>(r.below(static_cast<std::size_t>(n / 2) + 1));
      Bytes word, received;
      std::size_t errors = 0;
      unsigned src = static_cast<unsigned>(r.below(10));
      if (src < 5) {
        std::size_t len = pick_len(r, n);
        Bytes clear(len >= static_cast<std::size_t>(n) && len <= 254 ? len - n : 0);
        for (auto& c : clear)
          c = r.byte();
        word = protect_clear(clear, n);
        received = word;
        std::size_t k = r.below(4) == 0 ? r.below(static_cast<std::size_t>(n) + 2)
                                        : static_cast<std::size_t>(t) + r.below(3) - (t > 0);
        for (std::size_t e = 0; e < k && !received.empty(); ++e) {
          std::size_t at = r.below(received.size());
          std::uint8_t x = static_cast<std::uint8_t>(1 + r.below(255));
          received[at] ^= x;
        }
        errors = differing(word, received.data());
      } else if (src < 7 && !seeds.received.empty()) {
        auto const& s = seeds.received[r.below(seeds.received.size())];
        n = s.first;
        t = r.chance(70) ? n / 2 : static_cast<int>(r.below(static_cast<std::size_t>(n / 2) + 1));
        received = s.second;
        mutate(r, received);
      } else {
        received.resize(pick_len(r, n));
        unsigned style = static_cast<unsigned>(r.below(3));
        for (auto& b : received)
          b = style == 0 ? r.byte() : style == 1 ? 0xFF : 0x00;
        if (!received.empty() && style != 0)
          received[r.below(received.size())] = r.byte();
      }
      // Detect only: never writes.
      {
        Exact in(received);
        ecc::Outcome c = ecc::check(in.data(), in.n, n);
        if (in.n != 0 && std::memcmp(in.data(), received.data(), in.n) != 0)
          fail_note("check_wrote", received);
        (void)c;
      }
      // Repair in place.
      Exact in(received);
      auto ta = Clock::now();
      ecc::Outcome o = ecc::repair(in.data(), in.n, n, t);
      slow.see(seconds_since(ta), received);
      ++calls;
      ++kinds[static_cast<int>(o.kind)];
      if (!o.ok()) {
        ++refused;
        if (in.n != 0 && std::memcmp(in.data(), received.data(), in.n) != 0)
          fail_note("refused_repair_wrote", received);
        if (!word.empty() && errors <= static_cast<std::size_t>(t) && received.size() <= 254 &&
            received.size() >= static_cast<std::size_t>(n))
          fail_note("correctable_refused", received);
      } else {
        std::size_t d = differing(received, in.data());
        if (d != o.repaired || o.repaired > t)
          fail_note("repaired_count", received);
        if (ecc::check(in.data(), in.n, n).kind != ecc::Kind::Ok)
          fail_note("repair_not_codeword", received);
        if (o.repaired == 0)
          ++intact;
        else
          ++repaired_ok;
        if (!word.empty() && std::memcmp(in.data(), word.data(), word.size()) != 0) {
          ++miscorrected;
          if (errors <= static_cast<std::size_t>(n - t))
            fail_note("miscorrected_within_detection", received);
        }
      }
      // Through the API: single scheme (detect and repair) and the dispatcher.
      {
        auto sa40 = packbin::parity(ebase40, n);
        auto sa41 = packbin::parity(ebase41, n);
        ERow row40, row41;
        Exact p1(received);
        packbin::Result u = packbin::unpack(sa40, p1.data(), p1.n, row40);
        if (p1.n != 0 && std::memcmp(p1.data(), received.data(), p1.n) != 0)
          fail_note("api_unpack_wrote", received);
        Exact p2(received);
        packbin::Result ur = packbin::unpack_repair(sa40, p2.data(), p2.n, row40, t);
        if (ur.error == Error::Uncorrectable && p2.n != 0 &&
            std::memcmp(p2.data(), received.data(), p2.n) != 0)
          fail_note("api_refused_wrote", received);
        Exact p3(received);
        auto none = [](auto&) {};
        packbin::Result ud = packbin::unpack_repair(p3.data(), p3.n, t, packbin::on(sa40, row40, none),
                                                    packbin::on(sa41, row41, none));
        (void)u;
        (void)ud;
      }
    }
  }
  std::printf("mode=ecc-fuzz seed=%llu seconds=%.1f\n", static_cast<unsigned long long>(seed),
              seconds_since(t0));
  std::printf("repair_calls=%zu intact=%zu repaired=%zu refused=%zu miscorrected_beyond_n_minus_t=%zu\n",
              calls, intact, repaired_ok, refused, miscorrected);
  std::printf("kinds ok=%zu uncorrectable=%zu short=%zu too_long=%zu bad_parity=%zu bad_limit=%zu\n",
              kinds[0], kinds[1], kinds[2], kinds[3], kinds[4], kinds[5]);
  std::printf("slowest_repair_us=%.1f (input %zu B)\n", slow.t * 1e6, slow.input.size());
  std::printf("peak_rss_kb=%ld failures=%d\nresult=%s\n", peak_rss_kb(), g_fail,
              g_fail == 0 ? "PASS" : "FAIL");
  return g_fail == 0 ? 0 : 1;
}

}  // namespace probe
