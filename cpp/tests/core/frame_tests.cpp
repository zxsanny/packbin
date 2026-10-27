// Frame mode (include/packbin/frame.hpp, contract pack-session 3.0.0) on the target: the worked
// examples E1 to E5 of fixtures/frame/vectors.txt as constants, the four refusals of AC-3 and the
// D1 names. The firmware runner builds this file: no heap, no OS calls, no file input. All 157 rows of
// the fixture run on the host in frame_vectors_host_tests.cpp, which is where the rest of the frame
// tests live (frame_api_host_tests.cpp).
#include "packbin/frame.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstring>

using check::expect;
using packbin::ByteSpan;
using packbin::Error;
using packbin::FrameConfig;
using packbin::FrameDirection;
using packbin::FrameDirections;
using packbin::FrameOpened;
using packbin::FrameSession;
using packbin::FrameSlot;
using packbin::Freshness;
using packbin::MacKey;
using packbin::MsgContext;
using packbin::MutableByteSpan;
using packbin::ReplayWindow;
using packbin::Result;

namespace {

constexpr std::size_t kMax = 255;

// The D1 names are the same in every package: a package that renames one fails to build here.
static_assert(static_cast<int>(FrameDirection::Up) == 1 && static_cast<int>(FrameDirection::Down) == 2 &&
                  static_cast<int>(FrameDirection::Group) == 3,
              "FrameDirection Up, Down and Group are 1, 2 and 3");
static_assert(static_cast<int>(FrameDirections::None) == 0 && static_cast<int>(FrameDirections::Up) == 1 &&
                  static_cast<int>(FrameDirections::Down) == 2 &&
                  static_cast<int>(FrameDirections::Group) == 4 &&
                  static_cast<int>(FrameDirections::All) == 7,
              "FrameDirections None, Up, Down, Group and All are 0, 1, 2, 4 and 7");
static_assert(static_cast<int>(FrameSlot::Current) == 0 && static_cast<int>(FrameSlot::Previous) == 1,
              "FrameSlot Current and Previous");
static_assert(static_cast<int>(Freshness::Fresh) == 0 && static_cast<int>(Freshness::Duplicate) == 1 &&
                  static_cast<int>(Freshness::TooOld) == 2,
              "Freshness Fresh, Duplicate and TooOld");
static_assert(sizeof(ReplayWindow) == 16, "a replay window is 16 bytes");
static_assert(sizeof(MsgContext::msg_id) == 8, "a msg_id is 8 bytes");
static_assert(Error::TagMismatch != Error::Duplicate && Error::Duplicate != Error::TooOld &&
                  Error::TooOld != Error::TagMismatch,
              "TagMismatch, Duplicate and TooOld are error kinds beside the old ones");

void key_of(std::uint8_t byte, std::uint8_t (&key)[32]) { std::memset(key, byte, sizeof(key)); }

MsgContext context_of(char const* id_hex, std::uint8_t kind) {
  MsgContext m;
  check::parse_hex(id_hex, m.msg_id, sizeof(m.msg_id));
  m.kind = kind;
  return m;
}

// One sealed frame of the contract's worked examples.
struct Example {
  char const* name;
  std::uint8_t key_byte;
  std::uint32_t epoch;
  FrameDirection direction;
  std::uint8_t tag_len;
  char const* msg_id;
  std::uint8_t kind;
  char const* ad;
  char const* clear;
  char const* plain;
  char const* body;
};

constexpr Example kExamples[] = {
    {"E1", 0x11, 1, FrameDirection::Up, 4, "00301005e8030000", 4, "000100301005e803000004", "",
     "0102030405060708090a0b0c", "53e9dc75fb459d775e6205661cdf37ff"},
    {"E2", 0x11, 1, FrameDirection::Down, 4, "00022001e9030000", 5, "003000022001e903000005", "",
     "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60616263646566676869",
     "7f711291e9a9ebb93760ac8b851f2a29c46a3b70f6a447b62ddbc159ddfba687109cc6d02d5e509bb9bd00b7da70"},
    {"E3", 0x33, 7, FrameDirection::Group, 4, "00013002ea030000", 6, "ffff00013002ea03000006", "a1b2c3",
     "808182838485868788898a8b8c8d8e8f90919293", "a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7"},
    {"E3 with a 16-byte tag", 0x33, 7, FrameDirection::Group, 16, "00013002ea030000", 6,
     "ffff00013002ea03000006", "a1b2c3", "808182838485868788898a8b8c8d8e8f90919293",
     "a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7c519c38115025b8cd5b5f82b"},
};

// Seal then open of each worked example gives the recorded body and the plain text back.
void worked_examples_seal_and_open() {
  for (Example const& e : kExamples) {
    // Arrange
    std::uint8_t key[32];
    key_of(e.key_byte, key);
    FrameSession session;
    Result loaded = session.load(key, e.epoch, FrameConfig{e.tag_len, FrameDirections::All});
    MsgContext message = context_of(e.msg_id, e.kind);
    std::uint8_t ad[16], clear[8], plain[64], body[kMax], text[kMax];
    std::size_t ad_len = check::parse_hex(e.ad, ad, sizeof(ad));
    std::size_t clear_len = check::parse_hex(e.clear, clear, sizeof(clear));
    std::size_t plain_len = check::parse_hex(e.plain, plain, sizeof(plain));

    // Act
    Result sealed = session.seal(e.direction, message, ByteSpan(ad, ad_len), ByteSpan(clear, clear_len),
                                 ByteSpan(plain, plain_len), body);
    FrameOpened opened;
    Result got = session.open(e.direction, message, ByteSpan(ad, ad_len), ByteSpan(body, sealed.offset),
                              clear_len, text, opened);

    // Assert
    expect(loaded.ok(), e.name);
    expect(sealed.ok() && check::same_hex(body, sealed.offset, e.body), e.name);
    expect(got.ok() && got.offset == plain_len && opened.slot == FrameSlot::Current &&
               opened.clear_len == clear_len && opened.plain_len == plain_len &&
               std::memcmp(text, plain, plain_len) == 0,
           e.name);
  }
}

// E4 and E5: the MAC-only call, whole and in parts, and a verify that fails on a changed byte.
void mac_only_examples() {
  // Arrange
  std::uint8_t key[32];
  key_of(0x22, key);
  std::uint8_t const label[3] = {'n', 'e', 't'};
  std::uint8_t wave[4], frame[20], check_text[5] = {'c', 'h', 'e', 'c', 'k'};
  check::parse_hex("e8030000", wave, sizeof(wave));
  check::parse_hex("c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3", frame, sizeof(frame));
  MacKey e4, e5;
  Result r4 = e4.derive(key, 7, label);
  Result r5 = e5.derive(key, 8, label);
  ByteSpan parts[2] = {ByteSpan(wave), ByteSpan(frame)};
  std::uint8_t whole[24];
  std::memcpy(whole, wave, 4);
  std::memcpy(whole + 4, frame, 20);

  // Act
  std::uint8_t split[4], joined[4], later[4];
  Result t4 = e4.tag(parts, 2, split);
  Result t4b = e4.tag(ByteSpan(whole), joined);
  Result t5 = e5.tag(ByteSpan(check_text), later);
  std::uint8_t bad[4];
  std::memcpy(bad, joined, 4);
  bad[3] ^= 1;

  // Assert
  expect(r4.ok() && r5.ok(), "mac: E4 and E5 derive");
  expect(t4.ok() && t4b.ok() && check::same_hex(split, 4, "56db9bec") && check::same_hex(joined, 4, "56db9bec"),
         "mac: E4 tag, in parts and whole");
  expect(t5.ok() && check::same_hex(later, 4, "3cf8e8c5"), "mac: E5 tag");
  expect(e4.verify(parts, 2, ByteSpan(split)) && e4.verify(ByteSpan(whole), ByteSpan(joined)),
         "mac: verify accepts the tag of E4");
  expect(!e4.verify(ByteSpan(whole), ByteSpan(bad)) && !e4.verify(ByteSpan(whole), ByteSpan(joined, 3)),
         "mac: verify refuses a changed byte and a 3-byte tag");
}

// A session on key 0x44 / epoch 3 with all directions and a 4-byte tag, a fixed message and one frame
// sealed under it.
struct Fixture {
  std::uint8_t key[32];
  FrameSession session;
  MsgContext message = context_of("0102030405060708", 2);
  std::uint8_t ad[3] = {9, 8, 7};
  std::uint8_t plain[10] = {10, 11, 12, 13, 14, 15, 16, 17, 18, 19};
  std::uint8_t body[kMax];
  std::size_t body_len = 0;

  Fixture() {
    key_of(0x44, key);
    session.load(key, 3, FrameConfig{4, FrameDirections::All});
    body_len = session.seal(FrameDirection::Up, message, ad, ByteSpan(), plain, body).offset;
  }
};

// AC-3: a forged tag is TagMismatch; the output buffer and the window stay as they were.
void a_forged_tag_is_refused_and_changes_nothing() {
  // Arrange
  Fixture f;
  f.body[f.body_len - 1] ^= 0x80;
  std::uint8_t out[kMax];
  std::memset(out, 0xa5, sizeof(out));
  ReplayWindow window(40, 0x5);
  FrameOpened opened;

  // Act
  Result r = f.session.open(FrameDirection::Up, f.message, f.ad, ByteSpan(f.body, f.body_len), 0, out,
                            opened, &window, 41);

  // Assert
  expect(r.error == Error::TagMismatch, "forged tag: TagMismatch");
  expect(out[0] == 0xa5 && out[9] == 0xa5 && out[10] == 0xa5, "forged tag: the output buffer is untouched");
  expect(window.top() == 40 && window.bits() == 0x5, "forged tag: the window is untouched");
}

// AC-3: a counter already committed is Duplicate, and the tag is not looked at (a forged tag still gives
// Duplicate, so no MAC was computed).
void a_duplicate_is_refused_before_any_mac() {
  // Arrange
  Fixture f;
  f.body[f.body_len - 1] ^= 0x80;
  std::uint8_t out[kMax];
  std::memset(out, 0xa5, sizeof(out));
  ReplayWindow window(40, 0x5);
  FrameOpened opened;

  // Act
  Result r = f.session.open(FrameDirection::Up, f.message, f.ad, ByteSpan(f.body, f.body_len), 0, out,
                            opened, &window, 38);

  // Assert
  expect(r.error == Error::Duplicate, "duplicate: Duplicate, not TagMismatch");
  expect(out[0] == 0xa5 && window.top() == 40 && window.bits() == 0x5,
         "duplicate: the output buffer and the window are untouched");
}

// AC-3: a counter 64 or more below the top is TooOld before any MAC.
void a_counter_64_below_the_top_is_too_old_before_any_mac() {
  // Arrange
  Fixture f;
  f.body[f.body_len - 1] ^= 0x80;
  std::uint8_t out[kMax];
  std::memset(out, 0xa5, sizeof(out));
  ReplayWindow window(100, 0x1);
  FrameOpened opened;

  // Act
  Result r = f.session.open(FrameDirection::Up, f.message, f.ad, ByteSpan(f.body, f.body_len), 0, out,
                            opened, &window, 36);

  // Assert
  expect(r.error == Error::TooOld, "too old: TooOld, not TagMismatch");
  expect(out[0] == 0xa5 && window.top() == 100 && window.bits() == 0x1,
         "too old: the output buffer and the window are untouched");
}

// AC-3: a frame sealed under the previous key opens with slot Previous and commits into the window; the
// same frame is TagMismatch once the previous key is cleared.
void a_frame_under_the_previous_key_opens_as_previous() {
  // Arrange
  Fixture f;
  std::uint8_t next[32];
  key_of(0x55, next);
  FrameSession later;
  Result loaded = later.load(next, 4, FrameConfig{4, FrameDirections::All});
  Result kept = later.set_previous(f.key, 3);
  std::uint8_t out[kMax];
  ReplayWindow window;
  FrameOpened opened;

  // Act
  Result r = later.open(FrameDirection::Up, f.message, f.ad, ByteSpan(f.body, f.body_len), 0, out, opened,
                        &window, 7);
  later.clear_previous();
  FrameOpened again;
  Result gone = later.open(FrameDirection::Up, f.message, f.ad, ByteSpan(f.body, f.body_len), 0, out, again);

  // Assert
  expect(loaded.ok() && kept.ok(), "previous: the new session loads and keeps the old key");
  expect(r.ok() && opened.slot == FrameSlot::Previous && opened.plain_len == 10 &&
             std::memcmp(out, f.plain, 10) == 0,
         "previous: Ok with slot Previous and the plain text");
  expect(window.top() == 7 && window.bits() == 1, "previous: the counter is committed");
  expect(gone.error == Error::TagMismatch, "previous: TagMismatch after clear_previous");
}

}  // namespace

int run_core_frame_tests() {
  worked_examples_seal_and_open();
  mac_only_examples();
  a_forged_tag_is_refused_and_changes_nothing();
  a_duplicate_is_refused_before_any_mac();
  a_counter_64_below_the_top_is_too_old_before_any_mac();
  a_frame_under_the_previous_key_opens_as_previous();
  return check::failures();
}
