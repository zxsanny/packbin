// AZ-2737 (CS-D7, TW-5), AZ-2742: one 65,535-character text written in 200 rounds of a `times` group
// packs and unpacks within 1 second nominal. Python, TypeScript, Go, Swift, Rust and Java keep the encoded text of
// the last round; the C++ core has no heap, so it keeps one thing in the caller's scratch: the payload offset and
// the length of the last field written raw, and a round whose text equals that field skips the optimal parse
// (8 to 9.5 ms a round, 1.9 s for the 200 rounds on gcc:16 at load factor 1.00). A compact field has no memo.
// Host-only: the row holds 200 x Text<65535> (13 MB), the packet is as large and the scratch is
// Scratch<65535> (786 KB), all kept off the stack.
#include "packbin/packbin.hpp"

#include "check.hpp"
#include "load_factor.hpp"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

using check::expect;
using packbin::Array;
using packbin::Error;
using packbin::Text;
namespace pb = packbin;

namespace {

constexpr std::size_t kChars = 65535;
constexpr std::size_t kRounds = 200;

struct Round {
  Text<kChars> s;
};

struct Repeated {
  std::uint8_t n = 0;
  Array<Round, kRounds> rounds;
};

// u8 n; times(n) { utf8 s }
constexpr auto repeated_scheme = pb::scheme<Repeated>(
    1, pb::u8<&Repeated::n>(0), pb::times<&Repeated::rounds>(1, 0, pb::utf8<&Round::s>(1)));

// The type byte, the count byte, then per round the count header (3 bytes for 65,536) and the field
// (the raw prefix byte and the UTF-8 text; the compact form of "q" x 65,535 is not smaller).
constexpr std::size_t kPacketCap = 2 + kRounds * (3 + 1 + kChars);

double seconds_since(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
}

// AC-1 (TW-5): 200 rounds of "q" x 65,535 pack, and unpack to rounds equal to the input, within
// 1 s nominal times the load factor.
void two_hundred_rounds_of_65535_characters_within_one_second() {
  // Arrange
  auto input = std::make_unique<Repeated>();
  input->n = static_cast<std::uint8_t>(kRounds);
  input->rounds.count = static_cast<std::uint16_t>(kRounds);
  for (std::size_t i = 0; i < kRounds; ++i) {
    input->rounds.items[i].s.len = static_cast<std::uint16_t>(kChars);
    std::memset(input->rounds.items[i].s.data, 'q', kChars);
  }
  auto output = std::make_unique<Repeated>();
  std::vector<std::uint8_t> packet(kPacketCap);
  static pb::Scratch<kChars> scratch;
  auto limit = load_factor::bound(1.0);

  // Act
  auto start = std::chrono::steady_clock::now();
  auto packed = pb::pack(repeated_scheme, *input, packet.data(), packet.size(), scratch);
  double pack_seconds = seconds_since(start);
  auto unpack_start = std::chrono::steady_clock::now();
  auto unpacked = pb::unpack(repeated_scheme, packet.data(), packed.offset, *output);
  double unpack_seconds = seconds_since(unpack_start);
  double seconds = seconds_since(start);

  // Assert
  std::printf("text repeat: %zu rounds of %zu characters, pack %.3f s, unpack %.3f s, packet %zu bytes\n",
              kRounds, kChars, pack_seconds, unpack_seconds, packed.offset);
  expect(packed.ok(), "AC-1 200 rounds of 65,535 characters pack");
  expect(packed.offset > kRounds * kChars, "AC-1 the packet holds every round");
  expect(unpacked.ok() && unpacked.offset == packed.offset, "AC-1 the packet unpacks to its end");
  bool equal = output->n == input->n && output->rounds.count == input->rounds.count;
  for (std::size_t i = 0; equal && i < kRounds; ++i) {
    Text<kChars> const& want = input->rounds.items[i].s;
    Text<kChars> const& got = output->rounds.items[i].s;
    equal = got.len == want.len && std::memcmp(got.data, want.data, want.len) == 0;
  }
  expect(equal, "AC-1 every unpacked round equals the input");
  load_factor::expect_within(seconds, limit, "AC-1 200 rounds of 65,535 characters packed and unpacked");
}

constexpr std::size_t kSmallChars = 300;
constexpr std::size_t kSmallRounds = 6;

struct SmallRound {
  Text<kSmallChars> s;
};

struct SmallRepeated {
  std::uint8_t n = 0;
  Array<SmallRound, kSmallRounds> rounds;
};

constexpr auto small_scheme = pb::scheme<SmallRepeated>(
    1, pb::u8<&SmallRepeated::n>(0),
    pb::times<&SmallRepeated::rounds>(1, 0, pb::utf8<&SmallRound::s>(1)));

// The packet of `texts` as rounds of `small_scheme`; empty on a pack failure.
std::vector<std::uint8_t> pack_small(std::vector<std::string> const& texts) {
  SmallRepeated row;
  row.n = static_cast<std::uint8_t>(texts.size());
  row.rounds.count = static_cast<std::uint16_t>(texts.size());
  for (std::size_t i = 0; i < texts.size(); ++i) {
    row.rounds.items[i].s.len = static_cast<std::uint16_t>(texts[i].size());
    std::memcpy(row.rounds.items[i].s.data, texts[i].data(), texts[i].size());
  }
  static pb::Scratch<kSmallChars> scratch;
  std::vector<std::uint8_t> packet(2 + kSmallRounds * (3 + 1 + 4 * kSmallChars));
  auto r = pb::pack(small_scheme, row, packet.data(), packet.size(), scratch);
  packet.resize(r.ok() ? r.offset : 0);
  return packet;
}

// AC-2: every round packs to the bytes it packs to alone (type byte and count byte, then the fields):
// repeated raw texts, a raw text after a compact one, a changed last character, a longer text with the
// same start, a shorter one, compact texts repeated, and the empty text between two equal raw texts.
void rounds_pack_to_the_bytes_each_packs_to_alone() {
  // Arrange
  std::string raw(200, 'q');
  std::string changed = raw;
  changed.back() = 'x';
  std::string longer = raw + "q";
  std::string shorter = raw.substr(0, 199);
  std::string compact = "hello world hello world";
  // Raw as a whole (the q's lose to the raw form), though its first 23 characters alone compact.
  std::string raw_with_prefix = compact + std::string(250, 'q');
  std::string cyr = "\xD0\x9F\xD1\x80\xD0\xB8\xD0\xB2\xD1\x96\xD1\x82";
  std::vector<std::vector<std::string>> cases = {
      {raw, raw, raw},      {raw, compact, raw},  {raw, changed, raw}, {raw, longer, raw, shorter, raw},
      {compact, compact},   {cyr, cyr, raw, raw}, {raw, "", raw},      {raw, raw, compact, compact, raw, raw},
      {raw_with_prefix, compact, raw_with_prefix},
  };
  std::vector<std::uint8_t> whole = pack_small({raw_with_prefix});
  std::vector<std::uint8_t> prefix = pack_small({compact});
  std::vector<std::uint8_t> raw_alone = pack_small({raw});
  expect(raw_alone.size() > 4 && raw_alone[4] == 0x10, "AC-2 the q text is written raw");
  expect(whole.size() > 4 && whole[4] == 0x10, "AC-2 the long text is written raw");
  expect(prefix.size() > 2 && prefix[2] < compact.size() + 1,
         "AC-2 its prefix alone is written compact (a field smaller than the raw form)");

  for (auto const& texts : cases) {
    // Act
    std::vector<std::uint8_t> together = pack_small(texts);
    std::vector<std::uint8_t> expected(2);
    for (auto const& t : texts) {
      std::vector<std::uint8_t> alone = pack_small({t});
      expected.insert(expected.end(), alone.begin() + 2, alone.end());
    }

    // Assert
    expect(together.size() > 2, "AC-2 the rounds pack");
    if (together.size() > 2) {
      expected[0] = together[0];
      expected[1] = static_cast<std::uint8_t>(texts.size());
    }
    expect(together == expected, "AC-2 the rounds equal the fields packed alone");
  }
}

// AC-2: a Scratch that holds a memo of an earlier call (or of a parse) is not believed. The memo points at a
// raw field of 23 bytes at offset 5 of a buffer that already holds the compact text there; `pack` must still
// write the compact form, the one a fresh scratch gives.
void a_memo_left_in_the_scratch_is_not_believed() {
  // Arrange
  std::string compact = "hello world hello world";
  std::vector<std::uint8_t> want = pack_small({compact});
  SmallRepeated row;
  row.n = 1;
  row.rounds.count = 1;
  row.rounds.items[0].s.len = static_cast<std::uint16_t>(compact.size());
  std::memcpy(row.rounds.items[0].s.data, compact.data(), compact.size());
  static pb::Scratch<kSmallChars> scratch;
  scratch.words[0] = 4;
  scratch.words[1] = static_cast<std::uint32_t>(compact.size());
  std::vector<std::uint8_t> packet(2 + kSmallRounds * (3 + 1 + 4 * kSmallChars), 0);
  std::memcpy(packet.data() + 5, compact.data(), compact.size());

  // Act
  auto r = pb::pack(small_scheme, row, packet.data(), packet.size(), scratch);
  packet.resize(r.ok() ? r.offset : 0);

  // Assert
  expect(r.ok() && packet == want, "AC-2 a memo left in the scratch is not believed");
}

// AC-2: a compact result leaves no memo. The parse overwrites Scratch words 0 and 1 with its own cost cells
// (for "hello world hello world" word 0 is 103 and word 1 a packed delta), so `encode_field` must clear word 0
// after it writes a compact field; a stale word 0 would let a later text of the right length be compared with
// whatever the buffer holds at that offset. Word 0 is 0 after a compact field, also right after a raw one.
void a_compact_result_leaves_no_memo_in_the_scratch() {
  // Arrange
  std::string raw(200, 'q');
  std::string compact = "hello world hello world";
  static pb::Scratch<kSmallChars> scratch;
  auto pack_rounds = [&](std::vector<std::string> const& texts) {
    SmallRepeated row;
    row.n = static_cast<std::uint8_t>(texts.size());
    row.rounds.count = static_cast<std::uint16_t>(texts.size());
    for (std::size_t i = 0; i < texts.size(); ++i) {
      row.rounds.items[i].s.len = static_cast<std::uint16_t>(texts[i].size());
      std::memcpy(row.rounds.items[i].s.data, texts[i].data(), texts[i].size());
    }
    std::vector<std::uint8_t> packet(2 + kSmallRounds * (3 + 1 + 4 * kSmallChars));
    return pb::pack(small_scheme, row, packet.data(), packet.size(), scratch);
  };

  // Act
  auto after_raw = pack_rounds({raw});
  std::uint32_t memo_after_raw = scratch.words[0];
  auto after_compact = pack_rounds({raw, compact});
  std::uint32_t memo_after_compact = scratch.words[0];
  scratch.words[0] = 1;
  auto compact_first = pack_rounds({compact});
  std::uint32_t memo_after_compact_first = scratch.words[0];

  // Assert
  expect(after_raw.ok() && after_compact.ok() && compact_first.ok(), "AC-2 the rounds pack");
  expect(memo_after_raw != 0, "AC-2 a raw field leaves a memo (the check below is not vacuous)");
  expect(memo_after_compact == 0, "AC-2 a compact field after a raw one clears the memo");
  expect(memo_after_compact_first == 0, "AC-2 a compact field clears a stale memo");
}

}  // namespace

int run_core_text_repeat_host_tests() {
  two_hundred_rounds_of_65535_characters_within_one_second();
  rounds_pack_to_the_bytes_each_packs_to_alone();
  a_memo_left_in_the_scratch_is_not_believed();
  a_compact_result_leaves_no_memo_in_the_scratch();
  return 0;
}
