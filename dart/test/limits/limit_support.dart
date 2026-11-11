import 'dart:typed_data';

import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

/// The type byte then [rest] bytes of [value].
Uint8List packet(int rest, [int value = 1]) {
  final out = Uint8List(rest + 1)..fillRange(0, rest + 1, value);
  out[0] = 1;
  return out;
}

/// `repeat { u8 k }`: one name, one slot a round.
Scheme<Row> repeatK() => scheme(1, [
  repeat(0, [u8(0, 'k')]),
]);

/// `u32 n; times of n { u8 k }`.
Scheme<Row> timesK() => scheme(1, [
  u32(0, 'n'),
  times(1, 0, [u8(1, 'k')]),
]);

/// `repeat` of [names] u8 members named f0, f1, and so on.
Scheme<Row> wide(int names) => scheme(1, [
  repeat(0, [for (var i = 0; i < names; i++) u8(i, 'f$i')]),
]);

/// The count of entries in the lists of the top level of [row]: what the
/// rounds of a map scheme made.
int roundEntries(Row row) {
  var total = 0;
  for (final v in row.values) {
    if (v is List<Object?>) total += v.length;
  }
  return total;
}
