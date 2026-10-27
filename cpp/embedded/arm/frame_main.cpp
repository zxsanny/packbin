// Frame image (AZ-3292): the frame session and the MAC-only call on the target with no stdio and no heap.
// Linked with the aborting malloc/calloc/realloc/new wrappers (wrap.c); prints through semihosting only.
// The stage reads the image flash and the deepest stack of load, set_previous, seal, open (current and
// previous key, with a window) and the MAC-only call at their largest sizes (255-byte body, 16-byte tag,
// 255 bytes of associated data), and checks the worked example E1 byte for byte.

#include "packbin/frame.hpp"
#include "semihost.h"
#include "stack_meter.hpp"

#include <cstdint>
#include <cstring>

namespace {

namespace pb = packbin;

std::uint8_t ad[255];
std::uint8_t plain[239];
std::uint8_t body[255];
std::uint8_t text[255];
std::uint8_t old_body[255];

void say(char const* key, unsigned long value) {
  sh_write(key);
  sh_write_uint(value);
  sh_write("\n");
}

// E1 of the contract: key 0x11 x 32, epoch 1, direction Up, 4-byte tag.
constexpr std::uint8_t kE1Id[8] = {0x00, 0x30, 0x10, 0x05, 0xe8, 0x03, 0x00, 0x00};
constexpr std::uint8_t kE1Ad[11] = {0x00, 0x01, 0x00, 0x30, 0x10, 0x05, 0xe8, 0x03, 0x00, 0x00, 0x04};
constexpr std::uint8_t kE1Plain[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
constexpr std::uint8_t kE1Body[16] = {0x53, 0xe9, 0xdc, 0x75, 0xfb, 0x45, 0x9d, 0x77,
                                      0x5e, 0x62, 0x05, 0x66, 0x1c, 0xdf, 0x37, 0xff};

std::size_t larger(std::size_t a, std::size_t b) { return a > b ? a : b; }

}  // namespace

int main() {
  std::uint8_t key_a[32], key_b[32];
  std::memset(key_a, 0x11, sizeof(key_a));
  std::memset(key_b, 0x22, sizeof(key_b));
  for (std::size_t i = 0; i < sizeof(ad); ++i)
    ad[i] = static_cast<std::uint8_t>(i);
  for (std::size_t i = 0; i < sizeof(plain); ++i)
    plain[i] = static_cast<std::uint8_t>(i * 7);
  pb::MsgContext message;
  std::memcpy(message.msg_id, kE1Id, sizeof(kE1Id));
  message.kind = 4;

  int failures = 0;
  pb::FrameSession old_session;
  pb::FrameSession session;
  pb::Result r{};

  // The worked example E1 on the target.
  pb::Result e1_load = old_session.load(key_a, 1, pb::FrameConfig{4, pb::FrameDirections::All});
  pb::Result e1_seal = old_session.seal(pb::FrameDirection::Up, message, pb::ByteSpan(kE1Ad, sizeof(kE1Ad)),
                                        pb::ByteSpan(), pb::ByteSpan(kE1Plain, sizeof(kE1Plain)), body);
  failures += (e1_load.ok() ? 0 : 1) + (e1_seal.ok() && e1_seal.offset == sizeof(kE1Body) ? 0 : 1) +
              (std::memcmp(body, kE1Body, sizeof(kE1Body)) == 0 ? 0 : 1);

  // Largest sizes: a 16-byte tag, 255 bytes of associated data, a 255-byte body.
  std::size_t load_stack = stack_meter::measure(
      [&] { r = old_session.load(key_a, 1, pb::FrameConfig{16, pb::FrameDirections::All}); });
  failures += r.ok() ? 0 : 1;
  pb::Result sealed_old{};
  std::size_t seal_stack = stack_meter::measure([&] {
    sealed_old = old_session.seal(pb::FrameDirection::Down, message, ad, pb::ByteSpan(), plain, old_body);
  });
  failures += (sealed_old.ok() && sealed_old.offset == 255) ? 0 : 1;

  r = session.load(key_b, 2, pb::FrameConfig{16, pb::FrameDirections::All});
  failures += r.ok() ? 0 : 1;
  std::size_t previous_stack = stack_meter::measure([&] { r = session.set_previous(key_a, 1); });
  failures += r.ok() ? 0 : 1;
  pb::Result sealed{};
  r = session.seal(pb::FrameDirection::Down, message, ad, pb::ByteSpan(), plain, body);
  sealed = r;
  failures += (sealed.ok() && sealed.offset == 255) ? 0 : 1;

  pb::ReplayWindow window;
  pb::FrameOpened opened;
  pb::Result opened_current{};
  std::size_t open_stack = stack_meter::measure([&] {
    opened_current = session.open(pb::FrameDirection::Down, message, ad, pb::ByteSpan(body, sealed.offset), 0,
                                  text, opened, &window, 1);
  });
  failures += (opened_current.ok() && opened.slot == pb::FrameSlot::Current && opened.plain_len == sizeof(plain) &&
               std::memcmp(text, plain, sizeof(plain)) == 0)
                  ? 0
                  : 1;
  pb::Result opened_previous{};
  std::size_t open_previous_stack = stack_meter::measure([&] {
    opened_previous = session.open(pb::FrameDirection::Down, message, ad, pb::ByteSpan(old_body, 255), 0, text,
                                   opened, &window, 2);
  });
  failures += (opened_previous.ok() && opened.slot == pb::FrameSlot::Previous &&
               std::memcmp(text, plain, sizeof(plain)) == 0 && window.top() == 2)
                  ? 0
                  : 1;
  pb::Result again = session.open(pb::FrameDirection::Down, message, ad, pb::ByteSpan(body, sealed.offset), 0, text,
                                  opened, &window, 1);
  failures += again.error == pb::Error::Duplicate ? 0 : 1;

  pb::MacKey mac;
  std::uint8_t const label[3] = {'n', 'e', 't'};
  std::size_t derive_stack = stack_meter::measure([&] { r = mac.derive(key_a, 1, label); });
  failures += r.ok() ? 0 : 1;
  pb::ByteSpan parts[2] = {pb::ByteSpan(ad, sizeof(ad)), pb::ByteSpan(body, sealed.offset)};
  std::uint8_t tag[32];
  std::size_t tag_stack = stack_meter::measure([&] { r = mac.tag(parts, 2, tag); });
  failures += r.ok() ? 0 : 1;
  bool valid = false;
  std::size_t verify_stack = stack_meter::measure([&] { valid = mac.verify(parts, 2, tag); });
  failures += valid ? 0 : 1;

  std::size_t deepest = larger(larger(larger(load_stack, seal_stack), larger(previous_stack, open_stack)),
                               larger(larger(open_previous_stack, derive_stack), larger(tag_stack, verify_stack)));
  say("FRAME_LOAD_STACK ", load_stack);
  say("FRAME_SET_PREVIOUS_STACK ", previous_stack);
  say("FRAME_SEAL_STACK ", seal_stack);
  say("FRAME_OPEN_STACK ", open_stack);
  say("FRAME_OPEN_PREVIOUS_STACK ", open_previous_stack);
  say("FRAME_MAC_DERIVE_STACK ", derive_stack);
  say("FRAME_MAC_TAG_STACK ", tag_stack);
  say("FRAME_MAC_VERIFY_STACK ", verify_stack);
  say("FRAME_STACK ", deepest);
  say("FRAME_SESSION_BYTES ", sizeof(pb::FrameSession));
  say("FRAME_MACKEY_BYTES ", sizeof(pb::MacKey));
  say("WRAPPER_CALLS ", 0);
  say("FAILURES ", static_cast<unsigned long>(failures));
  return failures;
}
