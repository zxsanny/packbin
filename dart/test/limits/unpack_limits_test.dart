import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/repo.dart';
import 'limit_support.dart';

// AZ-4139 AC-1 and AC-2 (DT-5): unpack refuses a round past a limit when it
// would start, with too_many and needed 0, and the limits are the scheme's.

/// The packet hex of the case [id] in fixtures/hostile/cases.txt.
String caseHex(String id) {
  for (final line in repoText('fixtures/hostile/cases.txt').split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 4 && parts[0] == id && parts[1] == 'limit') {
      return parts[3];
    }
  }
  fail('no limit case $id');
}

/// `[kind, needed, left, name]` of the error of [result].
List<Object?> shape(Unpacked<Row> result) {
  final e = result.error!;
  return [e.kind, e.needed, e.left, e.name];
}

void main() {
  group('the default limits (AC-1)', () {
    test('65,535 rounds are read and the 65,536th is refused, 1 byte left', () {
      // Arrange
      final layout = repeatK();

      // Act
      final at = unpackRow(packet(65535), layout);
      final past = unpackRow(packet(65536), layout);

      // Assert
      expect((at.row!['k']! as List).length, 65535);
      expect(past.row, isNull);
      expect(shape(past), [ErrorKind.tooMany, 0, 1, 'k']);
    });

    test('a times of 65,535 rounds is read and its 65,536th is refused', () {
      // Arrange
      final layout = timesK();
      Uint8List raw(int count) =>
          (BytesBuilder()
                ..add([1, count & 255, (count >> 8) & 255, count >> 16, 0])
                ..add(Uint8List(count)))
              .toBytes();

      // Act
      final at = unpackRow(raw(65535), layout);
      final past = unpackRow(raw(65536), layout);

      // Assert
      expect(at.ok, isTrue);
      expect(shape(past), [ErrorKind.tooMany, 0, 1, 'k']);
    });

    test(
      'rounds that hold exactly 1,048,576 slots are read, one more is refused',
      () {
        // Arrange
        final layout = wide(2).withLimits(maxRounds: 1000000);

        // Act
        final at = unpackRow(packet(2 * 524288), layout);
        final past = unpackRow(packet(2 * 524289), layout);

        // Assert
        expect(roundEntries(at.row!), 1048576);
        expect(past.error!.kind, ErrorKind.tooMany);
        expect(past.error!.needed, 0);
        expect(
          past.error!.reason,
          contains('1048578 slots, above the limit of 1048576 slots'),
        );
      },
    );

    test('the refusal names the first member of the round and its id', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [u8(0, 'a'), u8(1, 'b')]),
      ]);

      // Act
      final error = unpackRow(packet(2 * 65536), layout).error!;

      // Assert
      expect([error.field, error.name], [0, 'a']);
      expect(
        error.reason,
        startsWith('a: round 65536 is above the limit of 65535 rounds'),
      );
    });
  });

  group('maxRounds (AC-2)', () {
    for (final id in ['repeat_rounds_over_limit', 'times_rounds_over_limit']) {
      test('$id with maxRounds 3 is too_many, needed 0, 1 byte left', () {
        // Arrange
        final layout = id.startsWith('repeat')
            ? scheme(1, [
                repeat(0, [u8(0, 'v')]),
              ])
            : scheme(1, [
                u8(0, 'n'),
                times(1, 0, [u8(1, 'v')]),
              ]);

        // Act
        final lowered = unpackRow(
          unhex(caseHex(id)),
          layout.withLimits(maxRounds: 3),
        );
        final plain = unpackRow(unhex(caseHex(id)), layout);

        // Assert
        expect(lowered.row, isNull);
        expect(shape(lowered), [ErrorKind.tooMany, 0, 1, 'v']);
        expect(plain.ok, isTrue);
      });
    }

    test('a repeat reads exactly maxRounds rounds and refuses one more', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 3);

      // Act
      final at = unpackRow(packet(3, 9), layout);
      final past = unpackRow(packet(4, 9), layout);

      // Assert
      expect(at.row, {
        'k': [9, 9, 9],
      });
      expect(shape(past), [ErrorKind.tooMany, 0, 1, 'k']);
    });

    test('a count of maxRounds is read, a count one above is refused at its last round', () {
      // Arrange
      final layout = timesK().withLimits(maxRounds: 3);

      // Act
      final at = unpackRow(unhex('01 03000000 070707'), layout);
      final past = unpackRow(unhex('01 04000000 07070707'), layout);

      // Assert
      expect(at.row, {
        'n': 3,
        'k': [7, 7, 7],
      });
      expect(shape(past), [ErrorKind.tooMany, 0, 1, 'k']);
    });

    test('a huge count with too few rounds keeps its short read', () {
      // Arrange
      final layout = timesK().withLimits(maxRounds: 3);

      // Act
      final result = unpackRow(unhex('01 ffffffff 07'), layout);

      // Assert
      expect(result.error!.kind, ErrorKind.short);
    });

    test('a raised limit reads the packet the default refuses', () {
      // Arrange
      final worst = packet(65536);
      final raised = repeatK().withLimits(maxRounds: 70000);

      // Act
      final refused = unpackRow(worst, repeatK());
      final read = unpackRow(worst, raised);

      // Assert
      expect(refused.error!.kind, ErrorKind.tooMany);
      expect((read.row!['k']! as List).length, 65536);
    });

    test('maxRounds 1 reads one round', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 1);

      // Act
      final one = unpackRow(packet(1), layout);
      final two = unpackRow(packet(2), layout);

      // Assert
      expect(one.ok, isTrue);
      expect(two.error!.kind, ErrorKind.tooMany);
    });
  });

  group('maxSlots (AC-2)', () {
    test(
      'rounds whose slots equal maxSlots are read, the next round is refused',
      () {
        // Arrange
        final layout = wide(3).withLimits(maxSlots: 9);

        // Act
        final at = unpackRow(packet(9), layout);
        final past = unpackRow(packet(12), layout);

        // Assert
        expect(roundEntries(at.row!), 9);
        expect(past.error!.kind, ErrorKind.tooMany);
        expect(past.error!.needed, 0);
        expect(past.error!.left, 3);
        expect(
          past.error!.reason,
          contains('12 slots, above the limit of 9 slots'),
        );
      },
    );

    test('a lowered limit refuses what the default reads and a raised one reads it again', () {
      // Arrange
      final bytes = packet(2 * 100);

      // Act
      final lowered = unpackRow(bytes, wide(2).withLimits(maxSlots: 199));
      final default_ = unpackRow(bytes, wide(2));
      final raised = unpackRow(bytes, wide(2).withLimits(maxSlots: 200));

      // Assert
      expect(lowered.error!.kind, ErrorKind.tooMany);
      expect(default_.ok, isTrue);
      expect(raised.ok, isTrue);
    });

    test('one counter covers every round field of one call', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        u8(1, 'm'),
        times(2, 0, [u8(2, 'a')]),
        times(3, 1, [u8(3, 'b')]),
      ]).withLimits(maxSlots: 3);

      // Act
      final fits = unpackRow(unhex('01 02 01 0a0b 0c'), layout);
      final over = unpackRow(unhex('01 02 02 0a0b 0c0d'), layout);

      // Assert
      expect(fits.row, {
        'n': 2,
        'm': 1,
        'a': [10, 11],
        'b': [12],
      });
      expect(over.error!.kind, ErrorKind.tooMany);
      expect(over.error!.name, 'b');
      expect(over.error!.left, 1);
    });

    test('rounds in the items of a list share the one counter', () {
      // Arrange
      final layout = scheme(1, [
        list(
          'items',
          nested('item', [
            u8(0, 'n'),
            times(1, 0, [u8(1, 'v')]),
          ]),
        ),
      ]).withLimits(maxSlots: 3);

      // Act
      final fits = unpackRow(unhex('01 0200 02 0102 01 03'), layout);
      final over = unpackRow(unhex('01 0200 02 0102 02 0304'), layout);

      // Assert
      expect(fits.ok, isTrue);
      expect(over.error!.kind, ErrorKind.tooMany);
      expect(over.error!.name, 'v');
    });
  });

  group('the limits belong to the scheme that reads the packet', () {
    test('unpack with several handlers uses the matched scheme\'s limits', () {
      // Arrange
      final low = repeatK().withLimits(maxRounds: 3);
      final high = scheme(2, [
        repeat(0, [u8(0, 'k')]),
      ]);
      final seen = <Row>[];
      final handlers = [low.on(seen.add), high.on(seen.add)];
      final four = Uint8List.fromList([1, 1, 2, 3, 4]);
      final fourToHigh = Uint8List.fromList([2, 1, 2, 3, 4]);

      // Act
      final refused = unpack(four, handlers);
      final read = unpack(fourToHigh, handlers);

      // Assert
      expect(refused.error!.kind, ErrorKind.tooMany);
      expect(read.ok, isTrue);
      expect(seen, [
        {
          'k': [1, 2, 3, 4],
        },
      ]);
    });

    test('an error value never calls the handler and gives no row', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 3);
      var calls = 0;

      // Act
      final result = unpack(packet(4), [layout.on((_) => calls++)]);

      // Assert
      expect([result.row, calls], [null, 0]);
    });

    test('a typed round is limited the same way', () {
      // Arrange
      final layout = rowScheme<Track>(1, Track.new, [
        repeat(0, [
          u8(0, 'k').bind<Dot>(get: (r) => r.k, set: (r, v) => r.k = v),
        ]).bind<Track, Dot>(
          create: Dot.new,
          get: (r) => r.dots,
          set: (r, v) => r.dots = v,
        ),
      ]);
      final bytes = unhex('01 01 02 03 04');

      // Act
      final lowered = unpackRow(bytes, layout.withLimits(maxRounds: 3));
      final plain = unpackRow(bytes, layout);

      // Assert
      expect(lowered.error!.kind, ErrorKind.tooMany);
      expect(plain.row!.dots!.length, 4);
    });
  });
}

class Dot {
  int? k;
}

class Track {
  List<Dot>? dots;
}
