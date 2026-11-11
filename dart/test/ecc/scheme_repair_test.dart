import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import 'scheme_support.dart';
import 'vectors.dart';

// AZ-4140 AC-2 (DT-18, S9): repair on unpack, and the percentage form.

void main() {
  final base = positionMapScheme();
  final protected = base.withParity(8);
  final raw = pack(protected, goldenMap());

  group('AC-2 repair', () {
    test('1 and 4 flipped bytes are repaired with limit 4', () {
      // Arrange
      final one = flipped(raw, [3]);
      final four = flipped(raw, [0, 5, 9, 15]);

      // Act
      final a = unpackRowRepair(one, protected, 4);
      final b = unpackRowRepair(four, protected, 4);

      // Assert
      expect(sameRow(a.row), isTrue);
      expect(a.repaired, 1);
      expect(sameRow(b.row), isTrue);
      expect(b.repaired, 4);
      expect(a.error, isNull);
      expect(b.error, isNull);
    });

    test('5 flipped bytes are uncorrectable with limit 4', () {
      // Arrange
      final five = flipped(raw, [1, 4, 6, 10, 20]);

      // Act
      final got = unpackRowRepair(five, protected, 4);

      // Assert
      expect(got.row, isNull);
      expect(got.error?.kind, ErrorKind.uncorrectable);
      expect(got.repaired, 0);
    });

    test('with limit 0 every damaged copy is uncorrectable', () {
      // Arrange
      final copies = [
        for (final places in [
          [3],
          [0, 5, 9, 15],
          [1, 4, 6, 10, 20],
        ])
          flipped(raw, places),
      ];

      // Act
      final kinds = [
        for (final c in copies) unpackRowRepair(c, protected, 0).error?.kind,
      ];

      // Assert
      expect(kinds, everyElement(ErrorKind.uncorrectable));
    });

    test('the clean copy unpacks with repaired 0 at limit 0 and 4', () {
      // Act
      final a = unpackRowRepair(raw, protected, 0);
      final b = unpackRowRepair(raw, protected, 4);
      final c = unpackRow(raw, protected);

      // Assert
      expect([a.repaired, b.repaired, c.repaired], [0, 0, 0]);
      expect([a.ok, b.ok, c.ok], [true, true, true]);
      expect(sameRow(a.row), isTrue);
    });

    test('plain unpackRow only detects: one wrong byte is uncorrectable', () {
      // Arrange
      final damaged = flipped(raw, [3]);

      // Act
      final got = unpackRow(damaged, protected);

      // Assert
      expect(got.error?.kind, ErrorKind.uncorrectable);
    });

    test('the caller buffer is not written when repair succeeds or fails', () {
      // Arrange
      final fixable = flipped(raw, [3, 7]);
      final hopeless = flipped(raw, [1, 4, 6, 10, 20]);
      final before = [hex(fixable), hex(hopeless)];

      // Act
      unpackRowRepair(fixable, protected, 4);
      unpackRowRepair(hopeless, protected, 4);

      // Assert
      expect([hex(fixable), hex(hopeless)], before);
    });

    test('a wrong type byte is repaired before the handler is picked', () {
      // Arrange
      final seen = <Row>[];
      final handler = protected.on(seen.add);
      final damaged = flipped(raw, [0, 2]);

      // Act
      final got = unpackRepair(damaged, [handler], 4);

      // Assert
      expect(got.repaired, 2);
      expect(seen.length, 1);
      expect(sameRow(seen.single), isTrue);
    });

    test('a refused repair calls no handler', () {
      // Arrange
      var calls = 0;
      final handler = protected.on((row) => calls++);

      // Act
      final got = unpackRepair(flipped(raw, [1, 4, 6, 10, 20]), [handler], 4);

      // Assert
      expect(got.error?.kind, ErrorKind.uncorrectable);
      expect(calls, 0);
    });

    test('a typed row scheme packs and repairs', () {
      // Arrange
      final typed = positionScheme().withParity(4);
      final packed = pack(typed, goldenPosition());

      // Act
      final got = unpackRowRepair(flipped(packed, [4]), typed, 2);

      // Assert
      expect(got.row?.lat, 500000000);
      expect(got.repaired, 1);
    });

    test('the unprotected bytes are the first bytes of the protected ones', () {
      // Act
      final clear = pack(base, goldenMap());

      // Assert
      expect(hex(raw.sublist(0, clear.length)), hex(clear));
      expect(raw.length, clear.length + 8);
    });

    test('a protected message cut or extended is refused', () {
      // Arrange
      final longer = Uint8List.fromList([...raw, 0]);
      final shorter = Uint8List.sublistView(raw, 0, raw.length - 1);

      // Act
      final a = unpackRowRepair(longer, protected, 4);
      final b = unpackRowRepair(shorter, protected, 4);

      // Assert
      expect(a.error?.kind, ErrorKind.uncorrectable);
      expect(b.error?.kind, ErrorKind.uncorrectable);
    });

    test('a buffer shorter than n is short naming the field parity', () {
      // Act
      final got = unpackRow(Uint8List(3), protected);

      // Assert
      expect(got.error?.kind, ErrorKind.short);
      expect(got.error?.name, 'parity');
      expect(got.error?.needed, 8);
      expect(got.error?.left, 3);
    });

    test('a clean buffer of n bytes only is an empty packet', () {
      // Arrange
      final s = runScheme(1, 0).withParity(2);

      // Act
      final got = unpackRow(Uint8List(2), s);

      // Assert
      expect(got.error?.kind, ErrorKind.short);
    });

    test(
      'a valid protected message with a trailing byte is trailing_bytes',
      () {
        // Arrange
        final s = runScheme(1, 2).withParity(2);
        final longer = pack(runScheme(1, 3).withParity(2), runRow(3));

        // Act
        final got = unpackRow(longer, s);

        // Assert
        expect(got.error?.kind, ErrorKind.trailing);
        expect(got.error?.left, 1);
      },
    );
  });

  group('percentage', () {
    test('25 percent of 13 clear bytes is 4 parity bytes', () {
      // Act
      final out = pack(base.withParityPercent(25), goldenMap());

      // Assert
      expect(out.length, 13 + 4);
    });

    test('the limit is lowered to n / 2 of the message', () {
      // Arrange
      final s = base.withParityPercent(10);
      final packed = pack(s, goldenMap());
      final one = flipped(packed, [4]);
      final two = flipped(packed, [4, 6]);

      // Act
      final a = unpackRowRepair(one, s, 16);
      final b = unpackRowRepair(two, s, 16);

      // Assert
      expect(packed.length, 15);
      expect(a.repaired, 1);
      expect(b.error?.kind, ErrorKind.uncorrectable);
    });

    test('a length no message has is uncorrectable', () {
      // Arrange
      final s = base.withParityPercent(100);

      // Act
      final got = unpackRow(Uint8List(33), s);

      // Assert
      expect(got.error?.kind, ErrorKind.uncorrectable);
    });

    test('a buffer above 254 bytes is too_long and carries its length', () {
      // Arrange
      final s = base.withParityPercent(25);

      // Act
      final got = unpackRow(Uint8List(255), s);

      // Assert
      expect(got.error?.kind, ErrorKind.tooLong);
      expect(got.error?.left, 255);
    });

    test('a limit above 16 is refused before any byte is read', () {
      // Arrange
      final s = base.withParityPercent(25);

      // Act
      final e = thrown(() => unpackRowRepair(Uint8List(0), s, 17));

      // Assert
      expect(e.name, 'limit');
    });
  });
}
