import 'dart:typed_data';

import 'sha256.dart';

/// Incremental HMAC-SHA256 (RFC 2104): the message is given in parts and
/// hashed as it comes, with no joined copy.
///
/// The key is read in the constructor and not kept. One object computes one
/// MAC: [digest] wipes the inner hasher and the outer pad block.
final class HmacSha256 {
  final Sha256 _inner = Sha256();
  final Uint8List _outerPad = Uint8List(sha256BlockSize);
  bool _open = true;

  HmacSha256(Uint8List key) {
    final block = Uint8List(sha256BlockSize);
    if (key.length > sha256BlockSize) {
      // A key longer than the block is hashed first.
      (Sha256()..update(key)).digestInto(block);
    } else {
      block.setRange(0, key.length, key);
    }
    for (var i = 0; i < sha256BlockSize; i++) {
      _outerPad[i] = block[i] ^ 0x5c;
      block[i] ^= 0x36;
    }
    _inner.update(block);
    block.fillRange(0, block.length, 0);
  }

  /// The buffers a wipe overwrites, for the wipe tests.
  List<TypedData> get workingBuffers => [_outerPad, ..._inner.workingBuffers];

  /// Adds `data[start..end)` to the message.
  void update(Uint8List data, [int start = 0, int? end]) {
    if (!_open) throw StateError('HmacSha256 used after digest() or wipe()');
    _inner.update(data, start, end);
  }

  /// The 32-byte MAC; the object is wiped.
  Uint8List digest() {
    final out = Uint8List(sha256DigestSize);
    digestInto(out);
    return out;
  }

  /// Writes the MAC to `out[offset..offset + 32)`; the object is wiped.
  void digestInto(Uint8List out, [int offset = 0]) {
    if (!_open) throw StateError('HmacSha256 used after digest() or wipe()');
    RangeError.checkValidRange(offset, offset + sha256DigestSize, out.length);
    final innerDigest = _inner.digest();
    final outer = Sha256()
      ..update(_outerPad)
      ..update(innerDigest);
    outer.digestInto(out, offset);
    innerDigest.fillRange(0, innerDigest.length, 0);
    wipe();
  }

  /// Zeroes the pad block and the inner hasher; the object stays closed.
  void wipe() {
    _outerPad.fillRange(0, _outerPad.length, 0);
    _inner.wipe();
    _open = false;
  }
}

/// HMAC-SHA256 of `data` under `key` in one piece.
Uint8List hmacSha256(Uint8List key, Uint8List data) =>
    (HmacSha256(key)..update(data)).digest();

/// HMAC-SHA256 of the parts in order, hashed piece by piece.
Uint8List hmacSha256Parts(Uint8List key, Iterable<Uint8List> parts) {
  final mac = HmacSha256(key);
  for (final part in parts) {
    mac.update(part);
  }
  return mac.digest();
}
