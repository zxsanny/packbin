#include "packbin/packbin.hpp"

#include <stdexcept>

namespace packbin {
namespace {

Field scalar(Field::Kind kind, std::string name, int width) {
  Field f;
  f.kind = kind;
  f.name = std::move(name);
  f.byte_count = width;
  return f;
}

}  // namespace

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
  bit.name = field.name;
  bit.group = group;
  bit.bit_index = static_cast<int>(group->bits.size());
  bit.inner = std::make_shared<Field>(std::move(field));
  group->bits.push_back(bit);
  return bit;
}

Field u8(std::string name) { return scalar(Field::Kind::U8, std::move(name), 1); }
Field u16(std::string name) { return scalar(Field::Kind::U16, std::move(name), 2); }
Field u32(std::string name) { return scalar(Field::Kind::U32, std::move(name), 4); }
Field u64(std::string name) { return scalar(Field::Kind::U64, std::move(name), 8); }
Field i8(std::string name) { return scalar(Field::Kind::I8, std::move(name), 1); }
Field i16(std::string name) { return scalar(Field::Kind::I16, std::move(name), 2); }
Field i32(std::string name) { return scalar(Field::Kind::I32, std::move(name), 4); }
Field i64(std::string name) { return scalar(Field::Kind::I64, std::move(name), 8); }
Field f32(std::string name) { return scalar(Field::Kind::F32, std::move(name), 4); }
Field f64(std::string name) { return scalar(Field::Kind::F64, std::move(name), 8); }

Field bytes(std::string name, int n) {
  if (n < 0)
    throw std::runtime_error("bytes length must be >= 0");
  Field f;
  f.kind = Field::Kind::Bytes;
  f.name = std::move(name);
  f.byte_count = n;
  return f;
}

Field be(Field field) { return field.be(); }

Field flags(std::string name, std::vector<Field> fields) {
  auto group = std::make_shared<FlagGroup>();
  group->name = name;
  Field f;
  f.kind = Field::Kind::Flags;
  f.name = std::move(name);
  f.group = group;
  f.children.reserve(fields.size());
  for (auto& child : fields) {
    Field bit;
    bit.kind = Field::Kind::FlagBit;
    bit.name = child.name;
    bit.group = group;
    bit.bit_index = static_cast<int>(group->bits.size());
    bit.inner = std::make_shared<Field>(std::move(child));
    group->bits.push_back(bit);
    f.children.push_back(bit);
  }
  return f;
}

Field flag_byte(std::string name) {
  auto group = std::make_shared<FlagGroup>();
  group->name = name;
  Field f;
  f.kind = Field::Kind::FlagByte;
  f.name = std::move(name);
  f.group = group;
  return f;
}

Eq eq(std::string field, Value value) { return Eq{std::move(field), std::move(value)}; }

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

Field group(std::string name, std::vector<Field> fields) {
  Field f;
  f.kind = Field::Kind::Group;
  f.name = std::move(name);
  f.children = std::move(fields);
  return f;
}

Field sized(std::string name, std::string count_field) {
  Field f;
  f.kind = Field::Kind::Sized;
  f.name = std::move(name);
  f.count_name = std::move(count_field);
  return f;
}

Field u2(std::vector<std::string> names) {
  if (names.empty())
    throw std::runtime_error("u2 needs at least one name");
  Field f;
  f.kind = Field::Kind::U2;
  f.children.reserve(names.size());
  for (auto& name : names) {
    Field child;
    child.name = std::move(name);
    f.children.push_back(std::move(child));
  }
  return f;
}

Field utf8(std::string name) {
  Field f;
  f.kind = Field::Kind::Utf8;
  f.name = std::move(name);
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

Field bits(std::string name, std::string count_field) {
  Field f;
  f.kind = Field::Kind::Bits;
  f.name = std::move(name);
  f.count_name = std::move(count_field);
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

std::size_t motion_field_count(Values const& values) {
  static char const* names[] = {"heading", "speed", "altitude", "frequency"};
  std::size_t n = 0;
  for (auto const* name : names) {
    if (present(values, name))
      ++n;
  }
  return n;
}

}  // namespace packbin
