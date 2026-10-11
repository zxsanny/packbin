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

// Kinds whose value a `when` can read; a count reads integers only (see `resolve`).
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
// starting at `scope`, or -1. An empty group is a source too, but it takes the id of the field
// after it, so a field of that id wins when there is one.
constexpr int find_ref(Field const* t, std::size_t scope, std::size_t before, int id) {
  int group = -1;
  std::size_t j = scope;
  while (j < before) {
    Field const& f = t[j];
    if (is_container(f.kind) && j + f.span <= before) {
      j += f.span;
      continue;
    }
    if (f.id == id && f.access != nullptr && f.span == 1) {
      if (is_count_source(f.kind))
        return static_cast<int>(j);
      if (f.kind == Kind::Group && group < 0)
        group = static_cast<int>(j);
    }
    ++j;
  }
  return group;
}

// A `when` source that holds a u2 slot reads 0..3; otherwise the range of its integer type. A
// presence source (bool or empty group) keeps its own rule (`true` only).
constexpr bool eq_fits(Field const* t, std::size_t at, std::int64_t value) {
  for (std::size_t k = 0; k < at; ++k) {
    if (t[k].kind == Kind::U2 && at < k + t[k].span)
      return value >= 0 && value <= 3;
  }
  switch (t[at].kind) {
    case Kind::U8:
      return value >= 0 && value <= 255;
    case Kind::U16:
      return value >= 0 && value <= 65535;
    case Kind::U32:
      return value >= 0 && value <= 4294967295;
    case Kind::U64:
      return value >= 0;
    case Kind::I8:
      return value >= -128 && value <= 127;
    case Kind::I16:
      return value >= -32768 && value <= 32767;
    case Kind::I32:
      return value >= -2147483647 - 1 && value <= 2147483647;
    default:
      return true;
  }
}

// Index of the flag byte numbered `number` in t[begin, end) before `before`, or -1. A part that
// ends before `before` and may not have run (a `when`, `flags`, a flag bit, a round or a list
// or dict element) hides the bytes it holds; so does every member of `flags` that ends before
// `before`, whatever it is. `members` is true when t[begin, end) are the members of `flags`.
constexpr int find_flag_byte_in(Field const* t, std::size_t begin, std::size_t end,
                                std::size_t before, int number, bool members) {
  int found = -1;
  for (std::size_t j = begin; j < end && j < before; j += t[j].span) {
    Field const& f = t[j];
    bool closed = j + f.span <= before;
    if (closed && (members || is_container(f.kind) || f.kind == Kind::When ||
                   f.kind == Kind::Flags || f.kind == Kind::FlagBit))
      continue;
    if (f.kind == Kind::FlagByte && f.size == number)
      found = static_cast<int>(j);
    int inner = find_flag_byte_in(t, j + 1, j + f.span, before, number, f.kind == Kind::Flags);
    if (inner >= 0)
      found = inner;
  }
  return found;
}

constexpr int find_flag_byte(Field const* t, std::size_t scope, std::size_t before, int number) {
  return find_flag_byte_in(t, scope, before, before, number, false);
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

// Sets `late` on the flag bit at `bit`: the first `when` or `times` it decides, directly or
// inside groups, whose source comes after the flag byte (resolved already).
constexpr void mark_late(Field* t, std::size_t bit, Check& c) {
  std::size_t end = bit + t[bit].span;
  for (std::size_t i = bit + 1; i < end; i += t[i].kind == Kind::Group ? 1 : t[i].span) {
    bool decided = t[i].kind == Kind::When || t[i].kind == Kind::Times;
    if (decided && t[i].ref > t[bit].ref) {
      if (i - bit > 255)
        c.fail_at(t[i].id);
      else
        t[bit].late = static_cast<std::uint8_t>(i - bit);
      return;
    }
  }
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
      // A bool is a source of a `when` for `true` only: a false bool is absent on the wire, so
      // the `when` could never match on unpack. A count names an integer field only. A `when`
      // whose value its source can never hold could never match either.
      bool bool_ok = f.kind == Kind::When && f.eq == 1;
      bool presence = at >= 0 && (t[at].kind == Kind::Bool || t[at].kind == Kind::Group);
      if (at < 0 || (presence && !bool_ok) ||
          (f.kind == Kind::When && !eq_fits(t, static_cast<std::size_t>(at), f.eq))) {
        c.fail_at(f.id);
        return;
      }
      f.ref = static_cast<std::int16_t>(at);
    }
    if (f.span > 1)
      resolve(t, j + 1, j + f.span, is_container(f.kind) ? j + 1 : scope, c);
    if (f.kind == Kind::FlagBit && !c.failed)
      mark_late(t, j, c);
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
