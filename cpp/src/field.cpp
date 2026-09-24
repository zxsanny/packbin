#include "packbin/packbin.hpp"

#include <stdexcept>

namespace packbin {
namespace {

Field scalar(Field::Kind kind, int id, int width) {
  Field f;
  f.kind = kind;
  f.id = id;
  f.name = id_name(id);
  f.byte_count = width;
  return f;
}

int validate_one(Field const& node, int next_id);

int validate_children(std::vector<Field> const& nodes, int next_id) {
  for (auto const& node : nodes)
    next_id = validate_one(node, next_id);
  return next_id;
}

void expect_id(int id, int next_id) {
  if (id != next_id)
    throw std::runtime_error("field id " + std::to_string(id) + " is not the next order " +
                             std::to_string(next_id));
}

int validate_one(Field const& node, int next_id) {
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
    case Field::Kind::Bytes:
    case Field::Kind::Bool:
    case Field::Kind::Utf8:
    case Field::Kind::Sized:
    case Field::Kind::Bits:
      expect_id(node.id, next_id);
      return next_id + 1;
    case Field::Kind::U2:
      for (auto const& child : node.children) {
        expect_id(child.id, next_id);
        ++next_id;
      }
      return next_id;
    case Field::Kind::Flags:
      for (auto const& bit : node.children) {
        if (bit.inner)
          next_id = validate_one(*bit.inner, next_id);
        else
          next_id = validate_one(bit, next_id);
      }
      return next_id;
    case Field::Kind::FlagBit:
      if (node.inner)
        return validate_one(*node.inner, next_id);
      return next_id;
    case Field::Kind::FlagByte:
      return next_id;
    case Field::Kind::When:
    case Field::Kind::Repeat:
    case Field::Kind::Group:
      return validate_children(node.children, next_id);
    case Field::Kind::List:
    case Field::Kind::Dict:
      validate_children(node.children, 0);
      return next_id;
  }
  return next_id;
}

}  // namespace

int validate_order(std::vector<Field> const& nodes, int next_id) {
  return validate_children(nodes, next_id);
}

Field Field::be() const {
  Field f = *this;
  f.big_endian = true;
  return f;
}

Field Field::bit(Field field) const {
  if (kind != Kind::FlagByte || !group)
    throw std::runtime_error("bit requires flag_byte");
  if (group->bits.size() >= 8)
    throw std::runtime_error("flags already has 8 bits");
  Field bit;
  bit.kind = Kind::FlagBit;
  bit.id = field.id;
  bit.name = field.name;
  bit.group = group;
  bit.bit_index = static_cast<int>(group->bits.size());
  bit.inner = std::make_shared<Field>(std::move(field));
  group->bits.push_back(bit);
  return bit;
}

Field u8(int id) { return scalar(Field::Kind::U8, id, 1); }
Field u16(int id) { return scalar(Field::Kind::U16, id, 2); }
Field u32(int id) { return scalar(Field::Kind::U32, id, 4); }
Field u64(int id) { return scalar(Field::Kind::U64, id, 8); }
Field i8(int id) { return scalar(Field::Kind::I8, id, 1); }
Field i16(int id) { return scalar(Field::Kind::I16, id, 2); }
Field i32(int id) { return scalar(Field::Kind::I32, id, 4); }
Field i64(int id) { return scalar(Field::Kind::I64, id, 8); }
Field f32(int id) { return scalar(Field::Kind::F32, id, 4); }
Field f64(int id) { return scalar(Field::Kind::F64, id, 8); }

Field bytes(int id, int n) {
  if (n < 0)
    throw std::runtime_error("bytes length must be >= 0");
  Field f;
  f.kind = Field::Kind::Bytes;
  f.id = id;
  f.name = id_name(id);
  f.byte_count = n;
  return f;
}

Field boolean(int id) {
  Field f;
  f.kind = Field::Kind::Bool;
  f.id = id;
  f.name = id_name(id);
  return f;
}

Field be(Field field) { return field.be(); }

Field flags(std::vector<Field> fields) {
  auto group = std::make_shared<FlagGroup>();
  Field f;
  f.kind = Field::Kind::Flags;
  f.name = "";
  f.group = group;
  f.children.reserve(fields.size());
  for (auto& child : fields) {
    Field bit;
    bit.kind = Field::Kind::FlagBit;
    bit.id = child.id;
    bit.name = child.name;
    bit.group = group;
    bit.bit_index = static_cast<int>(group->bits.size());
    bit.inner = std::make_shared<Field>(std::move(child));
    group->bits.push_back(bit);
    f.children.push_back(bit);
  }
  return f;
}

Field flag_byte() {
  auto group = std::make_shared<FlagGroup>();
  Field f;
  f.kind = Field::Kind::FlagByte;
  f.name = "";
  f.group = group;
  return f;
}

Eq eq(int field_id, Value value) { return Eq{id_name(field_id), std::move(value)}; }

Field when(Eq condition, std::vector<Field> fields) {
  Field f;
  f.kind = Field::Kind::When;
  f.name = condition.field;
  f.pred = std::move(condition);
  f.children = std::move(fields);
  return f;
}

Field repeat(std::vector<Field> fields) {
  Field f;
  f.kind = Field::Kind::Repeat;
  f.children = std::move(fields);
  return f;
}

Field group(std::vector<Field> fields) {
  Field f;
  f.kind = Field::Kind::Group;
  f.children = std::move(fields);
  return f;
}

Field group(std::string name, std::vector<Field> fields) {
  Field f;
  f.kind = Field::Kind::Group;
  f.name = std::move(name);
  f.children = std::move(fields);
  return f;
}

Field sized(int id, int count_id) {
  Field f;
  f.kind = Field::Kind::Sized;
  f.id = id;
  f.name = id_name(id);
  f.count_id = count_id;
  f.count_name = id_name(count_id);
  return f;
}

Field u2(std::vector<int> ids) {
  if (ids.empty())
    throw std::runtime_error("u2 needs at least one name");
  Field f;
  f.kind = Field::Kind::U2;
  f.id = ids.front();
  f.children.reserve(ids.size());
  for (auto id : ids) {
    Field child;
    child.id = id;
    child.name = id_name(id);
    f.children.push_back(std::move(child));
  }
  return f;
}

Field utf8(int id) {
  Field f;
  f.kind = Field::Kind::Utf8;
  f.id = id;
  f.name = id_name(id);
  return f;
}

Field list(std::string name, Field element) {
  if (element.kind == Field::Kind::Repeat)
    throw std::runtime_error("repeat is not a list element");
  Field f;
  f.kind = Field::Kind::List;
  f.name = std::move(name);
  f.children.push_back(std::move(element));
  return f;
}

Field dict(std::string name, Field element) {
  if (element.kind == Field::Kind::Repeat)
    throw std::runtime_error("repeat is not a dictionary element");
  Field f;
  f.kind = Field::Kind::Dict;
  f.name = std::move(name);
  f.children.push_back(std::move(element));
  return f;
}

Field bits(int id, int count_id) {
  Field f;
  f.kind = Field::Kind::Bits;
  f.id = id;
  f.name = id_name(id);
  f.count_id = count_id;
  f.count_name = id_name(count_id);
  return f;
}

std::string to_hex(std::vector<std::uint8_t> const& data) {
  static char const* hex = "0123456789abcdef";
  std::string s;
  s.resize(data.size() * 2);
  for (std::size_t i = 0; i < data.size(); ++i) {
    s[i * 2] = hex[data[i] >> 4];
    s[i * 2 + 1] = hex[data[i] & 0xf];
  }
  return s;
}

std::size_t mismatched_bytes(std::vector<std::uint8_t> const& a,
                             std::vector<std::uint8_t> const& b) {
  std::size_t mism = a.size() > b.size() ? a.size() - b.size() : b.size() - a.size();
  std::size_t n = a.size() < b.size() ? a.size() : b.size();
  for (std::size_t i = 0; i < n; ++i) {
    if (a[i] != b[i])
      ++mism;
  }
  return mism;
}

bool present(Values const& values, std::string const& name) {
  return values.find(name) != values.end();
}

bool present(Values const& values, int id) { return present(values, id_name(id)); }

std::size_t motion_field_count(Values const& values) {
  static int const ids[] = {4, 5, 6};
  std::size_t n = 0;
  for (auto id : ids) {
    if (present(values, id))
      ++n;
  }
  return n;
}

}  // namespace packbin
