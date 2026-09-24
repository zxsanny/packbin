#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <stdexcept>
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
  std::optional<int> expected;
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

std::string to_hex(std::vector<std::uint8_t> const& data);
std::size_t mismatched_bytes(std::vector<std::uint8_t> const& a,
                             std::vector<std::uint8_t> const& b);
std::size_t motion_field_count(Values const& values);
bool present(Values const& values, std::string const& name);

std::vector<std::uint8_t> pack_body(std::vector<Field> const& fields, Values const& values);
UnpackResult<> unpack_body(std::vector<Field> const& fields, std::uint8_t const* data,
                           std::size_t len, std::size_t offset);

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
class Scheme;

template <typename T>
struct SchemeHandler {
  int type_number = 0;
  Scheme<T> scheme;
  std::function<void(T const&)> handler;
};

template <typename T>
class Scheme {
 public:
  int type_number = 0;
  std::vector<Field> fields;
  struct Binding {
    std::string name;
    std::function<Value(T const&)> read;
    std::function<void(T&, Value const&)> write;
  };
  std::vector<Binding> bindings;

  Scheme() = default;

  template <typename... Nodes>
  Scheme(int type_number, Nodes&&... nodes) {
    if (type_number < 0 || type_number > 255)
      throw std::runtime_error("type number must be 0..255");
    this->type_number = type_number;
    (append(fields, std::forward<Nodes>(nodes)), ...);
  }

  template <typename F>
  SchemeHandler<T> on(F handler) const {
    return SchemeHandler<T>{type_number, *this, std::function<void(T const&)>(std::move(handler))};
  }

 private:
  void append(std::vector<Field>& out, Field field) { out.push_back(std::move(field)); }

  template <typename M>
  void append(std::vector<Field>& out, BoundMember<T, M> bound) {
    auto member = bound.member;
    std::string name = bound.field.name;
    out.push_back(std::move(bound.field));
    bindings.push_back(Binding{
        std::move(name),
        [member](T const& row) { return Value{row.*member}; },
        [member](T& row, Value const& v) { row.*member = std::get<M>(v.data); },
    });
  }

  template <typename Getter, typename Setter>
  void append(std::vector<Field>& out, BoundAccessors<T, Getter, Setter> bound) {
    using M = std::decay_t<decltype(bound.get(std::declval<T const&>()))>;
    std::string name = bound.field.name;
    out.push_back(std::move(bound.field));
    auto get = std::move(bound.get);
    auto set = std::move(bound.set);
    bindings.push_back(Binding{
        std::move(name),
        [get](T const& row) { return Value{get(row)}; },
        [set](T& row, Value const& v) { set(row, std::get<M>(v.data)); },
    });
  }
};

inline Scheme<Values> scheme(int type_number, std::vector<Field> fields) {
  if (type_number < 0 || type_number > 255)
    throw std::runtime_error("type number must be 0..255");
  Scheme<Values> s;
  s.type_number = type_number;
  s.fields = std::move(fields);
  return s;
}

namespace detail {

inline Values row_values(Scheme<Values> const&, Values const& row) { return row; }

template <typename T>
Values row_values(Scheme<T> const& s, T const& row) {
  Values values;
  for (auto const& binding : s.bindings)
    values.emplace(binding.name, binding.read(row));
  return values;
}

inline void write_row(Scheme<Values> const&, Values& row, Values const& raw) { row = raw; }

template <typename T>
void write_row(Scheme<T> const& s, T& row, Values const& raw) {
  for (auto const& binding : s.bindings) {
    auto it = raw.find(binding.name);
    if (it != raw.end())
      binding.write(row, it->second);
  }
}

}  // namespace detail

template <typename T>
std::vector<std::uint8_t> pack(Scheme<T> const& s, T const& row) {
  auto body = pack_body(s.fields, detail::row_values(s, row));
  std::vector<std::uint8_t> out;
  out.reserve(body.size() + 1);
  out.push_back(static_cast<std::uint8_t>(s.type_number));
  out.insert(out.end(), body.begin(), body.end());
  return out;
}

inline UnpackResult<> unpack(Scheme<Values> const& s, std::uint8_t const* data, std::size_t len) {
  UnpackResult<> out;
  if (len < 1) {
    out.ok = false;
    out.short_packet = ShortPacket{"", 1, 0};
    return out;
  }
  auto actual = static_cast<int>(data[0]);
  if (actual != s.type_number) {
    out.ok = false;
    out.type_mismatch = TypeMismatch{s.type_number, actual};
    return out;
  }
  auto raw = unpack_body(s.fields, data, len, 1);
  out.ok = raw.ok;
  out.short_packet = raw.short_packet;
  out.trailing = raw.trailing;
  out.type_mismatch = raw.type_mismatch;
  if (!raw.ok)
    return out;
  out.value = std::move(raw.value);
  return out;
}

inline UnpackResult<> unpack(Scheme<Values> const& s, std::vector<std::uint8_t> const& data) {
  return unpack(s, data.data(), data.size());
}

template <typename T>
UnpackResult<T> unpack(Scheme<T> const& s, std::uint8_t const* data, std::size_t len) {
  UnpackResult<T> out;
  if (len < 1) {
    out.ok = false;
    out.short_packet = ShortPacket{"", 1, 0};
    return out;
  }
  auto actual = static_cast<int>(data[0]);
  if (actual != s.type_number) {
    out.ok = false;
    out.type_mismatch = TypeMismatch{s.type_number, actual};
    return out;
  }
  auto raw = unpack_body(s.fields, data, len, 1);
  out.ok = raw.ok;
  out.short_packet = raw.short_packet;
  out.trailing = raw.trailing;
  out.type_mismatch = raw.type_mismatch;
  if (!raw.ok)
    return out;
  T row{};
  detail::write_row(s, row, raw.value);
  out.value = std::move(row);
  return out;
}

template <typename T>
UnpackResult<T> unpack(Scheme<T> const& s, std::vector<std::uint8_t> const& data) {
  return unpack(s, data.data(), data.size());
}

namespace detail {

template <typename H>
void check_unique(std::map<int, bool>& seen, H const& h) {
  if (!seen.emplace(h.type_number, true).second)
    throw std::runtime_error("duplicate type number");
}

template <typename H>
bool try_dispatch(UnpackResult<>& result, bool& matched, int actual, std::uint8_t const* data,
                  std::size_t len, H const& h) {
  if (matched || h.type_number != actual)
    return false;
  matched = true;
  auto row = unpack(h.scheme, data, len);
  result.ok = row.ok;
  result.short_packet = row.short_packet;
  result.trailing = row.trailing;
  result.type_mismatch = row.type_mismatch;
  if (row.ok && row.value)
    h.handler(*row.value);
  return true;
}

}  // namespace detail

template <typename... Handlers>
UnpackResult<> unpack(std::uint8_t const* data, std::size_t len, Handlers const&... handlers) {
  std::map<int, bool> seen;
  (detail::check_unique(seen, handlers), ...);

  UnpackResult<> result;
  if (len < 1) {
    result.ok = false;
    result.short_packet = ShortPacket{"", 1, 0};
    return result;
  }
  int actual = static_cast<int>(data[0]);
  bool matched = false;
  (detail::try_dispatch(result, matched, actual, data, len, handlers), ...);
  if (!matched) {
    result.ok = false;
    result.type_mismatch = TypeMismatch{std::nullopt, actual};
  }
  return result;
}

template <typename... Handlers>
UnpackResult<> unpack(std::vector<std::uint8_t> const& data, Handlers const&... handlers) {
  return unpack(data.data(), data.size(), handlers...);
}

}  // namespace packbin
