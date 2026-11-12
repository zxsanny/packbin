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

// R1 of the contract repeat-last.md: a repeat has no count on the wire and reads to the end of the
// packet, so the field after it (id 1) would be read as one more round.
constexpr auto s =
    packbin::scheme<Row>(1, packbin::repeat<&Row::rounds>(0, packbin::u8<&Round::v>(0)),
                         packbin::u8<&Row::x>(1));

int main() { return s.type_number; }
