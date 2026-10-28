#include "packbin/packbin.hpp"

#include <cctype>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <initializer_list>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using packbin::Array;
using packbin::Entry;
using Str = packbin::Text<16>;

Str text(char const* s) {
  Str t;
  t.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(t.data, s, t.len);
  return t;
}

bool text_is(Str const& v, char const* s) {
  return v.len == std::strlen(s) && std::memcmp(v.data, s, v.len) == 0;
}

using Names = Array<Str, 8>;

void set_names(Names& names, std::initializer_list<char const*> items) {
  names.count = 0;
  for (auto const* item : items)
    names.items[names.count++] = text(item);
}

bool names_are(Names const& names, std::initializer_list<char const*> items) {
  if (names.count != items.size())
    return false;
  std::size_t i = 0;
  for (auto const* item : items) {
    if (!text_is(names.items[i++], item))
      return false;
  }
  return true;
}

struct User {
  Str name;
  Names roles;
  Array<Entry<Names, Str>, 8> access;
};

constexpr auto user_scheme = packbin::scheme<User>(
    1, packbin::utf8<&User::name>(0), packbin::list<&User::roles>(packbin::utf8(0)),
    packbin::dict<&User::access>(packbin::list(packbin::utf8(0))));

User user_row() {
  User row;
  row.name = text("zxsanny");
  set_names(row.roles, {"user", "dispatcher"});
  row.access.count = 3;
  row.access.items[0].key = text("channel");
  set_names(row.access.items[0].value, {"read"});
  row.access.items[1].key = text("map");
  set_names(row.access.items[1].value, {"read", "gps_fix", "set", "edit"});
  row.access.items[2].key = text("store");
  set_names(row.access.items[2].value, {"read", "write"});
  return row;
}

Names const* find(Array<Entry<Names, Str>, 8> const& access, char const* key) {
  for (std::size_t i = 0; i < access.count; ++i) {
    if (text_is(access.items[i].key, key))
      return &access.items[i].value;
  }
  return nullptr;
}

using Fields = Array<Entry<Str, Str>, 4>;
using Rows = Array<Fields, 4>;

struct Nested {
  Array<Entry<Rows, Str>, 4> access;
};

constexpr auto nested_scheme = packbin::scheme<Nested>(
    1, packbin::dict<&Nested::access>(packbin::list(packbin::dict(packbin::utf8(0)))));

void set_op(Fields& fields, char const* op) {
  fields.count = 1;
  fields.items[0].key = text("op");
  fields.items[0].value = text(op);
}

bool op_is(Fields const& fields, char const* op) {
  return fields.count == 1 && text_is(fields.items[0].key, "op") &&
         text_is(fields.items[0].value, op);
}

Nested nested_row() {
  Nested row;
  row.access.count = 2;
  row.access.items[0].key = text("map");
  row.access.items[0].value.count = 1;
  set_op(row.access.items[0].value.items[0], "gps_fix");
  row.access.items[1].key = text("store");
  row.access.items[1].value.count = 2;
  set_op(row.access.items[1].value.items[0], "read");
  set_op(row.access.items[1].value.items[1], "write");
  return row;
}

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  packbin::Opt<std::uint16_t> heading;
  packbin::Opt<std::uint8_t> speed;
  packbin::Opt<std::int16_t> altitude;
};

constexpr auto position_scheme = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::flags(4, packbin::u16<&Position::heading>(4), packbin::u8<&Position::speed>(5),
                   packbin::i16<&Position::altitude>(6)));

struct BoolFlag {
  packbin::Opt<bool> on;
};

constexpr auto boolflag_scheme =
    packbin::scheme<BoolFlag>(1, packbin::flags(0, packbin::boolean<&BoolFlag::on>(0)));

struct BitWhen {
  std::uint8_t k = 0;
  packbin::Opt<std::uint8_t> v;
};

constexpr auto bitwhen_scheme = packbin::scheme<BitWhen>(
    1, packbin::u8<&BitWhen::k>(0), packbin::flag_byte(0),
    packbin::when(1, packbin::eq(0, 1), packbin::flag_bit(0, packbin::u8<&BitWhen::v>(1))));

struct FlagRound {
  packbin::Opt<bool> on;
  packbin::Opt<std::uint8_t> n;
};

struct RoundFlags {
  Array<FlagRound, 4> rounds;
};

constexpr auto roundflags_scheme = packbin::scheme<RoundFlags>(
    1, packbin::repeat<&RoundFlags::rounds>(
           0, packbin::flags(0, packbin::boolean<&FlagRound::on>(0),
                             packbin::u8<&FlagRound::n>(1))));

RoundFlags roundflags_row() {
  RoundFlags row;
  row.rounds.count = 3;
  row.rounds.items[0].on = true;
  row.rounds.items[1].on = false;
  row.rounds.items[2].on = true;
  for (std::size_t i = 0; i < row.rounds.count; ++i)
    row.rounds.items[i].n = static_cast<std::uint8_t>(i + 1);
  return row;
}

struct WhenRound {
  std::uint8_t k = 0;
  packbin::Opt<std::uint8_t> v;
};

struct RoundWhen {
  Array<WhenRound, 4> rounds;
};

constexpr auto roundwhen_scheme = packbin::scheme<RoundWhen>(
    1, packbin::repeat<&RoundWhen::rounds>(
           0, packbin::u8<&WhenRound::k>(0),
           packbin::when(1, packbin::eq(0, 1), packbin::u8<&WhenRound::v>(1))));

RoundWhen roundwhen_row() {
  RoundWhen row;
  row.rounds.count = 2;
  row.rounds.items[0].k = 1;
  row.rounds.items[0].v = 9;
  row.rounds.items[1].k = 2;
  return row;
}

constexpr std::size_t kMax = 512;

std::size_t parse_hex(std::string const& hex, std::uint8_t* out) {
  std::size_t n = hex.size() / 2;
  if (n > kMax)
    return 0;
  for (std::size_t i = 0; i < n; ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return n;
}

int print(packbin::Result r, std::uint8_t const* buf) {
  if (!r.ok())
    return 1;
  for (std::size_t i = 0; i < r.offset; ++i)
    std::printf("%02x", buf[i]);
  std::printf("\n");
  return 0;
}

bool user_ok(std::uint8_t const* data, std::size_t len) {
  User got;
  if (!packbin::unpack(user_scheme, data, len, got).ok())
    return false;
  auto const* channel = find(got.access, "channel");
  auto const* map = find(got.access, "map");
  auto const* store = find(got.access, "store");
  return text_is(got.name, "zxsanny") && names_are(got.roles, {"user", "dispatcher"}) &&
         got.access.count == 3 && channel && names_are(*channel, {"read"}) && map &&
         names_are(*map, {"read", "gps_fix", "set", "edit"}) && store &&
         names_are(*store, {"read", "write"});
}

bool nested_ok(std::uint8_t const* data, std::size_t len) {
  Nested got;
  if (!packbin::unpack(nested_scheme, data, len, got).ok() || got.access.count != 2)
    return false;
  auto const& map = got.access.items[0];
  auto const& store = got.access.items[1];
  return text_is(map.key, "map") && map.value.count == 1 && op_is(map.value.items[0], "gps_fix") &&
         text_is(store.key, "store") && store.value.count == 2 &&
         op_is(store.value.items[0], "read") && op_is(store.value.items[1], "write");
}

bool boolflag_ok(std::uint8_t const* data, std::size_t len) {
  BoolFlag got;
  if (!packbin::unpack(boolflag_scheme, data, len, got).ok())
    return false;
  return !(got.on.has && got.on.value);
}

bool booltrue_ok(std::uint8_t const* data, std::size_t len) {
  BoolFlag got;
  if (!packbin::unpack(boolflag_scheme, data, len, got).ok())
    return false;
  return got.on.has && got.on.value;
}

bool bitwhen_ok(std::uint8_t const* data, std::size_t len) {
  BitWhen got;
  if (!packbin::unpack(bitwhen_scheme, data, len, got).ok())
    return false;
  return got.k == 0 && !got.v.has;
}

bool same_bytes(packbin::Result r, std::uint8_t const* got, std::uint8_t const* want,
                std::size_t want_len) {
  return r.ok() && r.offset == want_len && std::memcmp(got, want, want_len) == 0;
}

bool roundflags_ok(std::uint8_t const* data, std::size_t len) {
  RoundFlags got;
  if (!packbin::unpack(roundflags_scheme, data, len, got).ok() || got.rounds.count != 3)
    return false;
  auto const* r = got.rounds.items;
  bool read = r[0].on.has && r[0].on.value && !r[1].on.has && r[2].on.has && r[2].on.value &&
              r[0].n.has && r[0].n.value == 1 && r[1].n.has && r[1].n.value == 2 &&
              r[2].n.has && r[2].n.value == 3;
  std::uint8_t again[kMax];
  return read && same_bytes(packbin::pack(roundflags_scheme, got, again, sizeof(again)), again,
                            data, len);
}

bool roundwhen_ok(std::uint8_t const* data, std::size_t len) {
  RoundWhen got;
  if (!packbin::unpack(roundwhen_scheme, data, len, got).ok() || got.rounds.count != 2)
    return false;
  auto const* r = got.rounds.items;
  bool read = r[0].k == 1 && r[0].v.has && r[0].v.value == 9 && r[1].k == 2 && !r[1].v.has;
  std::uint8_t again[kMax];
  return read && same_bytes(packbin::pack(roundwhen_scheme, got, again, sizeof(again)), again,
                            data, len);
}

// The message ECC commands (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.

std::string hex_of(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  return out;
}

std::vector<std::uint8_t> ecc_bytes(std::string const& token) {
  std::vector<std::uint8_t> out;
  if (token == "-")
    return out;
  for (std::size_t i = 0; i + 1 < token.size(); i += 2)
    out.push_back(static_cast<std::uint8_t>(std::stoul(token.substr(i, 2), nullptr, 16)));
  return out;
}

std::string ecc_protect(int n, std::vector<std::uint8_t> clear) {
  Position row;
  if (clear.empty() || !packbin::unpack(position_scheme, clear.data(), clear.size(), row).ok())
    return "unpack_failed";
  auto const protected_scheme = packbin::parity(position_scheme, n);
  std::uint8_t out[kMax];
  packbin::Result r = packbin::pack(protected_scheme, row, out, sizeof(out));
  if (r.error == packbin::Error::SchemeInvalid)
    return "bad_parity";
  return r.ok() ? hex_of(out, r.offset) : "pack_error";
}

std::string ecc_repair(int n, int t, std::vector<std::uint8_t> received) {
  auto const protected_scheme = packbin::parity(position_scheme, n);
  received.push_back(0);  // data() of an empty buffer is not a place to write
  std::size_t const len = received.size() - 1;
  Position row;
  packbin::Result r = packbin::unpack_repair(protected_scheme, received.data(), len, row, t);
  switch (r.error) {
    case packbin::Error::Ok: {
      std::uint8_t out[kMax];
      packbin::Result again = packbin::pack(position_scheme, row, out, sizeof(out));
      if (!again.ok())
        return "pack_error";
      return hex_of(out, again.offset) + " " + std::to_string(static_cast<int>(r.repaired));
    }
    case packbin::Error::Uncorrectable:
      return "uncorrectable";
    case packbin::Error::SchemeInvalid:
      return "bad_parity";
    case packbin::Error::TooLong:
      return "too_long";
    case packbin::Error::BadValue:
      return t < 0 || t > n / 2 ? "bad_limit" : "unpack_failed";
    case packbin::Error::ShortPacket:
      return n > 0 && len < static_cast<std::size_t>(n) ? "short" : "unpack_failed";
    case packbin::Error::TrailingBytes:
      return "trailing";
    case packbin::Error::TypeMismatch:
      return "type_mismatch";
    default:
      return "unpack_failed";
  }
}

bool ecc_line(std::vector<std::string> const& w) {
  std::string out;
  if (w.size() == 3 && w[0] == "protect")
    out = ecc_protect(std::stoi(w[1]), ecc_bytes(w[2]));
  else if (w.size() == 4 && w[0] == "repair")
    out = ecc_repair(std::stoi(w[1]), std::stoi(w[2]), ecc_bytes(w[3]));
  else
    return false;
  std::printf("%s\n", out.c_str());
  return true;
}

// Returns the exit status of an ecc command (argv[1]).
int ecc_main(int argc, char** argv) {
  std::string const cmd = argv[1];
  if (cmd == "ecc-protect" && argc == 4)
    return ecc_line({"protect", argv[2], argv[3]}) ? 0 : 1;
  if (cmd == "ecc-repair" && argc == 5)
    return ecc_line({"repair", argv[2], argv[3], argv[4]}) ? 0 : 1;
  if (cmd == "ecc-batch" && argc == 3) {
    std::ifstream file(argv[2]);
    if (!file) {
      std::fprintf(stderr, "ecc-batch: cannot read %s\n", argv[2]);
      return 1;
    }
    std::string text;
    while (std::getline(file, text)) {
      std::istringstream words(text);
      std::vector<std::string> w;
      for (std::string word; words >> word;)
        w.push_back(word);
      if (!w.empty() && !ecc_line(w)) {
        std::fprintf(stderr, "ecc line: %s\n", text.c_str());
        return 1;
      }
    }
    return 0;
  }
  return 2;
}

// The frame commands (AZ-3338; contract pack-session 3.0.0, frame mode).
//   frame-batch <file>   one line per line of the file: seal, open, mac, verify

// A token that is not hex (a bad digit, an odd length), a number with other characters and a missing field are errors of the
// line, never a zero, a cut or an unchecked read.
std::vector<std::uint8_t> frame_bytes(std::string const& token) {
  std::vector<std::uint8_t> out;
  if (token == "-")
    return out;
  if (token.size() % 2 != 0)
    throw std::invalid_argument("bad hex: " + token);
  for (char c : token)
    if (!std::isxdigit(static_cast<unsigned char>(c)))
      throw std::invalid_argument("bad hex: " + token);
  for (std::size_t i = 0; i < token.size(); i += 2)
    out.push_back(static_cast<std::uint8_t>(std::stoul(token.substr(i, 2), nullptr, 16)));
  return out;
}

// A number is decimal digits only (no sign, space or `_`) and at most top (255, 65535 or 4294967295 by field); no digit
// string wraps or overflows into another value.
std::uint32_t frame_int(std::vector<std::string> const& w, std::size_t i, std::uint32_t top) {
  std::string const& token = w.at(i);
  std::uint64_t n = 0;
  bool bad = token.empty();
  for (std::size_t j = 0; j < token.size() && !bad; ++j) {
    n = n * 10 + static_cast<std::uint64_t>(token[j] - '0');
    bad = token[j] < '0' || token[j] > '9' || n > top;
  }
  if (bad)
    throw std::invalid_argument("bad number: " + token + " (digits of 0 to " + std::to_string(top) + ")");
  return static_cast<std::uint32_t>(n);
}

std::string frame_hex(std::uint8_t const* data, std::size_t len) {
  return len == 0 ? "-" : hex_of(data, len);
}

char const* frame_kind(packbin::Error e) {
  switch (e) {
    case packbin::Error::BadValue: return "BadValue";
    case packbin::Error::TooLong: return "TooLong";
    case packbin::Error::BufferFull: return "BufferFull";
    case packbin::Error::ShortPacket: return "ShortPacket";
    case packbin::Error::TagMismatch: return "TagMismatch";
    default: return "error";
  }
}

// The package takes the byte as it comes (0 to 255 here): a direction outside 1 to 3 is its BadValue to give.
packbin::FrameDirection frame_dir(std::uint32_t d) {
  return static_cast<packbin::FrameDirection>(static_cast<std::uint8_t>(d));
}

// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
packbin::FrameDirections frame_dirs(std::vector<std::string> const& w) {
  std::string const digits = w.size() > 9 ? w.at(9) : "123";
  if (digits.find_first_not_of("123") != std::string::npos)
    throw std::invalid_argument("bad dirs: " + digits);
  int mask = 0;
  for (char c : digits) mask |= 1 << (c - '1');
  return static_cast<packbin::FrameDirections>(mask);
}

std::size_t frame_out_len(std::vector<std::string> const& w) {
  return w.size() > 10 ? frame_int(w, 10, 65535) : 300;
}

std::string frame_seal(std::vector<std::string> const& w) {
  auto key = frame_bytes(w.at(0));
  std::uint32_t epoch = frame_int(w, 1, 4294967295u), d = frame_int(w, 2, 255), tag_len = frame_int(w, 3, 255);
  auto msg_id = frame_bytes(w.at(4));
  std::uint32_t kind = frame_int(w, 5, 255);
  auto ad = frame_bytes(w.at(6)), clear = frame_bytes(w.at(7)), plain = frame_bytes(w.at(8));
  std::vector<std::uint8_t> out(frame_out_len(w));
  packbin::FrameSession session;
  auto r = session.load({key.data(), key.size()}, epoch, {static_cast<std::uint8_t>(tag_len), frame_dirs(w)});
  if (!r.ok()) return frame_kind(r.error);
  packbin::MsgContext ctx{};
  std::memcpy(ctx.msg_id, msg_id.data(), msg_id.size() < 8 ? msg_id.size() : 8);
  ctx.kind = static_cast<std::uint8_t>(kind);
  r = session.seal(frame_dir(d), ctx, {ad.data(), ad.size()}, {clear.data(), clear.size()},
      {plain.data(), plain.size()}, {out.data(), out.size()});
  return r.ok() ? frame_hex(out.data(), r.offset) : frame_kind(r.error);
}

std::string frame_open(std::vector<std::string> const& w) {
  auto key = frame_bytes(w.at(0));
  std::uint32_t epoch = frame_int(w, 1, 4294967295u), d = frame_int(w, 2, 255), tag_len = frame_int(w, 3, 255);
  auto msg_id = frame_bytes(w.at(4));
  std::uint32_t kind = frame_int(w, 5, 255);
  auto ad = frame_bytes(w.at(6));
  std::uint32_t clear_len = frame_int(w, 7, 65535);
  auto body = frame_bytes(w.at(8));
  std::vector<std::uint8_t> out(frame_out_len(w));
  packbin::FrameSession session;
  auto r = session.load({key.data(), key.size()}, epoch, {static_cast<std::uint8_t>(tag_len), frame_dirs(w)});
  if (!r.ok()) return frame_kind(r.error);
  packbin::MsgContext ctx{};
  std::memcpy(ctx.msg_id, msg_id.data(), msg_id.size() < 8 ? msg_id.size() : 8);
  ctx.kind = static_cast<std::uint8_t>(kind);
  packbin::FrameOpened opened;
  r = session.open(frame_dir(d), ctx, {ad.data(), ad.size()}, {body.data(), body.size()},
      clear_len, {out.data(), out.size()}, opened);
  return r.ok() ? frame_hex(out.data(), opened.plain_len) : frame_kind(r.error);
}

std::string frame_mac(std::vector<std::string> const& w) {
  auto key = frame_bytes(w.at(0));
  std::uint32_t epoch = frame_int(w, 1, 4294967295u);
  auto label = frame_bytes(w.at(2));
  std::uint32_t n = frame_int(w, 3, 255);
  auto message = frame_bytes(w.at(4));
  packbin::MacKey mk;
  auto r = mk.derive({key.data(), key.size()}, epoch, {label.data(), label.size()});
  if (!r.ok()) return frame_kind(r.error);
  std::uint8_t out[255];
  packbin::ByteSpan part{message.data(), message.size()};
  r = mk.tag(&part, 1, {out, n});
  return r.ok() ? frame_hex(out, n) : frame_kind(r.error);
}

std::string frame_verify(std::vector<std::string> const& w) {
  auto key = frame_bytes(w.at(0));
  std::uint32_t epoch = frame_int(w, 1, 4294967295u);
  auto label = frame_bytes(w.at(2));
  frame_int(w, 3, 255);  // n: checked, not used (the tag length comes from the tag)
  auto message = frame_bytes(w.at(4)), tag = frame_bytes(w.at(5));
  packbin::MacKey mk;
  auto r = mk.derive({key.data(), key.size()}, epoch, {label.data(), label.size()});
  if (!r.ok()) return frame_kind(r.error);
  packbin::ByteSpan part{message.data(), message.size()};
  return mk.verify(&part, 1, {tag.data(), tag.size()}) ? "valid" : "invalid";
}

std::string frame_line(std::vector<std::string> const& w) {
  if (w.at(0) == "seal") return frame_seal({w.begin() + 1, w.end()});
  if (w.at(0) == "open") return frame_open({w.begin() + 1, w.end()});
  if (w.at(0) == "mac") return frame_mac({w.begin() + 1, w.end()});
  if (w.at(0) == "verify") return frame_verify({w.begin() + 1, w.end()});
  if (w.at(0) == "open-skip" || w.at(0) == "verify-skip") return "skip";
  return "";
}

int frame_main(int argc, char** argv) {
  if (argc == 3 && std::string(argv[1]) == "frame-batch") {
    std::ifstream file(argv[2]);
    if (!file) {
      std::fprintf(stderr, "frame-batch: cannot read %s\n", argv[2]);
      return 1;
    }
    std::string text;
    std::size_t number = 0;
    while (std::getline(file, text)) {
      ++number;
      std::istringstream words(text);
      std::vector<std::string> w;
      for (std::string word; words >> word;)
        w.push_back(word);
      if (!w.empty()) {
        try {
          auto out = frame_line(w);
          if (out.empty())
            throw std::invalid_argument("unknown word " + w.at(0));
          std::printf("%s\n", out.c_str());
        } catch (std::invalid_argument const& e) {
          std::fprintf(stderr, "frame line %zu: %s\n", number, e.what());
          return 1;
        } catch (std::out_of_range const& e) {
          std::fprintf(stderr, "frame line %zu: %s\n", number, e.what());
          return 1;
        }
      }
    }
    return 0;
  }
  return 2;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2)
    return 2;
  std::string cmd = argv[1];
  if (cmd.rfind("frame-", 0) == 0)
    return frame_main(argc, argv);
  if (cmd.rfind("ecc-", 0) == 0)
    return ecc_main(argc, argv);
  std::uint8_t buf[kMax];
  packbin::Scratch<16> scratch;  // the longest string in the user and nested rows has 10 characters
  if (cmd == "pack-user")
    return print(packbin::pack(user_scheme, user_row(), buf, sizeof(buf), scratch), buf);
  if (cmd == "pack-nested")
    return print(packbin::pack(nested_scheme, nested_row(), buf, sizeof(buf), scratch), buf);
  if (cmd == "pack-boolflag") {
    BoolFlag row;
    row.on = false;
    return print(packbin::pack(boolflag_scheme, row, buf, sizeof(buf)), buf);
  }
  if (cmd == "pack-booltrue") {
    BoolFlag row;
    row.on = true;
    return print(packbin::pack(boolflag_scheme, row, buf, sizeof(buf)), buf);
  }
  if (cmd == "pack-bitwhen") {
    BitWhen row;
    row.v = 5;
    return print(packbin::pack(bitwhen_scheme, row, buf, sizeof(buf)), buf);
  }
  if (cmd == "pack-roundflags")
    return print(packbin::pack(roundflags_scheme, roundflags_row(), buf, sizeof(buf)), buf);
  if (cmd == "pack-roundwhen")
    return print(packbin::pack(roundwhen_scheme, roundwhen_row(), buf, sizeof(buf)), buf);
  if (argc < 3)
    return 2;
  std::size_t len = parse_hex(argv[2], buf);
  if (cmd == "unpack-user")
    return user_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-nested")
    return nested_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-boolflag")
    return boolflag_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-booltrue")
    return booltrue_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-bitwhen")
    return bitwhen_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-roundflags")
    return roundflags_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-roundwhen")
    return roundwhen_ok(buf, len) ? 0 : 1;
  return 2;
}
