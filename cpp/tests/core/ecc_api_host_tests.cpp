// Message ECC through unpack_repair and the dispatch call (AZ-2688): EC-5 recovery at every
// position and with seeded multi-byte cases, EC-6 refusals with no wrong row and an untouched
// buffer, EC-11 a compact-text field in a protected message, EC-16 the dispatch rule with the type
// byte among the wrong bytes, EC-17 the buffer equals the protected message after a repair.
#include "packbin/codec.hpp"

#include "check.hpp"
#include "ecc_support_host.hpp"

#include <cstdint>
#include <cstring>
#include <vector>

using check::expect;
using ecc_test::Bytes;
using ecc_test::Rng;
using packbin::Error;

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

constexpr auto p2 = position_scheme<0x40, 2>();
constexpr auto p4 = position_scheme<0x40, 4>();
constexpr auto p8 = position_scheme<0x40, 8>();
constexpr auto p16 = position_scheme<0x40, 16>();
// Three message types sharing the row type and the parity count, for the dispatch rule.
constexpr auto d40 = position_scheme<0x40, 4>();
constexpr auto d41 = position_scheme<0x41, 4>();
constexpr auto d42 = position_scheme<0x42, 4>();

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

template <std::size_t N>
Bytes protected_message(packbin::Scheme<Position, N> const& s) {
  Bytes out(64);
  auto r = packbin::pack(s, position_row(), out.data(), out.size());
  expect(r.ok(), "pack of the position row");
  out.resize(r.offset);
  return out;
}

// Changes `count` distinct positions of `word` to a different byte each; `pinned` (when it is
// not -1) is always one of them.
void corrupt(Bytes& word, int count, Rng& rng, int pinned = -1) {
  Bytes hit(word.size(), 0);
  int done = 0;
  if (pinned >= 0) {
    hit[static_cast<std::size_t>(pinned)] = 1;
    word[static_cast<std::size_t>(pinned)] =
        static_cast<std::uint8_t>(word[static_cast<std::size_t>(pinned)] ^ (1 + rng.below(255)));
    ++done;
  }
  while (done < count) {
    std::size_t p = rng.below(word.size());
    if (hit[p])
      continue;
    hit[p] = 1;
    word[p] = static_cast<std::uint8_t>(word[p] ^ (1 + rng.below(255)));
    ++done;
  }
}

// EC-5: n = 2, limit 1, every position and every changed value, through the API.
void every_position_and_value_n2() {
  Bytes sent = protected_message(p2);
  int recovered = 0;
  int cases = 0;
  for (std::size_t p = 0; p < sent.size(); ++p)
    for (int delta = 1; delta < 256; ++delta) {
      Bytes word = sent;
      word[p] = static_cast<std::uint8_t>(word[p] ^ delta);
      Position row;
      auto r = packbin::unpack_repair(p2, word.data(), word.size(), row, 1);
      ++cases;
      if (r.ok() && r.repaired == 1 && same_row(row, position_row()) && word == sent)
        ++recovered;
    }
  expect(cases == 15 * 255 && recovered == cases, "EC-5 n = 2: 15 positions x 255 values recover");
}

template <std::size_t N>
void seeded_recovery(packbin::Scheme<Position, N> const& s, int n) {
  Bytes sent = protected_message(s);
  Rng rng(7000 + static_cast<std::uint64_t>(n));
  int ok = 0;
  for (int c = 0; c < 1000; ++c) {
    int count = 1 + static_cast<int>(rng.below(static_cast<std::size_t>(n / 2)));
    Bytes word = sent;
    corrupt(word, count, rng);
    Position row;
    auto r = packbin::unpack_repair(s, word.data(), word.size(), row, n / 2);
    if (r.ok() && r.repaired == count && same_row(row, position_row()) && word == sent)
      ++ok;
  }
  expect(ok == 1000, "EC-5 1,000 seeded corruptions of 1 to n / 2 bytes recover");
}

// EC-6: beyond the limit the result is Uncorrectable, no row is written and the buffer is as it
// was. Wrong rows returned: 0.
void seeded_refusals() {
  Bytes sent = protected_message(p4);
  Rng rng(4004);
  int refused = 0;
  int wrong = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    corrupt(word, 2 + static_cast<int>(rng.below(2)), rng);
    Bytes before = word;
    Position row;
    auto r = packbin::unpack_repair(p4, word.data(), word.size(), row, 1);
    if (r.error == Error::Uncorrectable && word == before && row.sid == 0)
      ++refused;
    else if (r.ok())
      ++wrong;
  }
  expect(refused == 10000 && wrong == 0, "EC-6 n = 4, limit 1: 10,000 cases of 2 or 3 wrong bytes");

  int detected = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    corrupt(word, 1 + static_cast<int>(rng.below(4)), rng);
    Position row;
    auto r = packbin::unpack(p4, word.data(), word.size(), row);
    if (r.error == Error::Uncorrectable && row.sid == 0)
      ++detected;
  }
  expect(detected == 10000, "EC-6 n = 4, limit 0: 10,000 cases of 1 to 4 wrong bytes");
}

// EC-14: a shifted message of 1 to 3 bytes removed or added is refused, 10,000 seeded cases.
void seeded_shifts() {
  Bytes sent = protected_message(p4);
  Rng rng(1414);
  int refused = 0;
  for (int c = 0; c < 10000; ++c) {
    Bytes word = sent;
    std::size_t k = 1 + rng.below(3);
    if (rng.below(2) == 0) {
      word.resize(word.size() - k);
    } else {
      for (std::size_t i = 0; i < k; ++i)
        word.push_back(rng.byte());
    }
    Position row;
    auto r = packbin::unpack(p4, word.data(), word.size(), row);
    if (!r.ok() && row.sid == 0)
      ++refused;
  }
  expect(refused == 10000, "EC-14 10,000 messages with 1 to 3 bytes removed or added are refused");
}

// A protected message with a compact-text field and neighbours on both sides (EC-11).
struct Note {
  std::uint8_t kind = 0;
  packbin::Text<24> name;
  std::uint16_t id = 0;
};

constexpr auto note = packbin::parity(
    packbin::scheme<Note>(0x43, packbin::u8<&Note::kind>(0), packbin::utf8<&Note::name>(1),
                          packbin::u16<&Note::id>(2)),
    4);

bool same_note(Note const& a, Note const& b) {
  return a.kind == b.kind && a.id == b.id && a.name.len == b.name.len &&
         std::memcmp(a.name.data, b.name.data, a.name.len) == 0;
}

Note note_row() {
  // "привіт world"
  static char const text[] = "\xD0\xBF\xD1\x80\xD0\xB8\xD0\xB2\xD1\x96\xD1\x82 world";
  Note n;
  n.kind = 7;
  n.id = 4242;
  n.name.len = sizeof(text) - 1;
  std::memcpy(n.name.data, text, sizeof(text) - 1);
  return n;
}

// EC-11: any 2 wrong bytes anywhere (string payload, count, neighbours, parity) give the row and
// the original string back; strings that differ from the original: 0.
void text_survives_two_wrong_bytes() {
  Note original = note_row();
  Bytes sent(64);
  packbin::Scratch<32> scratch;
  auto p = packbin::pack(note, original, sent.data(), sent.size(), scratch);
  expect(p.ok(), "EC-11 the protected text message packs");
  sent.resize(p.offset);

  int cases = 0;
  int recovered = 0;
  int different = 0;
  Rng rng(4343);
  for (std::size_t a = 0; a < sent.size(); ++a)
    for (std::size_t b = a + 1; b < sent.size(); ++b)
      for (int round = 0; round < 8; ++round) {
        Bytes word = sent;
        word[a] = static_cast<std::uint8_t>(word[a] ^ (round == 0 ? 0xff : 1 + rng.below(255)));
        word[b] = static_cast<std::uint8_t>(word[b] ^ (round == 1 ? 0xff : 1 + rng.below(255)));
        Note row;
        auto r = packbin::unpack_repair(note, word.data(), word.size(), row, 2);
        ++cases;
        if (r.ok() && r.repaired == 2 && same_note(row, original))
          ++recovered;
        else if (r.ok())
          ++different;
      }
  expect(cases > 1000 && recovered == cases && different == 0,
         "EC-11 every pair of wrong bytes recovers the original string");

  Bytes three = sent;
  corrupt(three, 3, rng);
  Note row;
  auto refused = packbin::unpack_repair(note, three.data(), three.size(), row, 2);
  expect(refused.error != Error::Ok || same_note(row, original),
         "EC-11 three wrong bytes never give another string");
}

// The row type is filled by the handler it reaches; the others must not run.
struct Seen {
  int h40 = 0;
  int h41 = 0;
  int h42 = 0;
};

// EC-16: handlers share the parity count; the type byte is always among the wrong bytes (1 to 2
// wrong bytes), the message is repaired first and reaches the right handler. Wrong handlers run: 0.
void dispatch_repairs_the_type_byte() {
  Rng rng(1616);
  Bytes messages[3] = {protected_message(d40), protected_message(d41), protected_message(d42)};
  int right = 0;
  int wrong_runs = 0;
  for (int c = 0; c < 1000; ++c) {
    std::size_t which = rng.below(3);
    Bytes word = messages[which];
    corrupt(word, 1 + static_cast<int>(rng.below(2)), rng, 0);
    Seen seen;
    Position r40, r41, r42;
    auto result = packbin::unpack_repair(
        word.data(), word.size(), 2,
        packbin::on(d40, r40, [&](Position const&) { ++seen.h40; }),
        packbin::on(d41, r41, [&](Position const&) { ++seen.h41; }),
        packbin::on(d42, r42, [&](Position const&) { ++seen.h42; }));
    int runs[3] = {seen.h40, seen.h41, seen.h42};
    for (std::size_t i = 0; i < 3; ++i)
      if (i != which)
        wrong_runs += runs[i];
    Position const* rows[3] = {&r40, &r41, &r42};
    if (result.ok() && runs[which] == 1 && same_row(*rows[which], position_row()) &&
        word == messages[which])
      ++right;
  }
  expect(right == 1000 && wrong_runs == 0,
         "EC-16 1,000 messages with a wrong type byte reach the right handler");
}

void dispatch_refusals() {
  Bytes sent = protected_message(d41);
  Seen seen;
  Position r40, r41, r42;
  auto h40 = packbin::on(d40, r40, [&](Position const&) { ++seen.h40; });
  auto h41 = packbin::on(d41, r41, [&](Position const&) { ++seen.h41; });
  auto h42 = packbin::on(d42, r42, [&](Position const&) { ++seen.h42; });

  Bytes intact = sent;
  auto ok = packbin::unpack(intact.data(), intact.size(), h40, h41, h42);
  expect(ok.ok() && seen.h41 == 1 && seen.h40 == 0 && seen.h42 == 0 && ok.offset == sent.size(),
         "EC-16 an intact protected message reaches its handler through the read-only dispatch");

  Bytes bad = sent;
  bad[0] = 0x40;
  Bytes before = bad;
  seen = Seen{};
  auto detect = packbin::unpack(bad.data(), bad.size(), h40, h41, h42);
  expect(detect.error == Error::Uncorrectable && bad == before &&
             seen.h40 + seen.h41 + seen.h42 == 0,
         "EC-16 the read-only dispatch detects a wrong type byte and runs no handler");

  Bytes two = sent;
  two[0] = 0x40;
  two[5] = static_cast<std::uint8_t>(two[5] ^ 0x31);
  two[7] = static_cast<std::uint8_t>(two[7] ^ 0x22);
  before = two;
  seen = Seen{};
  auto beyond = packbin::unpack_repair(two.data(), two.size(), 1, h40, h41, h42);
  expect(beyond.error == Error::Uncorrectable && two == before &&
             seen.h40 + seen.h41 + seen.h42 == 0,
         "EC-16 beyond the limit no handler runs and the buffer is as it was");

  auto limit = packbin::unpack_repair(two.data(), two.size(), 3, h40, h41, h42);
  expect(limit.error == Error::BadValue && seen.h40 + seen.h41 + seen.h42 == 0,
         "EC-16 a limit above n / 2 is refused before any byte is read");

  auto other = position_scheme<0x50, 2>();
  Position r50;
  auto h50 = packbin::on(other, r50, [&](Position const&) { ++seen.h42; });
  auto mixed = packbin::unpack(intact.data(), intact.size(), h41, h50);
  expect(mixed.error == Error::SchemeInvalid && mixed.offset == 4 && mixed.needed == 2 &&
             seen.h40 + seen.h41 + seen.h42 == 0,
         "EC-16 a mix of parity counts is SchemeInvalid naming both counts, no handler runs");
  auto first_plain = packbin::unpack_repair(intact.data(), intact.size(), 0, h50, h41);
  expect(first_plain.error == Error::SchemeInvalid && first_plain.offset == 2 &&
             first_plain.needed == 4,
         "EC-16 the repairing dispatch refuses the mix too");

  constexpr auto none = position_scheme<0x60, 0>();
  Position r60;
  auto h60 = packbin::on(none, r60, [&](Position const&) { ++seen.h42; });
  auto with_zero = packbin::unpack(intact.data(), intact.size(), h41, h60);
  expect(with_zero.error == Error::SchemeInvalid && with_zero.offset == 4 && with_zero.needed == 0,
         "EC-16 n = 4 beside n = 0 is refused");
}

// EC-1: handlers without parity dispatch as before, whatever the buffer length.
void dispatch_without_parity() {
  constexpr auto plain = position_scheme<0x61, 0>();
  Bytes sent(32);
  auto packed = packbin::pack(plain, position_row(), sent.data(), sent.size());
  sent.resize(packed.offset);
  int calls = 0;
  Position row;
  auto h = packbin::on(plain, row, [&](Position const&) { ++calls; });
  auto r = packbin::unpack(sent.data(), sent.size(), h);
  expect(packed.offset == 13 && r.ok() && calls == 1 && r.repaired == 0 && r.offset == 13,
         "EC-1 an n = 0 handler reads as before");
  sent[0] = 0x62;
  auto miss = packbin::unpack(sent.data(), sent.size(), h);
  expect(miss.error == Error::TypeMismatch && calls == 1,
         "EC-1 an unknown type byte is TypeMismatch");
}

// EC-17 for the larger counts: the repaired buffer is the protected message.
void buffer_equals_message() {
  Bytes sent = protected_message(p16);
  Rng rng(1717);
  int equal = 0;
  for (int c = 0; c < 200; ++c) {
    Bytes word = sent;
    corrupt(word, 1 + static_cast<int>(rng.below(8)), rng);
    Position row;
    auto r = packbin::unpack_repair(p16, word.data(), word.size(), row, 8);
    if (r.ok() && word == sent)
      ++equal;
  }
  expect(equal == 200, "EC-17 bytes that differ from the protected message after a repair: 0");
}

}  // namespace

int run_core_ecc_api_host_tests() {
  every_position_and_value_n2();
  seeded_recovery(p4, 4);
  seeded_recovery(p8, 8);
  seeded_recovery(p16, 16);
  seeded_refusals();
  seeded_shifts();
  text_survives_two_wrong_bytes();
  dispatch_repairs_the_type_byte();
  dispatch_refusals();
  dispatch_without_parity();
  buffer_equals_message();
  return check::failures();
}
