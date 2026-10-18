#include "packbin/codec.hpp"

struct Row {
  packbin::View name;
};

// A string binds a Text<N> or a Packed; a View cannot hold a decoded string.
constexpr auto s = packbin::scheme<Row>(1, packbin::utf8<&Row::name>(0));

int main() { return s.type_number; }
