#include "packbin/packbin.hpp"

#include <iostream>

int main() {
  auto layout = packbin::scheme(0x40, {
      packbin::u16("sid"),
      packbin::i32("lat"),
      packbin::i32("lon"),
      packbin::u8("profile"),
      packbin::flags("motion",
                     {packbin::u16("heading"), packbin::u8("speed"), packbin::i16("altitude")}),
  });
  packbin::Values values;
  values.emplace("sid", packbin::Value{std::uint16_t{1}});
  values.emplace("lat", packbin::Value{std::int32_t{500000000}});
  values.emplace("lon", packbin::Value{std::int32_t{300000000}});
  values.emplace("profile", packbin::Value{std::uint8_t{1}});
  std::cout << packbin::to_hex(packbin::pack(layout, values)) << '\n';
}
