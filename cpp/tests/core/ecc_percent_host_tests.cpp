// Parity percentage (contract message-ecc.md 1.1.0, AZ-3507): the setting on the scheme, the count
// and the bytes of pack, the largest clear message, unpack finding the count from the received
// length, repair with the count of that message, the correction limit and the dispatch rule. The
// reference rule is written again in plain integers (ecc_percent_support_host.hpp).
#include "packbin/codec.hpp"

#include "check.hpp"
#include "ecc_percent_support_host.hpp"
#include "ecc_support_host.hpp"

#include "load_factor.hpp"

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

using check::expect;
using ecc_percent::base;
using ecc_percent::corrupt;
using ecc_percent::msg_of_length;
using ecc_percent::Msg;
using ecc_percent::protect_msg;
using ecc_percent::ref_clear;
using ecc_percent::ref_count;
using ecc_percent::ref_largest;
using ecc_percent::same_msg;
using ecc_percent::setting_of;
using ecc_percent::msg_scheme;
using ecc_percent::kHead;
using ecc_test::Bytes;
using ecc_test::from_hex;
using ecc_test::Rng;
using packbin::Error;

namespace {

namespace pd = packbin::detail;

// AC-1: the setting.
void setting() {
  auto s25 = packbin::parity_percent(base, 25);
  expect(s25.status.ok() && s25.parity_percent == 25 && s25.parity == 0, "AC-1 percentage 25");
  expect(packbin::parity_percent(base, 0).parity_percent == 0, "AC-1 percentage 0");
  expect(packbin::parity_percent(base, 100).status.ok(), "AC-1 percentage 100");
  for (int bad : {101, -1, 255, 1000}) {
    auto s = packbin::parity_percent(base, bad);
    expect(s.status.error == Error::SchemeInvalid && s.status.needed == 100 &&
               s.parity_percent == 0 && s.parity == 0,
           "AC-1 a percentage outside 0..100 is SchemeInvalid naming 100");
  }
  auto kept = packbin::parity_percent(packbin::parity_percent(base, 200), 25);
  expect(kept.status.error == Error::SchemeInvalid, "AC-1 an invalid scheme keeps its error");

  auto count_then_percent = packbin::parity_percent(packbin::parity(base, 4), 25);
  expect(count_then_percent.parity == 0 && count_then_percent.parity_percent == 25 &&
             count_then_percent.status.ok(),
         "AC-1 a percentage replaces a count");
  auto percent_then_count = packbin::parity(packbin::parity_percent(base, 25), 4);
  expect(percent_then_count.parity == 4 && percent_then_count.parity_percent == 0 &&
             percent_then_count.status.ok(),
         "AC-1 a count replaces a percentage");
  auto percent_then_zero = packbin::parity(packbin::parity_percent(base, 25), 0);
  expect(percent_then_zero.parity == 0 && percent_then_zero.parity_percent == 0,
         "AC-1 count 0 replaces a percentage");
  auto count_then_zero = packbin::parity_percent(packbin::parity(base, 4), 0);
  expect(count_then_zero.parity == 0 && count_then_zero.parity_percent == 0,
         "AC-1 percentage 0 replaces a count");
}

// AC-2, AC-3: count, bytes, and the largest message.
void count_and_bytes() {
  Rng rng(0x5eed);
  for (int p : {0, 10, 25, 50, 100}) {
    for (std::size_t clear : {3u, 4u, 6u, 13u, 40u, 100u, 222u}) {
      Msg m = msg_of_length(clear, rng);
      std::uint8_t a[300];
      std::uint8_t b[300];
      auto sp = packbin::parity_percent(base, p);
      auto r = packbin::pack(sp, m, a, sizeof(a));
      int n = ref_count(p, static_cast<int>(clear));
      auto fixed = packbin::pack(packbin::parity(base, n), m, b, sizeof(b));
      expect(r.ok() && r.offset == clear + static_cast<std::size_t>(n) && fixed.ok() &&
                 fixed.offset == r.offset && std::memcmp(a, b, r.offset) == 0,
             "AC-2 the bytes are those of the fixed count of the table");
    }
  }
  expect(pd::percent_count(10, 13) == 2 && pd::percent_count(25, 13) == 4 &&
             pd::percent_count(50, 13) == 7 && pd::percent_count(100, 13) == 13,
         "AC-2 counts of 13 clear bytes");
  expect(pd::percent_count(100, 40) == 32 && pd::percent_count(100, 0) == 0,
         "AC-2 the cap of 32, and 0 clear bytes");

  for (int p : {1, 10, 25, 50, 100}) {
    int largest = ref_largest(p);
    Msg fits = msg_of_length(static_cast<std::size_t>(largest), rng);
    std::uint8_t out[400];
    auto sp = packbin::parity_percent(base, p);
    auto good = packbin::pack(sp, fits, out, sizeof(out));
    expect(good.ok() && good.offset <= 254, "AC-3 the largest clear message packs");
    Msg over = msg_of_length(static_cast<std::size_t>(largest) + 1, rng);
    std::memset(out, 0xaa, sizeof(out));
    auto bad = packbin::pack(sp, over, out, sizeof(out));
    bool zero = true;
    for (int i = 0; i <= largest; ++i)
      zero = zero && out[i] == 0;
    expect(bad.error == Error::TooLong && bad.offset == static_cast<std::size_t>(largest) + 1 &&
               bad.needed == static_cast<std::size_t>(largest) && zero,
           "AC-3 one byte above the largest is TooLong naming the length and the limit");
  }
  expect(ref_largest(1) == 251 && ref_largest(10) == 230 && ref_largest(25) == 222 &&
             ref_largest(50) == 222 && ref_largest(100) == 222,
         "AC-3 the largest clear lengths");
  // A message far above the limit names the limit of the percentage, not of its own count.
  Msg far = msg_of_length(260, rng);
  std::uint8_t out[400];
  auto r = packbin::pack(packbin::parity_percent(base, 10), far, out, sizeof(out));
  expect(r.error == Error::TooLong && r.needed == 230, "AC-3 260 clear bytes at 10 percent");
  // Percentage 0 has no 254-byte limit.
  auto z = packbin::pack(packbin::parity_percent(base, 0), far, out, sizeof(out));
  expect(z.ok() && z.offset == 260, "AC-3 percentage 0 has no limit");
}

// AC-4: every pair through the codec steps and the API, by the code and by the independent rule.
void round_trips() {
  Rng rng(0x97);
  int pairs = 0;
  auto started = std::chrono::steady_clock::now();
  auto limit = load_factor::bound(10.0);
  for (int p = 0; p <= 100; ++p) {
    auto sp = packbin::parity_percent(base, p);
    for (int len = 0; len <= ref_largest(p); ++len) {
      ++pairs;
      Bytes clear(static_cast<std::size_t>(len));
      for (auto& b : clear)
        b = rng.byte();
      std::uint8_t buf[400] = {};
      // An empty vector's data() may be null, and memcpy from null is undefined even for 0 bytes (UBSan, AZ-4278).
      if (!clear.empty())
        std::memcpy(buf, clear.data(), clear.size());
      int setting = setting_of(p);
      int n = -1;
      auto room = pd::parity_room(buf, sizeof(buf), clear.size(), setting, n);
      auto sealed = pd::seal(buf, clear.size(), n);
      int want = ref_count(p, len);
      bool bytes_ok = room.ok() && sealed.ok() && n == want &&
                      sealed.offset == clear.size() + static_cast<std::size_t>(want) &&
                      (clear.empty() || std::memcmp(buf, clear.data(), clear.size()) == 0);
      int found = -1;
      auto got = pd::received_parity(setting, sealed.offset, found);
      std::uint8_t repaired = 9;
      int n2 = -1;
      auto fixed = pd::repair_setting(buf, sealed.offset, setting, 0, repaired, n2);
      if (!(bytes_ok && got.ok() && found == want && fixed.ok() && repaired == 0 && n2 == want)) {
        std::printf("round trip failed at p %d len %d\n", p, len);
        expect(false, "AC-4 round trip at every (p, len)");
        return;
      }
      if (len >= static_cast<int>(kHead)) {
        Msg m = msg_of_length(static_cast<std::size_t>(len), rng);
        std::uint8_t out[400];
        auto packed = packbin::pack(sp, m, out, sizeof(out));
        Msg back;
        auto un = packbin::unpack(sp, out, packed.offset, back);
        auto rep = packbin::unpack_repair(sp, out, packed.offset, back, 0);
        if (!(packed.ok() && packed.offset == static_cast<std::size_t>(len + want) && un.ok() &&
              un.offset == packed.offset && un.repaired == 0 && same_msg(m, back) && rep.ok() &&
              rep.repaired == 0)) {
          std::printf("API round trip failed at p %d len %d\n", p, len);
          expect(false, "AC-4 API round trip at every (p, len)");
          return;
        }
      }
    }
  }
  expect(pairs == 22752, "AC-4 22,752 pairs");
  double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count();
  load_factor::expect_within(seconds, limit, "AC-4 22,752 round trips");
}

// AC-4: a received length that no clear length gives.
void impossible_lengths() {
  int none[5] = {};
  int index = 0;
  for (int p : {1, 10, 25, 50, 100}) {
    for (int sent = 0; sent <= 254; ++sent) {
      int want = ref_clear(p, sent);
      int n = -1;
      auto r = pd::received_parity(setting_of(p), static_cast<std::size_t>(sent), n);
      if (want < 0) {
        ++none[index];
        expect(r.error == Error::Uncorrectable && r.offset == 0 && r.field == -1,
               "AC-4 an impossible length is Uncorrectable with no field named");
      } else {
        expect(r.ok() && n == sent - want, "AC-4 the clear length of a possible length");
      }
    }
    ++index;
  }
  expect(none[0] == 3 && none[1] == 24 && none[2] == 32 && none[3] == 32 && none[4] == 32,
         "AC-4 3, 24, 32, 32 and 32 impossible lengths");
  for (int sent = 0; sent < 64; ++sent) {
    int n = -1;
    bool impossible = !pd::received_parity(setting_of(100), static_cast<std::size_t>(sent), n).ok();
    expect(impossible == ((sent & 1) == 1), "AC-4 at 100 percent every odd length below 64");
  }

  // Through the API: nothing is read, nothing is named, the buffer is not touched.
  Rng rng(7);
  auto s = packbin::parity_percent(base, 100);
  std::uint8_t data[300];
  for (auto& b : data)
    b = rng.byte();
  std::uint8_t copy[300];
  std::memcpy(copy, data, sizeof(data));
  Msg row;
  auto u = packbin::unpack(s, data, 5, row);
  expect(u.error == Error::Uncorrectable && u.offset == 0 && u.field == -1,
         "AC-4 unpack of 5 bytes");
  auto r = packbin::unpack_repair(s, data, 5, row, 2);
  expect(r.error == Error::Uncorrectable && std::memcmp(data, copy, sizeof(data)) == 0,
         "AC-4 unpack_repair of 5 bytes");
  auto s25 = packbin::parity_percent(base, 25);
  auto big = packbin::unpack(s25, data, 255, row);
  expect(big.error == Error::TooLong && big.needed == 254, "AC-4 255 bytes is TooLong");
  auto bigr = packbin::unpack_repair(s25, data, 300, row, 2);
  expect(bigr.error == Error::TooLong, "AC-4 300 bytes is TooLong in unpack_repair");
  auto plain = packbin::unpack(packbin::parity_percent(base, 0), data, 5, row);
  expect(plain.error != Error::Uncorrectable && plain.error != Error::TooLong,
         "AC-4 percentage 0 checks no length");
}

// AC-5, AC-6: repair with the count of that message, and the limit.
void repair_and_limit() {
  Rng rng(0xa5);
  Msg m = msg_of_length(40, rng);
  struct Case {
    int p, wrong, t, count;
  };
  for (Case c : {Case{50, 10, 10, 10}, Case{25, 5, 5, 5}, Case{50, 3, 10, 3}, Case{25, 0, 5, 0}}) {
    auto s = packbin::parity_percent(base, c.p);
    Bytes good = protect_msg(s, m);
    Bytes bad = corrupt(good, c.wrong, rng);
    Msg back;
    auto r = packbin::unpack_repair(s, bad.data(), bad.size(), back, c.t);
    expect(r.ok() && r.repaired == c.count && same_msg(m, back) && bad == good,
           "AC-5 repaired with the count of the message");
  }

  auto s25 = packbin::parity_percent(base, 25);  // 40 clear bytes, 10 parity bytes
  Bytes good = protect_msg(s25, m);
  expect(good.size() == 50, "AC-6 40 clear bytes at 25 percent are 50 sent");
  Msg back;
  for (int t : {-1, 17, 100, -100}) {
    Bytes copy = good;
    copy[3] ^= 1;
    Bytes before = copy;
    auto r = packbin::unpack_repair(s25, copy.data(), copy.size(), back, t);
    expect(r.error == Error::BadValue && copy == before, "AC-6 a limit outside 0..16 is BadValue");
  }
  // Limit 16 behaves as 5 on this message: the same result for 1, 5, 6 and 12 wrong bytes.
  for (int wrong : {1, 5, 6, 12}) {
    Bytes bad = corrupt(good, wrong, rng);
    Bytes a = bad;
    Bytes b = bad;
    Msg ra;
    Msg rb;
    auto x = packbin::unpack_repair(s25, a.data(), a.size(), ra, 16);
    auto y = packbin::unpack_repair(s25, b.data(), b.size(), rb, 5);
    expect(x.error == y.error && x.repaired == y.repaired && a == b,
           "AC-6 limit 16 on 40 bytes at 25 percent behaves as limit 5");
  }
  Bytes five = corrupt(good, 5, rng);
  auto fixed = packbin::unpack_repair(s25, five.data(), five.size(), back, 16);
  expect(fixed.ok() && fixed.repaired == 5 && five == good, "AC-6 limit 16 repairs 5 wrong bytes");

  // A fixed count keeps its exact rule, percentage 0 the rule of count 0.
  Bytes fixed_good = protect_msg(packbin::parity(base, 10), m);
  auto f = packbin::unpack_repair(packbin::parity(base, 10), fixed_good.data(), fixed_good.size(),
                                  back, 6);
  expect(f.error == Error::BadValue, "AC-6 a fixed count of 10 with limit 6 is BadValue");
  auto z0s = packbin::parity_percent(base, 0);
  Bytes plain = protect_msg(z0s, m);
  auto z = packbin::unpack_repair(z0s, plain.data(), plain.size(), back, 1);
  expect(z.error == Error::BadValue, "AC-6 percentage 0 with limit 1 is BadValue as count 0");
  auto z0 = packbin::unpack_repair(z0s, plain.data(), plain.size(), back, 0);
  expect(z0.ok() && z0.repaired == 0 && same_msg(m, back), "AC-6 percentage 0 with limit 0 reads");

  // 3 clear bytes at 1 percent have 1 parity byte: the limit is lowered to 0.
  Msg tiny = msg_of_length(3, rng);
  auto s1 = packbin::parity_percent(base, 1);
  Bytes tiny_good = protect_msg(s1, tiny);
  Bytes tiny_bad = tiny_good;
  tiny_bad[1] ^= 0x10;
  auto t0 = packbin::unpack_repair(s1, tiny_bad.data(), tiny_bad.size(), back, 16);
  expect(t0.error == Error::Uncorrectable && tiny_good.size() == 4,
         "AC-6 a limit above n / 2 = 0 is lowered to 0");
}

template <int Type, int P>
constexpr auto percent_scheme() {
  return packbin::parity_percent(msg_scheme<Type>(), P);
}

// AC-7: the dispatch rule.
void dispatch() {
  constexpr auto d40 = percent_scheme<0x40, 25>();
  constexpr auto d41 = percent_scheme<0x41, 25>();
  constexpr auto d42 = percent_scheme<0x42, 25>();
  constexpr auto other = percent_scheme<0x41, 50>();
  constexpr auto counted = packbin::parity(msg_scheme<0x41>(), 10);
  constexpr auto none = msg_scheme<0x41>();
  constexpr auto zero_percent = percent_scheme<0x41, 0>();
  Rng rng(0x42);
  Msg m = msg_of_length(40, rng);
  Bytes good = protect_msg(d41, m);

  Msg a, b, c;
  int ran = 0;
  auto seen = [&](Msg const&) { ++ran; };
  auto u = packbin::unpack(good.data(), good.size(), packbin::on(d40, a, seen),
                           packbin::on(d41, b, seen), packbin::on(d42, c, seen));
  expect(u.ok() && ran == 1 && same_msg(b, m) && u.offset == good.size(),
         "AC-7 handlers of one percentage dispatch");

  Bytes bad = corrupt(good, 4, rng);
  ran = 0;
  Msg d;
  auto r = packbin::unpack_repair(bad.data(), bad.size(), 5, packbin::on(d40, a, seen),
                                  packbin::on(d41, d, seen), packbin::on(d42, c, seen));
  expect(r.ok() && r.repaired == 4 && ran == 1 && same_msg(d, m) && bad == good,
         "AC-7 dispatch after the repair");

  // A mix is refused when the call is built, before any byte is read.
  ran = 0;
  Bytes copy = good;
  auto x1 = packbin::unpack(copy.data(), copy.size(), packbin::on(d40, a, seen),
                            packbin::on(other, b, seen));
  auto y1 = packbin::unpack_repair(copy.data(), copy.size(), 5, packbin::on(d40, a, seen),
                                   packbin::on(other, b, seen));
  auto x2 = packbin::unpack(copy.data(), copy.size(), packbin::on(d40, a, seen),
                            packbin::on(counted, b, seen));
  auto y2 = packbin::unpack_repair(copy.data(), copy.size(), 5, packbin::on(d40, a, seen),
                                   packbin::on(counted, b, seen));
  auto x3 = packbin::unpack(copy.data(), copy.size(), packbin::on(d40, a, seen),
                            packbin::on(none, b, seen));
  auto y3 = packbin::unpack_repair(copy.data(), copy.size(), 5, packbin::on(d40, a, seen),
                                   packbin::on(none, b, seen));
  expect(x1.error == Error::SchemeInvalid && y1.error == Error::SchemeInvalid &&
             x2.error == Error::SchemeInvalid && y2.error == Error::SchemeInvalid &&
             x3.error == Error::SchemeInvalid && y3.error == Error::SchemeInvalid && ran == 0 &&
             copy == good,
         "AC-7 a mix of settings is SchemeInvalid, no handler runs");

  // Percentage 0 is the setting of count 0.
  ran = 0;
  Bytes plain = protect_msg(zero_percent, m);
  Msg e;
  auto both = packbin::unpack(plain.data(), plain.size(),
                              packbin::on(percent_scheme<0x40, 0>(), a, seen),
                              packbin::on(none, e, seen));
  expect(both.ok() && ran == 1 && same_msg(e, m), "AC-7 percentage 0 and count 0 share a setting");
}

}  // namespace

int run_core_ecc_percent_host_tests() {
  setting();
  count_and_bytes();
  impossible_lengths();
  round_trips();
  repair_and_limit();
  dispatch();
  return check::failures();
}
