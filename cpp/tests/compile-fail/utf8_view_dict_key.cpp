#include "packbin/codec.hpp"

struct Row {
  packbin::Array<packbin::Entry<std::uint8_t, packbin::View>, 4> access;
};

constexpr auto s = packbin::scheme<Row>(1, packbin::dict<&Row::access>(packbin::u8(0)));

int main() { return s.type_number; }
