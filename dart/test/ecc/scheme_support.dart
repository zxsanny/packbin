import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/position.dart';

typedef Row = Map<String, Object?>;

Uint8List flipped(Uint8List raw, List<int> places) {
  final copy = Uint8List.fromList(raw);
  for (final at in places) {
    copy[at] ^= 0x55;
  }
  return copy;
}

Scheme<Row> runScheme(int type, int size) =>
    scheme(type, [bytes(0, 'raw', size)]);

Row runRow(int size) => {'raw': Uint8List(size)};

bool sameRow(Object? got) => equals(goldenMap()).matches(got, {});
