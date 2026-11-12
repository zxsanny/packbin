// Support of probe.cpp (AZ-4242): the rows and values of ../README.md, the output of one line (cells
// written as they come, a `Result` printed as its members, hex) and `probe`, which builds, packs
// and unpacks one shape. Included once, by probe.cpp only.
#pragma once

#include <packbin/packbin.hpp>

#include <cstdio>
#include <cstring>
#include <string>

namespace pb = packbin;

#ifdef PROBE_CONSTEXPR
#define PROBE_SCHEME constexpr auto
#define PROBE_SUFFIX "-constexpr"
#else
#define PROBE_SCHEME auto
#define PROBE_SUFFIX ""
#endif

// The element row of AZ-4199.
struct Comment {
  pb::Text<4> id;
  pb::Text<4> text;
  std::uint32_t authorId = 0;
  pb::Text<4> author;
};

struct ListRow {
  pb::Array<Comment, 4> items;
};

struct DictRow {
  pb::Array<pb::Entry<Comment, pb::Text<4>>, 4> map;
};

// The element row of `when`: speed is on the wire only for mode 1.
struct WhenItem {
  std::uint8_t mode = 0;
  std::uint8_t speed = 0;
};

struct WhenRow {
  pb::Array<WhenItem, 4> items;
};

// The element row of `times`: c rounds of v.
struct TimesItem {
  std::uint8_t c = 0;
  pb::Array<std::uint8_t, 4> v;
};

struct TimesRow {
  pb::Array<TimesItem, 4> items;
};

// Ids 0 to 3; a group's id is its anchor, the id of its first child.
#define PROBE_COMMENT pb::group(0, pb::utf8(0), pb::utf8(1), pb::u32(2), pb::utf8(3))
#define PROBE_WHEN_ITEM pb::group(0, pb::u8(0), pb::when(1, pb::eq(0, 1), pb::u8(1)))
#define PROBE_TIMES_ITEM pb::group(0, pb::u8(0), pb::times(1, 0, pb::u8(1)))

std::string number(unsigned long long n) { return std::to_string(n); }

template <std::size_t N>
std::string shown(pb::Text<N> const& t) {
  return "\"" + std::string(t.data, t.len) + "\"";
}

// Keys in sorted order, as the TypeScript probe prints them.
std::string shown(Comment const& c) {
  return "{\"author\":" + shown(c.author) + ",\"authorId\":" + number(c.authorId) + ",\"id\":" + shown(c.id) +
         ",\"text\":" + shown(c.text) + "}";
}

std::string shown(WhenItem const& i) { return "{\"mode\":" + number(i.mode) + ",\"speed\":" + number(i.speed) + "}"; }

std::string shown(TimesItem const& i) {
  std::string v = "[";
  for (std::size_t k = 0; k < i.v.count; ++k)
    v += (k == 0 ? "" : ",") + number(i.v.items[k]);
  return "{\"c\":" + number(i.c) + ",\"v\":" + v + "]}";
}

template <typename T, std::size_t N>
std::string shown(pb::Array<T, N> const& a) {
  std::string out = "[";
  for (std::size_t i = 0; i < a.count; ++i)
    out += (i == 0 ? "" : ",") + shown(a.items[i]);
  return out + "]";
}

std::string shown(ListRow const& r) { return "{\"items\":" + shown(r.items) + "}"; }
std::string shown(WhenRow const& r) { return "{\"items\":" + shown(r.items) + "}"; }
std::string shown(TimesRow const& r) { return "{\"items\":" + shown(r.items) + "}"; }

std::string shown(DictRow const& r) {
  std::string out = "{\"map\":{";
  for (std::size_t i = 0; i < r.map.count; ++i)
    out += (i == 0 ? "" : ",") + shown(r.map.items[i].key) + ":" + shown(r.map.items[i].value);
  return out + "}}";
}

char const* name_of(pb::Error e) {
  switch (e) {
    case pb::Error::Ok:
      return "Ok";
    case pb::Error::ShortPacket:
      return "ShortPacket";
    case pb::Error::TrailingBytes:
      return "TrailingBytes";
    case pb::Error::TypeMismatch:
      return "TypeMismatch";
    case pb::Error::BufferFull:
      return "BufferFull";
    case pb::Error::TooMany:
      return "TooMany";
    case pb::Error::BadValue:
      return "BadValue";
    case pb::Error::SchemeInvalid:
      return "SchemeInvalid";
    case pb::Error::ScratchTooSmall:
      return "ScratchTooSmall";
    case pb::Error::Uncorrectable:
      return "Uncorrectable";
    case pb::Error::TooLong:
      return "TooLong";
    case pb::Error::TagMismatch:
      return "TagMismatch";
    case pb::Error::Duplicate:
      return "Duplicate";
    case pb::Error::TooOld:
      return "TooOld";
  }
  return "unknown";
}

// The error, the order id of the field (-1 when none), the bytes that field needed and the offset.
std::string result_of(pb::Result const& r) {
  return std::string("{\"error\":\"") + name_of(r.error) + "\",\"field\":" + std::to_string(r.field) +
         ",\"needed\":" + number(r.needed) + ",\"offset\":" + number(r.offset) + "}";
}

std::string refused(pb::Result const& r) { return "refused: " + result_of(r); }

std::string hex(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  return out;
}

std::size_t from_hex(char const* text, std::uint8_t* out, std::size_t cap) {
  auto digit = [](char c) { return c <= '9' ? c - '0' : c - 'a' + 10; };
  std::size_t n = std::strlen(text) / 2;
  for (std::size_t i = 0; i < n && i < cap; ++i)
    out[i] = static_cast<std::uint8_t>(digit(text[2 * i]) * 16 + digit(text[2 * i + 1]));
  return n < cap ? n : cap;
}

// Written at once: a line that a crash cuts short still holds the cells before it.
void emit(std::string const& text) {
  std::fputs(text.c_str(), stdout);
  std::fflush(stdout);
}

void na(char const* shape, char const* why) { emit(std::string("cpp\t") + shape + "\tn/a: " + why + "\t-\t-\n"); }

// Set by `probe <shape> reference`.
bool g_reference = false;

// The TypeScript bytes of the shape read with the scheme, on stderr: the unbound form packs nothing,
// so this is the only way its reader meets an element row.
template <typename R, std::size_t N>
void read_reference(char const* shape, pb::Scheme<R, N> const& s, char const* reference) {
  std::string what = std::string("probe: ") + shape + PROBE_SUFFIX " reads the TypeScript bytes " + reference + ": ";
  pb::Result built = pb::validate(s);
  if (!built.ok()) {
    std::fprintf(stderr, "%snot built, %s\n", what.c_str(), refused(built).c_str());
    return;
  }
  std::uint8_t buf[128] = {};
  std::size_t len = from_hex(reference, buf, sizeof(buf));
  R got;
  pb::Result read = pb::unpack(s, buf, len, got);
  if (read.ok())
    std::fprintf(stderr, "%sOk, %zu of %zu bytes read\n", what.c_str(), read.offset, len);
  else
    std::fprintf(stderr, "%s%s\n", what.c_str(), refused(read).c_str());
}

template <typename R, std::size_t N>
void probe(char const* shape, pb::Scheme<R, N> const& s, R const& values, char const* reference) {
  if (g_reference) {
    read_reference(shape, s, reference);
    return;
  }
  emit(std::string("cpp\t") + shape + PROBE_SUFFIX "\t");
  pb::Result built = pb::validate(s);
  if (!built.ok()) {
    emit(refused(built) + "\t-\t-\n");
    return;
  }
  emit("built\t");
  std::uint8_t buf[128] = {};
  pb::Scratch<8> scratch;
  pb::Result packed = pb::pack(s, values, buf, sizeof(buf), scratch);
  if (!packed.ok()) {
    emit(refused(packed) + "\t-\n");
    return;
  }
  emit(hex(buf, packed.offset) + "\t");
  R got;
  pb::Result read = pb::unpack(s, buf, packed.offset, got);
  if (!read.ok()) {
    emit(refused(read) + "\n");
    return;
  }
  emit(shown(got) == shown(values) ? "same\n" : "differs: " + shown(got) + "\n");
}

template <std::size_t N>
void set_text(pb::Text<N>& t, char const* s) {
  t.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(t.data, s, t.len);
}

Comment comment(char const* id, char const* text, std::uint32_t author_id, char const* author) {
  Comment c;
  set_text(c.id, id);
  set_text(c.text, text);
  c.authorId = author_id;
  set_text(c.author, author);
  return c;
}

Comment c1() { return comment("c1", "hi", 7, "ann"); }
Comment c2() { return comment("c2", "ok", 258, "bo"); }
Comment c3() { return comment("c3", "yes", 1, "cy"); }

ListRow list_of(std::size_t n) {
  Comment const all[] = {c1(), c2(), c3()};
  ListRow r;
  for (std::size_t i = 0; i < n; ++i)
    r.items.items[r.items.count++] = all[i];
  return r;
}

// {b: c2, a: c1}: an Array of entries holds the keys in the ascending order pack requires.
DictRow dict_values() {
  DictRow r;
  set_text(r.map.items[0].key, "a");
  r.map.items[0].value = c1();
  set_text(r.map.items[1].key, "b");
  r.map.items[1].value = c2();
  r.map.count = 2;
  return r;
}

WhenRow when_values() {
  WhenRow r;
  r.items.items[0].mode = 1;
  r.items.items[0].speed = 7;
  r.items.items[1].mode = 0;
  r.items.count = 2;
  return r;
}

TimesRow times_values() {
  TimesRow r;
  r.items.items[0].c = 2;
  r.items.items[0].v.items[0] = 5;
  r.items.items[0].v.items[1] = 6;
  r.items.items[0].v.count = 2;
  r.items.items[1].c = 0;
  r.items.count = 2;
  return r;
}

// The bytes of the TypeScript probe.
[[maybe_unused]] char const kList0[] = "010000";
[[maybe_unused]] char const kList1[] = "01010003106331022aaa0700000003c91980";
[[maybe_unused]] char const kList3[] =
    "01030003106331022aaa0700000003c919800310633203106f6b020100000310626f0310633303cb22000100000003106379";
[[maybe_unused]] char const kDict2[] = "01020002106103106331022aaa0700000003c919800210620310633203106f6b020100000310626f";
[[maybe_unused]] char const kWhen[] = "010200010700";
[[maybe_unused]] char const kTimes[] = "01020002050600";
