import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import 'scheme_support.dart';
import 'vectors.dart';

// AZ-4140 AC-4 and AC-5 (DT-18): the off values, the refusals and the
// reliability of unpack under parity.

void main() {
  final base = positionMapScheme();
  final protected = base.withParity(8);
  final raw = pack(protected, goldenMap());

  group('AC-4 off values', () {
    test('parity 0 and percentage 0 write the bytes of the plain scheme', () {
      // Arrange
      final plain = hex(pack(base, goldenMap()));

      // Act
      final zero = pack(base.withParity(4).withParity(0), goldenMap());
      final percent = pack(
        base.withParityPercent(25).withParityPercent(0),
        goldenMap(),
      );

      // Assert
      expect(hex(zero), plain);
      expect(hex(percent), plain);
      expect(zero.length, 13);
    });

    test('with parity 0 the 254-byte bound does not apply', () {
      // Arrange
      final big = runScheme(1, 999);

      // Act
      final out = pack(big.withParity(0), runRow(999));
      final percent = pack(big.withParityPercent(0), runRow(999));
      final back = unpackRow(out, big.withParity(0));

      // Assert
      expect(out.length, 1000);
      expect(percent.length, 1000);
      expect(back.ok, isTrue);
      expect(back.repaired, 0);
    });

    test('a scheme with no setting has parity 0 and percentage 0', () {
      // Assert
      expect([base.parity, base.parityPercent], [0, 0]);
    });

    test('unpack of an unprotected packet with limit 0 is unchanged', () {
      // Arrange
      final clear = pack(base, goldenMap());

      // Act
      final got = unpackRowRepair(clear, base, 0);

      // Assert
      expect(got.ok, isTrue);
      expect(got.repaired, 0);
    });

    test('a limit above 0 on a scheme with no parity is refused', () {
      // Act
      final e = thrown(() => unpackRowRepair(Uint8List(0), base, 1));

      // Assert
      expect(e.name, 'limit');
    });

    test('the setters replace each other: the last one wins', () {
      // Act
      final a = base.withParity(4).withParityPercent(10);
      final b = base.withParityPercent(10).withParity(4);

      // Assert
      expect([a.parity, a.parityPercent], [0, 10]);
      expect([b.parity, b.parityPercent], [4, 0]);
    });

    test('one declaration of both settings is refused when it is made', () {
      // Act
      final both = thrown(
        () => base.withParitySettings(parity: 4, parityPercent: 10),
      );

      // Assert
      expect(both.kind, ErrorKind.schemeError);
      expect(both.name, 'parity');
    });

    test('a declaration with neither setting keeps the scheme as it is', () {
      // Arrange
      final counted = base.withParity(4);
      final percent = base.withParityPercent(10);

      // Act
      final keepCount = counted.withParitySettings();
      final keepPercent = percent.withParitySettings();

      // Assert
      expect([keepCount.parity, keepCount.parityPercent], [4, 0]);
      expect([keepPercent.parity, keepPercent.parityPercent], [0, 10]);
    });

    test('a declaration replaces both settings; the one not given is 0', () {
      // Arrange
      final counted = base.withParity(4);

      // Act
      final swap = counted.withParitySettings(parityPercent: 10);
      final back = swap.withParitySettings(parity: 4, parityPercent: 0);
      final off = swap.withParitySettings(parity: 0);

      // Assert
      expect([swap.parity, swap.parityPercent], [0, 10]);
      expect([back.parity, back.parityPercent], [4, 0]);
      expect([off.parity, off.parityPercent], [0, 0]);
    });

    test('a setter returns a copy and leaves the scheme as it was', () {
      // Arrange
      final s = base.withParity(4);

      // Act
      final t = s.withParity(8);

      // Assert
      expect([s.parity, t.parity, base.parity], [4, 8, 0]);
      expect(t.typeNumber, base.typeNumber);
    });
  });

  group('AC-5 out of range', () {
    test('parity 33 and -1 are refused when set, naming parity', () {
      // Act
      final high = thrown(() => base.withParity(33));
      final low = thrown(() => base.withParity(-1));

      // Assert
      expect(high.kind, ErrorKind.schemeError);
      expect(high.name, 'parity');
      expect(high.reason, contains('33'));
      expect(low.name, 'parity');
      expect(low.reason, contains('32'));
    });

    test('percentage 101 and -1 are refused when set, naming parity', () {
      // Act
      final high = thrown(() => base.withParityPercent(101));
      final low = thrown(() => base.withParityPercent(-1));

      // Assert
      expect(high.kind, ErrorKind.schemeError);
      expect(high.name, 'parity');
      expect(high.reason, contains('101'));
      expect(low.reason, contains('100'));
    });

    test(
      'a limit above n / 2 or below 0 is refused before any byte is read',
      () {
        // Act
        final high = thrown(() => unpackRowRepair(Uint8List(0), protected, 5));
        final low = thrown(() => unpackRowRepair(Uint8List(0), protected, -1));
        final handlers = thrown(
          () => unpackRepair(Uint8List(0), [protected.on((r) {})], 5),
        );

        // Assert
        expect([high.name, low.name, handlers.name], everyElement('limit'));
        expect(high.kind, ErrorKind.schemeError);
      },
    );

    test('handlers that mix a count and a percentage are refused', () {
      // Arrange
      final a = runScheme(1, 1).withParity(4).on((r) {});
      final b = runScheme(2, 1).withParityPercent(10).on((r) {});

      // Act
      final e = thrown(() => unpack(Uint8List(0), [a, b]));

      // Assert
      expect(e.kind, ErrorKind.schemeError);
      expect(e.name, 'parity');
      expect(
        e.reason,
        allOf(contains('4 parity bytes'), contains('10 percent')),
      );
    });

    test('handlers with two counts or two percentages are refused', () {
      // Arrange
      final a = runScheme(1, 1);
      final b = runScheme(2, 1);

      // Act
      final counts = thrown(
        () => unpack(Uint8List(0), [
          a.withParity(2).on((r) {}),
          b.withParity(4).on((r) {}),
        ]),
      );
      final percents = thrown(
        () => unpack(Uint8List(0), [
          a.withParityPercent(2).on((r) {}),
          b.withParityPercent(4).on((r) {}),
        ]),
      );

      // Assert
      expect(
        counts.reason,
        allOf(contains('2 parity bytes'), contains('4 parity bytes')),
      );
      expect(
        percents.reason,
        allOf(contains('2 percent'), contains('4 percent')),
      );
    });

    test('handlers with the same setting are accepted', () {
      // Arrange
      final a = runScheme(1, 1).withParity(4);
      final b = runScheme(2, 2).withParity(4);
      final seen = <int>[];
      final msg = pack(b, {
        'raw': Uint8List.fromList([7, 8]),
      });

      // Act
      final got = unpack(msg, [
        a.on((r) => seen.add(1)),
        b.on((r) => seen.add(2)),
      ]);

      // Assert
      expect(got.ok, isTrue);
      expect(seen, [2]);
    });

    test(
      'an empty handler list and a duplicate type number are refused first',
      () {
        // Arrange
        final a = runScheme(1, 1).withParity(4);

        // Act
        final empty = thrown(() => unpack(Uint8List(0), []));
        final dup = thrown(
          () => unpack(Uint8List(0), [
            a.on((r) {}),
            runScheme(1, 2).withParity(2).on((r) {}),
          ]),
        );

        // Assert
        expect(empty.kind, ErrorKind.schemeError);
        expect(dup.reason, contains('duplicate'));
      },
    );

    test('a clear message of 255 bytes with parity is too_long at pack', () {
      // Arrange
      final s = runScheme(1, 254).withParity(1);

      // Act
      final e = thrown(() => pack(s, runRow(254)));

      // Assert
      expect(e.kind, ErrorKind.tooLong);
      expect(e.reason, allOf(contains('255'), contains('253')));
    });

    test('the largest message fits: 254 bytes with parity', () {
      // Arrange
      final one = runScheme(1, 252).withParity(1);
      final many = runScheme(1, 221).withParity(32);

      // Act
      final a = pack(one, runRow(252));
      final b = pack(many, runRow(221));

      // Assert
      expect([a.length, b.length], [254, 254]);
      expect(unpackRow(a, one).ok, isTrue);
      expect(unpackRow(b, many).ok, isTrue);
    });

    test('a buffer above 254 bytes is too_long at unpack', () {
      // Act
      final got = unpackRow(Uint8List(255), protected);

      // Assert
      expect(got.error?.kind, ErrorKind.tooLong);
      expect(got.error?.left, 255);
      expect(got.row, isNull);
    });

    test('a failed pack throws and returns no bytes under a percentage', () {
      // Arrange
      final s = runScheme(1, 251).withParityPercent(25);

      // Act
      final e = thrown(() => pack(s, runRow(251)));

      // Assert
      expect(e.kind, ErrorKind.tooLong);
    });
  });

  group('reliability', () {
    test(
      'seeded random buffers never throw, under a count and a percentage',
      () {
        // Arrange
        final random = Random(40);
        final settings = [
          (base.withParity(8), 4),
          (base.withParity(32), 16),
          (base.withParityPercent(25), 16),
          (base.withParityPercent(100), 16),
          (base.withParity(1), 0),
        ];
        var checked = 0;

        // Act
        for (var i = 0; i < 6000; i++) {
          final bytes = Uint8List(random.nextInt(300));
          for (var k = 0; k < bytes.length; k++) {
            bytes[k] = random.nextInt(256);
          }
          if (bytes.isNotEmpty && random.nextBool()) bytes[0] = 0x40;
          for (final (s, t) in settings) {
            final got = unpackRowRepair(bytes, s, t);
            checked++;
            expect(got.row != null && got.error != null, isFalse);
          }
        }

        // Assert
        expect(checked, 30000);
      },
    );

    test('up to 4 seeded flips under n = 8 always repair to the same row', () {
      // Arrange
      final random = Random(7);
      var wrong = 0;

      // Act
      for (var i = 0; i < 500; i++) {
        final flips = 1 + random.nextInt(4);
        final places = <int>{};
        while (places.length < flips) {
          places.add(random.nextInt(raw.length));
        }
        final copy = Uint8List.fromList(raw);
        for (final at in places) {
          copy[at] ^= 1 + random.nextInt(255);
        }
        final got = unpackRowRepair(copy, protected, 4);
        if (!sameRow(got.row) || got.repaired != flips) wrong++;
      }

      // Assert
      expect(wrong, 0);
    });

    test('a protected scheme works in other isolates', () async {
      // Arrange
      final s = protected;
      final damaged = flipped(raw, [2, 8]);

      // Act
      final repaired = await Future.wait([
        for (var i = 0; i < 3; i++)
          Isolate.run(() => unpackRowRepair(damaged, s, 4).repaired),
      ]);
      final bytes = await Isolate.run(() => pack(s, goldenMap()));

      // Assert
      expect(repaired, [2, 2, 2]);
      expect(hex(bytes), hex(raw));
    });
  });
}
