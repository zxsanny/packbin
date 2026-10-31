// Built with -DPACKBIN_NO_ECC: a constexpr scheme that declares a parity percentage does not compile.
#include "packbin/codec.hpp"

struct Row {
  std::uint8_t a = 0;
};

constexpr auto s = packbin::parity_percent(packbin::scheme<Row>(1, packbin::u8<&Row::a>(0)), 25);

int main() { return s.parity; }
