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

// R5 of the contract repeat-last.md: a second repeat is read as more rounds of the first; its
// member (id 1) is the first field after the first repeat.
constexpr auto s =
    packbin::scheme<Row>(1, packbin::repeat<&Row::rounds>(0, packbin::u8<&Round::v>(0)),
                         packbin::repeat<&Row::more>(1, packbin::u8<&Round::v>(1)));

int main() { return s.type_number; }
