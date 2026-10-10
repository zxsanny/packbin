#include "packbin/codec.hpp"

struct Row {
  packbin::Opt<std::uint8_t> v;
  packbin::Opt<std::uint8_t> x;
  packbin::Opt<std::uint8_t> b;
};

// The only flag byte 0 is read inside a flags member, so the bit after the flags has none.
constexpr auto s = packbin::scheme<Row>(
    1,
    packbin::flags(0, packbin::group(0, packbin::u8<&Row::v>(0), packbin::flag_byte(0),
                                     packbin::flag_bit(0, packbin::u8<&Row::x>(1)))),
    packbin::flag_bit(0, packbin::u8<&Row::b>(2)));

int main() { return s.type_number; }
