// The code the README shows for frame mode in C++ (AZ-3292). The lines between the markers are copied into
// the README by the docs task, and scripts/frame/readme-examples.sh checks that they still are; this test
// keeps them compiling and correct. Keep the region complete: includes, one function, no test helpers.

// README-BEGIN
#include <packbin/packbin.hpp>

#include <cstdint>
#include <cstring>

// Frame mode: sealed, authenticated frames. True when every step below gave the answer the comments name.
bool frame_example() {
  namespace pb = packbin;

  // A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
  std::uint8_t key[32] = {};  // use a random key from your key store
  pb::FrameSession node;
  if (!node.load(key, 1, {4, pb::FrameDirections::Up | pb::FrameDirections::Down}).ok())
    return false;  // BadValue: the key, the epoch or the tag length is out of range

  // msg_id: 8 bytes that are unique per (key, epoch, direction) for every message ever sealed.
  // **For one (key, epoch, direction), never seal two different messages with the same msg_id.**
  // Reuse breaks the confidentiality of both messages, and packbin cannot check it.
  pb::MsgContext message{{0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0}, 4};
  std::uint8_t const header[] = {0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4};  // authenticated, not sent
  std::uint8_t const text[] = {'h', 'e', 'l', 'l', 'o', ',', ' ', 'r', 'e', 'l', 'a', 'y'};

  std::uint8_t body[255];
  pb::Result sealed = node.seal(pb::FrameDirection::Up, message, header, {}, text, body);
  // sealed.error is Ok, or BadValue, TooLong or BufferFull; sealed.offset is the body length (12 + 4 here)

  // The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
  pb::ReplayWindow window;
  std::uint8_t plain[255];
  pb::FrameOpened opened;
  pb::Result first = node.open(pb::FrameDirection::Up, message, header, {body, sealed.offset}, 0, plain,
                               opened, &window, 7);
  // first.error is Ok, or TagMismatch, Duplicate, TooOld, ShortPacket, TooLong, BufferFull or BadValue
  // plain[0 .. opened.plain_len) is the text and opened.slot says which key opened it
  pb::Result again = node.open(pb::FrameDirection::Up, message, header, {body, sealed.offset}, 0, plain,
                               opened, &window, 7);  // Duplicate

  // The MAC-only call: a 4-byte network check over a message given in parts.
  pb::MacKey network;
  std::uint8_t const label[] = {'n', 'e', 't'};
  std::uint8_t const wave[] = {1, 2, 3, 4};
  pb::ByteSpan parts[] = {wave, {body, sealed.offset}};
  std::uint8_t tag[4];
  bool tagged = network.derive(key, 1, label).ok() && network.tag(parts, 2, tag).ok();
  bool valid = network.verify(parts, 2, tag);

  return sealed.ok() && first.ok() && first.offset == sizeof(text) && std::memcmp(plain, text, sizeof(text)) == 0 &&
         again.error == pb::Error::Duplicate && tagged && valid;
}
// README-END

#include "check.hpp"

#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>

namespace {

void the_readme_example_runs_and_is_between_its_markers() {
  // Arrange
  bool ran = frame_example();

  // Assert
  check::expect(ran, "README frame example: seal, open, Duplicate and the MAC-only call give the documented answers");
}

// The doc comment of the example states the uniqueness rule in bold, as the other packages do.
void the_example_states_the_uniqueness_rule_in_bold() {
  // Arrange
  char const* paths[] = {"tests/core/frame_readme_host_tests.cpp", "cpp/tests/core/frame_readme_host_tests.cpp"};
  std::string text;
  for (char const* path : paths) {
    std::ifstream in(path);
    if (in) {
      std::stringstream s;
      s << in.rdbuf();
      text = s.str();
      break;
    }
  }
  std::size_t begin = text.find("// README-" "BEGIN\n");
  std::size_t end = text.find("// README-" "END\n");

  // Assert
  check::expect(begin != std::string::npos && end != std::string::npos && begin < end &&
                    text.substr(begin, end - begin).find("// **For one (key, epoch, direction), never seal two different messages "
                                                         "with the same msg_id.**") != std::string::npos,
                "README frame example: the uniqueness rule is in bold between the markers");
}

}  // namespace

int run_core_frame_readme_host_tests() {
  the_readme_example_runs_and_is_between_its_markers();
  the_example_states_the_uniqueness_rule_in_bold();
  return check::failures();
}
