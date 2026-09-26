#include "walk.hpp"
#include "counted.hpp"

#include <algorithm>
#include <stdexcept>

namespace packbin {

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
    case Field::Kind::Bool:
    case Field::Kind::Utf8:
    case Field::Kind::List:
    case Field::Kind::Dict:
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
    case Field::Kind::Bool:
      break;
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
    case Field::Kind::Packed:
    case Field::Kind::Utf8:
      pack_counted(node, values, out);
      break;
    case Field::Kind::List: {
      auto const& list = std::get<Value::List>(require(values, node.name).data);
      if (!list || list->items.size() > 65535)
        throw std::runtime_error(node.name + ": list length");
      auto n = static_cast<std::uint16_t>(list->items.size());
      out.push_back(static_cast<std::uint8_t>(n & 0xff));
      out.push_back(static_cast<std::uint8_t>((n >> 8) & 0xff));
      auto const& child = node.children.front();
      for (auto const& item : list->items) {
        Values slice;
        slice.emplace(child.name, item);
        pack_one(child, slice, out);
      }
      break;
    }
    case Field::Kind::Dict: {
      auto const& map = std::get<Value::Map>(require(values, node.name).data);
      if (!map || map->items.size() > 65535)
        throw std::runtime_error(node.name + ": dictionary length");
      auto n = static_cast<std::uint16_t>(map->items.size());
      out.push_back(static_cast<std::uint8_t>(n & 0xff));
      out.push_back(static_cast<std::uint8_t>((n >> 8) & 0xff));
      auto const& child = node.children.front();
      for (auto const& [key, item] : map->items) {
        if (key.size() > 65535)
          throw std::runtime_error(node.name + ": key length");
        auto kn = static_cast<std::uint16_t>(key.size());
        out.push_back(static_cast<std::uint8_t>(kn & 0xff));
        out.push_back(static_cast<std::uint8_t>((kn >> 8) & 0xff));
        out.insert(out.end(), reinterpret_cast<std::uint8_t const*>(key.data()),
                   reinterpret_cast<std::uint8_t const*>(key.data()) + key.size());
        Values slice;
        slice.emplace(child.name, item);
        pack_one(child, slice, out);
      }
      break;
    }
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
    case Field::Kind::Times: {
      auto count = borrowed_item_count(node, values);
      for (std::int64_t i = 0; i < count; ++i) {
        Values slice;
        for (auto const& child : node.children) {
          auto const& name = field_name(child);
          auto vit = values.find(name);
          if (vit == values.end())
            continue;
          if (auto const* list = std::get_if<Value::List>(&vit->second.data)) {
            if (*list && static_cast<std::size_t>(i) < (*list)->items.size())
              slice.emplace(name, (*list)->items[static_cast<std::size_t>(i)]);
          } else if (i == 0) {
            slice.emplace(name, vit->second);
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

}  // namespace packbin
