#include "packbin/codec.hpp"

#include "../core/scheme_depth_chains.hpp"

// 257 nested list element rows (an unbound chain): one level more than the limit of 256.
constexpr auto s = packbin::scheme<depth_chain::Row>(1, depth_chain::inner_lists<257>());

int main() { return s.type_number; }
