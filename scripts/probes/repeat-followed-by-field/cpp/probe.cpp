// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md with the public API, packs the values given there and unpacks its own bytes. One line
// per shape: package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what
// happens.
//
// C++ rows are structs. The rounds of a repeat are an `Array<Round, N>` member, one `Round` a round
// (round 0 has v = 5, round 1 has v = 6); the values are printed under the names of the README, `v`
// as the list of the rounds' values. A failure is a `Result` value, printed as its members.
//
// A scheme is built at run time (`auto s = scheme<Row>(...)`, checked with `validate(s)`): the form
// that reports a refused scheme as a value. With -DPROBE_CONSTEXPR and one -DSHAPE_<NAME> the
// translation unit holds that one shape as a constant (`constexpr auto s = ...`), where a refused
// scheme does not compile; `run.sh` builds each shape that way too.
//
// `probe <shape>` prints one shape: `run.sh` starts one process per shape, so a crash in one shape
// is its own line.
#include <packbin/packbin.hpp>

#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <string>

namespace pb = packbin;

#ifdef PROBE_CONSTEXPR
#define PROBE_SCHEME constexpr auto
#define PROBE_SUFFIX "-constexpr"
#else
#define PROBE_SCHEME auto
#define PROBE_SUFFIX ""
#define SHAPE_CONTROL
#define SHAPE_A
#define SHAPE_B
#define SHAPE_B_UNBOUND
#define SHAPE_C
#define SHAPE_C_UNBOUND
#define SHAPE_D
#define SHAPE_E_WHEN
#define SHAPE_E_FLAGS
#define SHAPE_F
#endif

struct Round {
  std::uint8_t v = 0;
};

// Room for more rounds than any packet of the probe holds, so `TooMany` (an Array that is full) is
// never what the probe prints: with room for two rounds, a third round read from the bytes of the
// field after the repeat would be `TooMany` instead of what the walk finds next.
using Rounds = pb::Array<Round, 8>;

// control, a, d, e-flags.
struct Row {
  std::uint8_t x = 0;
  Rounds rounds;
};

// e-when.
struct KeyRow {
  std::uint8_t k = 0;
  std::uint8_t x = 0;
  Rounds rounds;
};

// f: one Array per repeat.
struct TwoRow {
  Rounds v;
  Rounds w;
};

// The element row of b and c.
struct Item {
  std::uint8_t mode = 0;
  Rounds rounds;
};

struct ListRow {
  pb::Array<Item, 4> items;
};

struct DictRow {
  pb::Array<pb::Entry<Item, pb::Text<4>>, 4> d;
};

std::string number(unsigned long long n) { return std::to_string(n); }

std::string shown(Rounds const& rounds) {
  std::string out = "[";
  for (std::size_t i = 0; i < rounds.count; ++i)
    out += (i == 0 ? "" : ",") + number(rounds.items[i].v);
  return out + "]";
}

std::string shown(Row const& r) { return "{\"v\":" + shown(r.rounds) + ",\"x\":" + number(r.x) + "}"; }

std::string shown(KeyRow const& r) {
  return "{\"k\":" + number(r.k) + ",\"v\":" + shown(r.rounds) + ",\"x\":" + number(r.x) + "}";
}

// An Array that holds no round is printed as `[]`.
std::string shown(TwoRow const& r) { return "{\"v\":" + shown(r.v) + ",\"w\":" + shown(r.w) + "}"; }

std::string shown(Item const& i) {
  return "{\"mode\":" + number(i.mode) + ",\"v\":" + shown(i.rounds) + "}";
}

std::string shown(ListRow const& r) {
  std::string out = "{\"items\":[";
  for (std::size_t i = 0; i < r.items.count; ++i)
    out += (i == 0 ? "" : ",") + shown(r.items.items[i]);
  return out + "]}";
}

std::string shown(DictRow const& r) {
  std::string out = "{\"d\":{";
  for (std::size_t i = 0; i < r.d.count; ++i) {
    auto const& e = r.d.items[i];
    out += (i == 0 ? "\"" : ",\"") + std::string(e.key.data, e.key.len) + "\":" + shown(e.value);
  }
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

// The package has no text for a failure: a `Result` is its error, the order id of the field (-1 when
// none), the bytes that field needed and the byte offset.
std::string refused(pb::Result const& r) {
  return std::string("refused: {\"error\":\"") + name_of(r.error) + "\",\"field\":" + std::to_string(r.field) +
         ",\"needed\":" + number(r.needed) + ",\"offset\":" + number(r.offset) + "}";
}

std::string hex(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  return out;
}

// Written at once: a line that a crash cuts short still holds the cells before it.
void emit(std::string const& text) {
  std::fputs(text.c_str(), stdout);
  std::fflush(stdout);
}

template <typename R, std::size_t N>
void probe(char const* shape, pb::Scheme<R, N> const& s, R const& values) {
  emit(std::string("cpp\t") + shape + PROBE_SUFFIX "\t");
  pb::Result built = pb::validate(s);
  if (!built.ok()) {
    emit(refused(built) + "\t-\t-\n");
    return;
  }
  emit("built\t");
  std::uint8_t buf[64] = {};
  // The keys of a dict are strings, and pack needs working memory to encode a string.
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

Rounds rounds_of(std::initializer_list<int> values) {
  Rounds out;
  for (int v : values)
    out.items[out.count++].v = static_cast<std::uint8_t>(v);
  return out;
}

Row row_of(std::initializer_list<int> v, int x) {
  Row r;
  r.rounds = rounds_of(v);
  r.x = static_cast<std::uint8_t>(x);
  return r;
}

Item item_of(int mode, std::initializer_list<int> v) {
  Item i;
  i.mode = static_cast<std::uint8_t>(mode);
  i.rounds = rounds_of(v);
  return i;
}

ListRow list_values() {
  ListRow r;
  r.items.items[r.items.count++] = item_of(1, {5});
  r.items.items[r.items.count++] = item_of(2, {});
  return r;
}

DictRow dict_values() {
  DictRow r;
  char const* keys[] = {"a", "b"};
  Item const items[] = {item_of(1, {5}), item_of(2, {})};
  for (std::size_t i = 0; i < 2; ++i) {
    auto& e = r.d.items[r.d.count++];
    e.key.len = static_cast<std::uint16_t>(std::strlen(keys[i]));
    std::memcpy(e.key.data, keys[i], e.key.len);
    e.value = items[i];
  }
  return r;
}

#ifdef SHAPE_CONTROL
// control: the repeat is the last thing read.
void shape_control() {
  PROBE_SCHEME s = pb::scheme<Row>(1, pb::u8<&Row::x>(0), pb::repeat<&Row::rounds>(1, pb::u8<&Round::v>(1)));
  probe("control", s, row_of({5, 6}, 9));
}
#endif

#ifdef SHAPE_A
// a: a field after a repeat, top level.
void shape_a() {
  PROBE_SCHEME s = pb::scheme<Row>(1, pb::repeat<&Row::rounds>(0, pb::u8<&Round::v>(0)), pb::u8<&Row::x>(1));
  probe("a", s, row_of({5, 6}, 9));
}
#endif

// The element row of b and c. An element is written unbound and bound through its list or dict; the
// only field that holds several fields is a group (C++ has no group without an anchor).
#define PROBE_ELEMENT pb::group(0, pb::u8(0), pb::repeat(1, pb::u8(1)))

#ifdef SHAPE_B
// b: a repeat inside a list element row, two items; the list is bound to an Array of the element rows.
void shape_b() {
  PROBE_SCHEME s = pb::scheme<ListRow>(1, pb::list<&ListRow::items>(PROBE_ELEMENT));
  probe("b", s, list_values());
}
#endif

#ifdef SHAPE_B_UNBOUND
// The same list unbound (`list(element)`): the scheme reads and skips the list, and has no member to
// pack it from.
void shape_b_unbound() {
  PROBE_SCHEME s = pb::scheme<ListRow>(1, pb::list(PROBE_ELEMENT));
  probe("b-unbound", s, list_values());
}
#endif

#ifdef SHAPE_C
// c: a repeat inside a dict element row, two entries; the dict is bound to an Array of entries.
void shape_c() {
  PROBE_SCHEME s = pb::scheme<DictRow>(1, pb::dict<&DictRow::d>(PROBE_ELEMENT));
  probe("c", s, dict_values());
}
#endif

#ifdef SHAPE_C_UNBOUND
void shape_c_unbound() {
  PROBE_SCHEME s = pb::scheme<DictRow>(1, pb::dict(PROBE_ELEMENT));
  probe("c-unbound", s, dict_values());
}
#endif

#ifdef SHAPE_D
// d: a repeat inside a group, then a field. C++ has no nested row: a group has an anchor, its members
// are members of the row around it and share its ids, so `x` is id 1.
void shape_d() {
  PROBE_SCHEME s = pb::scheme<Row>(
      1, pb::group(0, pb::repeat<&Row::rounds>(0, pb::u8<&Round::v>(0))), pb::u8<&Row::x>(1));
  probe("d", s, row_of({5, 6}, 9));
}
#endif

#ifdef SHAPE_E_WHEN
// e-when: a repeat under a when that is taken, then a field.
void shape_e_when() {
  PROBE_SCHEME s = pb::scheme<KeyRow>(
      1, pb::u8<&KeyRow::k>(0),
      pb::when(1, pb::eq(0, 1), pb::repeat<&KeyRow::rounds>(1, pb::u8<&Round::v>(1))),
      pb::u8<&KeyRow::x>(2));
  KeyRow values;
  values.k = 1;
  values.rounds = rounds_of({5, 6});
  values.x = 9;
  probe("e-when", s, values);
}
#endif

#ifdef SHAPE_E_FLAGS
// e-flags: a repeat under flags, then a field.
void shape_e_flags() {
  PROBE_SCHEME s = pb::scheme<Row>(
      1, pb::flags(0, pb::repeat<&Row::rounds>(0, pb::u8<&Round::v>(0))), pb::u8<&Row::x>(1));
  probe("e-flags", s, row_of({5, 6}, 9));
}
#endif

#ifdef SHAPE_F
// f: a repeat after a repeat, one round each; each repeat is bound to an Array of its own.
void shape_f() {
  PROBE_SCHEME s = pb::scheme<TwoRow>(
      1, pb::repeat<&TwoRow::v>(0, pb::u8<&Round::v>(0)), pb::repeat<&TwoRow::w>(1, pb::u8<&Round::v>(1)));
  TwoRow values;
  values.v = rounds_of({5});
  values.w = rounds_of({6});
  probe("f", s, values);
}
#endif

struct Shape {
  char const* name;
  void (*run)();
};

Shape const shapes[] = {
#ifdef SHAPE_CONTROL
    {"control", &shape_control},
#endif
#ifdef SHAPE_A
    {"a", &shape_a},
#endif
#ifdef SHAPE_B
    {"b", &shape_b},
#endif
#ifdef SHAPE_B_UNBOUND
    {"b-unbound", &shape_b_unbound},
#endif
#ifdef SHAPE_C
    {"c", &shape_c},
#endif
#ifdef SHAPE_C_UNBOUND
    {"c-unbound", &shape_c_unbound},
#endif
#ifdef SHAPE_D
    {"d", &shape_d},
#endif
#ifdef SHAPE_E_WHEN
    {"e-when", &shape_e_when},
#endif
#ifdef SHAPE_E_FLAGS
    {"e-flags", &shape_e_flags},
#endif
#ifdef SHAPE_F
    {"f", &shape_f},
#endif
};

int main(int argc, char** argv) {
  if (argc == 2) {
    for (Shape const& shape : shapes) {
      if (std::strcmp(shape.name, argv[1]) == 0) {
        shape.run();
        return 0;
      }
    }
  }
  std::fprintf(stderr, "usage: probe <shape>; this build holds:");
  for (Shape const& shape : shapes)
    std::fprintf(stderr, " %s", shape.name);
  std::fprintf(stderr, "\n");
  return 2;
}
