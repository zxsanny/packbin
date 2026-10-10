#include "packbin/codec.hpp"

struct Row {
  bool on = false;
  packbin::Opt<std::uint8_t> v;
};

// A false bool is absent on the wire, so a `when` on it could never match on unpack.
constexpr auto s = packbin::scheme<Row>(
    1, packbin::flags(0, packbin::boolean<&Row::on>(0)),
    packbin::when(1, packbin::eq(0, false), packbin::u8<&Row::v>(1)));

int main() { return s.type_number; }
