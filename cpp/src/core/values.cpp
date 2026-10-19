#include "values.hpp"

#include "packbin/platform.hpp"

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

bool any_child_present(Field const* t, std::size_t i, void* obj, std::uint8_t skip) {
  for (std::size_t j = i + 1; j < i + t[i].span; j += t[j].span) {
    if (present(t, j, obj, skip))
      return true;
  }
  return false;
}

// A times is present when its count is above zero or the row holds rounds (a count of zero
// with rounds is refused on pack, not dropped). Rounds whose count is not in the row are present
// too, so pack refuses them; a count that is not in the row and no rounds is no round.
bool times_present(Field const* t, Field const& f, void* m, void* obj) {
  bool rounds = m != nullptr && *f.count(m) != 0;
  std::int64_t count = 0;
  if (f.ref < 0 || !read_int(t[f.ref], obj, count))
    return rounds;
  return count != 0 || rounds;
}

}  // namespace

bool present(Field const* t, std::size_t i, void* obj, std::uint8_t skip) {
  Field const& f = t[i];
  if ((f.flags & skip) != 0)
    return false;
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
      return any_child_present(t, i, obj, skip);
    case Kind::Flags:
    case Kind::FlagBit:
    case Kind::U2:
      return any_child_present(t, i, obj, skip);
    case Kind::When:
      return when_matches(t, f, obj) && any_child_present(t, i, obj, skip);
    case Kind::Times:
      return times_present(t, f, m, obj);
    case Kind::Repeat:
      return m != nullptr && *f.count(m) != 0;
    default:
      return m != nullptr;
  }
}

bool read_int(Field const& f, void* obj, std::int64_t& out) {
  void* m = member(f, obj);
  if (m == nullptr)
    return false;
  if (f.kind == Kind::Bool || (f.kind == Kind::Group && f.span == 1)) {
    bool on = flag_on(f, m);
    out = on ? 1 : 0;
    return true;
  }
  if (!present(&f, 0, obj))
    return false;
  Result r = visit_integer(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    out = static_cast<std::int64_t>(load_member<T>(f, m));
    return Result{};
  });
  return r.ok();
}

bool when_matches(Field const* t, Field const& f, void* obj) {
  std::int64_t value = 0;
  return f.ref >= 0 && read_int(t[f.ref], obj, value) && value == f.eq;
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
    if (m != nullptr && (f.borrowed() || f.opaque() || f.fixed())) {
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
  } else if (f.opaque()) {
    auto const* v = static_cast<Packed const*>(m);
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
  if (f.opaque()) {
    *static_cast<Packed*>(m) = Packed{p, n};
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
  else if (f.opaque())
    *static_cast<Packed*>(m) = Packed{};
  else if (f.fixed())
    *static_cast<std::uint16_t*>(m) = 0;
}

namespace {

// A number is moved as its bytes through one 64-bit value, so the byte loops exist once and not
// once per number type (flash on the smallest targets). The byte order comes from the field.
std::uint64_t load_bits(std::uint8_t const* p, std::size_t n, bool be) {
  std::uint64_t v = 0;
  for (std::size_t k = 0; k < n; ++k)
    v = (v << 8) | p[be ? k : n - 1 - k];
  return v;
}

void store_bits(std::uint8_t* p, std::uint64_t v, std::size_t n, bool be) {
  for (std::size_t k = 0; k < n; ++k) {
    p[be ? n - 1 - k : k] = static_cast<std::uint8_t>(v);
    v >>= 8;
  }
}

template <typename T>
std::uint64_t to_u64(T value) {
  if constexpr (detail::is_floating_point<T>::value)
    return to_bits(value);
  else
    return static_cast<std::uint64_t>(value);
}

template <typename T>
T from_u64(std::uint64_t bits) {
  if constexpr (detail::is_floating_point<T>::value)
    return from_bits<T>(static_cast<unsigned_of<T>>(bits));
  else
    return static_cast<T>(bits);
}

}  // namespace

Result put_number(Field const& f, void* m, Writer& w) {
  return visit_number(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    if (w.cap - w.len < sizeof(T))
      return fail(Error::BufferFull, w.len, f.id, sizeof(T));
    store_bits(w.data + w.len, to_u64(load_member<T>(f, m)), sizeof(T), f.be());
    w.len += sizeof(T);
    return Result{Error::Ok, w.len};
  });
}

Result get_number(Field const& f, void* m, Reader& r) {
  return visit_number(f.kind, f.id, [&](auto zero) {
    using T = decltype(zero);
    if (r.left() < sizeof(T))
      return fail(Error::ShortPacket, r.pos, f.id, sizeof(T));
    T value = from_u64<T>(load_bits(r.data + r.pos, sizeof(T), f.be()));
    r.pos += sizeof(T);
    if (m != nullptr)
      store_member<T>(f, m, value);
    return Result{Error::Ok, r.pos};
  });
}

void set_bool(Field const& f, void* m) { set_flag(f, m, true); }

}  // namespace detail
}  // namespace packbin
