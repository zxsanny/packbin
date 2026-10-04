#include "packbin/codec.hpp"

struct Row {
  std::uint8_t a = 0;
  packbin::Opt<std::uint8_t> b;
};

// The `when` must take id 1, the id of its first child.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::u8<&Row::a>(0), packbin::when(7, packbin::eq(0, 1), packbin::u8<&Row::b>(1)));

int main() { return s.type_number; }
