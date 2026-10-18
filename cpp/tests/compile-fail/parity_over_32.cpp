// A constexpr scheme that declares more than 32 parity bytes does not compile.
#include "packbin/codec.hpp"

struct Row {
  std::uint8_t a = 0;
};

constexpr auto s = packbin::parity(packbin::scheme<Row>(1, packbin::u8<&Row::a>(0)), 33);

int main() { return s.parity; }
