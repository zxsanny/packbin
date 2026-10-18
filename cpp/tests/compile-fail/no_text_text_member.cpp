// Built with -DPACKBIN_NO_TEXT.
#include "packbin/codec.hpp"

struct Row {
  packbin::Text<16> name;
};

constexpr auto s = packbin::scheme<Row>(1, packbin::utf8<&Row::name>(0));

int main() { return s.type_number; }
