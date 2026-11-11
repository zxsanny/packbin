import 'dart:typed_data';

import 'frame_crypto.dart';

const List<int> _enc = [0x65, 0x6e, 0x63];
const List<int> _mac = [0x6d, 0x61, 0x63];

/// The keys of one (key, epoch) for the loaded directions: `K_enc(d)` and
/// `K_mac(d)`, derived once at load. Internal: not exported from the package.
final class FrameKeys {
  FrameKeys._(this.epoch);

  /// Derives the keys of every direction in the bit set [directions] (0 to
  /// 7) from a 32-byte [key] and a checked [epoch].
  factory FrameKeys.derive(Uint8List key, int epoch, int directions) {
    final keys = FrameKeys._(epoch);
    for (var d = 1; d <= 3; d++) {
      if (directions & (1 << (d - 1)) == 0) continue;
      keys._encKeys[d - 1] = deriveFrameKey(key, epoch, d, _enc);
      keys._macKeys[d - 1] = deriveFrameKey(key, epoch, d, _mac);
    }
    return keys;
  }

  final int epoch;
  final List<Uint8List?> _encKeys = [null, null, null];
  final List<Uint8List?> _macKeys = [null, null, null];

  /// The encryption key of a direction the caller has checked is loaded.
  Uint8List enc(int direction) => _encKeys[direction - 1]!;

  /// The MAC key of a direction the caller has checked is loaded.
  Uint8List mac(int direction) => _macKeys[direction - 1]!;

  /// Every key buffer this object owns.
  List<Uint8List> buffers() => [..._encKeys.nonNulls, ..._macKeys.nonNulls];

  /// Overwrites every key buffer with zeros.
  void wipeAll() {
    buffers().forEach(wipe);
  }
}
