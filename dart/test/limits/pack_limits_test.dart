import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/refusal.dart';
import 'limit_support.dart';

// AZ-4139 AC-1 and AC-2 (DT-5): pack refuses the same rounds and slots as
// unpack, and a packet past maxBytes, naming the member.

/// `u32 n; bytes(251) pad; times of n { bytes(256) b }`: 65,535 rounds and
/// [pad] bytes of padding make a packet of 16,777,216 - 251 + [pad] bytes.
Scheme<Row> bigPacket([int pad = 251]) => scheme(1, [
  u32(0, 'n'),
  bytes(1, 'pad', pad),
  times(2, 0, [bytes(2, 'b', 256)]),
]);

Row bigRow(int pad) => {
  'n': 65535,
  'pad': Uint8List(pad),
  'b': List<Uint8List>.filled(65535, Uint8List(256)),
};

void main() {
  group('the default byte limit (AC-1)', () {
    test('a packet of exactly 16,777,216 bytes packs and unpacks', () {
      // Arrange
      final layout = bigPacket();

      // Act
      final raw = pack(layout, bigRow(251));
      final back = unpackRow(raw, layout);

      // Assert
      expect(raw.length, 16777216);
      expect(back.ok, isTrue);
      expect((back.row!['b']! as List).length, 65535);
    });

    test(
      'one byte more is refused naming the member, and no bytes come out',
      () {
        // Arrange
        final layout = bigPacket(252);

        // Act
        final error = packRefusal(() => pack(layout, bigRow(252)));

        // Assert
        expect(error.name, 'b');
        expect(
          error.reason,
          'b: the packet would be 16777217 bytes, above the limit of 16777216 bytes',
        );
      },
    );

    test('a raised maxBytes packs the packet the default refuses', () {
      // Arrange
      final layout = bigPacket(252).withLimits(maxBytes: 16777217);

      // Act
      final raw = pack(layout, bigRow(252));
      final back = unpackRow(raw, layout);

      // Assert
      expect(raw.length, 16777217);
      expect(back.ok, isTrue);
    });
  });

  group('maxBytes', () {
    test('a packet of exactly maxBytes packs, one byte more is refused', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 's')]).withLimits(maxBytes: 64);
      final text = '中' * 20;

      // Act
      final exact = pack(layout, {'s': '${text}x'});
      final error = packRefusal(() => pack(layout, {'s': '${text}xx'}));

      // Assert
      expect(exact.length, 64);
      expect(hex(exact), '013e10${'e4b8ad' * 20}78');
      expect(
        error.reason,
        's: the packet would be 65 bytes, above the limit of 64 bytes',
      );
    });

    test('the boundary holds round by round: 63 rounds pack in 64 bytes', () {
      // Arrange
      final layout = repeatK().withLimits(maxBytes: 64);

      // Act
      final exact = pack(layout, {'k': List.filled(63, 7)});
      final error = packRefusal(() => pack(layout, {'k': List.filled(64, 7)}));

      // Assert
      expect(hex(exact), '01${'07' * 63}');
      expect(
        error.reason,
        'k: the packet would be 65 bytes, above the limit of 64 bytes',
      );
    });

    test('the type byte counts, and a flag byte or a list count is named by its member', () {
      // Arrange
      final fb = flagByte('m');
      final split = scheme(1, [fb, fb.bit(u8(0, 'c'))]).withLimits(maxBytes: 1);
      final combined = scheme(1, [
        flags(0, [u8(0, 'c')]),
      ]).withLimits(maxBytes: 1);
      final items = scheme(1, [list('xs', u8(0, 'v'))]).withLimits(maxBytes: 2);
      final single = scheme(1, [u8(0, 'a')]).withLimits(maxBytes: 1);
      final timesFirst = scheme(1, [
        u8(0, 'n'),
        flags(1, [
          times(1, 0, [u8(1, 'k')]),
        ]),
      ]).withLimits(maxBytes: 2);

      // Act
      final bare = pack(
        scheme(1, []).withLimits(maxBytes: 1),
        <String, Object?>{},
      );
      final messages = [
        packRefusal(() => pack(single, {'a': 1})).reason,
        packRefusal(() => pack(split, {'c': 1})).reason,
        packRefusal(() => pack(combined, {'c': 1})).reason,
        packRefusal(() => pack(items, {'xs': <int>[]})).reason,
        packRefusal(() => pack(timesFirst, {'n': 1, 'k': 3})).reason,
      ];

      // Assert
      expect(hex(bare), '01');
      expect(messages, [
        'a: the packet would be 2 bytes, above the limit of 1 bytes',
        'm: the packet would be 2 bytes, above the limit of 1 bytes',
        'c: the packet would be 2 bytes, above the limit of 1 bytes',
        'xs: the packet would be 3 bytes, above the limit of 2 bytes',
        'k: the packet would be 3 bytes, above the limit of 2 bytes',
      ]);
    });

    test('the refusal carries the field id and the pack error kind', () {
      // Arrange
      final layout = positionMapScheme().withLimits(maxBytes: 5);

      // Act
      final error = packRefusal(() => pack(layout, goldenMap()));

      // Assert
      expect(
        [error.kind, error.field, error.name],
        [ErrorKind.packError, 1, 'lat'],
      );
    });

    test('a limit changes no byte of a packet that fits', () {
      // Arrange
      final plain = hex(pack(positionMapScheme(), goldenMap()));
      final limited = positionMapScheme().withLimits(
        maxRounds: 2,
        maxSlots: 2,
        maxBytes: 13,
      );

      // Act
      final got = hex(pack(limited, goldenMap()));

      // Assert
      expect(got, plain);
      expect(got.length, 26);
    });

    test('maxBytes is not a limit of unpack: a longer packet is read', () {
      // Arrange
      final layout = repeatK().withLimits(maxBytes: 2);

      // Act
      final result = unpackRow(packet(10), layout);

      // Assert
      expect((result.row!['k']! as List).length, 10);
    });

    test('a raised maxBytes packs 17.8 MB and unpack reads it back', () {
      // Arrange
      final layout = scheme(1, [
        u32(0, 'n'),
        times(1, 0, [u16(1, 'len'), sized(2, 'p', 1)]),
      ]);
      final shared = Uint8List(300);
      final row = {
        'n': 65535,
        'len': 300,
        'p': List<Uint8List>.filled(65535, shared),
      };

      // Act
      final refused = packRefusal(() => pack(layout, row));
      final raw = pack(layout.withLimits(maxBytes: 33554432), row);
      final back = unpackRow(raw, layout);

      // Assert
      expect(refused.reason, contains('above the limit of 16777216 bytes'));
      expect(raw.length, 1 + 4 + 65535 * 302);
      expect((back.row!['p']! as List).length, 65535);
    });
  });

  group('maxRounds on pack', () {
    test('a times count above the limit is refused before any round, naming the member', () {
      // Arrange
      final layout = timesK().withLimits(
        maxRounds: 5,
        maxSlots: 3,
        maxBytes: 8,
      );

      // Act
      final error = packRefusal(() => pack(layout, {'n': 10, 'k': 7}));

      // Assert
      expect(
        error.reason,
        'k: the times count is 10, above the limit of 5 rounds',
      );
    });

    test('a count field is written before the round cap is checked', () {
      // Arrange
      final layout = timesK().withLimits(
        maxRounds: 5,
        maxSlots: 3,
        maxBytes: 4,
      );

      // Act
      final error = packRefusal(() => pack(layout, {'n': 10, 'k': 7}));

      // Assert
      expect(
        error.reason,
        'n: the packet would be 5 bytes, above the limit of 4 bytes',
      );
    });

    test('a times of maxRounds rounds packs, one more is refused', () {
      // Arrange
      final layout = timesK().withLimits(maxRounds: 3);

      // Act
      final raw = pack(layout, {'n': 3, 'k': 7});
      final error = packRefusal(() => pack(layout, {'n': 4, 'k': 7}));

      // Assert
      expect(hex(raw), '0103000000070707');
      expect(
        error.reason,
        contains('the times count is 4, above the limit of 3 rounds'),
      );
    });

    test(
      'a repeat list is refused naming its member, a raised limit packs it',
      () {
        // Arrange
        final layout = repeatK();
        final row = {'k': List.filled(65536, 1)};

        // Act
        final error = packRefusal(() => pack(layout, row));
        final raw = pack(layout.withLimits(maxRounds: 65536), row);
        final back = unpackRow(raw, layout.withLimits(maxRounds: 65536));

        // Assert
        expect(error.name, 'k');
        expect(
          error.reason,
          'k: the repeat count is 65536, above the limit of 65535 rounds',
        );
        expect((back.row!['k']! as List).length, 65536);
      },
    );

    test('a lowered limit lowers what packs, as it lowers what unpacks', () {
      // Arrange
      final layout = repeatK().withLimits(maxRounds: 3);

      // Act
      final raw = pack(layout, {
        'k': [1, 2, 3],
      });
      final error = packRefusal(
        () => pack(layout, {
          'k': [1, 2, 3, 4],
        }),
      );

      // Assert
      expect(unpackRow(raw, layout).ok, isTrue);
      expect(error.reason, contains('above the limit of 3 rounds'));
    });
  });

  group('maxSlots on pack', () {
    test(
      'rounds whose slots equal maxSlots pack, the next round is refused',
      () {
        // Arrange
        final layout = wide(3).withLimits(maxSlots: 9);
        Row rounds(int n) => {
          for (var i = 0; i < 3; i++) 'f$i': List.filled(n, 1),
        };

        // Act
        final raw = pack(layout, rounds(3));
        final error = packRefusal(() => pack(layout, rounds(4)));

        // Assert
        expect(unpackRow(raw, layout).ok, isTrue);
        expect(error.name, 'f0');
        expect(
          error.reason,
          'f0: the rounds would hold 12 slots, above the limit of 9 slots',
        );
      },
    );

    test('1,048,576 slots pack and unpack at the default, one round more is refused by both', () {
      // Arrange
      final layout = wide(2).withLimits(maxRounds: 1000000);
      Row rounds(int n) => {'f0': List.filled(n, 1), 'f1': List.filled(n, 2)};

      // Act
      final raw = pack(layout, rounds(524288));
      final read = unpackRow(raw, layout);
      final error = packRefusal(() => pack(layout, rounds(524289)));
      final more = pack(
        layout.withLimits(maxRounds: 1000000, maxSlots: 2000000),
        rounds(524289),
      );
      final refused = unpackRow(more, layout);

      // Assert
      expect(read.ok, isTrue);
      expect(
        error.reason,
        contains('1048578 slots, above the limit of 1048576 slots'),
      );
      expect(refused.error!.kind, ErrorKind.tooMany);
    });

    test(
      'slots are checked before bytes: the round is refused by slots first',
      () {
        // Arrange
        final layout = timesK().withLimits(maxSlots: 2, maxBytes: 7);

        // Act
        final error = packRefusal(() => pack(layout, {'n': 3, 'k': 7}));

        // Assert
        expect(
          error.reason,
          'k: the rounds would hold 3 slots, above the limit of 2 slots',
        );
      },
    );
  });
}
