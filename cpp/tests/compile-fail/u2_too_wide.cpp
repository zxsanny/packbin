#include "packbin/codec.hpp"

#include <cstddef>
#include <utility>

struct Row {
  std::uint8_t v = 0;
};

// 65 two-bit children need 17 bytes; a u2 holds at most 64 (16 bytes).
template <std::size_t... I>
constexpr auto wide(std::index_sequence<I...>) {
  return packbin::scheme<Row>(1, packbin::u2(packbin::u8(static_cast<int>(I))...));
}

constexpr auto s = wide(std::make_index_sequence<65>{});

int main() { return s.type_number; }
