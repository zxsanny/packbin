import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

/// A count of the integer kind [count] (named `n`) then `sized` bytes.
Scheme<Map<String, Object?>> sizedBy(ValueField<int> count) =>
    scheme(1, [count, sized(1, 'payload', 0)]);

Uint8List bytesOf(List<int> v) => Uint8List.fromList(v);

void main() {
  group('a count from an integer source of any kind', () {
    final cases = <(String, ValueField<int>, String)>[
      ('u8', u8(0, 'n'), '0102'),
      ('u16', u16(0, 'n'), '010200'),
      ('u32', u32(0, 'n'), '0102000000'),
      ('u64', u64(0, 'n'), '010200000000000000'),
      ('i8', i8(0, 'n'), '0102'),
      ('i16', i16(0, 'n'), '010200'),
      ('i32', i32(0, 'n'), '0102000000'),
      ('i64', i64(0, 'n'), '010200000000000000'),
      ('big-endian u16', be(u16(0, 'n')), '010002'),
      ('big-endian u32', be(u32(0, 'n')), '0100000002'),
    ];
    for (final (name, source, head) in cases) {
      test('$name: a count of 2 sizes the payload both ways', () {
        // Arrange
        final layout = sizedBy(source);
        final row = {
          'n': 2,
          'payload': bytesOf([7, 8]),
        };

        // Act
        final raw = pack(layout, row);
        final back = unpackRow(raw, layout);

        // Assert
        expect(hex(raw), '${head}0708');
        expect(back.row, row);
      });
    }

    test('a u2 slot counts', () {
      // Arrange
      final layout = scheme(1, [
        u2([slot(0, 'k')]),
        sized(1, 'payload', 0),
      ]);

      // Act
      final raw = pack(layout, {
        'k': 3,
        'payload': bytesOf([1, 2, 3]),
      });

      // Assert
      expect(hex(raw), '0103010203');
      expect(unpackRow(raw, layout).row!['payload'], [1, 2, 3]);
    });
  });

  group('a count that cannot be read', () {
    test('a negative i8 count is refused with needed 0, naming the field', () {
      // Arrange
      final layout = sizedBy(i8(0, 'n'));

      // Act
      final result = unpackRow(unhex('01ff61'), layout);

      // Assert
      expect(result.row, isNull);
      expect(result.error!.kind, ErrorKind.badValue);
      expect(result.error!.name, 'payload');
    });

    test('a u64 count above 2^63 - 1 is refused, not wrapped', () {
      // Arrange
      final layout = sizedBy(u64(0, 'n'));

      // Act
      final result = unpackRow(unhex('01ffffffffffffffff61'), layout);

      // Assert
      expect(result.error!.kind, ErrorKind.badValue);
    });

    test('a u64 count of 2^63 is refused (the int is negative)', () {
      // Arrange
      final layout = sizedBy(u64(0, 'n'));

      // Act
      final result = unpackRow(unhex('010000000000000080'), layout);

      // Assert
      expect(result.error!.needed, 0);
    });

    test(
      'a u64 count of 2^62 is compared with the bytes left, no list made',
      () {
        // Arrange
        final layout = sizedBy(u64(0, 'n'));

        // Act
        final result = unpackRow(unhex('010000000000000040ab'), layout);

        // Assert
        expect(
          [result.error!.name, result.error!.needed, result.error!.left],
          ['payload', 1 << 62, 1],
        );
      },
    );

    test('a u32 count of 4294967295 is short, not allocated', () {
      // Arrange
      final layout = sizedBy(u32(0, 'n'));

      // Act
      final result = unpackRow(unhex('01ffffffff61'), layout);

      // Assert
      expect([result.error!.needed, result.error!.left], [4294967295, 1]);
    });

    test('bits and packed counts near 2^63 give a short read, no overflow', () {
      // Arrange
      final manyBits = scheme(1, [u64(0, 'n'), bits(1, 'v', 0)]);
      final manyPacked2 = scheme(1, [u64(0, 'n'), packed(2, 1, 'v', 0)]);
      final head = unhex('01ffffffffffffff7f');

      // Act
      final a = unpackRow(head, manyBits).error!;
      final b = unpackRow(head, manyPacked2).error!;

      // Assert
      expect([a.needed, a.left], [(1 << 60), 0]);
      expect([b.needed, b.left], [(1 << 61), 0]);
    });

    test(
      'a times with a count of 2^62 reads rounds until the bytes run out',
      () {
        // Arrange
        final layout = scheme(1, [
          u64(0, 'n'),
          times(1, 0, [u8(1, 'x')]),
        ]);

        // Act
        final result = unpackRow(unhex('010000000000000040010203'), layout);

        // Assert
        expect(result.row, isNull);
        expect([result.error!.name, result.error!.needed], ['x', 1]);
      },
    );
  });

  group('a bias', () {
    test('packed bias -1 reads one item fewer than the count', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n'), packed(1, 1, 'legs', 0, bias: -1)]);

      // Act
      final row = unpackRow(unhex('0109ff'), layout).row!;

      // Assert
      expect(row['legs'], [1, 1, 1, 1, 1, 1, 1, 1]);
    });

    test('a count of 0 with bias -1 cannot be read', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n'), packed(1, 1, 'legs', 0, bias: -1)]);

      // Act
      final error = unpackRow(unhex('0100'), layout).error!;

      // Assert
      expect([error.name, error.needed], ['legs', 0]);
    });

    test('pack refuses a count of 0 with bias -1, naming the field', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n'), packed(1, 1, 'legs', 0, bias: -1)]);

      // Act
      final error = packRefusal(() => pack(layout, {'n': 0, 'legs': <int>[]}));

      // Assert
      expect([error.field, error.name], [1, 'legs']);
    });

    test('pack refuses a u64 count above 2^63 - 1 and shows it unsigned', () {
      // Arrange
      final layout = sizedBy(u64(0, 'n'));

      // Act
      final error = packRefusal(
        () => pack(layout, {'n': -1, 'payload': bytesOf([])}),
      );

      // Assert
      expect(error.reason, contains('18446744073709551615'));
    });

    test('pack refuses a count that does not match the list length', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n'), bits(1, 'v', 0)]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'n': 3,
          'v': [1, 0],
        }),
      );

      // Assert
      expect(error.name, 'v');
    });
  });

  group('a count behind a clear when', () {
    Scheme<Map<String, Object?>> splitBits() {
      final m = flagByte('m');
      return scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        m,
        m.bit(bits(2, 'v', 1)),
      ]);
    }

    test('without a value, a count above 0 is refused naming the member', () {
      // Arrange
      final layout = splitBits();

      // Act
      final error = packRefusal(() => pack(layout, {'mode': 0, 'c': 3}));

      // Assert
      expect(error.name, 'v');
      expect(error.reason, contains('no field wrote it'));
    });

    test('without a value, a count of 0, no count or a holding when pack', () {
      // Arrange
      final layout = splitBits();

      // Act
      final zero = pack(layout, {'mode': 0, 'c': 0});
      final none = pack(layout, {'mode': 0});
      final holds = pack(layout, {'mode': 1, 'c': 3});

      // Assert
      expect(
        [hex(zero), hex(none), hex(holds)],
        ['010000', '010000', '01010300'],
      );
    });

    test('with a value, the clear when refuses (bits)', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        bits(2, 'v', 1),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'mode': 0,
          'c': 3,
          'v': [1, 0, 1],
        }),
      );

      // Assert
      expect([error.name, error.reason], ['v', contains('was not written')]);
    });

    test('with a value, the clear when refuses (packed and sized)', () {
      // Arrange
      final withPacked = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        packed(1, 2, 'v', 1),
      ]);
      final withSized = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        sized(2, 'v', 1),
      ]);

      // Act
      final a = packRefusal(
        () => pack(withPacked, {
          'mode': 0,
          'c': 3,
          'v': [1, 0, 1],
        }),
      );
      final b = packRefusal(
        () => pack(withSized, {
          'mode': 0,
          'c': 3,
          'v': bytesOf([1, 2, 3]),
        }),
      );

      // Assert
      expect([a.name, b.name], ['v', 'v']);
    });

    test('a times count behind a clear when is refused, naming its member', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        m,
        m.bit(times(2, 1, [u8(2, 'pt')])),
        m.bit(u16(3, 'heading')),
      ]);

      // Act
      final refused = packRefusal(
        () => pack(layout, {'mode': 0, 'c': 1, 'heading': 90}),
      );
      final none = pack(layout, {'mode': 0, 'heading': 90});
      final zero = pack(layout, {'mode': 0, 'c': 0, 'heading': 90});

      // Assert
      expect(refused.name, 'pt');
      expect([hex(none), hex(zero)], ['0100025a00', '0100025a00']);
    });

    test('a times with a count and no round leaves its bit clear', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [
        m,
        u8(0, 'n'),
        m.bit(times(1, 0, [u8(1, 'pt')])),
        m.bit(u16(2, 'heading')),
      ]);

      // Act
      final bare = pack(layout, {'n': 2, 'heading': 90});
      final empty = pack(layout, {'n': 2, 'pt': <int>[], 'heading': 90});

      // Assert
      expect([hex(bare), hex(empty)], ['0102025a00', '0102025a00']);
    });

    test('a count that is itself skipped reads as no count on unpack', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        sized(2, 'v', 1),
      ]);

      // Act
      final error = unpackRow(unhex('0100'), layout).error!;

      // Assert
      expect([error.name, error.needed], ['v', 0]);
    });
  });
}
