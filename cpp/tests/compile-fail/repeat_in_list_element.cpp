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

// R7 of the contract repeat-last.md: a repeat (id 1) inside a list element would read the next
// element as its rounds. The list is unbound: a list bound to a member takes no row element.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::list(packbin::group(0, packbin::u8(0), packbin::repeat(1, packbin::u8(1)))));

int main() { return s.type_number; }
