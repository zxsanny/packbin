#pragma once

#include "packbin/packbin.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <optional>
#include <vector>

namespace packbin {

void pack_nodes(std::vector<Field> const& nodes, Values const& values,
                std::vector<std::uint8_t>& out);
std::optional<ShortPacket> unpack_nodes(std::uint8_t const* data, std::size_t len,
                                        std::size_t& offset, std::vector<Field> const& nodes,
                                        Values& out, bool as_list);

std::string const& field_name(Field const& field);
bool values_equal(Value const& a, Value const& b);
bool is_present(Values const& values, std::string const& name);

void write_raw(std::vector<std::uint8_t>& out, std::uint8_t const* raw, int n, bool be);

template <typename T>
void write_num(std::vector<std::uint8_t>& out, T value, bool be) {
  std::uint8_t raw[sizeof(T)];
  std::memcpy(raw, &value, sizeof(T));
  write_raw(out, raw, static_cast<int>(sizeof(T)), be);
}

template <typename T>
T read_num(std::uint8_t const* p, bool be) {
  std::uint8_t raw[sizeof(T)];
  if (be) {
    for (std::size_t i = 0; i < sizeof(T); ++i)
      raw[i] = p[sizeof(T) - 1 - i];
  } else {
    std::memcpy(raw, p, sizeof(T));
  }
  T value{};
  std::memcpy(&value, raw, sizeof(T));
  return value;
}

Value const& require(Values const& values, std::string const& name);
ShortPacket make_short(std::string const& name, int needed, std::size_t left);
void append_value(Values& out, std::string const& name, Value value, bool as_list);
std::int64_t value_as_int(Value const& value);
std::int64_t borrowed_item_count(Field const& node, Values const& values);

}  // namespace packbin
