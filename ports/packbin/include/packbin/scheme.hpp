#pragma once

template <typename T>
struct BoundField {
  Field field;
  struct Binding {
    std::string name;
    std::function<std::optional<Value>(T const&)> read;
    std::function<void(T&, Value const&)> write;
  };
  std::vector<Binding> bindings;
};

template <typename T, typename M>
BoundField<T> bind_scalar(Field field, M T::* member) {
  auto name = field.name;
  BoundField<T> out;
  out.field = std::move(field);
  out.bindings.push_back(typename BoundField<T>::Binding{
      name,
      [member](T const& row) -> std::optional<Value> { return Value{row.*member}; },
      [member](T& row, Value const& v) { row.*member = std::get<M>(v.data); },
  });
  return out;
}

template <typename T, typename M>
BoundField<T> bind_optional(Field field, std::optional<M> T::* member) {
  auto name = field.name;
  BoundField<T> out;
  out.field = std::move(field);
  out.bindings.push_back(typename BoundField<T>::Binding{
      name,
      [member](T const& row) -> std::optional<Value> {
        if (!(row.*member))
          return std::nullopt;
        return Value{*(row.*member)};
      },
      [member](T& row, Value const& v) { row.*member = std::get<M>(v.data); },
  });
  return out;
}

template <typename T, typename Getter, typename Setter>
BoundField<T> bind_accessors(Field field, Getter get, Setter set) {
  using M = std::decay_t<decltype(get(std::declval<T const&>()))>;
  auto name = field.name;
  BoundField<T> out;
  out.field = std::move(field);
  out.bindings.push_back(typename BoundField<T>::Binding{
      std::move(name),
      [get](T const& row) -> std::optional<Value> { return Value{get(row)}; },
      [set](T& row, Value const& v) { set(row, std::get<M>(v.data)); },
  });
  return out;
}

#define PACKBIN_SCALAR_OVERLOADS(fn)                                                               \
  template <typename T, typename M>                                                                \
  BoundField<T> fn(int id, M T::* member) {                                                         \
    return bind_scalar<T, M>(fn(id), member);                                                      \
  }                                                                                                \
  template <typename T, typename M>                                                                \
  BoundField<T> fn(int id, std::optional<M> T::* member) {                                         \
    return bind_optional<T, M>(fn(id), member);                                                    \
  }                                                                                                \
  template <typename T, typename Getter, typename Setter>                                          \
  BoundField<T> fn(int id, Getter get, Setter set) {                                               \
    return bind_accessors<T>(fn(id), std::move(get), std::move(set));                              \
  }

PACKBIN_SCALAR_OVERLOADS(u8)
PACKBIN_SCALAR_OVERLOADS(u16)
PACKBIN_SCALAR_OVERLOADS(u32)
PACKBIN_SCALAR_OVERLOADS(u64)
PACKBIN_SCALAR_OVERLOADS(i8)
PACKBIN_SCALAR_OVERLOADS(i16)
PACKBIN_SCALAR_OVERLOADS(i32)
PACKBIN_SCALAR_OVERLOADS(i64)
PACKBIN_SCALAR_OVERLOADS(f32)
PACKBIN_SCALAR_OVERLOADS(f64)
PACKBIN_SCALAR_OVERLOADS(utf8)

#undef PACKBIN_SCALAR_OVERLOADS

template <typename T, typename M>
BoundField<T> bytes(int id, M T::* member, int n) {
  return bind_scalar<T, M>(bytes(id, n), member);
}

template <typename T, typename Getter, typename Setter>
BoundField<T> bytes(int id, Getter get, Setter set, int n) {
  return bind_accessors<T>(bytes(id, n), std::move(get), std::move(set));
}

template <typename T>
BoundField<T> boolean(int id, std::optional<bool> T::* member) {
  auto field = boolean(id);
  auto name = field.name;
  BoundField<T> out;
  out.field = std::move(field);
  out.bindings.push_back(typename BoundField<T>::Binding{
      name,
      [member](T const& row) -> std::optional<Value> {
        if ((row.*member) == true)
          return Value{std::uint8_t{1}};
        return std::nullopt;
      },
      [member](T& row, Value const&) { row.*member = true; },
  });
  return out;
}

template <typename T>
BoundField<T> boolean(int id, bool T::* member) {
  auto field = boolean(id);
  auto name = field.name;
  BoundField<T> out;
  out.field = std::move(field);
  out.bindings.push_back(typename BoundField<T>::Binding{
      name,
      [member](T const& row) -> std::optional<Value> {
        if (row.*member)
          return Value{std::uint8_t{1}};
        return std::nullopt;
      },
      [member](T& row, Value const&) { row.*member = true; },
  });
  return out;
}

template <typename T, typename M>
BoundField<T> sized(int id, M T::* member, int count_id) {
  return bind_scalar<T, M>(sized(id, count_id), member);
}

template <typename T, typename M>
BoundField<T> bits(int id, M T::* member, int count_id) {
  return bind_scalar<T, M>(bits(id, count_id), member);
}

template <typename T>
BoundField<T> when(Eq condition, std::initializer_list<BoundField<T>> children) {
  std::vector<Field> fields;
  BoundField<T> out;
  fields.reserve(children.size());
  for (auto const& child : children) {
    fields.push_back(child.field);
    for (auto const& b : child.bindings)
      out.bindings.push_back(b);
  }
  out.field = when(std::move(condition), std::move(fields));
  return out;
}

template <typename T>
BoundField<T> flags(std::initializer_list<BoundField<T>> children) {
  std::vector<Field> fields;
  BoundField<T> out;
  fields.reserve(children.size());
  for (auto const& child : children) {
    fields.push_back(child.field);
    for (auto const& b : child.bindings)
      out.bindings.push_back(b);
  }
  out.field = flags(std::move(fields));
  return out;
}

template <typename T>
BoundField<T> repeat(std::initializer_list<BoundField<T>> children) {
  std::vector<Field> fields;
  BoundField<T> out;
  fields.reserve(children.size());
  for (auto const& child : children) {
    fields.push_back(child.field);
    for (auto const& b : child.bindings)
      out.bindings.push_back(b);
  }
  out.field = repeat(std::move(fields));
  return out;
}

template <typename T>
BoundField<T> group(std::initializer_list<BoundField<T>> children) {
  std::vector<Field> fields;
  BoundField<T> out;
  fields.reserve(children.size());
  for (auto const& child : children) {
    fields.push_back(child.field);
    for (auto const& b : child.bindings)
      out.bindings.push_back(b);
  }
  out.field = group(std::move(fields));
  return out;
}

template <typename T>
BoundField<T> list(std::vector<std::uint16_t> T::* member, Field element) {
  auto name = std::string("__list_") + id_name(element.id);
  BoundField<T> out;
  out.field = list(std::move(name), std::move(element));
  auto key = out.field.name;
  out.bindings.push_back(typename BoundField<T>::Binding{
      key,
      [member](T const& row) -> std::optional<Value> {
        auto items = std::make_shared<ValueList>();
        for (auto n : row.*member)
          items->items.push_back(Value{n});
        return Value{items};
      },
      [member](T& row, Value const& v) {
        auto const& list = std::get<Value::List>(v.data);
        (row.*member).clear();
        if (!list)
          return;
        (row.*member).reserve(list->items.size());
        for (auto const& item : list->items)
          (row.*member).push_back(std::get<std::uint16_t>(item.data));
      },
  });
  return out;
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
  using Binding = typename BoundField<T>::Binding;
  std::vector<Binding> bindings;

  Scheme() = default;

  template <typename... Nodes>
  Scheme(int type_number, Nodes&&... nodes) {
    if (type_number < 0 || type_number > 255)
      throw std::runtime_error("type number must be 0..255");
    this->type_number = type_number;
    (append(std::forward<Nodes>(nodes)), ...);
    validate_order(fields);
  }

  template <typename F>
  SchemeHandler<T> on(F handler) const {
    return SchemeHandler<T>{type_number, *this, std::function<void(T const&)>(std::move(handler))};
  }

 private:
  void append(Field field) { fields.push_back(std::move(field)); }

  void append(BoundField<T> bound) {
    fields.push_back(std::move(bound.field));
    for (auto& b : bound.bindings)
      bindings.push_back(std::move(b));
  }
};

inline Scheme<Values> scheme(int type_number, std::vector<Field> fields) {
  if (type_number < 0 || type_number > 255)
    throw std::runtime_error("type number must be 0..255");
  validate_order(fields);
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
  for (auto const& binding : s.bindings) {
    if (auto v = binding.read(row))
      values.emplace(binding.name, std::move(*v));
  }
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

struct BinaryPacker {
  template <typename T>
  static std::vector<std::uint8_t> pack(Scheme<T> const& s, T const& row) {
    auto body = pack_body(s.fields, detail::row_values(s, row));
    std::vector<std::uint8_t> out;
    out.reserve(body.size() + 1);
    out.push_back(static_cast<std::uint8_t>(s.type_number));
    out.insert(out.end(), body.begin(), body.end());
    return out;
  }

  static UnpackResult<> unpack(Scheme<Values> const& s, std::uint8_t const* data, std::size_t len) {
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

  static UnpackResult<> unpack(Scheme<Values> const& s, std::vector<std::uint8_t> const& data) {
    return unpack(s, data.data(), data.size());
  }

  template <typename T>
  static UnpackResult<T> unpack(Scheme<T> const& s, std::uint8_t const* data, std::size_t len) {
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
  static UnpackResult<T> unpack(Scheme<T> const& s, std::vector<std::uint8_t> const& data) {
    return unpack(s, data.data(), data.size());
  }

  template <typename... Handlers>
  static UnpackResult<> unpack(std::uint8_t const* data, std::size_t len,
                               Handlers const&... handlers);

  template <typename... Handlers>
  static UnpackResult<> unpack(std::vector<std::uint8_t> const& data, Handlers const&... handlers) {
    return unpack(data.data(), data.size(), handlers...);
  }
};

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
  auto row = BinaryPacker::unpack(h.scheme, data, len);
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
UnpackResult<> BinaryPacker::unpack(std::uint8_t const* data, std::size_t len,
                                    Handlers const&... handlers) {
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
