// A constexpr scheme that declares a parity percentage above 100 does not compile.
#include "packbin/codec.hpp"

struct Row {
  std::uint8_t a = 0;
};

constexpr auto s = packbin::parity_percent(packbin::scheme<Row>(1, packbin::u8<&Row::a>(0)), 101);

int main() { return s.parity; }
