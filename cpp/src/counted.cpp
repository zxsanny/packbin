#include "counted.hpp"

#include <stdexcept>

namespace packbin {
namespace {

std::uint64_t as_count(Value const& value) {
  if (auto const* v = std::get_if<std::uint8_t>(&value.data))
    return *v;
  if (auto const* v = std::get_if<std::uint16_t>(&value.data))
    return *v;
  if (auto const* v = std::get_if<std::uint32_t>(&value.data))
    return *v;
  if (auto const* v = std::get_if<std::uint64_t>(&value.data))
    return *v;
  if (auto const* v = std::get_if<std::int8_t>(&value.data))
    return static_cast<std::uint64_t>(*v);
  if (auto const* v = std::get_if<std::int16_t>(&value.data))
    return static_cast<std::uint64_t>(*v);
  if (auto const* v = std::get_if<std::int32_t>(&value.data))
    return static_cast<std::uint64_t>(*v);
  if (auto const* v = std::get_if<std::int64_t>(&value.data))
    return static_cast<std::uint64_t>(*v);
  throw std::runtime_error("expected integer count");
}

Value const& require(Values const& values, std::string const& name) {
  auto it = values.find(name);
  if (it == values.end())
    throw std::runtime_error("missing field " + name);
  return it->second;
}

void append_value(Values& out, std::string const& name, Value value, bool as_list) {
  if (!as_list) {
    out[name] = std::move(value);
    return;
  }
  auto it = out.find(name);
  if (it == out.end()) {
    auto list = std::make_shared<ValueList>();
    list->items.push_back(std::move(value));
    out.emplace(name, Value{list});
    return;
  }
  if (auto* list = std::get_if<Value::List>(&it->second.data)) {
    if (*list)
      (*list)->items.push_back(std::move(value));
    return;
  }
  auto list = std::make_shared<ValueList>();
  list->items.push_back(it->second);
  list->items.push_back(std::move(value));
  it->second = Value{list};
}

ShortPacket missing(std::string const& name, std::size_t needed, std::size_t left) {
  return ShortPacket{name, needed, left};
}

void pack_sized(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
  auto count = as_count(require(values, node.count_name));
  auto const& raw = std::get<Value::Bytes>(require(values, node.name).data);
  if (raw.size() != count)
    throw std::runtime_error(node.name + ": payload length");
  out.insert(out.end(), raw.begin(), raw.end());
}

void pack_u2(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
  auto nbytes = (node.children.size() + 3) / 4;
  std::vector<std::uint8_t> raw(nbytes, 0);
  for (std::size_t i = 0; i < node.children.size(); ++i) {
    auto value = as_count(require(values, node.children[i].name));
    if (value > 3)
      throw std::runtime_error(node.children[i].name + ": expected 2-bit int");
    raw[i / 4] = static_cast<std::uint8_t>(raw[i / 4] | (value << ((i % 4) * 2)));
  }
  out.insert(out.end(), raw.begin(), raw.end());
}

void pack_bits(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
  auto count = as_count(require(values, node.count_name));
  auto const& list = std::get<Value::List>(require(values, node.name).data);
  if (!list || list->items.size() != count)
    throw std::runtime_error(node.name + ": expected bit list");
  auto nbytes = (count + 7) / 8;
  std::vector<std::uint8_t> raw(nbytes, 0);
  for (std::size_t i = 0; i < count; ++i) {
    auto bit = as_count(list->items[i]);
    if (bit > 1)
      throw std::runtime_error(node.name + ": expected 0 or 1");
    raw[i / 8] = static_cast<std::uint8_t>(raw[i / 8] | (bit << (i % 8)));
  }
  out.insert(out.end(), raw.begin(), raw.end());
}

std::optional<ShortPacket> unpack_sized(std::uint8_t const* data, std::size_t len,
                                        std::size_t& offset, Field const& node, Values& out,
                                        bool as_list) {
  auto count = as_count(require(out, node.count_name));
  auto left = len - offset;
  if (left < count)
    return missing(node.name, count, left);
  Value::Bytes raw(data + offset, data + offset + count);
  offset += count;
  append_value(out, node.name, Value{std::move(raw)}, as_list);
  return std::nullopt;
}

std::optional<ShortPacket> unpack_u2(std::uint8_t const* data, std::size_t len, std::size_t& offset,
                                     Field const& node, Values& out, bool as_list) {
  auto nbytes = (node.children.size() + 3) / 4;
  auto left = len - offset;
  if (left < nbytes)
    return missing(node.children.front().name, nbytes, left);
  for (std::size_t i = 0; i < node.children.size(); ++i) {
    auto value = static_cast<std::uint8_t>((data[offset + i / 4] >> ((i % 4) * 2)) & 3);
    append_value(out, node.children[i].name, Value{value}, as_list);
  }
  offset += nbytes;
  return std::nullopt;
}

std::optional<ShortPacket> unpack_bits(std::uint8_t const* data, std::size_t len,
                                       std::size_t& offset, Field const& node, Values& out,
                                       bool as_list) {
  auto count = as_count(require(out, node.count_name));
  auto nbytes = (count + 7) / 8;
  auto left = len - offset;
  if (left < nbytes)
    return missing(node.name, nbytes, left);
  auto list = std::make_shared<ValueList>();
  list->items.reserve(count);
  for (std::uint64_t i = 0; i < count; ++i) {
    auto bit = static_cast<std::uint8_t>((data[offset + i / 8] >> (i % 8)) & 1);
    list->items.push_back(Value{bit});
  }
  offset += nbytes;
  append_value(out, node.name, Value{list}, as_list);
  return std::nullopt;
}

void pack_utf8(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
  auto const& text = std::get<std::string>(require(values, node.name).data);
  if (text.size() > 65535)
    throw std::runtime_error(node.name + ": utf-8 length");
  auto n = static_cast<std::uint16_t>(text.size());
  out.push_back(static_cast<std::uint8_t>(n & 0xff));
  out.push_back(static_cast<std::uint8_t>((n >> 8) & 0xff));
  out.insert(out.end(), reinterpret_cast<std::uint8_t const*>(text.data()),
             reinterpret_cast<std::uint8_t const*>(text.data()) + text.size());
}

std::optional<ShortPacket> unpack_utf8(std::uint8_t const* data, std::size_t len,
                                        std::size_t& offset, Field const& node, Values& out,
                                        bool as_list) {
  auto left = len - offset;
  if (left < 2)
    return missing(node.name, 2, left);
  auto count = static_cast<std::size_t>(data[offset] | (data[offset + 1] << 8));
  offset += 2;
  left = len - offset;
  if (left < count)
    return missing(node.name, count, left);
  std::string text(reinterpret_cast<char const*>(data + offset), count);
  offset += count;
  append_value(out, node.name, Value{std::move(text)}, as_list);
  return std::nullopt;
}

}  // namespace

void pack_counted(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
  switch (node.kind) {
    case Field::Kind::Sized:
      pack_sized(node, values, out);
      break;
    case Field::Kind::U2:
      pack_u2(node, values, out);
      break;
    case Field::Kind::Bits:
      pack_bits(node, values, out);
      break;
    case Field::Kind::Utf8:
      pack_utf8(node, values, out);
      break;
    default:
      throw std::runtime_error("not a counted field");
  }
}

std::optional<ShortPacket> unpack_counted(std::uint8_t const* data, std::size_t len,
                                          std::size_t& offset, Field const& node, Values& out,
                                          bool as_list) {
  switch (node.kind) {
    case Field::Kind::Sized:
      return unpack_sized(data, len, offset, node, out, as_list);
    case Field::Kind::U2:
      return unpack_u2(data, len, offset, node, out, as_list);
    case Field::Kind::Utf8:
      return unpack_utf8(data, len, offset, node, out, as_list);
    case Field::Kind::Bits:
      return unpack_bits(data, len, offset, node, out, as_list);
    default:
      throw std::runtime_error("not a counted field");
  }
}

}  // namespace packbin
