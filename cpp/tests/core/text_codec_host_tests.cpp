// Compact text codec (AZ-2655): scratch, Text<N> limits, hostile payloads, round trips, speed and
// the generated tables.
#include "packbin/packbin.hpp"

#include "check.hpp"
#include "load_factor.hpp"

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

using check::expect;
using packbin::Error;
using packbin::Text;

namespace {

struct Small {
  std::uint8_t a = 0;
  Text<4> s;
};

constexpr auto small_scheme =
    packbin::scheme<Small>(1, packbin::u8<&Small::a>(0), packbin::utf8<&Small::s>(1));

struct Line {
  Text<256> s;
};

constexpr auto line_scheme = packbin::scheme<Line>(1, packbin::utf8<&Line::s>(0));

void put(Line& l, char const* s) {
  l.s.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(l.s.data, s, l.s.len);
}

bool is(Line const& l, char const* s) {
  return l.s.len == std::strlen(s) && std::memcmp(l.s.data, s, l.s.len) == 0;
}

// AC-2: a Text<N> that is too small is TooMany with the full size, never a cut, and the fields
// before it keep their values.
void text_too_small() {
  // Arrange: u8 7, then "hello" (compact, 5 bytes of text).
  std::uint8_t wire[7] = {0x01, 0x07, 0x04, 0x8a, 0xa2, 0xd6, 0x70};
  Small row;
  // Act
  auto r = packbin::unpack(small_scheme, wire, sizeof(wire), row);
  // Assert
  expect(r.error == Error::TooMany && r.field == 1 && r.needed == 5 && row.a == 7 &&
             row.s.len == 0,
         "AC-2 Text<4> too small, earlier field kept");
  struct Five {
    Text<5> s;
  };
  constexpr auto five = packbin::scheme<Five>(1, packbin::utf8<&Five::s>(0));
  Five f;
  std::uint8_t one_field[6] = {0x01, 0x04, 0x8a, 0xa2, 0xd6, 0x70};
  auto fit = packbin::unpack(five, one_field, sizeof(one_field), f);
  expect(fit.ok() && f.s.len == 5 && std::memcmp(f.s.data, "hello", 5) == 0, "Text<5> fits");
}

// AC-3: a text that needs more scratch than given names its field and writes nothing for it; a
// larger scratch gives the vector bytes.
void scratch_too_small() {
  Line row;
  put(row, "привіт");  // 6 characters: 72 scratch bytes
  std::uint8_t buf[32];
  std::memset(buf, 0xEE, sizeof(buf));
  packbin::Scratch<5> small;
  auto e = packbin::pack(line_scheme, row, buf, sizeof(buf), small);
  expect(e.error == Error::ScratchTooSmall && e.field == 0 && e.needed == 72 && e.offset == 1,
         "AC-3 scratch too small names the field");
  bool untouched = true;
  for (std::size_t i = 1; i < sizeof(buf); ++i)
    untouched = untouched && buf[i] == 0xEE;
  expect(untouched, "AC-3 nothing written for the field");

  packbin::Scratch<6> enough;
  auto p = packbin::pack(line_scheme, row, buf, sizeof(buf), enough);
  expect(p.ok() && check::same_hex(buf, p.offset, "0105a37aa424e0"), "AC-3 enough scratch");

  auto none = packbin::pack(line_scheme, row, buf, sizeof(buf));
  expect(none.error == Error::ScratchTooSmall && none.needed == 72, "no scratch given");

  // Texts the format stores raw need none: one ASCII letter, and Chinese characters (each costs
  // more than the 3 bytes of UTF-8, so a parse cannot win).
  put(row, "a");
  auto a = packbin::pack(line_scheme, row, buf, sizeof(buf));
  expect(a.ok() && check::same_hex(buf, a.offset, "01021061"), "one letter needs no scratch");
  put(row, "\xe4\xb8\xad\xe6\x96\x87");
  auto cjk = packbin::pack(line_scheme, row, buf, sizeof(buf));
  expect(cjk.ok() && check::same_hex(buf, cjk.offset, "010710e4b8ade69687"),
         "a text a parse cannot shrink needs no scratch");
  Line empty;
  auto z = packbin::pack(line_scheme, empty, buf, sizeof(buf));
  expect(z.ok() && check::same_hex(buf, z.offset, "0100"), "empty text needs no scratch");

  // The scratch is reused for every string of a packet: it is sized for the longest one.
  struct Pair {
    Text<16> a;
    Text<16> b;
  };
  constexpr auto pair = packbin::scheme<Pair>(1, packbin::utf8<&Pair::a>(0),
                                              packbin::utf8<&Pair::b>(1));
  Pair two;
  two.a.len = 3;
  std::memcpy(two.a.data, "abc", 3);
  two.b.len = 11;
  std::memcpy(two.b.data, "hello world", 11);
  packbin::Scratch<10> ten;
  auto big = packbin::pack(pair, two, buf, sizeof(buf), ten);
  expect(big.error == Error::ScratchTooSmall && big.field == 1 && big.needed == 132,
         "the scratch fits the longest string");
  packbin::Scratch<11> eleven;
  auto good = packbin::pack(pair, two, buf, sizeof(buf), eleven);
  expect(good.ok(), "the scratch of the longest string serves every string");
}

// Pack refuses text that is not UTF-8, naming the field; the longest text, 65,535 bytes, is
// within the limit (a Text<N> cannot hold more).
void pack_refuses_bad_text() {
  struct Bad {
    Text<4> s;
  };
  constexpr auto bad = packbin::scheme<Bad>(1, packbin::utf8<&Bad::s>(0));
  std::uint8_t buf[64];
  packbin::Scratch<8> scratch;
  std::uint8_t const lone[][4] = {{0xC3, 0x28, 0, 0}, {0xED, 0xA0, 0x80, 0}, {0xC0, 0x80, 0, 0},
                                  {0xF4, 0x90, 0x80, 0x80}, {0xFF, 0, 0, 0}, {0x80, 0, 0, 0}};
  std::size_t const sizes[] = {2, 3, 2, 4, 1, 1};
  for (std::size_t i = 0; i < 6; ++i) {
    Bad row;
    row.s.len = static_cast<std::uint16_t>(sizes[i]);
    std::memcpy(row.s.data, lone[i], sizes[i]);
    auto r = packbin::pack(bad, row, buf, sizeof(buf), scratch);
    expect(r.error == Error::BadValue && r.field == 0, "invalid UTF-8 is refused on pack");
  }
  // 21,845 Chinese characters are 65,535 bytes: raw, so no scratch is needed.
  struct Big {
    Text<65535> s;
  };
  constexpr auto big_scheme = packbin::scheme<Big>(1, packbin::utf8<&Big::s>(0));
  static Big big;
  big.s.len = 65535;
  for (std::size_t i = 0; i + 2 < sizeof(big.s.data); i += 3) {
    big.s.data[i] = static_cast<char>(0xE4);
    big.s.data[i + 1] = static_cast<char>(0xB8);
    big.s.data[i + 2] = static_cast<char>(0xAD);
  }
  auto longest = packbin::pack(big_scheme, big, buf, sizeof(buf));
  expect(longest.error == Error::BufferFull && longest.needed == 3 + 65536,
         "65,535 bytes is within the limit");
}

// Deterministic generator for the random tests.
struct Rng {
  std::uint64_t x;
  std::uint32_t next() {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return static_cast<std::uint32_t>(x >> 16);
  }
};

struct Guard {
  std::uint8_t before[16];
  Text<400> s;
  std::uint8_t after[16];
};

constexpr auto guard_scheme = packbin::scheme<Guard>(1, packbin::utf8<&Guard::s>(0));

// AC-5: 100,000 random payloads: an error or a text of at most 6N + 8 bytes, never a write past
// the Text.
void random_payloads() {
  Rng rng{0x9E3779B97F4A7C15ull};
  static Guard g;
  std::uint8_t packet[128];
  std::size_t texts = 0;
  for (int i = 0; i < 100000; ++i) {
    std::size_t n = 1 + rng.next() % 40;
    packet[0] = 1;
    packet[1] = static_cast<std::uint8_t>(n);
    for (std::size_t k = 0; k < n; ++k)
      packet[2 + k] = static_cast<std::uint8_t>(rng.next());
    if (rng.next() % 4 != 0)  // most payloads start in a real mode, with a pad that fits
      packet[2] = static_cast<std::uint8_t>((packet[2] & ~0x1C) | ((rng.next() % 4) << 2));
    std::memset(g.before, 0xA5, sizeof(g.before));
    std::memset(g.after, 0xA5, sizeof(g.after));
    g.s.len = 0;
    auto r = packbin::unpack(guard_scheme, packet, 2 + n, g);
    bool guards = true;
    for (std::size_t k = 0; k < 16; ++k)
      guards = guards && g.before[k] == 0xA5 && g.after[k] == 0xA5;
    bool bounded = !r.ok() || g.s.len <= 6 * n + 8;
    expect(guards && bounded, "AC-5 random payload");
    texts += r.ok();
  }
  expect(texts > 1000, "AC-5 random payloads include texts");
}

// Random texts round trip, and the packed field is never larger than raw.
void random_round_trips() {
  static const std::uint32_t pool[] = {'a', 'z', 'k', ' ', '0', '9', '.', ',', 'A', 'Z', '\'', '\n',
                                       0x430, 0x44F, 0x456, 0x491, 0x401, 0x410, 0x42F, 0x451,
                                       0x4E8, 0xE9, 0x4E2D, 0x1F600};
  Rng rng{12345};
  std::uint8_t buf[512];
  packbin::Scratch<64> scratch;
  for (int i = 0; i < 20000; ++i) {
    Line row;
    std::size_t chars = 1 + rng.next() % 60;
    std::size_t len = 0;
    for (std::size_t c = 0; c < chars; ++c) {
      std::uint32_t cp = pool[rng.next() % (sizeof(pool) / sizeof(pool[0]))];
      if (cp < 0x80) {
        row.s.data[len++] = static_cast<char>(cp);
      } else if (cp < 0x800) {
        row.s.data[len++] = static_cast<char>(0xC0 | (cp >> 6));
        row.s.data[len++] = static_cast<char>(0x80 | (cp & 0x3F));
      } else if (cp < 0x10000) {
        row.s.data[len++] = static_cast<char>(0xE0 | (cp >> 12));
        row.s.data[len++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        row.s.data[len++] = static_cast<char>(0x80 | (cp & 0x3F));
      } else {
        row.s.data[len++] = static_cast<char>(0xF0 | (cp >> 18));
        row.s.data[len++] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        row.s.data[len++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        row.s.data[len++] = static_cast<char>(0x80 | (cp & 0x3F));
      }
    }
    row.s.len = static_cast<std::uint16_t>(len);
    auto p = packbin::pack(line_scheme, row, buf, sizeof(buf), scratch);
    Line back;
    auto u = packbin::unpack(line_scheme, buf, p.offset, back);
    bool same = u.ok() && back.s.len == row.s.len && std::memcmp(back.s.data, row.s.data, len) == 0;
    expect(p.ok() && same && p.offset <= 1 + 2 + len + 1, "random text round trip");
  }
}

// AC-7: 100,000 round trips of a 20-character Ukrainian string in at most one second.
void speed() {
  Line row;
  put(row, "Доброго ранку, друже");  // 20 characters
  std::uint8_t buf[64];
  packbin::Scratch<20> scratch;
  Line back;
  std::size_t good = 0;
  auto limit = load_factor::bound(1.0);
  auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < 100000; ++i) {
    auto p = packbin::pack(line_scheme, row, buf, sizeof(buf), scratch);
    auto u = packbin::unpack(line_scheme, buf, p.offset, back);
    good += p.ok() && u.ok() && back.s.len == row.s.len;
  }
  double seconds =
      std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
  std::printf("text speed: 100000 round trips of 20 characters in %.3f s\n", seconds);
  expect(good == 100000 && is(back, "Доброго ранку, друже"), "AC-7 round trips are correct");
  load_factor::expect_within(seconds, limit, "AC-7 100,000 round trips within one second");
}

// The committed tables are the emitter's output for fixtures/text/tables.json.
void tables_are_current() {
  int rc = std::system(
      "python3 ../scripts/text/emit_tables.py cpp --check include/packbin/text_tables.hpp "
      "< /dev/null");
  expect(rc == 0, "include/packbin/text_tables.hpp equals the emitter output");
}

}  // namespace

int run_core_text_codec_host_tests() {
  text_too_small();
  scratch_too_small();
  pack_refuses_bad_text();
  random_payloads();
  random_round_trips();
  speed();
  tables_are_current();
  return 0;
}
