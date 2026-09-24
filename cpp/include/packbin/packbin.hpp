#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <type_traits>
#include <utility>
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

struct TypeMismatch {
  int expected = 0;
  int actual = 0;
};

struct ValueList;
struct ValueMap;

struct Value {
  using Bytes = std::vector<std::uint8_t>;
  using List = std::shared_ptr<ValueList>;
  using Map = std::shared_ptr<ValueMap>;
  using Storage = std::variant<std::uint8_t, std::uint16_t, std::uint32_t, std::uint64_t,
                               std::int8_t, std::int16_t, std::int32_t, std::int64_t, float,
                               double, Bytes, std::string, List, Map>;
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
  Value(Map v) : data(std::move(v)) {}
};

struct ValueList {
  std::vector<Value> items;
};

struct ValueMap {
  std::map<std::string, Value> items;
};

using Values = std::map<std::string, Value>;

template <typename T = void>
struct UnpackResult;

template <>
struct UnpackResult<void> {
  bool ok = false;
  Values value;
  std::optional<ShortPacket> short_packet;
  std::optional<TrailingBytes> trailing;
  std::optional<TypeMismatch> type_mismatch;

  std::size_t value_count() const { return value.size(); }
};

template <typename T>
struct UnpackResult {
  bool ok = false;
  std::optional<T> value;
  std::optional<ShortPacket> short_packet;
  std::optional<TrailingBytes> trailing;
  std::optional<TypeMismatch> type_mismatch;
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
    Dict,
    TypeNum,
  };

  Kind kind{};
  std::string name;
  bool big_endian = false;
  int byte_count = 0;
  std::uint8_t constant = 0;
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
Field dict(std::string name, Field element);
Field type_num(int value);
Packet packet(std::vector<Field> fields);

std::vector<std::uint8_t> pack(Packet const& target, Values const& values);
UnpackResult<> unpack(Packet const& target, std::vector<std::uint8_t> const& data);
UnpackResult<> unpack(Packet const& target, std::uint8_t const* data, std::size_t len);

std::string to_hex(std::vector<std::uint8_t> const& data);
std::size_t mismatched_bytes(std::vector<std::uint8_t> const& a,
                             std::vector<std::uint8_t> const& b);
std::size_t motion_field_count(Values const& values);
bool present(Values const& values, std::string const& name);

template <typename T, typename M>
struct BoundMember {
  Field field;
  M T::* member;
};

template <typename T, typename Getter, typename Setter>
struct BoundAccessors {
  Field field;
  Getter get;
  Setter set;
};

template <typename T, typename M>
BoundMember<T, M> bind(Field field, M T::* member) {
  return BoundMember<T, M>{std::move(field), member};
}

template <typename T, typename Getter, typename Setter>
BoundAccessors<T, Getter, Setter> bind(Field field, Getter get, Setter set) {
  return BoundAccessors<T, Getter, Setter>{std::move(field), std::move(get), std::move(set)};
}

template <typename T>
class Scheme {
 public:
  Packet packet;
  struct Binding {
    std::string name;
    std::function<Value(T const&)> read;
    std::function<void(T&, Value const&)> write;
  };
  std::vector<Binding> bindings;

  template <typename... Nodes>
  static Scheme of(Nodes&&... nodes) {
    Scheme scheme;
    std::vector<Field> fields;
    (scheme.append(fields, std::forward<Nodes>(nodes)), ...);
    scheme.packet = packbin::packet(std::move(fields));
    return scheme;
  }

 private:
  void append(std::vector<Field>& fields, Field field) {
    fields.push_back(std::move(field));
  }

  template <typename M>
  void append(std::vector<Field>& fields, BoundMember<T, M> bound) {
    auto member = bound.member;
    std::string name = bound.field.name;
    fields.push_back(std::move(bound.field));
    bindings.push_back(Binding{
        std::move(name),
        [member](T const& row) { return Value{row.*member}; },
        [member](T& row, Value const& v) { row.*member = std::get<M>(v.data); },
    });
  }

  template <typename Getter, typename Setter>
  void append(std::vector<Field>& fields, BoundAccessors<T, Getter, Setter> bound) {
    using M = std::decay_t<decltype(bound.get(std::declval<T const&>()))>;
    std::string name = bound.field.name;
    fields.push_back(std::move(bound.field));
    auto get = std::move(bound.get);
    auto set = std::move(bound.set);
    bindings.push_back(Binding{
        std::move(name),
        [get](T const& row) { return Value{get(row)}; },
        [set](T& row, Value const& v) { set(row, std::get<M>(v.data)); },
    });
  }
};

class BinaryPacker {
 public:
  BinaryPacker() = delete;

  template <typename T>
  static std::vector<std::uint8_t> pack(Scheme<T> const& scheme, T const& row) {
    Values values;
    for (auto const& binding : scheme.bindings)
      values.emplace(binding.name, binding.read(row));
    return packbin::pack(scheme.packet, values);
  }

  template <typename T>
  static UnpackResult<T> unpack(Scheme<T> const& scheme, std::uint8_t const* data,
                                std::size_t len) {
    auto raw = packbin::unpack(scheme.packet, data, len);
    UnpackResult<T> out;
    out.ok = raw.ok;
    out.short_packet = raw.short_packet;
    out.trailing = raw.trailing;
    out.type_mismatch = raw.type_mismatch;
    if (!raw.ok)
      return out;
    T row{};
    for (auto const& binding : scheme.bindings) {
      auto it = raw.value.find(binding.name);
      if (it != raw.value.end())
        binding.write(row, it->second);
    }
    out.value = std::move(row);
    return out;
  }

  template <typename T>
  static UnpackResult<T> unpack(Scheme<T> const& scheme,
                                std::vector<std::uint8_t> const& data) {
    return unpack(scheme, data.data(), data.size());
  }
};

}  // namespace packbin
