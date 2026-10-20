// AZ-2737 (CS-D7, TW-5): one 65,535-character text written in 200 rounds of a `times` group packs
// and unpacks within 3 seconds nominal. Python, TypeScript, Go, Swift, Rust and (since AZ-2737) Java keep the
// encoded text of the last round and meet 1 second; the C++ core has no heap and no cache, so it runs the optimal
// parse in every round: 8 to 9.5 ms a round, 1.9 s on gcc:16 at load factor 1.00. The owner chose a 3 s bound
// with a ticket for a later shortcut (2026-10-20, loop 46). Host-only: the row holds 200 x Text<65535> (13 MB),
// the packet is as large and the scratch is Scratch<65535> (786 KB), all kept off the stack.
#include "packbin/packbin.hpp"

#include "check.hpp"
#include "load_factor.hpp"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
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
// 3 s nominal times the load factor.
void two_hundred_rounds_of_65535_characters_within_three_seconds() {
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
  auto limit = load_factor::bound(3.0);

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

}  // namespace

int run_core_text_repeat_host_tests() {
  two_hundred_rounds_of_65535_characters_within_three_seconds();
  return 0;
}
