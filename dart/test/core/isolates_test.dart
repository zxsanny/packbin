import 'dart:isolate';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/repo.dart';

/// Round trips of the AC-1 row on [layout]; the count of wrong packets,
/// wrong rows and errors.
int roundTrips(Scheme<Position> layout, String golden, int count) {
  var wrong = 0;
  for (var i = 0; i < count; i++) {
    final raw = pack(layout, goldenPosition());
    final got = unpackRow(raw, layout);
    final row = got.row;
    if (hex(raw) != golden ||
        row == null ||
        row.sid != 1 ||
        row.lat != 500000000 ||
        row.lon != 300000000 ||
        row.profile != 1 ||
        row.heading != null) {
      wrong++;
    }
  }
  return wrong;
}

/// Runs the round trips in a new isolate, with the scheme sent to it.
Future<int> inIsolate(Scheme<Position> layout, String golden, int count) =>
    Isolate.run(() => roundTrips(layout, golden, count));

void main() {
  group('AC-6 isolates', () {
    test('4 isolates each do 10,000 round trips on one built scheme', () async {
      // Arrange
      final layout = positionScheme();
      final golden = goldenHex();

      // Act
      final wrong = await Future.wait([
        for (var i = 0; i < 4; i++) inIsolate(layout, golden, 10000),
      ]);

      // Assert
      expect(wrong, [0, 0, 0, 0]);
    });

    test('the scheme still packs in the isolate that built it', () async {
      // Arrange
      final layout = positionScheme();
      await inIsolate(layout, goldenHex(), 10);

      // Act
      final wrong = roundTrips(layout, goldenHex(), 10);

      // Assert
      expect(wrong, 0);
    });
  });
}
