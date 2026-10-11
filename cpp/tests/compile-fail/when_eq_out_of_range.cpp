#include "packbin/codec.hpp"

struct Row {
  packbin::Opt<std::uint8_t> s;
  packbin::Opt<std::uint8_t> v;
};

// A u8 never holds 300, so a `when` on it could never match.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::u8<&Row::s>(0),
    packbin::when(1, packbin::eq(0, 300), packbin::u8<&Row::v>(1)));

int main() { return s.type_number; }
