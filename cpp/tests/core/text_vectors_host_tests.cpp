// Compact text vectors (AZ-2655): every row kind of fixtures/text/vectors.txt through pack and
// unpack. enc: pack gives the bytes, unpack gives the text and uses every byte. alt: unpack gives
// the text. bad: unpack is refused. ref: the ring packets. flip: each payload bit flipped.
#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <initializer_list>
#include <sstream>
#include <string>
#include <vector>

using check::expect;
using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::Text;

namespace {

constexpr std::size_t kCap = 16384;  // the longest vector text is 16,383 bytes

struct One {
  Text<kCap> s;
};

struct OneThenByte {
  Text<kCap> s;
  std::uint8_t after = 0;
};

constexpr auto one = packbin::scheme<One>(1, packbin::utf8<&One::s>(0));
constexpr auto skipping = packbin::scheme<One>(1, packbin::utf8(0));
constexpr auto flipping = packbin::scheme<OneThenByte>(1, packbin::utf8<&OneThenByte::s>(0),
                                                       packbin::u8<&OneThenByte::after>(1));

using Bytes = std::vector<std::uint8_t>;

struct Row {
  std::string kind;
  std::string id;
  std::string a;
  std::string b;
};

int nibble(char c) { return c <= '9' ? c - '0' : c - 'a' + 10; }

// "-" is the empty text; the buffer of a `bad` row may be empty too.
Bytes from_hex(std::string const& hex) {
  Bytes out;
  if (hex == "-")
    return out;
  for (std::size_t i = 0; i + 1 < hex.size(); i += 2)
    out.push_back(static_cast<std::uint8_t>(nibble(hex[i]) * 16 + nibble(hex[i + 1])));
  return out;
}

bool read_rows(std::vector<Row>& rows) {
  for (auto const* path : {"../fixtures/text/vectors.txt", "fixtures/text/vectors.txt"}) {
    std::ifstream in(path);
    if (!in)
      continue;
    std::string line;
    while (std::getline(in, line)) {
      if (line.empty() || line[0] == '#')
        continue;
      std::istringstream fields(line);
      Row r;
      // enc/alt <id> <text> <field>; bad <id> <kind> <buffer> (the buffer may be empty); ref <id>
      // <packet>; flip <id> <enc id>.
      fields >> r.kind >> r.id >> r.a >> r.b;
      rows.push_back(r);
    }
    return true;
  }
  return false;
}

Bytes packet_of(Bytes const& field) {
  Bytes p{0x01};
  p.insert(p.end(), field.begin(), field.end());
  return p;
}

packbin::Scratch<kCap>& scratch() {
  static packbin::Scratch<kCap> s;
  return s;
}

One& row_one() {
  static One r;
  return r;
}

OneThenByte& row_flip() {
  static OneThenByte r;
  return r;
}

bool same_text(Text<kCap> const& t, Bytes const& want) {
  return t.len == want.size() && (want.empty() || std::memcmp(t.data, want.data(), t.len) == 0);
}

void run_enc(Row const& r, bool alt) {
  Bytes text = from_hex(r.a);
  Bytes field = from_hex(r.b);
  Bytes packet = packet_of(field);
  if (!alt) {
    One& row = row_one();
    row.s.len = static_cast<std::uint16_t>(text.size());
    if (!text.empty())
      std::memcpy(row.s.data, text.data(), text.size());
    static std::uint8_t out[kCap + 16];
    auto p = packbin::pack(one, row, out, sizeof(out), scratch());
    expect(p.ok() && p.offset == packet.size() && std::memcmp(out, packet.data(), p.offset) == 0,
           r.id.c_str());
    // Not one byte more or less room: the exact size packs, one byte less is BufferFull.
    auto fits = packbin::pack(one, row, out, packet.size(), scratch());
    expect(fits.ok(), r.id.c_str());
    auto tight = packbin::pack(one, row, out, packet.size() - 1, scratch());
    expect(tight.error == Error::BufferFull && tight.field == 0, r.id.c_str());
  }
  One& back = row_one();
  back.s.len = 7;
  auto u = packbin::unpack(one, packet.data(), packet.size(), back);
  expect(u.ok() && same_text(back.s, text), r.id.c_str());
  auto k = packbin::unpack(skipping, packet.data(), packet.size(), back);
  expect(k.ok(), r.id.c_str());
}

void run_bad(Row const& r) {
  Bytes packet = packet_of(from_hex(r.b));
  auto u = packbin::unpack(one, packet.data(), packet.size(), row_one());
  expect(!u.ok(), r.id.c_str());
  auto k = packbin::unpack(skipping, packet.data(), packet.size(), row_one());
  expect(!k.ok(), r.id.c_str());
}

// ---- ref rows: the user and nested packets of the ring, with the new strings.

using Word = Text<32>;
using Names = Array<Word, 4>;

struct User {
  Word name;
  Names roles;
  Array<Entry<Names, Word>, 4> access;
};

constexpr auto user_scheme = packbin::scheme<User>(
    1, packbin::utf8<&User::name>(0), packbin::list<&User::roles>(packbin::utf8(0)),
    packbin::dict<&User::access>(packbin::list(packbin::utf8(0))));

using Fields = Array<Entry<Word, Word>, 4>;
using Rows = Array<Fields, 4>;

struct Nested {
  Array<Entry<Rows, Word>, 4> access;
};

constexpr auto nested_scheme = packbin::scheme<Nested>(
    1, packbin::dict<&Nested::access>(packbin::list(packbin::dict(packbin::utf8(0)))));

void put(Word& w, char const* s) {
  w.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(w.data, s, w.len);
}

bool is(Word const& w, char const* s) {
  return w.len == std::strlen(s) && std::memcmp(w.data, s, w.len) == 0;
}

void names(Names& n, std::initializer_list<char const*> items) {
  n.count = 0;
  for (auto const* s : items)
    put(n.items[n.count++], s);
}

void fields(Fields& f, std::initializer_list<char const*> pairs) {
  f.count = 0;
  for (auto it = pairs.begin(); it != pairs.end(); it += 2) {
    put(f.items[f.count].key, it[0]);
    put(f.items[f.count].value, it[1]);
    ++f.count;
  }
}

// Packs `row`, compares with the vector, unpacks the vector and packs that again; returns what
// was unpacked.
template <typename R, std::size_t N>
R const& ref_roundtrip(Row const& r, packbin::Scheme<R, N> const& s, R const& row) {
  Bytes want = from_hex(r.a);
  static std::uint8_t out[256];
  packbin::Scratch<32> sc;
  auto p = packbin::pack(s, row, out, sizeof(out), sc);
  expect(p.ok() && p.offset == want.size() && std::memcmp(out, want.data(), p.offset) == 0,
         r.id.c_str());
  static R back;
  auto u = packbin::unpack(s, want.data(), want.size(), back);
  auto again = packbin::pack(s, back, out, sizeof(out), sc);
  expect(u.ok() && again.ok() && again.offset == want.size() &&
             std::memcmp(out, want.data(), want.size()) == 0,
         r.id.c_str());
  return back;
}

void user_row(User& u, char const* name, std::initializer_list<char const*> roles) {
  put(u.name, name);
  names(u.roles, roles);
  u.access.count = 0;
}

void add_access(User& u, char const* key, std::initializer_list<char const*> actions) {
  put(u.access.items[u.access.count].key, key);
  names(u.access.items[u.access.count].value, actions);
  ++u.access.count;
}

void run_ref(Row const& r) {
  static User u;
  static Nested n;
  if (r.id == "ref.user") {
    user_row(u, "zxsanny", {"user", "dispatcher"});
    add_access(u, "channel", {"read"});
    add_access(u, "map", {"read", "gps_fix", "set", "edit"});
    add_access(u, "store", {"read", "write"});
    User const& back = ref_roundtrip(r, user_scheme, u);
    expect(is(back.name, "zxsanny") && is(back.access.items[1].value.items[1], "gps_fix"),
           "ref.user unpacked");
  } else if (r.id == "ref.user_ua") {
    user_row(u, "Олександр", {"диспетчер", "Оператор"});
    add_access(u, "канал", {"читати"});
    add_access(u, "карта", {"читати", "правити"});
    User const& back = ref_roundtrip(r, user_scheme, u);
    expect(is(back.name, "Олександр") && is(back.roles.items[1], "Оператор"),
           "ref.user_ua unpacked");
  } else if (r.id == "ref.nested") {
    n.access.count = 2;
    put(n.access.items[0].key, "map");
    n.access.items[0].value.count = 1;
    fields(n.access.items[0].value.items[0], {"op", "gps_fix"});
    put(n.access.items[1].key, "store");
    n.access.items[1].value.count = 2;
    fields(n.access.items[1].value.items[0], {"op", "read"});
    fields(n.access.items[1].value.items[1], {"op", "write"});
    ref_roundtrip(r, nested_scheme, n);
  } else if (r.id == "ref.nested_mixed") {
    n.access.count = 2;
    put(n.access.items[0].key, "store");
    n.access.items[0].value.count = 1;
    fields(n.access.items[0].value.items[0], {"op", "ЧИТАТИ"});
    put(n.access.items[1].key, "Карта");
    n.access.items[1].value.count = 1;
    fields(n.access.items[1].value.items[0], {"note", "увага 48.46, 35.04", "op", "gps_fix"});
    ref_roundtrip(r, nested_scheme, n);
  } else {
    expect(false, "a ref row this test does not know");
  }
}

// ---- flip rows.

// Flips each bit of the payload (not the count) in [field][5a]: a string or an error, and a string
// is followed by 5a. Nothing reads or writes past the buffer (the Text has room for any output).
void run_flip(Row const& r, std::vector<Row> const& rows) {
  Bytes field;
  for (auto const& e : rows)
    if (e.kind == "enc" && e.id == r.a)
      field = from_hex(e.b);
  expect(!field.empty(), r.id.c_str());
  std::size_t head = 1;
  while (head < field.size() && (field[head - 1] & 0x80) != 0)
    ++head;
  Bytes packet = packet_of(field);
  packet.push_back(0x5a);
  for (std::size_t bit = 0; bit < 8 * (field.size() - head); ++bit) {
    Bytes flipped = packet;
    flipped[1 + head + bit / 8] ^= static_cast<std::uint8_t>(0x80 >> (bit % 8));
    OneThenByte& back = row_flip();
    back.after = 0;
    auto u = packbin::unpack(flipping, flipped.data(), flipped.size(), back);
    expect(!u.ok() || (back.after == 0x5a && back.s.len <= 6 * (field.size() - head) + 8),
           r.id.c_str());
  }
}

}  // namespace

int run_core_text_vectors_host_tests() {
  std::vector<Row> rows;
  expect(read_rows(rows), "fixtures/text/vectors.txt found");
  std::size_t seen[6] = {};
  for (auto const& r : rows) {
    if (r.kind == "enc") {
      run_enc(r, false);
      ++seen[0];
    } else if (r.kind == "alt") {
      run_enc(r, true);
      ++seen[1];
    } else if (r.kind == "bad") {
      run_bad(r);
      ++seen[2];
    } else if (r.kind == "ref") {
      run_ref(r);
      ++seen[3];
    } else if (r.kind == "flip") {
      run_flip(r, rows);
      ++seen[4];
    } else {
      expect(false, "a row kind this test does not know");
    }
  }
  // Every enc row also gets the flip treatment, short fields only (the long ones are corpus text).
  for (auto const& r : rows) {
    if (r.kind == "enc" && r.b.size() <= 200) {
      Row flip{"flip", "flip.all." + r.id, r.id, ""};
      run_flip(flip, rows);
      ++seen[5];
    }
  }
  expect(seen[0] >= 300 && seen[1] >= 10 && seen[2] >= 30 && seen[3] == 4 && seen[4] >= 20,
         "every row kind ran");
  std::printf("text vectors: enc %zu alt %zu bad %zu ref %zu flip %zu (+%zu all-enc flips)\n",
              seen[0], seen[1], seen[2], seen[3], seen[4], seen[5]);
  return 0;
}
