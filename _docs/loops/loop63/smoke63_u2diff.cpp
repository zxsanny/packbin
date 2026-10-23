#include <cstdio>
#include "packbin/packbin.hpp"
struct Kinds { std::uint8_t a = 0, b = 0, c = 0, d = 0; };
int main() {
  constexpr auto s4 = packbin::scheme<Kinds>(1, packbin::u2(packbin::u8<&Kinds::a>(0), packbin::u8<&Kinds::b>(1), packbin::u8<&Kinds::c>(2), packbin::u8<&Kinds::d>(3)));
  Kinds rows[3] = {{0,1,2,3},{1,4,0,0},{0,0,0,7}};
  for (auto& row : rows)
    for (std::size_t cap = 0; cap <= 3; ++cap) {
      std::uint8_t buf[8] = {0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA,0xAA};
      auto r = packbin::pack(s4, row, buf, cap);
      std::printf("cap %zu row %d%d%d%d: err %d off %zu field %d need %zu\n", cap, row.a,row.b,row.c,row.d, (int)r.error, r.offset, r.field, r.needed);
    }
}
