#include "packbin/codec.hpp"

#include "../core/scheme_depth_chains.hpp"

// 257 nested groups, written by a recursive builder: one level more than the limit of 256.
constexpr auto s = packbin::scheme<depth_chain::Row>(
    1, depth_chain::groups<257>(packbin::u8<&depth_chain::Row::b>(0)));

int main() { return s.type_number; }
