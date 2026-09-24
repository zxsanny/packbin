#include "packbin/packbin.hpp"

#include <iostream>

int main() {
  auto layout = packbin::scheme(0x40, {
      packbin::u16(0),
      packbin::i32(1),
      packbin::i32(2),
      packbin::u8(3),
      packbin::flags({packbin::u16(4), packbin::u8(5), packbin::i16(6)}),
  });
  packbin::Values values;
  values.emplace("0", packbin::Value{std::uint16_t{1}});
  values.emplace("1", packbin::Value{std::int32_t{500000000}});
  values.emplace("2", packbin::Value{std::int32_t{300000000}});
  values.emplace("3", packbin::Value{std::uint8_t{1}});
  std::cout << packbin::to_hex(packbin::BinaryPacker::pack(layout, values)) << '\n';
}
