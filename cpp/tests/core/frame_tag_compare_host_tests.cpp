// The frame tag compare reads every tag byte and decides once at the end (AZ-3293, as Go's
// TestNoFrameSourceComparesATagWithAnEarlyExit): a source check that frame.cpp compares a tag only through
// `tags_equal`, a fold with no early exit and no secret-dependent branch, and a behavioural check through the
// public API that a flipped bit in the first, middle or last tag byte is TagMismatch for every tag length.
#include "packbin/frame.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using check::expect;
using namespace packbin;

namespace {

using Bytes = std::vector<std::uint8_t>;

std::string read_source(char const* name) {
  for (std::string base : {"src/core/", "cpp/src/core/"}) {
    std::ifstream in(base + name);
    if (in) {
      std::stringstream s;
      s << in.rdbuf();
      return s.str();
    }
  }
  return std::string();
}

// The text of a function from its signature to the closing brace at column 0.
std::string body_of(std::string const& text, char const* signature) {
  std::size_t at = text.find(signature);
  if (at == std::string::npos)
    return std::string();
  std::size_t end = text.find("\n}", at);
  return end == std::string::npos ? std::string() : text.substr(at, end - at + 2);
}

// The code of a text without // comments, so a comment that names memcmp does not count.
std::string without_comments(std::string const& text) {
  std::string out;
  std::istringstream lines(text);
  for (std::string line; std::getline(lines, line);) {
    std::size_t slash = line.find("//");
    out += (slash == std::string::npos ? line : line.substr(0, slash)) + "\n";
  }
  return out;
}

bool contains(std::string const& text, char const* needle) { return text.find(needle) != std::string::npos; }

std::size_t count_of(std::string const& text, char const* needle) {
  std::size_t n = 0;
  for (std::size_t at = text.find(needle); at != std::string::npos; at = text.find(needle, at + 1))
    ++n;
  return n;
}

void no_frame_source_compares_a_tag_with_an_early_exit() {
  // Arrange
  std::string source = read_source("frame.cpp");
  std::string code = without_comments(source);
  std::string compare = without_comments(body_of(source, "bool tags_equal("));

  // Act
  bool has_fold = contains(compare, "volatile std::uint8_t difference") && contains(compare, "difference | (a[i] ^ b[i])");
  bool no_exit = contains(compare, "for (std::size_t i = 0; i < n; ++i)") && !contains(compare, "break") &&
                 count_of(compare, "return") == 1;
  bool decides_once = contains(compare, "return difference == 0;");
  bool no_banned = true;
  for (char const* banned : {"memcmp", "bcmp", "strcmp", "std::equal", "std::mismatch"})
    if (contains(code, banned))
      no_banned = false;

  // Assert
  expect(!source.empty() && !compare.empty(), "tag compare: frame.cpp and tags_equal are found");
  expect(has_fold, "tag compare: tags_equal ORs the XOR of every byte pair into one volatile accumulator");
  expect(no_exit, "tag compare: the loop has no break and the function one return");
  expect(decides_once, "tag compare: tags_equal decides only at the end");
  expect(no_banned, "tag compare: frame.cpp has no memcmp, bcmp, strcmp, std::equal or std::mismatch");
  expect(count_of(code, "tags_equal(") == 4,
         "tag compare: tags_equal is its definition and the three uses (current, previous, MacKey)");
}

void every_tag_length_refuses_a_flipped_first_middle_and_last_tag_byte() {
  // Arrange
  Bytes key(32, 0x42);
  Bytes ad = {1, 2, 3};
  Bytes clear = {9, 8};
  Bytes plain = {10, 20, 30, 40, 50};
  MsgContext message;
  message.msg_id[0] = 7;
  message.kind = 2;
  int refused = 0, tried = 0;
  bool intact_opens = true, untouched = true;

  for (std::uint8_t tag_len : {4, 8, 16}) {
    FrameSession session;
    session.load(ByteSpan(key.data(), key.size()), 3, FrameConfig{tag_len, FrameDirections::All});
    Bytes body(clear.size() + plain.size() + tag_len, 0);
    Result sealed = session.seal(FrameDirection::Up, message, ByteSpan(ad.data(), ad.size()),
                                 ByteSpan(clear.data(), clear.size()), ByteSpan(plain.data(), plain.size()),
                                 MutableByteSpan(body.data(), body.size()));
    std::size_t tag_at = body.size() - tag_len;
    std::size_t const positions[] = {0, static_cast<std::size_t>(tag_len / 2), static_cast<std::size_t>(tag_len - 1)};

    // Act
    for (std::size_t position : positions) {
      for (std::uint8_t bit : {0x01, 0x80}) {
        Bytes bad = body;
        bad[tag_at + position] = static_cast<std::uint8_t>(bad[tag_at + position] ^ bit);
        Bytes out(plain.size(), 0xa5);
        FrameOpened opened;
        Result r = session.open(FrameDirection::Up, message, ByteSpan(ad.data(), ad.size()),
                                ByteSpan(bad.data(), bad.size()), clear.size(),
                                MutableByteSpan(out.data(), out.size()), opened);
        ++tried;
        if (r.error == Error::TagMismatch)
          ++refused;
        for (std::uint8_t b : out)
          if (b != 0xa5)
            untouched = false;
      }
    }
    Bytes out(plain.size(), 0);
    FrameOpened opened;
    Result r = session.open(FrameDirection::Up, message, ByteSpan(ad.data(), ad.size()),
                            ByteSpan(body.data(), body.size()), clear.size(),
                            MutableByteSpan(out.data(), out.size()), opened);
    intact_opens = intact_opens && sealed.ok() && r.ok() && out == plain;
  }

  // Assert
  expect(tried == 18 && refused == tried,
         "tag compare: a flipped bit in the first, middle or last tag byte is TagMismatch for tag 4, 8 and 16");
  expect(untouched, "tag compare: a refused tag leaves the plain buffer untouched");
  expect(intact_opens, "tag compare: the unflipped frame opens for every tag length");
}

}  // namespace

int run_core_frame_tag_compare_host_tests() {
  no_frame_source_compares_a_tag_with_an_early_exit();
  every_tag_length_refuses_a_flipped_first_middle_and_last_tag_byte();
  return check::failures();
}
