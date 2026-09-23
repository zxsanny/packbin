#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace packbin {

struct ShortPacket {
  std::string field;
  std::size_t needed = 0;
  std::size_t left = 0;
};

struct TrailingBytes {
  std::size_t left = 0;
};

struct ValueList;

struct Value {
  using Bytes = std::vector<std::uint8_t>;
  using List = std::shared_ptr<ValueList>;
  using Storage = std::variant<std::uint8_t, std::uint16_t, std::uint32_t, std::uint64_t,
                               std::int8_t, std::int16_t, std::int32_t, std::int64_t, float,
                               double, Bytes, std::string, List>;
  Storage data;

  Value() : data(std::uint8_t{0}) {}
  Value(std::uint8_t v) : data(v) {}
  Value(std::uint16_t v) : data(v) {}
  Value(std::uint32_t v) : data(v) {}
  Value(std::uint64_t v) : data(v) {}
  Value(std::int8_t v) : data(v) {}
  Value(std::int16_t v) : data(v) {}
  Value(std::int32_t v) : data(v) {}
  Value(std::int64_t v) : data(v) {}
  Value(float v) : data(v) {}
  Value(double v) : data(v) {}
  Value(Bytes v) : data(std::move(v)) {}
  Value(std::string v) : data(std::move(v)) {}
  Value(char const* v) : data(std::string(v)) {}
  Value(List v) : data(std::move(v)) {}
};

struct ValueList {
  std::vector<Value> items;
};

using Values = std::map<std::string, Value>;

struct UnpackResult {
  bool ok = false;
  Values value;
  std::optional<ShortPacket> short_packet;
  std::optional<TrailingBytes> trailing;

  std::size_t value_count() const { return value.size(); }
};

class Field;

struct Eq {
  std::string field;
  Value value;
};

struct FlagGroup {
  std::string name;
  std::vector<Field> bits;
  std::uint8_t unpacked = 0;
};

class Field {
 public:
  enum class Kind : std::uint8_t {
    U8,
    U16,
    U32,
    U64,
    I8,
    I16,
    I32,
    I64,
    F32,
    F64,
    Bytes,
    Flags,
    FlagByte,
    FlagBit,
    When,
    Repeat,
    Group,
    Sized,
    U2,
    Bits,
    Utf8,
    List,
  };

  Kind kind{};
  std::string name;
  bool big_endian = false;
  int byte_count = 0;
  std::vector<Field> children;
  std::shared_ptr<FlagGroup> group;
  int bit_index = 0;
  std::shared_ptr<Field> inner;
  Eq pred;
  std::string count_name;

  Field be() const;
  Field bit(Field field) const;
};

struct Packet {
  std::vector<Field> fields;
};

Field u8(std::string name);
Field u16(std::string name);
Field u32(std::string name);
Field u64(std::string name);
Field i8(std::string name);
Field i16(std::string name);
Field i32(std::string name);
Field i64(std::string name);
Field f32(std::string name);
Field f64(std::string name);
Field bytes(std::string name, int n);
Field be(Field field);
Field flags(std::string name, std::vector<Field> fields);
Field flag_byte(std::string name);
Eq eq(std::string field, Value value);
Field when(Eq condition, std::vector<Field> fields);
Field repeat(std::vector<Field> fields);
Field group(std::string name, std::vector<Field> fields);
Field sized(std::string name, std::string count_field);
Field u2(std::vector<std::string> names);
Field bits(std::string name, std::string count_field);
Field utf8(std::string name);
Field list(std::string name, Field element);
Packet packet(std::vector<Field> fields);

std::vector<std::uint8_t> pack(Packet const& target, Values const& values);
UnpackResult unpack(Packet const& target, std::vector<std::uint8_t> const& data);
UnpackResult unpack(Packet const& target, std::uint8_t const* data, std::size_t len);

std::string to_hex(std::vector<std::uint8_t> const& data);
std::size_t mismatched_bytes(std::vector<std::uint8_t> const& a,
                             std::vector<std::uint8_t> const& b);
std::size_t motion_field_count(Values const& values);
bool present(Values const& values, std::string const& name);

}  // namespace packbin
