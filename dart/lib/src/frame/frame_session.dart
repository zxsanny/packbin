import 'dart:typed_data';

import '../crypto/chacha20.dart';
import '../crypto/hmac_sha256.dart';
import 'frame_crypto.dart';
import 'frame_keys.dart';
import 'frame_results.dart';
import 'frame_types.dart';
import 'replay_window.dart';

const int _allDirections = 7;
const int _firstBlock = 0;

/// Frame mode of the session (`pack-session.md` 3.0.0): sealed, authenticated
/// frames for links that lose, reorder and duplicate messages.
///
/// A frame body is `clear ‖ ciphertext ‖ tag`: ChaCha20 under a key per (key,
/// epoch, direction), a nonce built from the caller's `msg_id`, the `kind`,
/// the direction and the epoch, and a tag that is the first 4, 8 or 16 bytes
/// of HMAC-SHA256 over the nonce, the associated data, the clear part and the
/// ciphertext. The session works on bytes: a packed message in, a frame out.
///
/// [seal] is deterministic and never changes the session. [open] reads the
/// previous slot, which [setPrevious] and [clearPrevious] replace, and
/// [close] overwrites the keys; a call after [close] is refused as a bad
/// value. Refusals are values ([FrameRefusal]): no call throws for an
/// argument or for wire bytes.
///
/// **A session is used by one isolate at a time.** Every call runs to its end
/// on the calling isolate. Sending a session to another isolate copies it,
/// keys included, and [close] wipes only the copy it is called on.
///
/// **Dart cannot wipe at garbage collection.** The key buffers this object
/// owns are overwritten by [close] and by nothing else, so a session that is
/// not closed leaves its keys in memory until the memory is reused. The wipe
/// and the compare are best effort: the garbage collector may have moved a
/// buffer before the wipe, the caller's key is not touched, and the tag
/// compare folds every byte with no early exit while the Dart VM promises no
/// constant time.
final class FrameSession {
  FrameSession._(this.tagLength, this._directions, this._current);

  /// The length of a key in bytes.
  static const int keySize = frameKeySize;

  /// The longest frame body and the longest associated data, in bytes.
  static const int maxBody = frameMaxBody;

  /// The bytes of the tag at the end of every frame body: 4, 8 or 16.
  final int tagLength;

  final int _directions;
  final FrameKeys _current;
  FrameKeys? _previous;
  bool _closed = false;
  int _macComputations = 0;

  /// The epoch of the current key.
  int get epoch => _current.epoch;

  /// True after [close].
  bool get isClosed => _closed;

  /// Derives the keys of each loaded direction from a 32-byte key and an
  /// epoch of 0 to 0xFFFFFF.
  ///
  /// Null (the contract's BadValue) for a key that is not 32 bytes, an epoch
  /// outside 0 to 0xFFFFFF, a tag length that is not 4, 8 or 16, or a
  /// direction bit outside [FrameDirections.all]. With
  /// [FrameDirections.none] it gives a session that refuses every seal and
  /// open as a bad value. The key is read, not kept.
  static FrameSession? load(Uint8List key, int epoch, FrameConfig config) {
    final tagLength = config.tagLength;
    final directions = config.directions.bits;
    if (key.length != frameKeySize || !epochOk(epoch)) return null;
    if (tagLength != 4 && tagLength != 8 && tagLength != 16) return null;
    if (directions < 0 || directions > _allDirections) return null;
    return FrameSession._(
      tagLength,
      directions,
      FrameKeys.derive(key, epoch, directions),
    );
  }

  /// Keeps a previous (key, epoch) that [open] tries when the current key's
  /// tag does not match: the key just replaced, for frames sealed before the
  /// change. Seal never uses it.
  ///
  /// False (the contract's BadValue) for a key that is not 32 bytes, an epoch
  /// outside 0 to 0xFFFFFF or a closed session. A frame that opens under it
  /// commits into the same replay window, so keep it only for the changeover
  /// and call [clearPrevious] when that ends.
  bool setPrevious(Uint8List key, int epoch) {
    if (_closed || key.length != frameKeySize || !epochOk(epoch)) return false;
    final replaced = _previous;
    _previous = FrameKeys.derive(key, epoch, _directions);
    replaced?.wipeAll();
    return true;
  }

  /// Drops the previous (key, epoch) and overwrites its keys.
  void clearPrevious() {
    final replaced = _previous;
    _previous = null;
    replaced?.wipeAll();
  }

  /// Seals `clear ‖ plain` into [output] as `clear ‖ ciphertext ‖ tag` and
  /// gives the body length. The same inputs give the same bytes; the session
  /// does not change and the previous key is not used.
  ///
  /// A direction not loaded, a kind outside 0 to 15, a `msg_id` that is not 8
  /// bytes, an [output] that cannot be written or a closed session is a bad
  /// value; [ad] above 255 bytes, or `clear + plain + tag` above 255, is too
  /// long; an [output] shorter than the body is buffer full. On any refusal
  /// nothing is written. The body is built apart and copied to [output] last,
  /// so [ad], [clear] and [plain] may be views of it (sealing in place gives
  /// the same bytes).
  ///
  /// **For one (key, epoch, direction), never seal two different messages
  /// with the same `msg_id`.** Reuse breaks the confidentiality of both
  /// messages, and the library cannot check it (see [MsgContext]).
  FrameSealResult seal(
    FrameDirection direction,
    MsgContext message,
    Uint8List ad,
    Uint8List clear,
    Uint8List plain,
    Uint8List output,
  ) {
    final d = direction.number;
    final kind = message.kind;
    final id = _callId(d, message, kind);
    if (id == null) {
      return badValue(
        'direction not loaded, kind not 0 to 15, msg_id not 8 bytes or '
        'closed session',
      );
    }
    final adLength = ad.length;
    final clearLength = clear.length;
    final plainLength = plain.length;
    if (adLength > frameMaxBody) return tooLong(adLength);
    final length = clearLength + plainLength + tagLength;
    if (length > frameMaxBody) return tooLong(length);
    if (output.length < length) return bufferFull(length);

    final keys = _current;
    final cipherEnd = clearLength + plainLength;
    final nonce = _makeNonce(id, kind, d, keys.epoch);
    final body = Uint8List(length);
    body.setRange(0, clearLength, clear);
    body.setRange(clearLength, cipherEnd, plain);
    chacha20XorInPlace(
      keys.enc(d),
      nonce,
      _firstBlock,
      body,
      clearLength,
      cipherEnd,
    );
    final full = _tag(
      keys.mac(d),
      nonce,
      ad,
      adLength,
      body,
      clearLength,
      cipherEnd,
    );
    body.setRange(cipherEnd, length, full);
    wipe(full);
    if (!writeOutput(output, body, 0, length)) {
      return badValue('the output buffer cannot be written');
    }
    return FrameSealed(length);
  }

  /// Opens [body] (`clear ‖ ciphertext ‖ tag`, the first [clearLength] bytes
  /// clear) in the contract's order: argument checks, the replay window (when
  /// given, with the message's [counter]: duplicate or too old before any
  /// hashing), the tag with the current key and then once with the previous
  /// key (tag mismatch), decryption into [plain], and only then the window
  /// commit. [plain] and the window are untouched unless the result is a
  /// [FrameOpened].
  ///
  /// A direction not loaded, a kind outside 0 to 15, a `msg_id` that is not 8
  /// bytes, a negative [clearLength], a [counter] outside 0 to 2^64 - 1 (when
  /// a window is given; no counter is 0), a [plain] that cannot be written or
  /// a closed session is a bad value; [ad], [body] or [clearLength] above 255
  /// is too long (before any hashing); a body shorter than `clearLength +
  /// tag` is a short packet; a [plain] shorter than the plaintext is buffer
  /// full. The frame and [ad] are copied once before hashing, so the tag is
  /// checked and the text decrypted from the same bytes, and [plain] may
  /// overlap [body].
  ///
  /// The counter must come from bytes the tag covers, never from an
  /// unauthenticated wire field: it is not part of the tag.
  FrameOpenResult open(
    FrameDirection direction,
    MsgContext message,
    Uint8List ad,
    Uint8List body,
    int clearLength,
    Uint8List plain, {
    ReplayWindow? window,
    BigInt? counter,
  }) {
    final d = direction.number;
    final kind = message.kind;
    final id = _callId(d, message, kind);
    final count = counter ?? BigInt.zero;
    final counterOk = window == null || ReplayWindow.isCounter(count);
    if (id == null || clearLength < 0 || !counterOk) {
      return badValue(
        'direction not loaded, kind not 0 to 15, msg_id not 8 bytes, bad '
        'clear length or counter, or closed session',
      );
    }
    final adLength = ad.length;
    final bodyLength = body.length;
    if (adLength > frameMaxBody) return tooLong(adLength);
    if (bodyLength > frameMaxBody) return tooLong(bodyLength);
    if (clearLength > frameMaxBody) return tooLong(clearLength);
    final framing = clearLength + tagLength;
    if (bodyLength < framing) return shortPacket(framing, bodyLength);
    final plainLength = bodyLength - framing;
    if (plain.length < plainLength) return bufferFull(plainLength);

    if (window != null) {
      final freshness = window.check(count);
      if (freshness == Freshness.duplicate) return duplicate;
      if (freshness == Freshness.tooOld) return tooOld;
    }

    final frame = Uint8List.fromList(body);
    final adCopy = Uint8List.fromList(ad);
    final cipherEnd = clearLength + plainLength;
    var keys = _current;
    var slot = FrameSlot.current;
    if (!_matches(keys, d, id, kind, adCopy, frame, clearLength, cipherEnd)) {
      final previous = _previous;
      if (previous == null ||
          !_matches(
            previous,
            d,
            id,
            kind,
            adCopy,
            frame,
            clearLength,
            cipherEnd,
          )) {
        return tagMismatch;
      }
      keys = previous;
      slot = FrameSlot.previous;
    }

    final nonce = _makeNonce(id, kind, d, keys.epoch);
    chacha20XorInPlace(
      keys.enc(d),
      nonce,
      _firstBlock,
      frame,
      clearLength,
      cipherEnd,
    );
    final written = writeOutput(plain, frame, clearLength, cipherEnd);
    wipe(frame);
    if (!written) return badValue('the output buffer cannot be written');
    window?.commit(count);
    return FrameOpened(slot, clearLength, plainLength);
  }

  /// Overwrites the keys of both slots with zeros. Every later call is
  /// refused as a bad value. Calling it again does nothing more.
  void close() {
    _closed = true;
    _current.wipeAll();
    _previous?.wipeAll();
  }

  // The message's id when the call is allowed: session open, direction 1 to 3
  // and loaded, an 8-byte id, a kind of 0 to 15.
  Uint8List? _callId(int direction, MsgContext message, int kind) {
    if (_closed || direction < 1 || direction > 3) return null;
    if (_directions & (1 << (direction - 1)) == 0) return null;
    if (kind < 0 || kind > 15) return null;
    return msgIdOf(message);
  }

  // The full HMAC over M = N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext,
  // hashed piece by piece. `frame[0..clearLength)` is the clear part and
  // `frame[clearLength..cipherEnd)` the ciphertext.
  Uint8List _tag(
    Uint8List macKey,
    Uint8List nonce,
    Uint8List ad,
    int adLength,
    Uint8List frame,
    int clearLength,
    int cipherEnd,
  ) {
    _macComputations++;
    final lengths = Uint8List(2);
    lengths[0] = adLength;
    lengths[1] = clearLength;
    final mac = HmacSha256(macKey)
      ..update(nonce)
      ..update(lengths, 0, 1)
      ..update(ad, 0, adLength)
      ..update(lengths, 1, 2)
      ..update(frame, 0, clearLength)
      ..update(frame, clearLength, cipherEnd);
    return mac.digest();
  }

  bool _matches(
    FrameKeys keys,
    int direction,
    Uint8List id,
    int kind,
    Uint8List ad,
    Uint8List frame,
    int clearLength,
    int cipherEnd,
  ) {
    final nonce = _makeNonce(id, kind, direction, keys.epoch);
    final full = _tag(
      keys.mac(direction),
      nonce,
      ad,
      ad.length,
      frame,
      clearLength,
      cipherEnd,
    );
    final equal = tagsEqual(
      Uint8List.sublistView(full, 0, tagLength),
      Uint8List.sublistView(frame, cipherEnd),
    );
    wipe(full);
    return equal;
  }
}

// msg_id (8) ‖ ((kind << 4) | direction) (1) ‖ epoch as 24 bits (3).
Uint8List _makeNonce(Uint8List id, int kind, int direction, int epoch) {
  final nonce = Uint8List(12);
  nonce.setRange(0, 8, id);
  nonce[8] = (kind << 4) | direction;
  nonce[9] = epoch & 0xff;
  nonce[10] = (epoch >> 8) & 0xff;
  nonce[11] = (epoch >> 16) & 0xff;
  return nonce;
}

/// The keys of the current slot, for the vector tests. Internal: not exported
/// from the package.
FrameKeys frameCurrentKeys(FrameSession session) => session._current;

/// Every key buffer of both slots (current first), for the wipe tests.
/// Internal: not exported from the package.
List<Uint8List> frameKeyBuffers(FrameSession session) => [
  ...session._current.buffers(),
  ...?session._previous?.buffers(),
];

/// The number of HMAC computations of seal and open so far, for the tests of
/// open's order. Internal: not exported from the package.
int frameMacComputations(FrameSession session) => session._macComputations;
