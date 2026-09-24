#pragma once

#include "packbin/packbin.hpp"

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace packbin {

void pack_nodes(std::vector<Field> const& nodes, Values const& values,
                std::vector<std::uint8_t>& out);
std::optional<ShortPacket> unpack_nodes(std::uint8_t const* data, std::size_t len,
                                        std::size_t& offset, std::vector<Field> const& nodes,
                                        Values& out, bool as_list);

}  // namespace packbin
