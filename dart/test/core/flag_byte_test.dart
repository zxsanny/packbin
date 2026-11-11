import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

const why =
    'a value is given, but the condition or count of its when or times is not written before the flag byte, '
    'so its bit is clear; write that field before the flag byte';

/// The condition is written before the flag byte.
Scheme<Map<String, Object?>> whenBefore() {
  final m = flagByte('m');
  return scheme(1, [
    u8(0, 'mode'),
    m,
    m.bit(when(1, eq(0, 1), [u8(1, 'speed')])),
    m.bit(u16(2, 'heading')),
  ]);
}

/// The condition is written after the flag byte, so the byte cannot know it.
Scheme<Map<String, Object?>> whenAfter() {
  final m = flagByte('m');
  return scheme(1, [
    m,
    u8(0, 'mode'),
    m.bit(when(1, eq(0, 1), [u8(1, 'speed')])),
    m.bit(u16(2, 'heading')),
  ]);
}

class Split {
  int? a;
  bool? on;
  int? c;
}

void main() {
  group('flag-byte bits (split form)', () {
    test('the byte sits where it is read and its bits follow in order', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [
        m,
        u8(0, 'head'),
        m.bit(u8(1, 'a')),
        m.bit(flagBool(2, 'on')),
        m.bit(u16(3, 'c')),
      ]);
      final row = {'head': 9, 'a': 1, 'c': 2};

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row;
      final marked = pack(layout, {'head': 9, 'on': true});

      // Assert
      expect([hex(raw), hex(marked)], ['010509010200', '010209']);
      expect(back, row);
      expect(unpackRow(marked, layout).row, {'head': 9, 'on': true});
    });

    test('a typed row packs and unpacks through the split bits', () {
      // Arrange
      final m = flagByte('m');
      final layout = rowScheme(1, Split.new, [
        m,
        m.bit(u8(0, 'a').bind<Split>(get: (r) => r.a, set: (r, v) => r.a = v)),
        m.bit(
          flagBool(
            1,
            'on',
          ).bind<Split>(get: (r) => r.on, set: (r, v) => r.on = v),
        ),
        m.bit(
          be(u16(2, 'c')).bind<Split>(get: (r) => r.c, set: (r, v) => r.c = v),
        ),
      ]);
      final row = Split()
        ..on = true
        ..c = 2;

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '01060002');
      expect([back.a, back.on, back.c], [null, true, 2]);
    });

    test('be flips the number under a bit', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [m, be(m.bit(u16(0, 'n')))]);

      // Act
      final raw = pack(layout, {'n': 1});

      // Assert
      expect(hex(raw), '01010001');
    });

    test('a when whose condition is written before the byte keeps its reference bytes', () {
      // Act
      final held = pack(whenBefore(), {'mode': 1, 'speed': 7, 'heading': 90});
      final noBody = pack(whenBefore(), {'mode': 1, 'heading': 90});
      final clear = pack(whenBefore(), {'mode': 0, 'speed': 7, 'heading': 90});

      // Assert
      expect(
        [hex(held), hex(noBody), hex(clear)],
        ['010103075a00', '0101025a00', '0100025a00'],
      );
      expect(unpackRow(held, whenBefore()).row, {
        'mode': 1,
        'speed': 7,
        'heading': 90,
      });
      expect(unpackRow(clear, whenBefore()).row, {'mode': 0, 'heading': 90});
    });

    test('a when condition written after the byte, body given, is refused naming the member', () {
      // Act
      Object? thrown;
      try {
        pack(whenAfter(), {'mode': 1, 'speed': 7, 'heading': 90});
      } on PackbinException catch (e) {
        thrown = e.error;
      }

      // Assert
      expect(
        thrown,
        const PackbinError(
          ErrorKind.packError,
          field: 1,
          name: 'speed',
          reason: 'speed: $why',
        ),
      );
    });

    test(
      'a condition written after the byte with no body, or false, still packs',
      () {
        // Act
        final noBody = pack(whenAfter(), {'mode': 1, 'heading': 90});
        final falseBody = pack(whenAfter(), {
          'mode': 0,
          'speed': 7,
          'heading': 90,
        });

        // Assert
        expect([hex(noBody), hex(falseBody)], ['0102015a00', '0102005a00']);
      },
    );

    test('a short flag byte names the handle and no field id', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [u8(0, 'head'), m, m.bit(u8(1, 'a'))]);

      // Act
      final got = unpackRow(unhex('0109'), layout);

      // Assert
      expect(
        got.error,
        const PackbinError(ErrorKind.short, name: 'm', needed: 1, left: 0),
      );
    });

    test('one handle read by two schemes numbers its bits in each', () {
      // Arrange
      final m = flagByte('m');
      final first = scheme(1, [m, m.bit(u8(0, 'a'))]);
      final second = scheme(2, [m, m.bit(u8(0, 'x')), m.bit(u8(1, 'y'))]);

      // Act
      final one = pack(first, {'a': 5});
      final two = pack(second, {'y': 6});

      // Assert
      expect([hex(one), hex(two)], ['010105', '020206']);
    });
  });
}
