// Message ECC codec behavior (AZ-2687; EC-5 to EC-8, EC-13, EC-14 at the codec level): repair of
// every position and value, seeded multi-error cases, refusals with no wrong row, shifted
// buffers, hostile buffers, the speed bound and the build with the codec removed.
#include "packbin/ecc.hpp"

#include "check.hpp"
#include "ecc_support_host.hpp"

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

using check::expect;
using ecc_test::Bytes;
using ecc_test::from_hex;
using ecc_test::Rng;
using packbin::ecc::Kind;

namespace {

Bytes protect_of(Bytes const& clear, int n) {
  std::uint8_t parity[32] = {};
  Kind k = packbin::ecc::protect(clear.data(), clear.size(), n, parity);
  expect(k == Kind::Ok, "protect of a valid clear message");
  Bytes out = clear;
  out.insert(out.end(), parity, parity + n);
  return out;
}

// Changes `count` distinct positions of `word` to a different byte each.
void corrupt(Bytes& word, int count, Rng& rng) {
  Bytes hit(word.size(), 0);
  for (int done = 0; done < count;) {
    std::size_t p = rng.below(word.size());
    if (hit[p])
      continue;
    hit[p] = 1;
    word[p] = static_cast<std::uint8_t>(word[p] ^ (1 + rng.below(255)));
    ++done;
  }
}

Bytes random_bytes(std::size_t len, Rng& rng) {
  Bytes out(len);
  for (auto& b : out)
    b = rng.byte();
  return out;
}

// EC-5: n = 2, t = 1, the position fixture, every position and every changed value.
void every_position_and_value_n2() {
  Bytes clear = from_hex(ecc_test::kPositionHex);
  Bytes sent = protect_of(clear, 2);
  int recovered = 0;
  int cases = 0;
  for (std::size_t p = 0; p < sent.size(); ++p)
    for (int delta = 1; delta < 256; ++delta) {
      Bytes word = sent;
      word[p] = static_cast<std::uint8_t>(word[p] ^ delta);
      auto o = packbin::ecc::repair(word.data(), word.size(), 2, 1);
      ++cases;
      if (o.ok() && o.repaired == 1 && word == sent)
        ++recovered;
    }
  expect(cases == 15 * 255 && recovered == cases, "n = 2: 15 positions x 255 values all repaired");
}

// EC-5: n = 4, 8, 16 with t = n / 2 and 1 to t wrong bytes, 1,000 seeded cases each.
void seeded_repairs() {
  Bytes clear = from_hex(ecc_test::kPositionHex);
  for (int n : {4, 8, 16}) {
    Bytes sent = protect_of(clear, n);
    Rng rng(1000 + n);
    int wrong = 0;
    for (int c = 0; c < 1000; ++c) {
      int count = 1 + static_cast<int>(rng.below(n / 2));
      Bytes word = sent;
      corrupt(word, count, rng);
      auto o = packbin::ecc::repair(word.data(), word.size(), n, n / 2);
      if (!o.ok() || o.repaired != count || word != sent)
        ++wrong;
    }
    expect(wrong == 0, "seeded repairs of 1 to n / 2 wrong bytes");
  }
}

// EC-6: more wrong bytes than t and up to n - t are refused, the buffer untouched.
void refusals_beyond_the_limit() {
  Bytes clear = from_hex(ecc_test::kPositionHex);
  Bytes sent = protect_of(clear, 4);
  Rng rng(46);
  int accepted = 0;
  int touched = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    corrupt(word, 2 + static_cast<int>(rng.below(2)), rng);
    Bytes before = word;
    auto o = packbin::ecc::repair(word.data(), word.size(), 4, 1);
    if (o.kind != Kind::Uncorrectable || o.repaired != 0)
      ++accepted;
    if (word != before)
      ++touched;
  }
  expect(accepted == 0, "n = 4, t = 1: 2 or 3 wrong bytes are all refused");
  expect(touched == 0, "a refused repair leaves the buffer as it was");

  accepted = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    corrupt(word, 1 + static_cast<int>(rng.below(4)), rng);
    auto r = packbin::ecc::repair(word.data(), word.size(), 4, 0);
    auto k = packbin::ecc::check(word.data(), word.size(), 4);
    if (r.kind != Kind::Uncorrectable || k.kind != Kind::Uncorrectable)
      ++accepted;
  }
  expect(accepted == 0, "n = 4, t = 0: 1 to 4 wrong bytes are all refused");
}

// EC-7: random garbage of the fixture's length under n = 2, t = 0.
void garbage_is_refused() {
  Rng rng(7);
  int accepted = 0;
  for (int c = 0; c < 200000; ++c) {
    Bytes word = random_bytes(15, rng);
    if (packbin::ecc::repair(word.data(), word.size(), 2, 0).ok())
      ++accepted;
  }
  expect(accepted <= 12, "200,000 random buffers: at most 12 pass");
}

// EC-8: intact, short and limit refusals; EC-14: shifted buffers.
void intact_short_and_shifted() {
  Bytes clear = from_hex(ecc_test::kPositionHex);
  Bytes sent = protect_of(clear, 4);
  Bytes word = sent;
  auto o = packbin::ecc::repair(word.data(), word.size(), 4, 2);
  expect(o.ok() && o.repaired == 0 && word == sent, "an intact buffer reports 0 repaired");

  std::uint8_t three[3] = {1, 2, 3};
  expect(packbin::ecc::repair(three, 3, 4, 2).kind == Kind::Short, "shorter than n");
  expect(packbin::ecc::check(three, 3, 4).kind == Kind::Short, "check: shorter than n");
  expect(packbin::ecc::repair(three, 3, 4, 3).kind == Kind::BadLimit, "t above n / 2");
  expect(packbin::ecc::repair(three, 3, 4, -1).kind == Kind::BadLimit, "t below 0");
  expect(packbin::ecc::repair(three, 3, 33, 0).kind == Kind::BadParity, "n above 32");
  expect(packbin::ecc::repair(three, 3, -1, 0).kind == Kind::BadParity, "n below 0");

  Bytes longer(255, 0);
  expect(packbin::ecc::repair(longer.data(), longer.size(), 4, 2).kind == Kind::TooLong,
         "a buffer above 254 bytes");
  expect(packbin::ecc::check(longer.data(), longer.size(), 4).kind == Kind::TooLong,
         "check: a buffer above 254 bytes");

  Bytes plus_zero = sent;
  plus_zero.push_back(0);
  expect(packbin::ecc::repair(plus_zero.data(), plus_zero.size(), 4, 0).kind == Kind::Uncorrectable,
         "a trailing 00 added");
  Bytes minus_one(sent.begin(), sent.end() - 1);
  expect(packbin::ecc::repair(minus_one.data(), minus_one.size(), 4, 0).kind == Kind::Uncorrectable,
         "the last byte removed");
  expect(packbin::ecc::repair(clear.data(), clear.size(), 4, 0).kind == Kind::Uncorrectable,
         "an unprotected message read as protected");

  Rng rng(14);
  int accepted = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    std::size_t k = 1 + rng.below(3);
    if (rng.below(2) == 0) {
      word.resize(word.size() - k);
    } else {
      for (std::size_t i = 0; i < k; ++i)
        word.push_back(rng.byte());
    }
    if (packbin::ecc::repair(word.data(), word.size(), 4, 0).ok())
      ++accepted;
  }
  expect(accepted == 0, "n = 4: 1 to 3 bytes removed or added are all refused");

  // A last parity byte of 00 shifted by one byte is refused too.
  Bytes zero_tail;
  for (int b = 0; b < 256 && zero_tail.empty(); ++b) {
    Bytes c = clear;
    c.push_back(static_cast<std::uint8_t>(b));
    Bytes p = protect_of(c, 4);
    if (p.back() == 0)
      zero_tail = p;
  }
  expect(!zero_tail.empty(), "a message with a last parity byte 00 exists");
  if (!zero_tail.empty()) {
    Bytes cut(zero_tail.begin(), zero_tail.end() - 1);
    Bytes grown = zero_tail;
    grown.push_back(0);
    expect(packbin::ecc::repair(zero_tail.data(), zero_tail.size(), 4, 0).ok(), "00 tail intact");
    expect(!packbin::ecc::repair(cut.data(), cut.size(), 4, 0).ok(), "00 tail removed");
    expect(!packbin::ecc::repair(grown.data(), grown.size(), 4, 0).ok(), "00 tail grown");
  }
}

// n = 0 changes nothing: no parity, no refusal of a long buffer, no write.
void n_zero_is_unchanged() {
  Bytes clear = from_hex(ecc_test::kPositionHex);
  std::uint8_t sentinel[1] = {0x5a};
  expect(packbin::ecc::protect(clear.data(), clear.size(), 0, sentinel) == Kind::Ok &&
             sentinel[0] == 0x5a,
         "n = 0 writes no parity");
  Bytes word = clear;
  auto o = packbin::ecc::repair(word.data(), word.size(), 0, 0);
  expect(o.ok() && o.repaired == 0 && word == clear, "n = 0 repair is a no-op");
  expect(packbin::ecc::check(word.data(), word.size(), 0).ok(), "n = 0 check passes");
}

// The largest message: n = 32 and 222 clear bytes, 8 to 16 wrong bytes.
void largest_message_n32() {
  Rng rng(32);
  Bytes sent = protect_of(random_bytes(222, rng), 32);
  expect(sent.size() == 254, "222 + 32 = 254 sent bytes");
  int wrong = 0;
  for (int c = 0; c < 200; ++c) {
    Bytes word = sent;
    int count = 1 + static_cast<int>(rng.below(16));
    corrupt(word, count, rng);
    auto o = packbin::ecc::repair(word.data(), word.size(), 32, 16);
    if (!o.ok() || o.repaired != count || word != sent)
      ++wrong;
  }
  expect(wrong == 0, "n = 32, t = 16 on a 254-byte message");
}

// Hostile buffers: any n, t and length never crash; Ok only for a codeword of at most t errors;
// anything else leaves the buffer as it was.
void hostile_buffers() {
  Rng rng(99);
  int bad_state = 0;
  for (int c = 0; c < 20000; ++c) {
    int n = static_cast<int>(rng.below(34));
    int t = n == 0 ? 0 : static_cast<int>(rng.below(static_cast<std::size_t>(n) / 2 + 1));
    Bytes word = random_bytes(rng.below(300), rng);
    if (rng.below(2) == 0 && word.size() > static_cast<std::size_t>(n) && n >= 1 && n <= 32 &&
        word.size() <= 254) {
      Bytes clear(word.begin(), word.end() - n);
      word = protect_of(clear, n);
      std::size_t count = rng.below(static_cast<std::size_t>(n) + 2);
      corrupt(word, static_cast<int>(count < word.size() ? count : word.size()), rng);
    }
    Bytes before = word;
    auto o = packbin::ecc::repair(word.data(), word.size(), n, t);
    if (o.ok()) {
      if (o.repaired > t || !packbin::ecc::check(word.data(), word.size(), n).ok())
        ++bad_state;
    } else if (word != before || o.repaired != 0) {
      ++bad_state;
    }
  }
  expect(bad_state == 0, "hostile buffers: Ok leaves a codeword, a refusal leaves the bytes");
}

// EC-13: a 254-byte message with 16 parity bytes and 8 wrong bytes, repaired 1,000 times in 1 s;
// pack of 1,000 such blocks in 1 s.
void speed_bound() {
  using Clock = std::chrono::steady_clock;
  Rng rng(13);
  Bytes clear = random_bytes(238, rng);
  Bytes sent = protect_of(clear, 16);
  Bytes broken = sent;
  corrupt(broken, 8, rng);
  int wrong = 0;
  Bytes work;
  auto start = Clock::now();
  for (int i = 0; i < 1000; ++i) {
    work = broken;
    auto o = packbin::ecc::repair(work.data(), work.size(), 16, 8);
    if (!o.ok() || o.repaired != 8 || work != sent)
      ++wrong;
  }
  double repair_s = std::chrono::duration<double>(Clock::now() - start).count();
  expect(wrong == 0, "the speed loop repairs every block");
  expect(repair_s <= 1.0, "1,000 repairs of 254 bytes with 8 wrong bytes within 1 s");

  std::uint8_t parity[16];
  start = Clock::now();
  for (int i = 0; i < 1000; ++i) {
    clear[0] = static_cast<std::uint8_t>(i);
    if (packbin::ecc::protect(clear.data(), clear.size(), 16, parity) != Kind::Ok)
      ++wrong;
  }
  double protect_s = std::chrono::duration<double>(Clock::now() - start).count();
  expect(wrong == 0, "the pack loop protects every block");
  expect(protect_s <= 1.0, "1,000 protects of 254 bytes within 1 s");
  std::printf("ecc speed: 1,000 repairs %.3f s, 1,000 protects %.3f s\n", repair_s, protect_s);
}

}  // namespace

int run_core_ecc_repair_host_tests() {
  every_position_and_value_n2();
  seeded_repairs();
  refusals_beyond_the_limit();
  garbage_is_refused();
  intact_short_and_shifted();
  n_zero_is_unchanged();
  largest_message_n32();
  hostile_buffers();
  speed_bound();
  return check::failures();
}
