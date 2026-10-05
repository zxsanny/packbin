#pragma once

#include "packbin/table.hpp"

#include <cstddef>
#include <cstdint>

// Field-order and reference rules, evaluated at compile time for a constexpr scheme and at
// run time for a scheme built at run time. Same rules as the other five languages: each field
// takes the next order id; flags, when, repeat, times and group take the id of their first
// child (the anchor); a flag byte, list and dict take none (list and dict elements start at 0).

namespace packbin {
namespace detail {

constexpr bool is_container(Kind k) {
  return k == Kind::Repeat || k == Kind::Times || k == Kind::List || k == Kind::Dict;
}

// Kinds whose value a `when` or a count can read.
constexpr bool is_count_source(Kind k) {
  switch (k) {
    case Kind::U8:
    case Kind::U16:
    case Kind::U32:
    case Kind::U64:
    case Kind::I8:
    case Kind::I16:
    case Kind::I32:
    case Kind::I64:
    case Kind::Bool:
      return true;
    default:
      return false;
  }
}

struct Check {
  bool failed = false;
  int field = -1;

  constexpr void fail_at(int id) {
    if (!failed) {
      failed = true;
      field = id;
    }
  }
};

constexpr int check_subtree(Field const* t, std::size_t i, int next, Check& c);

constexpr int check_children(Field const* t, std::size_t i, int next, Check& c) {
  std::size_t end = i + t[i].span;
  for (std::size_t j = i + 1; j < end && !c.failed; j += t[j].span)
    next = check_subtree(t, j, next, c);
  return next;
}

constexpr int check_subtree(Field const* t, std::size_t i, int next, Check& c) {
  Field const& f = t[i];
  switch (f.kind) {
    case Kind::FlagByte:
      return next;
    case Kind::FlagBit:
    case Kind::U2:
      return check_children(t, i, next, c);
    case Kind::List:
      check_children(t, i, 0, c);
      return next;
    case Kind::Dict:
      // The first child is the entry key, which has no order id.
      if (f.span > 2)
        check_subtree(t, i + 2, 0, c);
      return next;
    case Kind::Flags:
    case Kind::When:
    case Kind::Repeat:
    case Kind::Times:
    case Kind::Group:
      if (f.id != next) {
        c.fail_at(f.id);
        return next;
      }
      return check_children(t, i, next, c);
    default:
      if (f.id != next) {
        c.fail_at(f.id);
        return next;
      }
      return next + 1;
  }
}

// Index of the bound count source with order id `id` that comes before `before` in the scope
// starting at `scope`, or -1.
constexpr int find_ref(Field const* t, std::size_t scope, std::size_t before, int id) {
  std::size_t j = scope;
  while (j < before) {
    Field const& f = t[j];
    if (is_container(f.kind) && j + f.span <= before) {
      j += f.span;
      continue;
    }
    if (f.id == id && is_count_source(f.kind) && f.access != nullptr && f.span == 1)
      return static_cast<int>(j);
    ++j;
  }
  return -1;
}

// Index of the flag byte numbered `number` before `before` in the scope, or -1.
constexpr int find_flag_byte(Field const* t, std::size_t scope, std::size_t before, int number) {
  int found = -1;
  std::size_t j = scope;
  while (j < before) {
    Field const& f = t[j];
    if (is_container(f.kind) && j + f.span <= before) {
      j += f.span;
      continue;
    }
    if (f.kind == Kind::FlagByte && f.size == number)
      found = static_cast<int>(j);
    ++j;
  }
  return found;
}

// Position of the flag bit at `at` among the bits of its flag byte.
constexpr int bit_position(Field const* t, std::size_t byte, std::size_t at) {
  int n = 0;
  for (std::size_t j = byte + 1; j < at; ++j) {
    if (t[j].kind == Kind::FlagBit && t[j].ref == static_cast<std::int16_t>(byte))
      ++n;
  }
  return n;
}

constexpr void resolve(Field* t, std::size_t begin, std::size_t end, std::size_t scope,
                       Check& c) {
  for (std::size_t j = begin; j < end && !c.failed; j += t[j].span) {
    Field& f = t[j];
    if (f.kind == Kind::FlagBit) {
      int byte = find_flag_byte(t, scope, j, f.size);
      int child = f.span > 1 ? t[j + 1].id : -1;
      if (byte < 0) {
        c.fail_at(child);
        return;
      }
      f.ref = static_cast<std::int16_t>(byte);
      int position = bit_position(t, static_cast<std::size_t>(byte), j);
      if (position > 7) {
        c.fail_at(child);
        return;
      }
      f.bit = static_cast<std::uint8_t>(position);
    }
    if (f.ref_id >= 0) {
      int at = find_ref(t, scope, j, f.ref_id);
      if (at < 0) {
        c.fail_at(f.id);
        return;
      }
      f.ref = static_cast<std::int16_t>(at);
    }
    if (f.span > 1)
      resolve(t, j + 1, j + f.span, is_container(f.kind) ? j + 1 : scope, c);
  }
}

// A u2 packs into a 16-byte buffer: at most 64 two-bit children.
constexpr std::size_t kMaxU2Children = 64;

// `presence_ok`: the entries here are children of `flags` or of a flag bit. A bool or an empty
// group is only a presence bit, so it is accepted nowhere else.
constexpr void check_shape(Field const* t, std::size_t begin, std::size_t end, bool presence_ok,
                           Check& c) {
  for (std::size_t j = begin; j < end && !c.failed; j += t[j].span) {
    Field const& f = t[j];
    std::size_t children = 0;
    for (std::size_t k = j + 1; k < j + f.span; k += t[k].span)
      ++children;
    bool is_presence = f.kind == Kind::Bool || (f.kind == Kind::Group && f.span == 1);
    bool too_wide = (f.kind == Kind::Flags && children > 8) ||
                    (f.kind == Kind::U2 && children > kMaxU2Children);
    if (too_wide || (is_presence && !presence_ok) || (f.flags & flag::Invalid) != 0)
      c.fail_at(f.id);
    if (f.span > 1)
      check_shape(t, j + 1, j + f.span, f.kind == Kind::Flags || f.kind == Kind::FlagBit, c);
  }
}

}  // namespace detail

// Checks a whole scheme table and resolves its `when` and count references.
constexpr Result check_table(Field* t, std::size_t n) {
  detail::Check c{};
  int next = 0;
  for (std::size_t j = 0; j < n && !c.failed; j += t[j].span)
    next = detail::check_subtree(t, j, next, c);
  if (!c.failed)
    detail::check_shape(t, 0, n, false, c);
  if (!c.failed)
    detail::resolve(t, 0, n, 0, c);
  if (c.failed)
    return fail(Error::SchemeInvalid, 0, c.field);
  return Result{};
}

}  // namespace packbin
