import 'dart:isolate';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/refusal.dart';
import 'limit_support.dart';

// AZ-4139 AC-1 to AC-3 (DT-5): the three limits are settings of a scheme.

/// The limit setting [name] of [layout]'s `withLimits` call, one at a time.
Scheme<Row> withOne(Scheme<Row> layout, String name, int value) =>
    switch (name) {
      'maxRounds' => layout.withLimits(maxRounds: value),
      'maxSlots' => layout.withLimits(maxSlots: value),
      _ => layout.withLimits(maxBytes: value),
    };

void main() {
  group('the defaults', () {
    test('a scheme has the limits of the other packages', () {
      // Arrange
      final layout = repeatK();

      // Act
      final got = [layout.maxRounds, layout.maxSlots, layout.maxBytes];

      // Assert
      expect(got, [65535, 1048576, 16777216]);
      expect([
        Scheme.defaultMaxRounds,
        Scheme.defaultMaxSlots,
        Scheme.defaultMaxBytes,
      ], got);
    });
  });

  group('withLimits', () {
    test('returns a copy and leaves the scheme as it was', () {
      // Arrange
      final base = repeatK();

      // Act
      final lowered = base.withLimits(maxRounds: 3, maxSlots: 9, maxBytes: 64);

      // Assert
      expect(
        [lowered.maxRounds, lowered.maxSlots, lowered.maxBytes],
        [3, 9, 64],
      );
      expect(
        [base.maxRounds, base.maxSlots, base.maxBytes],
        [65535, 1048576, 16777216],
      );
      expect(lowered.typeNumber, base.typeNumber);
      expect(identical(lowered, base), isFalse);
    });

    test('a limit left out takes its default, not the value of the scheme', () {
      // Arrange
      final base = repeatK().withLimits(maxRounds: 3, maxBytes: 64);

      // Act
      final again = base.withLimits(maxSlots: 9);

      // Assert
      expect(
        [again.maxRounds, again.maxSlots, again.maxBytes],
        [65535, 9, 16777216],
      );
      expect(base.withLimits().maxBytes, 16777216);
    });

    for (final name in ['maxRounds', 'maxSlots', 'maxBytes']) {
      for (final bad in [0, -1, -9223372036854775808]) {
        test('$name: $bad is refused when it is set, naming $name', () {
          // Arrange
          final base = repeatK();

          // Act
          final error = refusal(() => withOne(base, name, bad));

          // Assert
          expect(error.name, name);
          expect(error.field, isNull);
          expect(
            error.reason,
            startsWith('$name: expected a positive integer'),
          );
          expect(error.reason, contains('$bad'));
        });
      }

      test('$name: 1 and the largest int are accepted', () {
        // Arrange
        final base = repeatK();

        // Act
        final one = withOne(base, name, 1);
        final most = withOne(base, name, 9223372036854775807);

        // Assert
        final read = {
          'maxRounds': [one.maxRounds, most.maxRounds],
          'maxSlots': [one.maxSlots, most.maxSlots],
          'maxBytes': [one.maxBytes, most.maxBytes],
        }[name];
        expect(read, [1, 9223372036854775807]);
      });
    }

    test('a limit of 0 is refused, so no scheme reads or writes 0 rounds', () {
      // Arrange
      final base = repeatK();

      // Act
      final rounds = refusal(() => base.withLimits(maxRounds: 0));
      final slots = refusal(() => base.withLimits(maxSlots: 0));
      final bytes = refusal(() => base.withLimits(maxBytes: 0));

      // Assert
      expect(
        [rounds.kind, slots.kind, bytes.kind],
        [ErrorKind.schemeError, ErrorKind.schemeError, ErrorKind.schemeError],
      );
      expect(
        [rounds.name, slots.name, bytes.name],
        ['maxRounds', 'maxSlots', 'maxBytes'],
      );
    });

    test('the largest int raises a limit: 65,536 rounds are read', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 9223372036854775807);

      // Act
      final result = unpackRow(packet(65536), layout);

      // Assert
      expect((result.row!['k']! as List).length, 65536);
    });
  });

  group('the parity setting and the limits live in one scheme', () {
    test('withLimits keeps a parity count and a percentage', () {
      // Arrange
      final base = positionMapScheme();

      // Act
      final count = base.withParity(6).withLimits(maxBytes: 64);
      final percent = base.withParityPercent(25).withLimits(maxRounds: 3);

      // Assert
      expect([count.parity, count.parityPercent], [6, 0]);
      expect([percent.parity, percent.parityPercent], [0, 25]);
    });

    test('the parity setters keep the limits', () {
      // Arrange
      final limited = repeatK().withLimits(
        maxRounds: 3,
        maxSlots: 9,
        maxBytes: 64,
      );

      // Act
      final copies = [
        limited.withParity(4),
        limited.withParityPercent(10),
        limited.withParitySettings(parity: 2),
        limited.withParitySettings(parityPercent: 20),
        limited.withParitySettings(),
      ];

      // Assert
      for (final copy in copies) {
        expect([copy.maxRounds, copy.maxSlots, copy.maxBytes], [3, 9, 64]);
      }
    });

    test('a protected scheme packs and unpacks under its limits', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 3).withParity(4);
      final raised = repeatK().withLimits(maxRounds: 100).withParity(4);
      final three = pack(layout, {
        'k': [1, 2, 3],
      });
      final four = pack(raised, {
        'k': [1, 2, 3, 4],
      });

      // Act
      final ok = unpackRow(three, layout);
      final over = unpackRow(four, layout);
      final tooLong = packRefusal(
        () => pack(layout, {
          'k': [1, 2, 3, 4],
        }),
      );

      // Assert
      expect(three.length, 1 + 3 + 4);
      expect(ok.row, {
        'k': [1, 2, 3],
      });
      expect(over.error!.kind, ErrorKind.tooMany);
      expect(tooLong.reason, contains('above the limit of 3 rounds'));
    });
  });

  group('a limited scheme is immutable', () {
    test('another isolate reads it with the same limits', () async {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 3);
      final good = packet(3);
      final bad = packet(4);

      // Act
      final kinds = await Future.wait([
        for (var i = 0; i < 4; i++)
          Isolate.run(
            () => [
              unpackRow(good, layout).ok,
              unpackRow(bad, layout).error?.kind,
              pack(layout, {
                'k': [1, 2, 3],
              }).length,
            ],
          ),
      ]);

      // Assert
      for (final got in kinds) {
        expect(got, [true, ErrorKind.tooMany, 4]);
      }
    });

    test(
      'the limited copy and the scheme it came from do not affect each other',
      () {
        // Arrange
        final base = positionMapScheme();
        final copy = base.withLimits(maxBytes: 5);

        // Act
        final fine = pack(base, goldenMap());
        final error = packRefusal(() => pack(copy, goldenMap()));

        // Assert
        expect(hex(fine), startsWith('4001000065cd1d00'));
        expect(error.name, 'lat');
      },
    );
  });
}
