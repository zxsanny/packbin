import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:packbin/src/ecc/codec.dart';
import 'package:packbin/src/ecc/percent.dart';
import 'package:test/test.dart';

import 'scheme_support.dart';
import 'vectors.dart';

// AL-4 (loop 100): a clear message above what its parity allows is a pack
// error with TypeScript's RangeError text, a count and a percentage alike;
// unpack of more than 254 bytes stays too_long. The limits and the messages
// were read by running typescript/src/ecc.ts.

const countLimits = {1: 253, 4: 250, 32: 222};
const percentLimits = {1: 251, 10: 230, 50: 222, 100: 222};

void main() {
  group('a count of parity bytes', () {
    countLimits.forEach((n, limit) {
      test('n $n: $limit bytes pack, one more is a pack error', () {
        // Arrange
        final atLimit = Uint8List(limit);
        final over = Uint8List(limit + 1);

        // Act
        final packed = protect(atLimit, n);
        final e = thrown(() => protect(over, n));

        // Assert
        expect(packed.length, limit + n);
        expect(e.kind, ErrorKind.packError);
        expect(e.field, isNull);
        expect(e.name, '');
        expect(
          e.reason,
          'the packet would be ${limit + 1} bytes, above the limit of '
          '$limit bytes for $n parity bytes',
        );
        expect(e.toString(), 'packbin: pack refused: ${e.reason}');
      });
    });
  });

  group('a percentage', () {
    percentLimits.forEach((p, limit) {
      test('p $p: $limit bytes pack, one more is a pack error', () {
        // Arrange
        final atLimit = Uint8List(limit);
        final over = Uint8List(limit + 1);

        // Act
        final packed = protectPercent(atLimit, p);
        final e = thrown(() => protectPercent(over, p));

        // Assert
        expect(packed.length, greaterThan(limit));
        expect(e.kind, ErrorKind.packError);
        expect(e.field, isNull);
        expect(e.name, '');
        expect(
          e.reason,
          'the packet would be ${limit + 1} bytes, above the limit of '
          '$limit bytes for $p percent parity',
        );
      });
    });
  });

  group('through a scheme', () {
    test('a row of 250 bytes packs under 4 parity bytes, 251 is refused', () {
      // Arrange: the type byte counts, so the row's bytes are one fewer.
      final s = runScheme(1, 249).withParity(4);
      final big = runScheme(1, 250).withParity(4);

      // Act
      final packed = pack(s, runRow(249));
      final e = thrown(() => pack(big, runRow(250)));

      // Assert
      expect(packed.length, 250 + 4);
      expect(e.kind, ErrorKind.packError);
      expect(e.reason, contains('the packet would be 251 bytes'));
    });

    test('the byte limit is checked first, naming the member', () {
      // Arrange
      final s = runScheme(1, 65).withLimits(maxBytes: 64).withParity(4);

      // Act
      final e = thrown(() => pack(s, runRow(65)));

      // Assert
      expect(e.kind, ErrorKind.packError);
      expect(e.name, 'raw');
      expect(e.reason, contains('above the limit of 64 bytes'));
      expect(e.reason, isNot(contains('parity')));
    });

    test('unpack of more than 254 bytes is still too_long', () {
      // Arrange
      final s = runScheme(1, 254).withParity(1);

      // Act
      final got = unpackRow(Uint8List(255), s);

      // Assert
      expect(got.error?.kind, ErrorKind.tooLong);
      expect(got.error?.left, 255);
    });
  });
}
