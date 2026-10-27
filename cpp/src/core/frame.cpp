#include "packbin/frame.hpp"

#include "crypto.hpp"

#include "packbin/platform.hpp"

namespace packbin {

namespace {

namespace crypto = detail::crypto;

constexpr std::size_t kSaltSize = 17;
constexpr std::size_t kNonceSize = crypto::kNonceSize;

Result refuse(Error error, std::size_t offset = 0, std::size_t needed = 0) {
  return fail(error, offset, -1, needed);
}

bool tag_len_allowed(std::size_t n) { return n == 4 || n == 8 || n == 16; }
bool mac_len_allowed(std::size_t n) { return n == 4 || n == 8 || n == 16 || n == 32; }

// "packbin-frame" followed by the epoch as a 32-bit little-endian integer.
void write_salt(std::uint32_t epoch, std::uint8_t salt[kSaltSize]) {
  static constexpr char kLabel[13] = {'p', 'a', 'c', 'k', 'b', 'i', 'n', '-', 'f', 'r', 'a', 'm', 'e'};
  for (std::size_t i = 0; i < sizeof(kLabel); ++i)
    salt[i] = static_cast<std::uint8_t>(kLabel[i]);
  for (std::size_t i = 0; i < 4; ++i)
    salt[13 + i] = static_cast<std::uint8_t>(epoch >> (8 * i));
}

// msg_id (8) ‖ ((kind << 4) | direction) (1) ‖ epoch as 24 bits (3).
void write_nonce(MsgContext const& message, FrameDirection direction, std::uint32_t epoch,
                 std::uint8_t nonce[kNonceSize]) {
  for (std::size_t i = 0; i < MsgContext::kIdSize; ++i)
    nonce[i] = message.msg_id[i];
  nonce[8] = static_cast<std::uint8_t>((message.kind << 4) | static_cast<unsigned>(direction));
  nonce[9] = static_cast<std::uint8_t>(epoch);
  nonce[10] = static_cast<std::uint8_t>(epoch >> 8);
  nonce[11] = static_cast<std::uint8_t>(epoch >> 16);
}

// Folds every byte of both inputs into one value and decides only at the end: no early exit. The
// accumulator is volatile so the compiler cannot turn the fold into a loop that stops at the first
// difference (best effort, like every wipe here).
bool tags_equal(std::uint8_t const* a, std::uint8_t const* b, std::size_t n) {
  volatile std::uint8_t difference = 0;
  for (std::size_t i = 0; i < n; ++i)
    difference = static_cast<std::uint8_t>(difference | (a[i] ^ b[i]));
  return difference == 0;
}

void put(std::uint8_t* to, std::uint8_t const* from, std::size_t n) {
  if (n != 0)
    std::memcpy(to, from, n);
}

// The full HMAC over M = N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext, hashed piece by piece with no
// joined copy. `clear_and_cipher` holds the clear part then the ciphertext, which is how both a sealed
// and a received body lay them out.
void frame_tag(std::uint8_t const mac_key[crypto::kKeySize], std::uint8_t const nonce[kNonceSize],
               ByteSpan ad, std::uint8_t const* clear_and_cipher, std::size_t clear_len,
               std::size_t cipher_len, std::uint8_t full[crypto::kDigestSize]) {
  crypto::HmacSha256 mac;
  mac.begin(mac_key, crypto::kKeySize);
  mac.update(nonce, kNonceSize);
  std::uint8_t length = static_cast<std::uint8_t>(ad.size);
  mac.update(&length, 1);
  if (ad.size != 0)
    mac.update(ad.data, ad.size);
  length = static_cast<std::uint8_t>(clear_len);
  mac.update(&length, 1);
  if (clear_len + cipher_len != 0)
    mac.update(clear_and_cipher, clear_len + cipher_len);
  mac.end(full);
}

}  // namespace

// ---- FrameSession --------------------------------------------------------------------------------

FrameSession::~FrameSession() { crypto::wipe(this, sizeof(*this)); }

bool FrameSession::call_allowed(FrameDirection direction, MsgContext const& message) const {
  unsigned d = static_cast<unsigned>(direction);
  return loaded_ && message.kind <= 15 && d >= 1 && d <= 3 &&
         (static_cast<unsigned>(directions_) & (1u << (d - 1))) != 0;
}

namespace {

// K_enc(d) and K_mac(d) of every loaded direction into `enc` and `mac`; the others are cleared. One
// extract serves all six expands (the PRK depends on the key and the salt only). False only if an expand
// refuses, which 32 bytes of output never do.
template <typename Slot>
bool derive_slot(Slot& slot, std::uint8_t const* key, std::uint32_t epoch, unsigned directions) {
  std::uint8_t salt[kSaltSize];
  write_salt(epoch, salt);
  std::uint8_t prk[crypto::kDigestSize];
  crypto::hkdf_extract(salt, sizeof(salt), key, crypto::kKeySize, prk);
  bool ok = true;
  for (unsigned d = 0; d < 3; ++d) {
    if ((directions & (1u << d)) == 0) {
      crypto::wipe(slot.enc[d], sizeof(slot.enc[d]));
      crypto::wipe(slot.mac[d], sizeof(slot.mac[d]));
      continue;
    }
    std::uint8_t info[4] = {static_cast<std::uint8_t>(d + 1), 'e', 'n', 'c'};
    ok = crypto::hkdf_expand(prk, info, sizeof(info), slot.enc[d], crypto::kKeySize) && ok;
    info[1] = 'm';
    info[2] = 'a';
    info[3] = 'c';
    ok = crypto::hkdf_expand(prk, info, sizeof(info), slot.mac[d], crypto::kKeySize) && ok;
  }
  crypto::wipe(prk, sizeof(prk));
  slot.epoch = epoch;
  return ok;
}

}  // namespace

Result FrameSession::load(ByteSpan key, std::uint32_t epoch, FrameConfig config) {
  unsigned directions = static_cast<unsigned>(config.directions);
  if (key.size != kKeySize || epoch > kMaxEpoch || !tag_len_allowed(config.tag_len) ||
      (directions & ~static_cast<unsigned>(FrameDirections::All)) != 0)
    return refuse(Error::BadValue);
  loaded_ = false;
  has_previous_ = false;
  crypto::wipe(&previous_, sizeof(previous_));
  if (!derive_slot(current_, key.data, epoch, directions)) {
    crypto::wipe(&current_, sizeof(current_));
    return refuse(Error::BadValue);
  }
  tag_len_ = config.tag_len;
  directions_ = config.directions;
  loaded_ = true;
  return Result{};
}

Result FrameSession::set_previous(ByteSpan key, std::uint32_t epoch) {
  if (!loaded_ || key.size != kKeySize || epoch > kMaxEpoch)
    return refuse(Error::BadValue);
  has_previous_ = false;
  if (!derive_slot(previous_, key.data, epoch, static_cast<unsigned>(directions_))) {
    crypto::wipe(&previous_, sizeof(previous_));
    return refuse(Error::BadValue);
  }
  has_previous_ = true;
  return Result{};
}

void FrameSession::clear_previous() {
  has_previous_ = false;
  crypto::wipe(&previous_, sizeof(previous_));
}

Result FrameSession::seal(FrameDirection direction, MsgContext const& message, ByteSpan ad,
                          ByteSpan clear, ByteSpan plain, MutableByteSpan out) const {
  if (!call_allowed(direction, message))
    return refuse(Error::BadValue);
  if (ad.size > kMaxBody)
    return refuse(Error::TooLong, ad.size, kMaxBody);
  if (clear.size > kMaxBody || plain.size > kMaxBody || clear.size + plain.size + tag_len_ > kMaxBody)
    return refuse(Error::TooLong, clear.size + plain.size + tag_len_, kMaxBody);
  std::size_t body_len = clear.size + plain.size + tag_len_;
  if (out.size < body_len)
    return refuse(Error::BufferFull, 0, body_len);

  unsigned d = static_cast<unsigned>(direction) - 1;
  std::uint8_t nonce[kNonceSize];
  write_nonce(message, direction, current_.epoch, nonce);
  std::uint8_t* body = out.data;
  put(body, clear.data, clear.size);
  put(body + clear.size, plain.data, plain.size);
  if (!crypto::chacha20_xor(current_.enc[d], nonce, 0, body + clear.size, plain.size)) {
    crypto::wipe(body, body_len);
    return refuse(Error::BadValue);
  }
  std::uint8_t full[crypto::kDigestSize];
  frame_tag(current_.mac[d], nonce, ad, body, clear.size, plain.size, full);
  put(body + clear.size + plain.size, full, tag_len_);
  crypto::wipe(full, sizeof(full));
  return Result{Error::Ok, body_len};
}

Result FrameSession::open(FrameDirection direction, MsgContext const& message, ByteSpan ad,
                          ByteSpan body, std::size_t clear_len, MutableByteSpan plain,
                          FrameOpened& opened, ReplayWindow* window, std::uint64_t counter) const {
  opened = FrameOpened{};
  if (!call_allowed(direction, message))
    return refuse(Error::BadValue);
  if (ad.size > kMaxBody)
    return refuse(Error::TooLong, ad.size, kMaxBody);
  if (body.size > kMaxBody)
    return refuse(Error::TooLong, body.size, kMaxBody);
  if (clear_len > kMaxBody)
    return refuse(Error::TooLong, clear_len, kMaxBody);
  std::size_t framing = clear_len + tag_len_;
  if (body.size < framing)
    return refuse(Error::ShortPacket, body.size, framing);
  std::size_t plain_len = body.size - framing;
  if (plain.size < plain_len)
    return refuse(Error::BufferFull, 0, plain_len);

  if (window != nullptr) {
    Freshness freshness = window->check(counter);
    if (freshness == Freshness::Duplicate)
      return refuse(Error::Duplicate);
    if (freshness == Freshness::TooOld)
      return refuse(Error::TooOld);
  }

  unsigned d = static_cast<unsigned>(direction) - 1;
  std::uint8_t const* cipher = body.data + clear_len;
  std::uint8_t const* tag = cipher + plain_len;
  std::uint8_t nonce[kNonceSize];
  std::uint8_t full[crypto::kDigestSize];
  Slot const* slot = &current_;
  FrameSlot which = FrameSlot::Current;
  write_nonce(message, direction, slot->epoch, nonce);
  frame_tag(slot->mac[d], nonce, ad, body.data, clear_len, plain_len, full);
  bool matched = tags_equal(full, tag, tag_len_);
  if (!matched && has_previous_) {
    slot = &previous_;
    which = FrameSlot::Previous;
    write_nonce(message, direction, slot->epoch, nonce);
    frame_tag(slot->mac[d], nonce, ad, body.data, clear_len, plain_len, full);
    matched = tags_equal(full, tag, tag_len_);
  }
  crypto::wipe(full, sizeof(full));
  if (!matched)
    return refuse(Error::TagMismatch);

  if (plain_len != 0)
    std::memmove(plain.data, cipher, plain_len);
  if (!crypto::chacha20_xor(slot->enc[d], nonce, 0, plain.data, plain_len)) {
    crypto::wipe(plain.data, plain_len);
    return refuse(Error::BadValue);
  }
  if (window != nullptr)
    window->commit(counter);
  opened = FrameOpened{which, clear_len, plain_len};
  return Result{Error::Ok, plain_len};
}

// ---- MacKey --------------------------------------------------------------------------------------

MacKey::~MacKey() { crypto::wipe(this, sizeof(*this)); }

Result MacKey::derive(ByteSpan key, std::uint32_t epoch, ByteSpan label) {
  if (key.size != FrameSession::kKeySize || epoch > FrameSession::kMaxEpoch || label.size < 1 ||
      label.size > kMaxLabel)
    return refuse(Error::BadValue);
  std::uint8_t salt[kSaltSize];
  write_salt(epoch, salt);
  std::uint8_t info[1 + kMaxLabel];
  info[0] = 0;
  put(info + 1, label.data, label.size);
  std::uint8_t derived[sizeof(key_)];
  bool ok = crypto::hkdf_sha256(key.data, key.size, salt, sizeof(salt), info, 1 + label.size,
                                derived, sizeof(derived));
  if (!ok) {
    crypto::wipe(derived, sizeof(derived));
    return refuse(Error::BadValue);
  }
  std::memcpy(key_, derived, sizeof(key_));
  crypto::wipe(derived, sizeof(derived));
  epoch_ = epoch;
  ready_ = true;
  return Result{};
}

void MacKey::clear() { crypto::wipe(this, sizeof(*this)); }

namespace {

// The full HMAC of the parts joined, under the 32-byte label key.
void mac_of_parts(std::uint8_t const key[32], ByteSpan const* parts, std::size_t count,
                  std::uint8_t full[crypto::kDigestSize]) {
  crypto::HmacSha256 mac;
  mac.begin(key, 32);
  for (std::size_t i = 0; i < count; ++i)
    if (parts[i].size != 0)
      mac.update(parts[i].data, parts[i].size);
  mac.end(full);
}

}  // namespace

Result MacKey::tag(ByteSpan message, MutableByteSpan out) const { return tag(&message, 1, out); }

Result MacKey::tag(ByteSpan const* parts, std::size_t count, MutableByteSpan out) const {
  if (!ready_ || !mac_len_allowed(out.size))
    return refuse(Error::BadValue);
  std::uint8_t full[crypto::kDigestSize];
  mac_of_parts(key_, parts, count, full);
  put(out.data, full, out.size);
  crypto::wipe(full, sizeof(full));
  return Result{Error::Ok, out.size};
}

bool MacKey::verify(ByteSpan message, ByteSpan tag) const { return verify(&message, 1, tag); }

bool MacKey::verify(ByteSpan const* parts, std::size_t count, ByteSpan tag) const {
  if (!ready_ || !mac_len_allowed(tag.size))
    return false;
  std::uint8_t full[crypto::kDigestSize];
  mac_of_parts(key_, parts, count, full);
  bool equal = tags_equal(full, tag.data, tag.size);
  crypto::wipe(full, sizeof(full));
  return equal;
}

}  // namespace packbin
