// Message ECC under an open session (AZ-2688; EC-10): the code covers the padded bytes, the
// payload is the clear length + n, unpack repairs, drops the parity, removes the pad, then reads,
// and the receive index advances for a refused payload so the next one still lines up.
#include "packbin/codec.hpp"
#include "packbin/session.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstring>

using check::expect;
using packbin::Error;
using packbin::PackSession;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

template <int Type, int N>
constexpr auto position_scheme() {
  return packbin::parity(
      packbin::scheme<Position>(Type, packbin::u16<&Position::sid>(0),
                                packbin::i32<&Position::lat>(1), packbin::i32<&Position::lon>(2),
                                packbin::u8<&Position::profile>(3),
                                packbin::u8<&Position::flags>(4)),
      N);
}

constexpr auto plain = position_scheme<0x40, 0>();
constexpr auto p4 = position_scheme<0x40, 4>();
constexpr auto q4 = position_scheme<0x41, 4>();
constexpr auto q2 = position_scheme<0x42, 2>();

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";
// The session pad of the position fixture at packet index 0 (session_tests.cpp).
constexpr char const* kCipherHex = "b55d0a29c56c203712b241232e";
constexpr char const* kNonceHex = "01000000000000000000000000000000";

Position position_row() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

bool same_row(Position const& a, Position const& b) {
  return a.sid == b.sid && a.lat == b.lat && a.lon == b.lon && a.profile == b.profile &&
         a.flags == b.flags;
}

// Two sessions of one seed and nonce: `a` initiates, `b` joins.
struct Pair {
  PackSession a;
  PackSession b;
};

void open_pair(Pair& pair) {
  std::uint8_t seed[32];
  for (std::size_t i = 0; i < sizeof(seed); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  std::uint8_t nonce[16];
  check::parse_hex(kNonceHex, nonce, sizeof(nonce));
  bool ok = pair.a.load(seed, sizeof(seed)) && pair.b.load(seed, sizeof(seed)) &&
            pair.a.start(nonce, sizeof(nonce)) && pair.b.join(nonce, sizeof(nonce));
  expect(ok, "both sessions open");
}

// EC-10: pack = clear pack, pad, then parity; the payload is the clear length + n.
void payload_is_padded_clear_plus_parity() {
  Pair pair;
  open_pair(pair);
  std::uint8_t out[32];
  auto r = pair.a.pack(p4, position_row(), out, sizeof(out));
  expect(r.ok() && r.offset == 17, "EC-10 the payload is the clear length + 4");
  expect(check::same_hex(out, 13, kCipherHex),
         "EC-10 the first 13 bytes are the padded clear message");
  std::uint8_t parity[4];
  auto k = packbin::ecc::protect(out, 13, 4, parity);
  expect(k == packbin::ecc::Kind::Ok && std::memcmp(parity, out + 13, 4) == 0,
         "EC-10 the parity covers the padded bytes");

  Pair zero;
  open_pair(zero);
  auto u = zero.a.pack(plain, position_row(), out, sizeof(out));
  expect(u.ok() && u.offset == 13 && check::same_hex(out, 13, kCipherHex),
         "EC-10 n = 0 keeps the payload the length of the clear pack");
}

// EC-10: 2 wrong bytes anywhere in the payload are repaired before the pad is removed.
void two_wrong_bytes_are_repaired() {
  int recovered = 0;
  int cases = 0;
  for (std::size_t x = 0; x < 17; ++x)
    for (std::size_t y = x + 1; y < 17; ++y) {
      Pair pair;
      open_pair(pair);
      std::uint8_t wire[32];
      auto p = pair.a.pack(p4, position_row(), wire, sizeof(wire));
      wire[x] = static_cast<std::uint8_t>(wire[x] ^ 0xff);
      wire[y] = static_cast<std::uint8_t>(wire[y] ^ 0x5a);
      Position row;
      auto r = pair.b.unpack_repair(p4, wire, p.offset, row, 2);
      ++cases;
      if (r.ok() && r.repaired == 2 && r.offset == 17 && same_row(row, position_row()) &&
          check::same_hex(wire, 13, kGoldenHex))
        ++recovered;
    }
  expect(cases == 136 && recovered == cases, "EC-10 every pair of wrong bytes is repaired");

  Pair pair;
  open_pair(pair);
  std::uint8_t wire[32];
  auto p = pair.a.pack(p4, position_row(), wire, sizeof(wire));
  Position row;
  auto clean = pair.b.unpack(p4, wire, p.offset, row);
  expect(clean.ok() && clean.repaired == 0 && same_row(row, position_row()) &&
             check::same_hex(wire, 13, kGoldenHex),
         "EC-10 an intact payload reads, 0 repaired, and the buffer holds the clear packet");
}

// EC-10: 3 wrong bytes with limit 2 is an error and the next payload from the same sender is
// still read correctly.
void next_payload_after_an_uncorrectable_one() {
  Pair pair;
  open_pair(pair);
  std::uint8_t first[32];
  std::uint8_t second[32];
  auto p1 = pair.a.pack(p4, position_row(), first, sizeof(first));
  auto p2 = pair.a.pack(p4, position_row(), second, sizeof(second));
  first[1] = static_cast<std::uint8_t>(first[1] ^ 0x11);
  first[6] = static_cast<std::uint8_t>(first[6] ^ 0x22);
  first[12] = static_cast<std::uint8_t>(first[12] ^ 0x33);
  std::uint8_t before[32];
  std::memcpy(before, first, p1.offset);

  Position row;
  auto bad = pair.b.unpack_repair(p4, first, p1.offset, row, 2);
  expect(bad.error == Error::Uncorrectable && row.sid == 0 &&
             std::memcmp(before, first, p1.offset) == 0,
         "EC-10 3 wrong bytes with limit 2 is Uncorrectable, 0 values, the buffer as it was");
  auto next = pair.b.unpack_repair(p4, second, p2.offset, row, 2);
  expect(next.ok() && same_row(row, position_row()),
         "EC-10 the next payload from the sender is still read");
}

// A refused argument (limit, mixed counts) does not use up a pad index.
void refused_arguments_keep_the_index() {
  Pair pair;
  open_pair(pair);
  std::uint8_t wire[32];
  auto p = pair.a.pack(p4, position_row(), wire, sizeof(wire));
  Position row;
  auto limit = pair.b.unpack_repair(p4, wire, p.offset, row, 3);
  expect(limit.error == Error::BadValue && row.sid == 0, "a limit above n / 2 is BadValue");

  Position r41, r42;
  auto mixed = pair.b.unpack_repair(wire, p.offset, 0, packbin::on(q4, r41, [](Position const&) {}),
                                    packbin::on(q2, r42, [](Position const&) {}));
  expect(mixed.error == Error::SchemeInvalid && mixed.offset == 4 && mixed.needed == 2,
         "handlers with different parity counts are SchemeInvalid");

  auto ok = pair.b.unpack(p4, wire, p.offset, row);
  expect(ok.ok() && same_row(row, position_row()), "the index was not used up by the refusals");
}

// The session dispatch repairs first, then removes the pad, then picks the handler.
void dispatch_in_a_session() {
  Pair pair;
  open_pair(pair);
  std::uint8_t wire[32];
  auto p = pair.a.pack(q4, position_row(), wire, sizeof(wire));
  wire[0] = static_cast<std::uint8_t>(wire[0] ^ 0x77);
  wire[9] = static_cast<std::uint8_t>(wire[9] ^ 0x01);

  int p4_runs = 0;
  int q4_runs = 0;
  Position r40, r41;
  auto r = pair.b.unpack_repair(wire, p.offset, 2,
                                packbin::on(p4, r40, [&](Position const&) { ++p4_runs; }),
                                packbin::on(q4, r41, [&](Position const&) { ++q4_runs; }));
  expect(r.ok() && r.repaired == 2 && q4_runs == 1 && p4_runs == 0 && same_row(r41, position_row()),
         "a session dispatch with a wrong type byte reaches the right handler");
}

// EC-10 with a refused payload that is short or too long: the index still advances.
void malformed_payloads_use_an_index() {
  Pair pair;
  open_pair(pair);
  std::uint8_t first[32];
  std::uint8_t second[32];
  pair.a.pack(p4, position_row(), first, sizeof(first));
  auto p2 = pair.a.pack(p4, position_row(), second, sizeof(second));

  Position row;
  std::uint8_t stub[3] = {1, 2, 3};
  auto tiny = pair.b.unpack_repair(p4, stub, 3, row, 2);
  expect(tiny.error == Error::ShortPacket && tiny.needed == 4 && tiny.offset == 3,
         "a payload shorter than n is ShortPacket");
  auto next = pair.b.unpack_repair(p4, second, p2.offset, row, 2);
  expect(next.ok() && same_row(row, position_row()), "the payload after it lines up");
}

}  // namespace

int run_core_ecc_session_host_tests() {
  payload_is_padded_clear_plus_parity();
  two_wrong_bytes_are_repaired();
  next_payload_after_an_uncorrectable_one();
  refused_arguments_keep_the_index();
  dispatch_in_a_session();
  malformed_payloads_use_an_index();
  return check::failures();
}
