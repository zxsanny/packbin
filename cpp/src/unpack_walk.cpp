#include "walk.hpp"
#include "counted.hpp"

namespace packbin {

std::optional<ShortPacket> unpack_nodes(std::uint8_t const* data, std::size_t len,
                                    std::size_t& offset, std::vector<Field> const& nodes,
                                    Values& out, bool as_list);

std::optional<ShortPacket> unpack_one(std::uint8_t const* data, std::size_t len,
                                  std::size_t& offset, Field const& node, Values& out,
                                  bool as_list) {
  auto left = [&] { return len - offset; };

  switch (node.kind) {
    case Field::Kind::U8:
    case Field::Kind::U16:
    case Field::Kind::U32:
    case Field::Kind::U64:
    case Field::Kind::I8:
    case Field::Kind::I16:
    case Field::Kind::I32:
    case Field::Kind::I64:
    case Field::Kind::F32:
    case Field::Kind::F64: {
      if (left() < static_cast<std::size_t>(node.byte_count))
        return make_short(node.name, node.byte_count, left());
      std::uint8_t const* p = data + offset;
      Value value;
      switch (node.kind) {
        case Field::Kind::U8:
          value = Value{p[0]};
          break;
        case Field::Kind::U16:
          value = Value{read_num<std::uint16_t>(p, node.big_endian)};
          break;
        case Field::Kind::U32:
          value = Value{read_num<std::uint32_t>(p, node.big_endian)};
          break;
        case Field::Kind::U64:
          value = Value{read_num<std::uint64_t>(p, node.big_endian)};
          break;
        case Field::Kind::I8:
          value = Value{static_cast<std::int8_t>(p[0])};
          break;
        case Field::Kind::I16:
          value = Value{read_num<std::int16_t>(p, node.big_endian)};
          break;
        case Field::Kind::I32:
          value = Value{read_num<std::int32_t>(p, node.big_endian)};
          break;
        case Field::Kind::I64:
          value = Value{read_num<std::int64_t>(p, node.big_endian)};
          break;
        case Field::Kind::F32:
          value = Value{read_num<float>(p, node.big_endian)};
          break;
        case Field::Kind::F64:
          value = Value{read_num<double>(p, node.big_endian)};
          break;
        default:
          break;
      }
      offset += static_cast<std::size_t>(node.byte_count);
      append_value(out, node.name, std::move(value), as_list);
      return std::nullopt;
    }
    case Field::Kind::Bytes: {
      if (left() < static_cast<std::size_t>(node.byte_count))
        return make_short(node.name, node.byte_count, left());
      Value::Bytes raw(data + offset, data + offset + node.byte_count);
      offset += static_cast<std::size_t>(node.byte_count);
      append_value(out, node.name, Value{std::move(raw)}, as_list);
      return std::nullopt;
    }
    case Field::Kind::Bool:
      append_value(out, node.name, Value{std::uint8_t{1}}, as_list);
      return std::nullopt;
    case Field::Kind::Flags: {
      if (left() < 1)
        return make_short(node.name, 1, left());
      std::uint8_t flag = data[offset++];
      out[node.name] = Value{flag};
      node.group->unpacked = flag;
      for (std::size_t i = 0; i < node.children.size(); ++i) {
        if ((flag & (1u << i)) == 0)
          continue;
        auto const& bit = node.children[i];
        auto err = unpack_one(data, len, offset, bit.inner ? *bit.inner : bit, out, as_list);
        if (err)
          return err;
      }
      return std::nullopt;
    }
    case Field::Kind::FlagByte: {
      if (left() < 1)
        return make_short(node.name, 1, left());
      std::uint8_t flag = data[offset++];
      out[node.name] = Value{flag};
      node.group->unpacked = flag;
      return std::nullopt;
    }
    case Field::Kind::FlagBit: {
      if ((node.group->unpacked & (1u << node.bit_index)) == 0)
        return std::nullopt;
      return unpack_one(data, len, offset, *node.inner, out, as_list);
    }
    case Field::Kind::When: {
      auto it = out.find(node.pred.field);
      if (it == out.end() || !values_equal(it->second, node.pred.value))
        return std::nullopt;
      return unpack_nodes(data, len, offset, node.children, out, as_list);
    }
    case Field::Kind::Repeat: {
      while (offset < len) {
        auto err = unpack_nodes(data, len, offset, node.children, out, true);
        if (err)
          return err;
      }
      return std::nullopt;
    }
    case Field::Kind::Group: {
      if (node.children.empty()) {
        out[node.name] = Value{std::uint8_t{1}};
        return std::nullopt;
      }
      return unpack_nodes(data, len, offset, node.children, out, as_list);
    }
    case Field::Kind::Sized:
    case Field::Kind::U2:
    case Field::Kind::Bits:
    case Field::Kind::Utf8: {
      auto err = unpack_counted(data, len, offset, node, out, as_list);
      if (err)
        return err;
      return std::nullopt;
    }
    case Field::Kind::List: {
      if (left() < 2)
        return make_short(node.name, 2, left());
      auto count = static_cast<std::size_t>(data[offset] | (data[offset + 1] << 8));
      offset += 2;
      auto const& child = node.children.front();
      auto items = std::make_shared<ValueList>();
      items->items.reserve(count);
      for (std::size_t i = 0; i < count; ++i) {
        Values one;
        auto err = unpack_one(data, len, offset, child, one, false);
        if (err)
          return err;
        items->items.push_back(one.at(child.name));
      }
      append_value(out, node.name, Value{items}, as_list);
      return std::nullopt;
    }
    case Field::Kind::Dict: {
      if (left() < 2)
        return make_short(node.name, 2, left());
      auto count = static_cast<std::size_t>(data[offset] | (data[offset + 1] << 8));
      offset += 2;
      auto const& child = node.children.front();
      auto items = std::make_shared<ValueMap>();
      for (std::size_t i = 0; i < count; ++i) {
        if (left() < 2)
          return make_short(node.name, 2, left());
        auto key_len = static_cast<std::size_t>(data[offset] | (data[offset + 1] << 8));
        offset += 2;
        if (left() < key_len)
          return make_short(node.name, static_cast<int>(key_len), left());
        std::string key(reinterpret_cast<char const*>(data + offset), key_len);
        offset += key_len;
        Values one;
        auto err = unpack_one(data, len, offset, child, one, false);
        if (err)
          return err;
        if (!items->items.emplace(std::move(key), one.at(child.name)).second)
          return make_short(node.name, 0, 0);
      }
      append_value(out, node.name, Value{items}, as_list);
      return std::nullopt;
    }
  }
  return std::nullopt;
}

std::optional<ShortPacket> unpack_nodes(std::uint8_t const* data, std::size_t len,
                                    std::size_t& offset, std::vector<Field> const& nodes,
                                    Values& out, bool as_list) {
  for (auto const& node : nodes) {
    auto err = unpack_one(data, len, offset, node, out, as_list);
    if (err)
      return err;
  }
  return std::nullopt;
}

}  // namespace packbin
