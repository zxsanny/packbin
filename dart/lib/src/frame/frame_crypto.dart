import 'dart:typed_data';

import '../crypto/hkdf_sha256.dart';

// The pieces of frame mode that sit on top of the crypto primitives: the key
// schedule's salt, the tag compare, the wipe and the guarded write to a
// caller's buffer. Internal: not exported from the package.

const int frameMaxEpoch = 0xffffff;
const int frameKeySize = 32;

// "packbin-frame" in ASCII.
const List<int> _saltLabel = [
  0x70, 0x61, 0x63, 0x6b, 0x62, 0x69, 0x6e, 0x2d, 0x66, 0x72, 0x61, 0x6d, //
  0x65,
];

bool epochOk(int epoch) => epoch >= 0 && epoch <= frameMaxEpoch;

/// "packbin-frame" followed by the epoch as a 32-bit little-endian integer
/// (17 bytes). The epoch is at most 0xFFFFFF, so the last byte is 0.
Uint8List frameSalt(int epoch) {
  final out = Uint8List(17);
  out.setRange(0, 13, _saltLabel);
  out[13] = epoch & 0xff;
  out[14] = (epoch >> 8) & 0xff;
  out[15] = (epoch >> 16) & 0xff;
  out[16] = (epoch >> 24) & 0xff;
  return out;
}

/// `HKDF(IKM = key, salt of the epoch, info = [first] ‖ use, L = 32)`.
Uint8List deriveFrameKey(Uint8List key, int epoch, int first, List<int> use) {
  final info = Uint8List(1 + use.length);
  info[0] = first;
  info.setRange(1, info.length, use);
  return hkdfSha256(key, frameSalt(epoch), info, frameKeySize);
}

/// Test hook: when set, the tag compare calls it with the index of every
/// byte it reads. Null outside tests.
void Function(int index)? tagCompareProbe;

/// The tag compare: folds every byte of both lists into one value and decides
/// only at the end. A different length is public (the tag length is fixed
/// per key), so it is the one early exit. The Dart VM promises no timing, but
/// the loop has no data-dependent branch and no early return.
bool tagsEqual(Uint8List left, Uint8List right) {
  final length = left.length;
  if (length != right.length) return false;
  final probe = tagCompareProbe;
  var difference = 0;
  for (var i = 0; i < length; i++) {
    difference |= left[i] ^ right[i];
    probe?.call(i);
  }
  return difference == 0;
}

/// Overwrites the bytes with zeros.
void wipe(Uint8List bytes) {
  bytes.fillRange(0, bytes.length, 0);
}

/// Copies `source[start..end)` to the start of [output]. False, with nothing
/// written, when [output] is an unmodifiable view.
///
/// The bytes are stored one by one: an indexed store into an unmodifiable
/// view fails on the first byte, while `setRange` from typed data writes
/// through such a view on the Dart VM (seen on 3.13.5).
bool writeOutput(Uint8List output, Uint8List source, int start, int end) {
  try {
    for (var i = start; i < end; i++) {
      output[i - start] = source[i];
    }
    return true;
  } on UnsupportedError {
    return false;
  }
}
