#include "packbin/codec.hpp"

struct Row {
  packbin::Array<packbin::View, 4> roles;
};

constexpr auto s = packbin::scheme<Row>(1, packbin::list<&Row::roles>(packbin::utf8(0)));

int main() { return s.type_number; }
