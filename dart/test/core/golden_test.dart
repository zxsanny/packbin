import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/repo.dart';

void main() {
  group('AC-1 golden bytes', () {
    test('the fixture file holds the 13-byte packet', () {
      // Act
      final golden = goldenHex();

      // Assert
      expect(golden, '4001000065cd1d00a3e1110100');
    });

    test('a typed row packs to the golden bytes', () {
      // Arrange
      final position = positionScheme();

      // Act
      final raw = pack(position, goldenPosition());

      // Assert
      expect(hex(raw), goldenHex());
    });

    test('a map row packs to the golden bytes', () {
      // Arrange
      final position = positionMapScheme();

      // Act
      final raw = pack(position, goldenMap());

      // Assert
      expect(hex(raw), goldenHex());
    });

    test('unpack gives the typed row its five fields and no motion field', () {
      // Arrange
      final position = positionScheme();

      // Act
      final got = unpackRow(unhex(goldenHex()), position);

      // Assert
      final row = got.row!;
      expect(got.error, isNull);
      expect(
        [row.sid, row.lat, row.lon, row.profile],
        [1, 500000000, 300000000, 1],
      );
      expect([row.heading, row.speed, row.altitude], [null, null, null]);
    });

    test('unpack gives the map row five keys and no motion key', () {
      // Arrange
      final position = positionMapScheme();

      // Act
      final got = unpackRow(unhex(goldenHex()), position);

      // Assert
      expect(got.ok, isTrue);
      expect(got.row, goldenMap());
    });

    test('a heading of 90 sets bit 0 and writes 5a 00, both row forms', () {
      // Arrange
      final typed = goldenPosition()..heading = 90;
      final map = goldenMap()..['heading'] = 90;

      // Act
      final fromTyped = pack(positionScheme(), typed);
      final fromMap = pack(positionMapScheme(), map);
      final back = unpackRow(fromTyped, positionScheme()).row!;

      // Assert
      expect(hex(fromTyped), '4001000065cd1d00a3e11101015a00');
      expect(hex(fromMap), hex(fromTyped));
      expect([back.heading, back.speed, back.altitude], [90, null, null]);
    });

    test('a packed row is a buffer of its own length', () {
      // Act
      final raw = pack(positionMapScheme(), goldenMap());

      // Assert
      expect(raw.buffer.lengthInBytes, 13);
    });
  });
}
