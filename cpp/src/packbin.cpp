#include "counted.hpp"
#include "packbin/packbin.hpp"

#include <algorithm>
#include <cstring>
#include <stdexcept>

namespace packbin {
namespace {

std::string const& field_name(Field const& field) {
  if (field.kind == Field::Kind::FlagBit && field.inner)
    return field_name(*field.inner);
  return field.name;
}

bool values_equal(Value const& a, Value const& b) { return a.data == b.data; }

bool is_present(Values const& values, std::string const& name) {
  return values.find(name) != values.end();
}

void write_raw(std::vector<std::uint8_t>& out, std::uint8_t const* raw, int n, bool be) {
  if (be) {
    for (int i = n - 1; i >= 0; --i)
      out.push_back(raw[i]);
  } else {
    out.insert(out.end(), raw, raw + n);
  }
}

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

Value const& require(Values const& values, std::string const& name) {
  auto it = values.find(name);
  if (it == values.end())
    throw std::runtime_error("missing field " + name);
  return it->second;
}

void pack_scalar(Field const& field, Values const& values, std::vector<std::uint8_t>& out) {
  Value const& v = require(values, field.name);
  switch (field.kind) {
    case Field::Kind::U8:
      out.push_back(std::get<std::uint8_t>(v.data));
      break;
    case Field::Kind::U16:
      write_num(out, std::get<std::uint16_t>(v.data), field.big_endian);
      break;
    case Field::Kind::U32:
      write_num(out, std::get<std::uint32_t>(v.data), field.big_endian);
      break;
    case Field::Kind::U64:
      write_num(out, std::get<std::uint64_t>(v.data), field.big_endian);
      break;
    case Field::Kind::I8:
      out.push_back(static_cast<std::uint8_t>(std::get<std::int8_t>(v.data)));
      break;
    case Field::Kind::I16:
      write_num(out, std::get<std::int16_t>(v.data), field.big_endian);
      break;
    case Field::Kind::I32:
      write_num(out, std::get<std::int32_t>(v.data), field.big_endian);
      break;
    case Field::Kind::I64:
      write_num(out, std::get<std::int64_t>(v.data), field.big_endian);
      break;
    case Field::Kind::F32:
      write_num(out, std::get<float>(v.data), field.big_endian);
      break;
    case Field::Kind::F64:
      write_num(out, std::get<double>(v.data), field.big_endian);
      break;
    default:
      throw std::runtime_error("not a scalar");
  }
}

void pack_nodes(std::vector<Field> const& nodes, Values const& values,
                std::vector<std::uint8_t>& out);

bool scalar_or_bytes(Field::Kind kind) {
  switch (kind) {
    case Field::Kind::U8:
    case Field::Kind::U16:
    case Field::Kind::U32:
    case Field::Kind::U64:
    case Field::Kind::I8:
    case Field::Kind::I16:
    case Field::Kind::I32:
    case Field::Kind::I64:
    case Field::Kind::F32:
    case Field::Kind::F64:
    case Field::Kind::Bytes:
      return true;
    default:
      return false;
  }
}

bool group_present(Field const& node, Values const& values) {
  if (is_present(values, node.name))
    return true;
  for (auto const& child : node.children) {
    if (scalar_or_bytes(child.kind) && is_present(values, child.name))
      return true;
  }
  return false;
}

bool bit_on(Field const& bit, Values const& values) {
  if (bit.inner && bit.inner->kind == Field::Kind::Group)
    return group_present(*bit.inner, values);
  return is_present(values, field_name(bit));
}

std::uint8_t compute_bits(FlagGroup const& group, Values const& values) {
  std::uint8_t flag = 0;
  for (std::size_t i = 0; i < group.bits.size(); ++i) {
    if (bit_on(group.bits[i], values))
      flag = static_cast<std::uint8_t>(flag | (1u << i));
  }
  return flag;
}

void pack_one(Field const& node, Values const& values, std::vector<std::uint8_t>& out) {
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
    case Field::Kind::F64:
      pack_scalar(node, values, out);
      break;
    case Field::Kind::Bytes: {
      Value const& v = require(values, node.name);
      auto const& raw = std::get<Value::Bytes>(v.data);
      if (static_cast<int>(raw.size()) != node.byte_count)
        throw std::runtime_error(node.name + ": expected bytes length mismatch");
      out.insert(out.end(), raw.begin(), raw.end());
      break;
    }
    case Field::Kind::Flags: {
      std::uint8_t flag = compute_bits(*node.group, values);
      out.push_back(flag);
      for (std::size_t i = 0; i < node.children.size(); ++i) {
        if (flag & (1u << i))
          pack_one(node.children[i].inner ? *node.children[i].inner : node.children[i], values,
                   out);
      }
      break;
    }
    case Field::Kind::FlagByte:
      out.push_back(compute_bits(*node.group, values));
      break;
    case Field::Kind::FlagBit: {
      if (!bit_on(node, values))
        break;
      pack_one(*node.inner, values, out);
      break;
    }
    case Field::Kind::Group:
      pack_nodes(node.children, values, out);
      break;
    case Field::Kind::Sized:
    case Field::Kind::U2:
    case Field::Kind::Bits:
      pack_counted(node, values, out);
      break;
    case Field::Kind::When: {
      auto it = values.find(node.pred.field);
      if (it != values.end() && values_equal(it->second, node.pred.value))
        pack_nodes(node.children, values, out);
      break;
    }
    case Field::Kind::Repeat: {
      std::size_t count = 0;
      for (auto const& child : node.children) {
        auto const& name = field_name(child);
        auto it = values.find(name);
        if (it == values.end())
          continue;
        if (auto const* list = std::get_if<Value::List>(&it->second.data)) {
          if (*list)
            count = std::max(count, (*list)->items.size());
        } else {
          count = std::max(count, std::size_t{1});
        }
      }
      for (std::size_t i = 0; i < count; ++i) {
        Values slice;
        for (auto const& child : node.children) {
          auto const& name = field_name(child);
          auto it = values.find(name);
          if (it == values.end())
            continue;
          if (auto const* list = std::get_if<Value::List>(&it->second.data)) {
            if (*list && i < (*list)->items.size())
              slice.emplace(name, (*list)->items[i]);
          } else if (i == 0) {
            slice.emplace(name, it->second);
          }
        }
        pack_nodes(node.children, slice, out);
      }
      break;
    }
  }
}

void pack_nodes(std::vector<Field> const& nodes, Values const& values,
                std::vector<std::uint8_t>& out) {
  for (auto const& node : nodes)
    pack_one(node, values, out);
}

ShortPacket make_short(std::string const& name, int needed, std::size_t left) {
  return ShortPacket{name, static_cast<std::size_t>(needed), left};
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
      return unpack_counted(data, len, offset, node, out, as_list);
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

}  // namespace

std::vector<std::uint8_t> pack(Packet const& target, Values const& values) {
  std::vector<std::uint8_t> out;
  out.reserve(32);
  pack_nodes(target.fields, values, out);
  return out;
}

UnpackResult unpack(Packet const& target, std::uint8_t const* data, std::size_t len) {
  Values out;
  std::size_t offset = 0;
  auto err = unpack_nodes(data, len, offset, target.fields, out, false);
  if (err) {
    UnpackResult r;
    r.ok = false;
    r.short_packet = std::move(err);
    return r;
  }
  if (offset < len) {
    UnpackResult r;
    r.ok = false;
    r.trailing = TrailingBytes{len - offset};
    return r;
  }
  UnpackResult r;
  r.ok = true;
  r.value = std::move(out);
  return r;
}

UnpackResult unpack(Packet const& target, std::vector<std::uint8_t> const& data) {
  return unpack(target, data.data(), data.size());
}

}  // namespace packbin
