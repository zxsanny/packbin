#pragma once

// Frame mode (contract _docs/02_document/contracts/library/pack-session.md 3.0.0): sealed, authenticated
// frames for links that lose, reorder and duplicate messages, and the MAC-only call. A frame body is
// `clear ‖ ciphertext ‖ tag`: ChaCha20 under a key per (key, epoch, direction), a nonce built from the
// caller's 8-byte `msg_id`, the 4-bit `kind`, the direction and the epoch, and a tag that is the first
// 4, 8 or 16 bytes of HMAC-SHA-256 over the nonce, the associated data, the clear part and the
// ciphertext (encrypt, then MAC). It is the only session of the package (ADR 009).
//
// Allocation-free and exception-free like the core: every buffer is the caller's, the keys live in the
// session object, standard names come from packbin/platform.hpp only. Each call returns a `Result`
// (`error` is Ok, BadValue, TooLong, BufferFull, ShortPacket, TagMismatch, Duplicate or TooOld; `offset`
// is the body length of a seal, the plaintext length of an open and 0 for a refusal; `needed` the bytes
// a refusal asked for).
//
// **For one (key, epoch, direction), a `msg_id` is never sealed twice with different contents.** Reuse
// breaks the confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys
// and nonces. (meshbell builds `msg_id` as source (2 bytes), id field (2 bytes) and creation wave
// (4 bytes), so it is unique by construction.)

#include "packbin/core.hpp"
#include "packbin/platform.hpp"

namespace packbin {

// Input bytes of a call: a pointer and a length. An array of std::uint8_t converts by itself; an empty
// span may hold a null pointer.
struct ByteSpan {
  std::uint8_t const* data = nullptr;
  std::size_t size = 0;

  constexpr ByteSpan() = default;
  constexpr ByteSpan(std::uint8_t const* bytes, std::size_t n) : data(bytes), size(n) {}
  template <std::size_t N>
  constexpr ByteSpan(std::uint8_t const (&bytes)[N]) : data(bytes), size(N) {}
};

// Output bytes of a call: a pointer and the capacity.
struct MutableByteSpan {
  std::uint8_t* data = nullptr;
  std::size_t size = 0;

  constexpr MutableByteSpan() = default;
  constexpr MutableByteSpan(std::uint8_t* bytes, std::size_t n) : data(bytes), size(n) {}
  template <std::size_t N>
  constexpr MutableByteSpan(std::uint8_t (&bytes)[N]) : data(bytes), size(N) {}
  constexpr operator ByteSpan() const { return ByteSpan(data, size); }
};

// The direction of a frame: the nonce and the keys depend on it.
enum class FrameDirection : std::uint8_t {
  Up = 1,
  Down = 2,
  Group = 3,
};

// The directions a frame session loaded keys for (a set: combine with `|`).
enum class FrameDirections : std::uint8_t {
  None = 0,
  Up = 1,
  Down = 2,
  Group = 4,
  All = 7,
};

constexpr FrameDirections operator|(FrameDirections a, FrameDirections b) {
  return static_cast<FrameDirections>(static_cast<std::uint8_t>(a) | static_cast<std::uint8_t>(b));
}

constexpr FrameDirections operator&(FrameDirections a, FrameDirections b) {
  return static_cast<FrameDirections>(static_cast<std::uint8_t>(a) & static_cast<std::uint8_t>(b));
}

// Which loaded key opened a frame.
enum class FrameSlot : std::uint8_t {
  Current,
  Previous,
};

// What a replay window says about a counter.
enum class Freshness : std::uint8_t {
  Fresh,
  Duplicate,
  TooOld,
};

// What a frame session is loaded with besides the key. A `tag_len` other than 4, 8 or 16 makes load fail
// with BadValue; it is fixed for the lifetime of the loaded key.
struct FrameConfig {
  std::uint8_t tag_len = 4;
  FrameDirections directions = FrameDirections::None;
};

// What `FrameSession::open` reports for a frame that opened.
struct FrameOpened {
  FrameSlot slot = FrameSlot::Current;
  std::size_t clear_len = 0;
  std::size_t plain_len = 0;
};

// What the caller supplies per message: the 8-byte `msg_id` and the 4-bit `kind` (0 to 15; above 15 is
// BadValue).
//
// **For one (key, epoch, direction), a `msg_id` is never sealed twice with different contents.** Reuse
// breaks the confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys
// and nonces.
struct MsgContext {
  static constexpr std::size_t kIdSize = 8;

  std::uint8_t msg_id[kIdSize] = {};
  std::uint8_t kind = 0;
};

// The replay window of frame mode: the highest counter a sender's frames reached (`top`) and which of
// the 64 counters up to it were committed (`bits`: bit i set means counter `top - i` was committed; 0 is
// an empty window). The caller owns one per sender and passes it, with the message's counter, to
// `FrameSession::open`. 16 bytes; not thread safe.
//
// The counter must come from bytes the tag covers (for example the `msg_id` or the associated data),
// never from an unauthenticated field of the wire: it is an argument of open and not part of the tag.
// A window restored from stored state with `bits` 0 is empty whatever `top` is (replay protection is off
// until the next commit); a caller that restores a window validates it (bit 0 set when `bits` is not 0).
class ReplayWindow {
 public:
  static constexpr std::uint64_t kSize = 64;

  constexpr ReplayWindow() = default;
  constexpr ReplayWindow(std::uint64_t top, std::uint64_t bits) : top_(top), bits_(bits) {}

  constexpr std::uint64_t top() const { return top_; }
  constexpr std::uint64_t bits() const { return bits_; }

  // What the window says about `counter`. Never changes the state.
  constexpr Freshness check(std::uint64_t counter) const {
    if (bits_ == 0 || counter > top_)
      return Freshness::Fresh;
    std::uint64_t behind = top_ - counter;
    if (behind >= kSize)
      return Freshness::TooOld;
    return ((bits_ >> behind) & 1u) != 0 ? Freshness::Duplicate : Freshness::Fresh;
  }

  // Records `counter`. Open calls this only after a frame opened; a counter 64 or more behind the
  // highest is ignored.
  constexpr void commit(std::uint64_t counter) {
    if (bits_ == 0) {
      top_ = counter;
      bits_ = 1;
    } else if (counter > top_) {
      std::uint64_t shift = counter - top_;
      bits_ = (shift >= kSize ? 0 : bits_ << shift) | 1u;
      top_ = counter;
    } else {
      std::uint64_t behind = top_ - counter;
      if (behind < kSize)
        bits_ |= std::uint64_t{1} << behind;
    }
  }

 private:
  std::uint64_t top_ = 0;
  std::uint64_t bits_ = 0;
};

namespace detail {
struct FrameTestAccess;
}  // namespace detail

// A frame-mode session: the keys of each loaded direction, derived once at `load` from a 32-byte key and
// an epoch of at most 0xFFFFFF, plus an optional previous (key, epoch) that `open` tries when the current
// key's tag does not match. No heap: the object holds the keys (about 400 bytes). Not copyable, so the
// keys live in one place; the destructor overwrites them.
//
// Concurrency: `seal` and `open` only read the session, so any number of threads may call them at once
// (each with its own buffers, and `open` with its own window). `load`, `set_previous`, `clear_previous`
// and the destructor change it: call them while no other call on the session runs. A ReplayWindow is not
// thread safe either.
//
// Limits of a wipe: the keys, the derived HMAC states and the temporaries of a call are overwritten with
// volatile stores before they go out of scope, but a compiler may keep a copy in a register or a spilled
// slot, and the caller's own copy of the 32-byte key is the caller's to clear. The wipe is best effort.
// The tag compare folds every byte into one value with no early exit; the compiler is not promised to
// keep that, which is also best effort. SHA-256 and ChaCha20 use no secret-indexed tables.
class FrameSession {
 public:
  static constexpr std::size_t kKeySize = 32;
  static constexpr std::size_t kMaxBody = 255;
  static constexpr std::uint32_t kMaxEpoch = 0xFFFFFF;

  // A session with no keys: every call on it is refused as BadValue until `load` succeeds.
  FrameSession() = default;
  ~FrameSession();
  FrameSession(FrameSession const&) = delete;
  FrameSession& operator=(FrameSession const&) = delete;

  // Derives the keys of each loaded direction from a 32-byte key and an epoch. BadValue (and the session
  // as it was) for a key that is not 32 bytes, an epoch above 0xFFFFFF, a tag length that is not 4, 8 or
  // 16, or a direction bit outside FrameDirections::All. With FrameDirections::None the session refuses
  // every seal and open as BadValue. Loading again replaces the keys and drops the previous slot.
  Result load(ByteSpan key, std::uint32_t epoch, FrameConfig config);

  // Keeps a previous (key, epoch) that `open` tries when the current key's tag does not match: the key
  // just replaced, for frames sealed before the change. Seal never uses it. BadValue for a key that is not
  // 32 bytes, an epoch above 0xFFFFFF or a session that is not loaded. A frame that opens under it commits
  // into the same replay window, so keep it only for the changeover and call `clear_previous` when that
  // ends.
  Result set_previous(ByteSpan key, std::uint32_t epoch);

  // Drops the previous (key, epoch) and overwrites its keys.
  void clear_previous();

  bool loaded() const { return loaded_; }
  bool has_previous() const { return has_previous_; }
  std::uint8_t tag_len() const { return tag_len_; }
  std::uint32_t epoch() const { return current_.epoch; }

  // Seals `clear ‖ plain` into `out` as `clear ‖ ciphertext ‖ tag`; `offset` of the result is the body
  // length. The same inputs give the same bytes; the session does not change and the previous key is not
  // used. A session that is not loaded, a direction not loaded or a `kind` above 15 is BadValue; `ad`
  // above 255 bytes, or `clear + plain + tag` above 255, is TooLong; an `out` shorter than the body is
  // BufferFull. On any refusal nothing is written. `ad`, `clear` and `plain` must not overlap `out`.
  //
  // **For one (key, epoch, direction), never seal two different messages with the same `msg_id`.** Reuse
  // breaks the confidentiality of both messages, and the library cannot check it (see MsgContext). A new
  // epoch derives new keys and nonces.
  Result seal(FrameDirection direction, MsgContext const& message, ByteSpan ad, ByteSpan clear,
              ByteSpan plain, MutableByteSpan out) const;

  // Opens `body` (`clear ‖ ciphertext ‖ tag`, the first `clear_len` bytes clear) in the contract's order:
  // argument checks, the replay window (when given, with the message's counter: Duplicate or TooOld
  // before any hashing), the tag with the current key and then once with the previous key (TagMismatch),
  // decryption into `plain`, and only then the window commit. On Ok, `offset` of the result and
  // `opened.plain_len` are the plaintext length and `opened.slot` says which key opened it. `plain` and the
  // window are untouched unless the result is Ok. A session that is not loaded, a direction not loaded
  // or a `kind` above 15 is BadValue; `ad`, `body` or `clear_len` above 255 is TooLong (before any
  // hashing); a body shorter than `clear_len` plus the tag is ShortPacket; a `plain` shorter than the
  // plaintext is BufferFull. `plain` may start at the ciphertext inside `body` (decrypt in place); `body`
  // must not change while the call runs.
  //
  // The counter must come from bytes the tag covers, never from an unauthenticated wire field: it is not
  // part of the tag.
  Result open(FrameDirection direction, MsgContext const& message, ByteSpan ad, ByteSpan body,
              std::size_t clear_len, MutableByteSpan plain, FrameOpened& opened,
              ReplayWindow* window = nullptr, std::uint64_t counter = 0) const;

 private:
  friend struct detail::FrameTestAccess;

  // K_enc(d) and K_mac(d) of one (key, epoch) for the three directions (index d - 1).
  struct Slot {
    std::uint32_t epoch = 0;
    std::uint8_t enc[3][kKeySize] = {};
    std::uint8_t mac[3][kKeySize] = {};
  };

  bool call_allowed(FrameDirection direction, MsgContext const& message) const;

  Slot current_;
  Slot previous_;
  bool loaded_ = false;
  bool has_previous_ = false;
  std::uint8_t tag_len_ = 0;
  FrameDirections directions_ = FrameDirections::None;
};

// The MAC-only call of frame mode: a tag without encryption, for a per-hop network check and for key
// fingerprints. `K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)` and `tag = the first n bytes
// of HMAC(K_label, message)`, with `n` of 4, 8, 16 or 32. The message is passed in parts and hashed piece
// by piece with no joined copy; the tag does not depend on how it is split.
//
// The object holds the 32-byte `K_label` (36 bytes with the epoch); the destructor overwrites it (best
// effort, see FrameSession). `verify` compares every byte with no early exit. Not copyable. `tag` and
// `verify` only read the object; `derive`, `clear` and the destructor change it.
class MacKey {
 public:
  static constexpr std::size_t kMaxLabel = 32;

  // A key with nothing derived: `tag` is refused as BadValue and `verify` is false until `derive` works.
  MacKey() = default;
  ~MacKey();
  MacKey(MacKey const&) = delete;
  MacKey& operator=(MacKey const&) = delete;

  // BadValue (and the key as it was) for a key that is not 32 bytes, an epoch above 0xFFFFFF or a label
  // that is not 1 to 32 bytes.
  Result derive(ByteSpan key, std::uint32_t epoch, ByteSpan label);

  // Overwrites the key; every later call is refused.
  void clear();

  bool ready() const { return ready_; }
  std::uint32_t epoch() const { return epoch_; }

  // Writes `out.size` bytes (4, 8, 16 or 32; any other size is BadValue and nothing is written) of the
  // HMAC of the message, given whole or in `count` parts.
  Result tag(ByteSpan message, MutableByteSpan out) const;
  Result tag(ByteSpan const* parts, std::size_t count, MutableByteSpan out) const;

  // True when `tag` (4, 8, 16 or 32 bytes) is the tag of the message. False for any other length and for a
  // key that is not ready.
  bool verify(ByteSpan message, ByteSpan tag) const;
  bool verify(ByteSpan const* parts, std::size_t count, ByteSpan tag) const;

 private:
  friend struct detail::FrameTestAccess;

  std::uint8_t key_[32] = {};
  std::uint32_t epoch_ = 0;
  bool ready_ = false;
};

}  // namespace packbin
