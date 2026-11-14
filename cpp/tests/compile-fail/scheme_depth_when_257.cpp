#include "packbin/codec.hpp"

#include "../core/scheme_depth_chains.hpp"

// 257 nested `when`s, written by a recursive builder: one level more than the limit of 256.
constexpr auto s = packbin::scheme<depth_chain::Row>(
    1, packbin::u8<&depth_chain::Row::a>(0),
    depth_chain::whens<257>(packbin::u8<&depth_chain::Row::b>(1)));

int main() { return s.type_number; }
