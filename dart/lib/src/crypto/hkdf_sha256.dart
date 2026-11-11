import 'dart:typed_data';

import 'hmac_sha256.dart';
import 'sha256.dart';

/// The longest output of HKDF-SHA256: 255 blocks of 32 bytes.
const int hkdfMaxLength = 255 * sha256DigestSize;

/// The pseudorandom key of RFC 5869 step 1 (32 bytes, the caller wipes it).
/// An empty salt is the RFC's string of 32 zero bytes.
Uint8List hkdfExtract(Uint8List salt, Uint8List ikm) {
  final key = salt.isEmpty ? Uint8List(sha256DigestSize) : salt;
  return hmacSha256(key, ikm);
}

/// RFC 5869 step 2: `length` bytes (0 to 8160) from a pseudorandom key.
Uint8List hkdfExpand(Uint8List prk, Uint8List info, int length) {
  if (length < 0 || length > hkdfMaxLength) {
    throw RangeError.range(length, 0, hkdfMaxLength, 'length');
  }
  final out = Uint8List(length);
  final previous = Uint8List(sha256DigestSize);
  final counter = Uint8List(1);
  var written = 0;
  for (var index = 1; written < length; index++) {
    final mac = HmacSha256(prk);
    if (index > 1) mac.update(previous);
    mac.update(info);
    counter[0] = index;
    mac.update(counter);
    mac.digestInto(previous);
    final take = length - written < sha256DigestSize
        ? length - written
        : sha256DigestSize;
    out.setRange(written, written + take, previous);
    written += take;
  }
  previous.fillRange(0, previous.length, 0);
  return out;
}

/// Extract then expand; the pseudorandom key is wiped before return.
Uint8List hkdfSha256(
  Uint8List ikm,
  Uint8List salt,
  Uint8List info,
  int length,
) {
  if (length < 0 || length > hkdfMaxLength) {
    throw RangeError.range(length, 0, hkdfMaxLength, 'length');
  }
  final prk = hkdfExtract(salt, ikm);
  try {
    return hkdfExpand(prk, info, length);
  } finally {
    prk.fillRange(0, prk.length, 0);
  }
}
