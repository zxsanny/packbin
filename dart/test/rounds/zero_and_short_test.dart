import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

Scheme<Map<String, Object?>> pointsRepeat() => scheme(1, [
  repeat(0, [i32(0, 'lat'), i32(1, 'lon')]),
]);

Scheme<Map<String, Object?>> pointsTimes() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [i32(1, 'lat'), i32(2, 'lon')]),
  u8(3, 'tail'),
]);

/// Three points: round 1 is bytes 1 to 8, round 2 bytes 9 to 16.
const threePoints = '01 0a000000 14000000 1e000000 28000000 32000000 3c000000';

void main() {
  group('zero rounds (zero value rule)', () {
    test('an empty list for a times name packs count 0 and no round bytes', () {
      // Arrange
      final layout = pointsTimes();
      final row = {'n': 0, 'lat': <int>[], 'lon': <int>[], 'tail': 7};

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '010007');
      expect(back, {'n': 0, 'lat': <int>[], 'lon': <int>[], 'tail': 7});
      expect(back['lat'], isNotNull);
    });

    test('a times with no list at all packs count 0 too', () {
      // Arrange
      final layout = pointsTimes();

      // Act
      final raw = pack(layout, {'n': 0, 'tail': 7});

      // Assert
      expect(hex(raw), '010007');
    });

    test('a repeat with no rounds packs the type byte only and unpacks to empty lists', () {
      // Arrange
      final layout = pointsRepeat();

      // Act
      final raw = pack(layout, {'lat': <int>[], 'lon': <int>[]});
      final back = unpackRow(raw, layout);

      // Assert
      expect(hex(raw), '01');
      expect(hex(pack(layout, <String, Object?>{})), '01');
      expect(back.row, {'lat': <int>[], 'lon': <int>[]});
    });

    test('empty lists pack again to the same bytes (zero rounds repack)', () {
      // Arrange
      final layout = pointsTimes();
      final back = unpackRow(unhex('010007'), layout).row!;

      // Act
      final again = pack(layout, back);

      // Assert
      expect(hex(again), '010007');
    });

    test('a times whose count is 0 refuses values for its names', () {
      // Arrange
      final layout = pointsTimes();

      // Act
      void run() => pack(layout, {
        'n': 0,
        'lat': [1],
        'lon': [2],
        'tail': 7,
      });

      // Assert
      expect(run, throwsA(isA<PackbinException>()));
    });

    test('a lone scalar with a count of 0 packs without a word', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'a'),
        times(1, 0, [u8(1, 'x')]),
      ]);

      // Act
      final raw = pack(layout, {'a': 0, 'x': 5});

      // Assert
      expect(hex(raw), '0100');
    });
  });

  group('a short packet inside a round', () {
    test('cut inside round 2 of 3 of a repeat: an error value, no row', () {
      // Arrange
      final layout = pointsRepeat();
      final full = unhex(threePoints);

      // Act and Assert
      for (var cut = 10; cut < 17; cut++) {
        final result = unpackRow(full.sublist(0, cut), layout);
        expect(result.row, isNull, reason: 'cut $cut');
        expect(result.error!.kind, ErrorKind.short, reason: 'cut $cut');
      }
    });

    test('a repeat cut one byte into round 2 needs 4 and has 1 for lat', () {
      // Arrange
      final layout = pointsRepeat();
      final cut = unhex(threePoints).sublist(0, 10);

      // Act
      final error = unpackRow(cut, layout).error!;

      // Assert
      expect(
        [error.name, error.field, error.needed, error.left],
        ['lat', 0, 4, 1],
      );
    });

    test('a repeat cut inside the lon of round 2 names lon', () {
      // Arrange
      final layout = pointsRepeat();
      final cut = unhex(threePoints).sublist(0, 14);

      // Act
      final error = unpackRow(cut, layout).error!;

      // Assert
      expect(
        [error.name, error.field, error.needed, error.left],
        ['lon', 1, 4, 1],
      );
    });

    test('a times of 3 cut inside round 2 names the field and the bytes', () {
      // Arrange
      final layout = pointsTimes();
      final full = unhex(
        '01 03 0a000000 14000000 1e000000 28000000 32000000 3c000000 07',
      );
      final cut = full.sublist(0, 12);

      // Act
      final result = unpackRow(cut, layout);

      // Assert
      expect(result.row, isNull);
      expect(
        [result.error!.name, result.error!.needed, result.error!.left],
        ['lat', 4, 2],
      );
    });

    test('every prefix of a times packet is refused without throwing', () {
      // Arrange
      final layout = pointsTimes();
      final full = unhex(
        '01 03 0a000000 14000000 1e000000 28000000 32000000 3c000000 07',
      );

      // Act and Assert
      for (var cut = 1; cut < full.length; cut++) {
        final result = unpackRow(full.sublist(0, cut), layout);
        expect(result.ok, isFalse, reason: 'cut $cut');
        expect(result.row, isNull, reason: 'cut $cut');
      }
      expect(unpackRow(full, layout).ok, isTrue);
    });

    test('bytes after the last whole round of a times are trailing bytes', () {
      // Arrange
      final layout = pointsTimes();
      final wire = unhex('01 00 07 ff');

      // Act
      final error = unpackRow(wire, layout).error!;

      // Assert
      expect([error.kind, error.left], [ErrorKind.trailing, 1]);
    });
  });
}
