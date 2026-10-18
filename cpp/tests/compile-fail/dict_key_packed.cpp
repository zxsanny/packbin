#include "packbin/codec.hpp"

struct Row {
  packbin::Array<packbin::Entry<std::uint8_t, packbin::Packed>, 4> access;
};

// Keys are ordered and checked for repeats as decoded text: a Packed cannot be a key.
constexpr auto s = packbin::scheme<Row>(1, packbin::dict<&Row::access>(packbin::u8(0)));

int main() { return s.type_number; }
