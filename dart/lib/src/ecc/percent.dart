import 'dart:typed_data';

import '../errors.dart';
import 'codec.dart';

/// The most percentage a scheme declares.
const int maxPercent = 100;

/// The largest correction limit under a percentage.
const int maxPercentLimit = 16;

/// The parity count of a clear message of [length] bytes under percentage
/// [p]: the percentage of the length, rounded up, at most 32.
int parityCount(int p, int length) {
  final n = (p * length + 99) ~/ 100;
  return n < maxParity ? n : maxParity;
}

/// The largest clear length under percentage [p] 1 to 100: the sent length
/// stays within 254.
int largestClear(int p) {
  var length = 0;
  while (length + 1 + parityCount(p, length + 1) <= maxBlock) {
    length++;
  }
  return length;
}

/// The one clear length whose protected message is [sent] bytes long under
/// percentage [p], or null when no message has that length.
int? clearLength(int p, int sent) {
  final last = sent < maxBlock ? sent : maxBlock;
  for (var length = 0; length <= last; length++) {
    if (length + parityCount(p, length) == sent) return length;
  }
  return null;
}

/// The clear message followed by the parity of percentage [p] (0 adds
/// nothing and has no length limit). A clear message above the largest of
/// [p] throws a [PackbinException] of kind [ErrorKind.tooLong].
Uint8List protectPercent(Uint8List clear, int p) {
  if (p == 0) return clear;
  final limit = largestClear(p);
  if (clear.length > limit) {
    throw PackbinException(
      PackbinError(
        ErrorKind.tooLong,
        left: clear.length,
        reason:
            'the packet would be ${clear.length} bytes, above the limit of '
            '$limit bytes for $p percent parity',
      ),
    );
  }
  return protect(clear, parityCount(p, clear.length));
}

/// As [repair], with the count found from the received length under
/// percentage [p]. [t] is 0 to 16 and is lowered to `n / 2` of this message.
Repair repairPercent(Uint8List received, int p, int t) {
  if (p == 0) return repair(received, 0, 0);
  final size = received.length;
  if (size > maxBlock) return Repair.fail(tooLongBuffer(size));
  final length = clearLength(p, size);
  if (length == null) return const Repair.fail(uncorrectableError);
  final n = size - length;
  final half = n ~/ 2;
  return repair(received, n, t < half ? t : half);
}
