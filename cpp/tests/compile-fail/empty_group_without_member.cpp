#include "packbin/codec.hpp"

struct Row {
  bool b = false;
};

// A group with no fields and no member can never set its bit, even directly in flags.
constexpr auto s = packbin::scheme<Row>(1, packbin::flags(0, packbin::group(0)));

int main() { return s.type_number; }
