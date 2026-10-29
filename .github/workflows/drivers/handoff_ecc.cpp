#include "handoff_common.hpp"

#include "packbin/packbin.hpp"

#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace {

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

// The message ECC commands (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.

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

}  // namespace

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
