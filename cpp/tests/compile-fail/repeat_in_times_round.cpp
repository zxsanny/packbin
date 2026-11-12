#include "packbin/codec.hpp"

struct Round {
  std::uint8_t v = 0;
};

struct Row {
  std::uint8_t k = 0;
  std::uint8_t x = 0;
  packbin::Array<Round, 4> rounds;
  packbin::Array<Round, 4> more;
};

// R9 of the contract repeat-last.md: a repeat (id 1) inside a times round would read the next
// round as its own rounds. A times inside a round has a count and builds.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::u8<&Row::k>(0), packbin::times(1, 0, packbin::repeat(1, packbin::u8(1))));

int main() { return s.type_number; }
