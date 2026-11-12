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

// R3 of the contract repeat-last.md: the field (id 1) after the `flags` that holds a repeat follows
// the repeat whenever the repeat wrote a round.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::flags(0, packbin::repeat<&Row::rounds>(0, packbin::u8<&Round::v>(0))),
    packbin::u8<&Row::x>(1));

int main() { return s.type_number; }
