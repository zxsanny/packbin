#include "handoff_common.hpp"

#include "packbin/packbin.hpp"

#include <cctype>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

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

// MsgContext holds an 8-byte id: another length cannot be handed to the package, so BadValue is the driver's to give in
// frame_seal and frame_open (fixtures/frame/README.md). A key of any length goes to the package, which refuses it.
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
  if (msg_id.size() != sizeof ctx.msg_id) return "BadValue";
  std::memcpy(ctx.msg_id, msg_id.data(), sizeof ctx.msg_id);
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
  if (msg_id.size() != sizeof ctx.msg_id) return "BadValue";
  std::memcpy(ctx.msg_id, msg_id.data(), sizeof ctx.msg_id);
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
}  // namespace

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
