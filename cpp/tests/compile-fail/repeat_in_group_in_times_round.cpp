#include "packbin/codec.hpp"

struct Round {
  std::uint8_t v = 0;
};

struct Outer {
  packbin::Array<Round, 4> inner;
};

struct Row {
  std::uint8_t k = 0;
  packbin::Array<Outer, 4> outer;
};

// Rule 3 of the contract repeat-last.md: a group does not hide a repeat from the round around it.
// The repeat (id 1) inside the group of a times round would read the next round as its own rounds.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::u8<&Row::k>(0),
    packbin::times<&Row::outer>(
        1, 0, packbin::group(1, packbin::repeat<&Outer::inner>(1, packbin::u8<&Round::v>(1)))));

int main() { return s.type_number; }
