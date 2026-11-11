import 'dart:typed_data';

import '../crypto/hmac_sha256.dart';
import 'frame_crypto.dart';
import 'frame_results.dart';

bool _lengthAllowed(int length) =>
    length == 4 || length == 8 || length == 16 || length == 32;

/// The MAC-only call of frame mode: a tag without encryption, for a per-hop
/// network check and for key fingerprints.
///
/// `K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)` and
/// `tag = first n bytes of HMAC(K_label, message)`, with `n` of 4, 8, 16 or
/// 32. The message is a list of parts, hashed piece by piece with no joined
/// copy; the tag does not depend on how the message is split.
///
/// This object holds the 32-byte `K_label` and [close] overwrites it. Dart
/// has no wipe at garbage collection, so a key that is not closed is wiped
/// by nothing. Verification compares every byte with no early exit; the
/// Dart VM promises no constant time. A key is used by one isolate at a
/// time: sending it to another isolate copies it, and [close] wipes only the
/// copy it is called on.
final class MacKey {
  MacKey._(this._key, this.epoch);

  /// The epoch the key was derived for.
  final int epoch;

  final Uint8List _key;
  bool _closed = false;

  /// True after [close].
  bool get isClosed => _closed;

  /// The key of a label. Null (the contract's BadValue) for a key that is
  /// not 32 bytes, an epoch outside 0 to 0xFFFFFF or a label that is not 1
  /// to 32 bytes. The key is read, not kept.
  static MacKey? derive(Uint8List key, int epoch, Uint8List label) {
    if (key.length != frameKeySize || !epochOk(epoch)) return null;
    if (label.isEmpty || label.length > 32) return null;
    return MacKey._(deriveFrameKey(key, epoch, 0, label), epoch);
  }

  /// The first [length] bytes of the HMAC of the parts in order. A length
  /// other than 4, 8, 16 or 32, or a closed key, is a bad value.
  MacTagResult tag(List<Uint8List> parts, int length) {
    if (_closed || !_lengthAllowed(length)) {
      return badValue('tag length not 4, 8, 16 or 32, or closed key');
    }
    final full = hmacSha256Parts(_key, parts);
    final tag = Uint8List.fromList(Uint8List.sublistView(full, 0, length));
    wipe(full);
    return MacTag(tag);
  }

  /// True when [tag] (4, 8, 16 or 32 bytes) is the tag of the parts. False
  /// for any other length and for a closed key.
  bool verify(List<Uint8List> parts, Uint8List tag) {
    final length = tag.length;
    if (_closed || !_lengthAllowed(length)) return false;
    final full = hmacSha256Parts(_key, parts);
    final equal = tagsEqual(Uint8List.sublistView(full, 0, length), tag);
    wipe(full);
    return equal;
  }

  /// Overwrites the key with zeros. Every later call is refused. Calling it
  /// again does nothing more.
  void close() {
    _closed = true;
    wipe(_key);
  }
}

/// The key buffer of a [MacKey], for the vector and wipe tests. Internal:
/// not exported from the package.
Uint8List macKeyBytes(MacKey key) => key._key;
