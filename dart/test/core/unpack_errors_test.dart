import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/repo.dart';

void main() {
  group('AC-3 short, trailing, unknown type', () {
    // What each cut of the golden packet must report: field id, name, needed, left.
    const cuts = <int, (int?, String, int, int)>{
      0: (null, '', 1, 0),
      1: (0, 'sid', 2, 0),
      2: (0, 'sid', 2, 1),
      3: (1, 'lat', 4, 0),
      4: (1, 'lat', 4, 1),
      5: (1, 'lat', 4, 2),
      6: (1, 'lat', 4, 3),
      7: (2, 'lon', 4, 0),
      8: (2, 'lon', 4, 1),
      9: (2, 'lon', 4, 2),
      10: (2, 'lon', 4, 3),
      11: (3, 'profile', 1, 0),
      12: (4, '', 1, 0),
    };

    for (final MapEntry(key: length, value: want) in cuts.entries) {
      test(
        'the golden packet cut to $length bytes is a short packet, typed and map',
        () {
          // Arrange
          final cut = unhex(goldenHex()).sublist(0, length);
          final (field, name, needed, left) = want;
          final expected = PackbinError(
            ErrorKind.short,
            field: field,
            name: name,
            needed: needed,
            left: left,
          );

          // Act
          final typed = unpackRow(cut, positionScheme());
          final map = unpackRow(cut, positionMapScheme());

          // Assert
          expect([typed.error, map.error], [expected, expected]);
          expect([typed.row, map.row, typed.ok], [null, null, false]);
        },
      );
    }

    test('a set bit whose member is cut names the member', () {
      // Arrange
      final cut = unhex('4001000065cd1d00a3e11101015a');

      // Act
      final got = unpackRow(cut, positionScheme());

      // Assert
      expect(
        got.error,
        const PackbinError(
          ErrorKind.short,
          field: 4,
          name: 'heading',
          needed: 2,
          left: 1,
        ),
      );
      expect(got.row, isNull);
    });

    test('one trailing byte is a trailing error with no row', () {
      // Arrange
      final long = unhex('${goldenHex()}00');

      // Act
      final got = unpackRow(long, positionScheme());

      // Assert
      expect(got.error, const PackbinError(ErrorKind.trailing, left: 1));
      expect(got.error!.kind.term, 'trailing_bytes');
      expect(got.row, isNull);
    });

    test(
      'a first byte that names no scheme is an unknown type with that byte',
      () {
        // Arrange
        final other = unhex(goldenHex())..[0] = 0x41;
        Object? seen;

        // Act
        final one = unpackRow(other, positionScheme());
        final many = unpack(other, [positionScheme().on((row) => seen = row)]);

        // Assert
        expect(
          one.error,
          const PackbinError(ErrorKind.unknownType, actual: 0x41),
        );
        expect(many.error, one.error);
        expect([one.row, many.row, seen], [null, null, null]);
      },
    );

    test('an empty buffer is a short packet that names no field', () {
      // Arrange
      Object? seen;

      // Act
      final got = unpack(Uint8List(0), [
        positionScheme().on((row) => seen = row),
      ]);

      // Assert
      expect(
        got.error,
        const PackbinError(ErrorKind.short, needed: 1, left: 0),
      );
      expect([got.row, seen], [null, null]);
    });

    test('a short fixed bytes field names the bytes it needed', () {
      // Arrange
      final layout = scheme(1, [bytes(0, 'b', 6)]);

      // Act
      final got = unpackRow(unhex('01aabb'), layout);

      // Assert
      expect(
        got.error,
        const PackbinError(
          ErrorKind.short,
          field: 0,
          name: 'b',
          needed: 6,
          left: 2,
        ),
      );
    });

    test('a packet inside a larger buffer is read through a view', () {
      // Arrange
      final big = unhex('ffff${goldenHex()}ffff');
      final view = Uint8List.sublistView(big, 2, 15);

      // Act
      final got = unpackRow(view, positionMapScheme());

      // Assert
      expect(got.row, goldenMap());
    });

    test('the kinds carry the shared outcome terms', () {
      // Act
      final terms = [for (final kind in ErrorKind.values) kind.term];

      // Assert
      expect(terms, [
        'short_packet',
        'trailing_bytes',
        'type_mismatch',
        'bad_value',
        'too_many',
        'scheme_error',
        'pack_error',
        'uncorrectable',
        'too_long',
      ]);
    });

    test('20,000 seeded random buffers never throw and never give both a row and an error', () {
      // Arrange
      final random = Random(99);
      final fb = flagByte('m');
      final mixed = scheme(2, [
        fb,
        u8(0, 'mode'),
        fb.bit(u64(1, 'a')),
        fb.bit(flagBool(2, 'on')),
        when(3, eq(0, 1), [bytes(3, 'raw', 5), be(f64(4, 'x'))]),
        flags(5, [
          i16(5, 'p'),
          f32(6, 'q'),
          when(7, eq(0, 2), [u32(7, 'r')]),
        ]),
      ]);
      final handlers = [positionScheme().on((_) {}), mixed.on((_) {})];
      var bad = 0;

      // Act
      for (var i = 0; i < 20000; i++) {
        final buf = Uint8List(random.nextInt(40));
        for (var j = 0; j < buf.length; j++) {
          buf[j] = random.nextInt(256);
        }
        if (buf.isNotEmpty && random.nextBool()) {
          buf[0] = random.nextBool() ? 0x40 : 2;
        }
        final got = unpack(buf, handlers);
        if ((got.row == null) == (got.error == null)) bad++;
      }

      // Assert
      expect(bad, 0);
    });
  });
}
