#include "packbin/codec.hpp"

struct Row {
  packbin::Opt<std::uint8_t> a;
  std::uint8_t b = 0;
};

// The `when` at id 0 names field 1, which comes after it.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::when(0, packbin::eq(1, 1), packbin::u8<&Row::a>(0)), packbin::u8<&Row::b>(1));

int main() { return s.type_number; }
