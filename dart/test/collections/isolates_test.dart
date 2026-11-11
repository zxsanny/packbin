import 'dart:isolate';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/user_rows.dart';

/// Round trips of the README packet; the count of wrong packets and rows.
int mapTrips(Scheme<Map<String, Object?>> layout, int count) {
  var wrong = 0;
  for (var i = 0; i < count; i++) {
    final got = unpackRow(unhex(userHex), layout);
    final row = got.row;
    if (row == null || hex(pack(layout, row)) != userHex.replaceAll(' ', '')) {
      wrong++;
    }
  }
  return wrong;
}

int typedTrips(Scheme<User> layout, int count) {
  var wrong = 0;
  for (var i = 0; i < count; i++) {
    final got = unpackRow(unhex(userHex), layout);
    final row = got.row;
    if (row == null || hex(pack(layout, row)) != userHex.replaceAll(' ', '')) {
      wrong++;
    }
  }
  return wrong;
}

void main() {
  group('a scheme with lists, dictionaries and nested rows in isolates', () {
    test('4 isolates each do 2,000 round trips on one map scheme', () async {
      // Arrange
      final layout = userMapScheme();

      // Act
      final wrong = await Future.wait([
        for (var i = 0; i < 4; i++) Isolate.run(() => mapTrips(layout, 2000)),
      ]);

      // Assert
      expect(wrong, [0, 0, 0, 0]);
    });

    test('4 isolates each do 2,000 round trips on one typed scheme', () async {
      // Arrange
      final layout = userScheme();

      // Act
      final wrong = await Future.wait([
        for (var i = 0; i < 4; i++) Isolate.run(() => typedTrips(layout, 2000)),
      ]);

      // Assert
      expect(wrong, [0, 0, 0, 0]);
    });
  });
}
