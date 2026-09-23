#pragma once

#include "packbin/packbin.hpp"

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace packbin {

void pack_counted(Field const& node, Values const& values, std::vector<std::uint8_t>& out);
std::optional<ShortPacket> unpack_counted(std::uint8_t const* data, std::size_t len,
                                          std::size_t& offset, Field const& node, Values& out,
                                          bool as_list);

}  // namespace packbin
