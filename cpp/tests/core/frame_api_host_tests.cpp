// Frame mode (include/packbin/frame.hpp) through the public API on the host: the D1 names (AC-4), the
// refusals and their order, what a refusal leaves untouched, the previous slot, the wipes of the destructors
// and several threads sealing on one session. The worked examples, AC-3 and the 157 fixture rows are in
// frame_tests.cpp and frame_vectors_host_tests.cpp.
#include "packbin/frame.hpp"

#include "check.hpp"
#include "frame_access_host.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <new>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

using check::expect;
using namespace packbin;
using packbin::detail::FrameTestAccess;

namespace {

using Bytes = std::vector<std::uint8_t>;

constexpr std::uint8_t kSentinel = 0xa5;

std::string read_text(char const* name) {
  for (std::string base : {"include/packbin/", "cpp/include/packbin/"}) {
    std::ifstream in(base + name);
    if (in) {
      std::stringstream s;
      s << in.rdbuf();
      return s.str();
    }
  }
  return std::string();
}

bool declares(std::string const& text, char const* keyword, char const* name) {
  std::string pattern = std::string(keyword) + " " + name;
  for (std::size_t at = text.find(pattern); at != std::string::npos; at = text.find(pattern, at + 1)) {
    char after = text[at + pattern.size()];
    if (after == ' ' || after == ':' || after == '{' || after == '\n')
      return true;
  }
  return false;
}

// AC-4: the public header lists the D1 names, spelled as in the other packages.
void the_public_api_lists_the_d1_names() {
  // Arrange
  std::string frame = read_text("frame.hpp");
  std::string core = read_text("core.hpp");
  struct Name {
    char const* keyword;
    char const* name;
  };
  Name const names[] = {{"class", "FrameSession"},      {"struct", "FrameConfig"},   {"enum class", "FrameDirection"},
                        {"enum class", "FrameDirections"}, {"enum class", "FrameSlot"}, {"struct", "FrameOpened"},
                        {"struct", "MsgContext"},        {"class", "ReplayWindow"},   {"enum class", "Freshness"},
                        {"class", "MacKey"}};

  // Act
  int found = 0;
  for (Name const& n : names)
    if (declares(frame, n.keyword, n.name))
      ++found;
  bool kinds = core.find("  TagMismatch,") != std::string::npos && core.find("  Duplicate,") != std::string::npos &&
               core.find("  TooOld,") != std::string::npos;
  std::string umbrella = read_text("packbin.hpp");

  // Assert
  expect(found == 10, "names: the ten D1 types are declared in packbin/frame.hpp");
  expect(kinds, "names: TagMismatch, Duplicate and TooOld are Error kinds in packbin/core.hpp");
  expect(umbrella.find("packbin/frame.hpp") != std::string::npos, "names: packbin/packbin.hpp includes frame.hpp");
}

struct Loaded {
  Bytes key = Bytes(32, 0x66);
  FrameSession session;
  MsgContext message;
  Bytes ad = {1, 2, 3};

  explicit Loaded(std::uint8_t tag_len = 4, FrameDirections dirs = FrameDirections::All) {
    session.load(ByteSpan(key.data(), key.size()), 5, FrameConfig{tag_len, dirs});
    message.msg_id[0] = 9;
    message.kind = 3;
  }

  Result seal(Bytes const& plain, Bytes const& clear, Bytes& out, FrameDirection d = FrameDirection::Up) const {
    return session.seal(d, message, ByteSpan(ad.data(), ad.size()), ByteSpan(clear.data(), clear.size()),
                        ByteSpan(plain.data(), plain.size()), MutableByteSpan(out.data(), out.size()));
  }
};

void load_refuses_bad_arguments_and_keeps_the_session() {
  // Arrange
  Loaded f;
  Bytes short_key(31, 1);
  Bytes before(1, 0);
  FrameSession fresh;

  // Act
  Result key31 = fresh.load(ByteSpan(short_key.data(), short_key.size()), 1, FrameConfig{4, FrameDirections::All});
  Result epoch = fresh.load(ByteSpan(f.key.data(), f.key.size()), 0x1000000, FrameConfig{4, FrameDirections::All});
  Result tag5 = fresh.load(ByteSpan(f.key.data(), f.key.size()), 1, FrameConfig{5, FrameDirections::All});
  Result bit = fresh.load(ByteSpan(f.key.data(), f.key.size()), 1, FrameConfig{4, static_cast<FrameDirections>(8)});
  Result kept = f.session.load(ByteSpan(f.key.data(), f.key.size()), 0x1000000, FrameConfig{4, FrameDirections::All});
  Result last = fresh.load(ByteSpan(f.key.data(), f.key.size()), 0xFFFFFF, FrameConfig{16, FrameDirections::Group});

  // Assert
  expect(key31.error == Error::BadValue && epoch.error == Error::BadValue && tag5.error == Error::BadValue &&
             bit.error == Error::BadValue,
         "load: a 31-byte key, epoch 0x1000000, tag length 5 and direction bit 8 are BadValue");
  expect(kept.error == Error::BadValue && f.session.loaded() && f.session.tag_len() == 4 && f.session.epoch() == 5,
         "load: a refused load leaves a loaded session as it was");
  expect(last.ok() && fresh.epoch() == 0xFFFFFF && fresh.tag_len() == 16, "load: epoch 0xFFFFFF and a 16-byte tag load");
}

void an_unloaded_session_and_an_unloaded_direction_are_bad_value() {
  // Arrange
  FrameSession none;
  Loaded up_only(4, FrameDirections::Up);
  Loaded no_dirs(4, FrameDirections::None);
  Bytes out(64, kSentinel), plain(4, 7), clear;
  FrameOpened opened;

  // Act
  Result unloaded = none.seal(FrameDirection::Up, MsgContext{}, ByteSpan(), ByteSpan(), ByteSpan(), MutableByteSpan(out.data(), out.size()));
  Result opened_unloaded = none.open(FrameDirection::Up, MsgContext{}, ByteSpan(), ByteSpan(out.data(), 8), 0,
                                     MutableByteSpan(out.data(), out.size()), opened);
  Result down = up_only.session.seal(FrameDirection::Down, up_only.message, ByteSpan(), ByteSpan(), ByteSpan(plain.data(), 4),
                             MutableByteSpan(out.data(), out.size()));
  Result group = no_dirs.session.seal(FrameDirection::Group, no_dirs.message, ByteSpan(), ByteSpan(), ByteSpan(),
                              MutableByteSpan(out.data(), out.size()));
  Result zero = up_only.session.seal(static_cast<FrameDirection>(0), up_only.message, ByteSpan(), ByteSpan(), ByteSpan(),
                             MutableByteSpan(out.data(), out.size()));
  Result four = up_only.session.seal(static_cast<FrameDirection>(4), up_only.message, ByteSpan(), ByteSpan(), ByteSpan(),
                             MutableByteSpan(out.data(), out.size()));
  MsgContext wide = up_only.message;
  wide.kind = 16;
  Result kind = up_only.session.seal(FrameDirection::Up, wide, ByteSpan(), ByteSpan(), ByteSpan(), MutableByteSpan(out.data(), out.size()));
  wide.kind = 15;
  Result edge = up_only.session.seal(FrameDirection::Up, wide, ByteSpan(), ByteSpan(), ByteSpan(), MutableByteSpan(out.data(), out.size()));

  // Assert
  expect(unloaded.error == Error::BadValue && opened_unloaded.error == Error::BadValue,
         "refusals: a session that is not loaded refuses seal and open as BadValue");
  expect(down.error == Error::BadValue && group.error == Error::BadValue && zero.error == Error::BadValue &&
             four.error == Error::BadValue,
         "refusals: a direction not loaded, 0 and 4 are BadValue");
  expect(kind.error == Error::BadValue && edge.ok() && edge.offset == 4, "refusals: kind 16 is BadValue, kind 15 seals");
  std::size_t touched = 0;
  for (std::size_t i = 4; i < out.size(); ++i)
    touched += out[i] != kSentinel ? 1 : 0;
  expect(touched == 0, "refusals: nothing past the 4 tag bytes of the one good seal was written");
}

void seal_refusals_name_the_kind_and_write_nothing() {
  // Arrange
  Loaded f;
  Bytes out(300, kSentinel);
  Bytes empty;
  Bytes p251(251, 1), p252(252, 1), c3(3, 2);

  // Act
  Result max = f.seal(p251, empty, out);
  std::fill(out.begin(), out.end(), kSentinel);
  Result over = f.seal(p252, empty, out);
  Bytes long_ad(256, 4);
  f.ad = long_ad;
  Result ad = f.seal(empty, empty, out);
  f.ad = Bytes{1, 2, 3};
  Bytes tight(3 + 10 + 4 - 1, kSentinel);
  Result full = f.seal(Bytes(10, 5), c3, tight);

  // Assert
  expect(max.ok() && max.offset == 255, "seal: 251 plain bytes and a 4-byte tag are the 255-byte body");
  expect(over.error == Error::TooLong && over.needed == 255, "seal: a 256-byte body is TooLong");
  bool untouched = true;
  for (std::uint8_t b : out)
    untouched = untouched && b == kSentinel;
  expect(untouched, "seal: the refused TooLong wrote nothing");
  expect(ad.error == Error::TooLong, "seal: 256 bytes of associated data are TooLong");
  expect(full.error == Error::BufferFull && full.needed == 17, "seal: a buffer one byte short is BufferFull and names 17");
  bool tight_untouched = true;
  for (std::uint8_t b : tight)
    tight_untouched = tight_untouched && b == kSentinel;
  expect(tight_untouched, "seal: the refused BufferFull wrote nothing");
}

void open_checks_its_arguments_in_the_contract_order() {
  // Arrange
  Loaded f;
  Bytes body(20, 1), plain(40, kSentinel);
  ReplayWindow window(10, 1);
  FrameOpened opened;
  Bytes big(256, 1);
  Bytes long_ad(256, 1);

  // Act: each call also carries a duplicate counter, which only an earlier-checked argument can beat.
  Result too_long_body = f.session.open(FrameDirection::Up, f.message, ByteSpan(), ByteSpan(big.data(), big.size()), 0,
                                        MutableByteSpan(plain.data(), plain.size()), opened, &window, 10);
  Result too_long_ad = f.session.open(FrameDirection::Up, f.message, ByteSpan(long_ad.data(), long_ad.size()),
                                      ByteSpan(body.data(), body.size()), 0, MutableByteSpan(plain.data(), plain.size()),
                                      opened, &window, 10);
  Result too_long_clear = f.session.open(FrameDirection::Up, f.message, ByteSpan(), ByteSpan(body.data(), body.size()),
                                         256, MutableByteSpan(plain.data(), plain.size()), opened, &window, 10);
  Result shorter = f.session.open(FrameDirection::Up, f.message, ByteSpan(), ByteSpan(body.data(), 6), 3,
                                  MutableByteSpan(plain.data(), plain.size()), opened, &window, 10);
  Result no_room = f.session.open(FrameDirection::Up, f.message, ByteSpan(), ByteSpan(body.data(), body.size()), 0,
                                  MutableByteSpan(plain.data(), 15), opened, &window, 10);
  Result duplicate = f.session.open(FrameDirection::Up, f.message, ByteSpan(), ByteSpan(body.data(), body.size()), 0,
                                    MutableByteSpan(plain.data(), plain.size()), opened, &window, 10);

  // Assert
  expect(too_long_body.error == Error::TooLong && too_long_ad.error == Error::TooLong &&
             too_long_clear.error == Error::TooLong,
         "open: a body, associated data or clear_len above 255 is TooLong, before the window");
  expect(shorter.error == Error::ShortPacket, "open: a body shorter than clear_len plus the tag is ShortPacket");
  expect(no_room.error == Error::BufferFull && no_room.needed == 16, "open: a plain buffer one byte short is BufferFull");
  expect(duplicate.error == Error::Duplicate, "open: with sound arguments the window decides next");
  bool untouched = true;
  for (std::uint8_t b : plain)
    untouched = untouched && b == kSentinel;
  expect(untouched && window.top() == 10 && window.bits() == 1 && opened.plain_len == 0,
         "open: every refusal left the output buffer, the window and the report as they were");
}

void the_previous_key_is_kept_replaced_and_cleared() {
  // Arrange
  Loaded old_key;
  Bytes plain(8, 3), none, out(64);
  Result sealed = old_key.seal(plain, none, out);
  Bytes next(32, 0x77);
  FrameSession later;
  later.load(ByteSpan(next.data(), next.size()), 6, FrameConfig{4, FrameDirections::All});
  Bytes bad(31, 1);
  FrameSession unloaded;
  FrameOpened opened;
  Bytes text(16);

  // Act
  Result refused = later.set_previous(ByteSpan(bad.data(), bad.size()), 5);
  Result epoch = later.set_previous(ByteSpan(old_key.key.data(), old_key.key.size()), 0x1000000);
  Result not_loaded = unloaded.set_previous(ByteSpan(old_key.key.data(), old_key.key.size()), 5);
  Result kept = later.set_previous(ByteSpan(old_key.key.data(), old_key.key.size()), 5);
  Bytes also(64);
  Result sealed_later = later.seal(FrameDirection::Up, old_key.message, ByteSpan(old_key.ad.data(), old_key.ad.size()), ByteSpan(),
                                   ByteSpan(plain.data(), plain.size()), MutableByteSpan(also.data(), also.size()));
  Result via_previous = later.open(FrameDirection::Up, old_key.message, ByteSpan(old_key.ad.data(), old_key.ad.size()),
                                   ByteSpan(out.data(), sealed.offset), 0, MutableByteSpan(text.data(), text.size()), opened);
  bool had = later.has_previous();
  later.clear_previous();
  bool zero = true;
  for (unsigned d = 1; d <= 3; ++d)
    for (unsigned i = 0; i < 32; ++i)
      zero = zero && FrameTestAccess::previous_enc(later, d)[i] == 0 && FrameTestAccess::previous_mac(later, d)[i] == 0;
  Result gone = later.open(FrameDirection::Up, old_key.message, ByteSpan(old_key.ad.data(), old_key.ad.size()),
                           ByteSpan(out.data(), sealed.offset), 0, MutableByteSpan(text.data(), text.size()), opened);

  // Assert
  expect(refused.error == Error::BadValue && epoch.error == Error::BadValue && not_loaded.error == Error::BadValue,
         "previous: a 31-byte key, epoch 0x1000000 and a session that is not loaded are BadValue");
  expect(kept.ok() && had && via_previous.ok(), "previous: a set previous key opens the old frame");
  expect(sealed_later.ok() && std::memcmp(also.data(), out.data(), sealed.offset) != 0,
         "previous: seal uses the current key only");
  expect(zero && !later.has_previous(), "previous: clear_previous overwrites the previous keys");
  expect(gone.error == Error::TagMismatch, "previous: the old frame is TagMismatch after clear_previous");
}

void a_plain_buffer_may_start_at_the_ciphertext() {
  // Arrange
  Loaded f;
  Bytes plain = {10, 11, 12, 13, 14}, clear = {0xc1, 0xc2}, body(64);
  Result sealed = f.seal(plain, clear, body);
  FrameOpened opened;

  // Act
  Result in_place = f.session.open(FrameDirection::Up, f.message, ByteSpan(f.ad.data(), f.ad.size()),
                                   ByteSpan(body.data(), sealed.offset), 2, MutableByteSpan(body.data() + 2, 5), opened);

  // Assert
  expect(in_place.ok() && std::memcmp(body.data() + 2, plain.data(), 5) == 0 && body[0] == 0xc1,
         "open: decrypting in place gives the plain text");
}

void the_destructors_and_clear_overwrite_the_keys() {
  // Arrange
  alignas(FrameSession) unsigned char session_storage[sizeof(FrameSession)];
  alignas(MacKey) unsigned char mac_storage[sizeof(MacKey)];
  Bytes key(32, 0x99), label = {'l'};
  FrameSession* session = new (session_storage) FrameSession();
  session->load(ByteSpan(key.data(), key.size()), 1, FrameConfig{8, FrameDirections::All});
  session->set_previous(ByteSpan(key.data(), key.size()), 0);
  MacKey* mac = new (mac_storage) MacKey();
  mac->derive(ByteSpan(key.data(), key.size()), 1, ByteSpan(label.data(), label.size()));
  MacKey other;
  other.derive(ByteSpan(key.data(), key.size()), 2, ByteSpan(label.data(), label.size()));
  unsigned char probe[4] = {1, 2, 3, 4};
  Bytes tag(4);

  // Act
  bool keyed = false;
  for (unsigned char b : session_storage)
    keyed = keyed || b != 0;
  session->~FrameSession();
  mac->~MacKey();
  other.clear();
  Result refused = other.tag(ByteSpan(probe, 4), MutableByteSpan(tag.data(), 4));
  bool refused_verify = other.verify(ByteSpan(probe, 4), ByteSpan(tag.data(), 4));

  // Assert
  bool session_zero = true, mac_zero = true;
  for (unsigned char b : session_storage)
    session_zero = session_zero && b == 0;
  for (unsigned char b : mac_storage)
    mac_zero = mac_zero && b == 0;
  expect(keyed && session_zero, "wipe: the destructor of a loaded session zeroes every byte of it");
  expect(mac_zero, "wipe: the destructor of a MacKey zeroes every byte of it");
  expect(!other.ready() && refused.error == Error::BadValue && !refused_verify,
         "wipe: a cleared MacKey is refused as BadValue and verifies nothing");
}

void mac_only_refusals() {
  // Arrange
  Bytes key(32, 0x21), message(10, 1), label(33, 'x');
  MacKey fresh, mac;
  std::uint8_t out[32];
  std::uint8_t sentinel[5] = {kSentinel, kSentinel, kSentinel, kSentinel, kSentinel};

  // Act
  Result key31 = fresh.derive(ByteSpan(key.data(), 31), 1, ByteSpan(label.data(), 3));
  Result epoch = fresh.derive(ByteSpan(key.data(), 32), 0x1000000, ByteSpan(label.data(), 3));
  Result empty = fresh.derive(ByteSpan(key.data(), 32), 1, ByteSpan());
  Result wide = fresh.derive(ByteSpan(key.data(), 32), 1, ByteSpan(label.data(), 33));
  Result unready = fresh.tag(ByteSpan(message.data(), 10), MutableByteSpan(out, 4));
  Result narrow = mac.derive(ByteSpan(key.data(), 32), 1, ByteSpan(label.data(), 32));
  Result n5 = mac.tag(ByteSpan(message.data(), 10), MutableByteSpan(sentinel, 5));
  Result n0 = mac.tag(ByteSpan(message.data(), 10), MutableByteSpan());
  Result n32 = mac.tag(ByteSpan(message.data(), 10), MutableByteSpan(out, 32));
  ByteSpan empties[3] = {ByteSpan(), ByteSpan(message.data(), 10), ByteSpan()};
  std::uint8_t split[32];
  Result parts = mac.tag(empties, 3, MutableByteSpan(split, 32));

  // Assert
  expect(key31.error == Error::BadValue && epoch.error == Error::BadValue && empty.error == Error::BadValue &&
             wide.error == Error::BadValue && !fresh.ready(),
         "mac: a 31-byte key, epoch 0x1000000 and labels of 0 and 33 bytes are BadValue");
  expect(unready.error == Error::BadValue && !fresh.verify(ByteSpan(message.data(), 10), ByteSpan(out, 4)),
         "mac: a key with nothing derived refuses tag and verifies nothing");
  expect(narrow.ok() && n5.error == Error::BadValue && n0.error == Error::BadValue && sentinel[0] == kSentinel &&
             sentinel[4] == kSentinel,
         "mac: an output of 0 or 5 bytes is BadValue and nothing is written");
  expect(n32.ok() && parts.ok() && std::memcmp(out, split, 32) == 0 && mac.verify(ByteSpan(message.data(), 10), ByteSpan(out, 32)),
         "mac: 32 bytes, empty parts around a part and verify of the full tag agree");
}

// Eight threads seal on one session; the bodies equal the ones a single thread gives.
void several_threads_sealing_one_session_give_the_single_thread_bodies() {
  // Arrange
  Loaded f(8);
  constexpr int kThreads = 8, kEach = 200;
  auto body_of = [&](int t, int i) {
    MsgContext m;
    std::memcpy(m.msg_id, &t, sizeof(t));
    std::memcpy(m.msg_id + 4, &i, sizeof(i));
    m.kind = static_cast<std::uint8_t>(i % 16);
    Bytes plain(static_cast<std::size_t>(i % 80), static_cast<std::uint8_t>(t + i)), out(255);
    Bytes clear = {static_cast<std::uint8_t>(i), 7};
    Result r = f.session.seal(FrameDirection::Down, m, ByteSpan(f.ad.data(), f.ad.size()), ByteSpan(clear.data(), clear.size()),
                              ByteSpan(plain.data(), plain.size()), MutableByteSpan(out.data(), out.size()));
    out.resize(r.ok() ? r.offset : 0);
    return out;
  };
  std::vector<Bytes> expected(kThreads * kEach), actual(kThreads * kEach);
  for (int t = 0; t < kThreads; ++t)
    for (int i = 0; i < kEach; ++i)
      expected[t * kEach + i] = body_of(t, i);

  // Act
  std::vector<std::thread> threads;
  for (int t = 0; t < kThreads; ++t)
    threads.emplace_back([&, t] {
      for (int i = 0; i < kEach; ++i)
        actual[t * kEach + i] = body_of(t, i);
    });
  for (std::thread& th : threads)
    th.join();

  // Assert
  bool same = true;
  for (int k = 0; k < kThreads * kEach; ++k)
    same = same && !expected[k].empty() && expected[k] == actual[k];
  expect(same, "concurrency: 8 threads x 200 seals on one session equal the single-thread bodies");
}

void a_default_context_is_a_zero_msg_id_and_kind_zero() {
  // Arrange
  MsgContext m;
  ReplayWindow w;

  // Assert
  expect(m.kind == 0 && std::memcmp(m.msg_id, "\0\0\0\0\0\0\0\0", 8) == 0 && w.top() == 0 && w.bits() == 0 &&
             w.check(0) == Freshness::Fresh,
         "defaults: a MsgContext is zeros and a new window is empty (any counter is Fresh)");
}

}  // namespace

int run_core_frame_api_host_tests() {
  the_public_api_lists_the_d1_names();
  load_refuses_bad_arguments_and_keeps_the_session();
  an_unloaded_session_and_an_unloaded_direction_are_bad_value();
  seal_refusals_name_the_kind_and_write_nothing();
  open_checks_its_arguments_in_the_contract_order();
  the_previous_key_is_kept_replaced_and_cleared();
  a_plain_buffer_may_start_at_the_ciphertext();
  the_destructors_and_clear_overwrite_the_keys();
  mac_only_refusals();
  several_threads_sealing_one_session_give_the_single_thread_bodies();
  a_default_context_is_a_zero_msg_id_and_kind_zero();
  return check::failures();
}
