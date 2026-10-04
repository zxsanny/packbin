#include "values.hpp"

#include <cstring>

namespace packbin {
namespace detail {

namespace {

bool flag_on(Field const& f, void* m) {
  if (m == nullptr)
    return false;
  if (f.optional()) {
    auto const* o = static_cast<Opt<bool>*>(m);
    return o->has && o->value;
  }
  return *static_cast<bool*>(m);
}

void set_flag(Field const& f, void* m, bool on) {
  if (m == nullptr)
    return;
  if (f.optional()) {
    auto* o = static_cast<Opt<bool>*>(m);
    if (on)
      *o = true;
    else
      o->reset();
    return;
  }
  *static_cast<bool*>(m) = on;
}

}  // namespace

bool present(Field const* t, std::size_t i, void* obj) {
  Field const& f = t[i];
  void* m = member(f, obj);
  if (is_number(f.kind)) {
    if (m == nullptr)
      return false;
    if (!f.optional())
      return true;
    bool has = false;
    visit_number(f.kind, f.id, [&](auto zero) {
      has = static_cast<Opt<decltype(zero)>*>(m)->has;
      return Result{};
    });
    return has;
  }
  switch (f.kind) {
    case Kind::Bool:
      return flag_on(f, m);
    case Kind::Group:
      if (f.span == 1)
        return flag_on(f, m);
      for (std::size_t j = i + 1; j < i + f.span; j += t[j].span) {
        if (present(t, j, obj))
          return true;
      }
      return false;
    default:
      return m != nullptr;
  }
}

bool read_int(Field const& f, void* obj, std::int64_t& out) {
  void* m = member(f, obj);
  if (m == nullptr)
    return false;
  if (f.kind == Kind::Bool) {
    bool on = flag_on(f, m);
    out = on ? 1 : 0;
    return true;
  }
  if (!present(&f, 0, obj))
    return false;
  Result r = visit_number(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    out = static_cast<std::int64_t>(load_member<T>(f, m));
    return Result{};
  });
  return r.ok();
}

void clear_scope(Field const* t, std::size_t begin, std::size_t end, void* obj) {
  for (std::size_t j = begin; j < end; j += t[j].span) {
    Field const& f = t[j];
    void* m = member(f, obj);
    if (is_number(f.kind) && m != nullptr && f.optional()) {
      visit_number(f.kind, f.id, [&](auto zero) {
        static_cast<Opt<decltype(zero)>*>(m)->reset();
        return Result{};
      });
      continue;
    }
    if (f.kind == Kind::Bool || (f.kind == Kind::Group && f.span == 1)) {
      set_flag(f, m, false);
      continue;
    }
    if (m != nullptr && is_container(f.kind)) {
      *f.count(m) = 0;
      continue;
    }
    if (m != nullptr && (f.kind == Kind::Bits || f.kind == Kind::Packed)) {
      *f.count(m) = 0;
      continue;
    }
    if (m != nullptr && (f.borrowed() || f.fixed())) {
      clear_text(f, m);
      continue;
    }
    if (f.span > 1 && !is_container(f.kind))
      clear_scope(t, j + 1, j + f.span, obj);
  }
}

void text_bytes(Field const& f, void* m, std::uint8_t const*& data, std::size_t& len) {
  if (f.borrowed()) {
    auto const* v = static_cast<View const*>(m);
    data = v->data;
    len = v->len;
  } else if (f.fixed()) {
    data = static_cast<std::uint8_t const*>(m) + sizeof(std::uint16_t);
    len = *static_cast<std::uint16_t const*>(m);
  } else {
    data = static_cast<std::uint8_t const*>(m);
    len = f.size;
  }
}

Result store_text(Field const& f, void* m, std::uint8_t const* p, std::size_t n,
                  std::size_t offset) {
  if (m == nullptr)
    return Result{};
  if (f.borrowed()) {
    *static_cast<View*>(m) = View{p, n};
    return Result{};
  }
  if (f.fixed()) {
    if (n > f.size)
      return fail(Error::TooMany, offset, f.id, n);
    if (n != 0)
      std::memcpy(static_cast<std::uint8_t*>(m) + sizeof(std::uint16_t), p, n);
    *static_cast<std::uint16_t*>(m) = static_cast<std::uint16_t>(n);
    return Result{};
  }
  if (n != 0)
    std::memcpy(m, p, n);
  return Result{};
}

void clear_text(Field const& f, void* m) {
  if (f.borrowed())
    *static_cast<View*>(m) = View{};
  else if (f.fixed())
    *static_cast<std::uint16_t*>(m) = 0;
}

Result put_number(Field const& f, void* m, Writer& w) {
  return visit_number(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    return put_num<T>(w, load_member<T>(f, m), f.be(), f.id);
  });
}

Result get_number(Field const& f, void* m, Reader& r) {
  return visit_number(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    T value{};
    Result res = get_num<T>(r, value, f.be(), f.id);
    if (res.ok() && m != nullptr)
      store_member<T>(f, m, value);
    return res;
  });
}

void set_bool(Field const& f, void* m) { set_flag(f, m, true); }

}  // namespace detail
}  // namespace packbin
