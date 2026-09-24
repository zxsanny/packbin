#include "walk.hpp"

#include <stdexcept>

namespace packbin {

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

Value const& require(Values const& values, std::string const& name) {
  auto it = values.find(name);
  if (it == values.end())
    throw std::runtime_error("missing field " + name);
  return it->second;
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

}  // namespace packbin
