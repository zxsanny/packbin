#include "packbin/codec.hpp"

struct Row {
  std::uint8_t v = 0;
};

// Nine children do not fit in one flags byte.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::flags(0, packbin::u8(0), packbin::u8(1), packbin::u8(2), packbin::u8(3),
                      packbin::u8(4), packbin::u8(5), packbin::u8(6), packbin::u8(7),
                      packbin::u8(8)));

int main() { return s.type_number; }
