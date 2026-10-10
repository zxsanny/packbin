#include "packbin/codec.hpp"

struct Row {
  packbin::Opt<std::uint8_t> v;
  packbin::Opt<std::uint8_t> x;
  packbin::Opt<std::uint8_t> b;
};

// The only flag byte 1 is read inside the child of a flag bit, so the bit after it has none.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::flag_byte(0),
    packbin::flag_bit(0, packbin::group(0, packbin::u8<&Row::v>(0), packbin::flag_byte(1),
                                        packbin::flag_bit(1, packbin::u8<&Row::x>(1)))),
    packbin::flag_bit(1, packbin::u8<&Row::b>(2)));

int main() { return s.type_number; }
