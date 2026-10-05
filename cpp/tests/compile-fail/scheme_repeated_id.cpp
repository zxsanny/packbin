#include "packbin/codec.hpp"

struct Row {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

// Order id 0 twice.
constexpr auto s = packbin::scheme<Row>(1, packbin::u8<&Row::a>(0), packbin::u8<&Row::b>(0));

int main() { return s.type_number; }
