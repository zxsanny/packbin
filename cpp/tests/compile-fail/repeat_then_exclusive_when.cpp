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

// R6 of the contract repeat-last.md: the field (id 2) under a `when` that cannot be taken together
// with the repeat's `when` still follows the repeat; the two conditions are not compared.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::u8<&Row::k>(0),
    packbin::when(1, packbin::eq(0, 1),
                  packbin::repeat<&Row::rounds>(1, packbin::u8<&Round::v>(1))),
    packbin::when(2, packbin::eq(0, 2), packbin::u8<&Row::x>(2)));

int main() { return s.type_number; }
