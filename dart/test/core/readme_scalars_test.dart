import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

/// Packs [row], checks the README hex, unpacks it and checks the row again.
void bothWays(
  Scheme<Map<String, Object?>> layout,
  Map<String, Object?> row,
  String wire,
) {
  // Act
  final raw = pack(layout, row);
  final back = unpackRow(unhex(wire), layout);

  // Assert
  expect(hex(raw), wire.replaceAll(' ', ''));
  expect(back.error, isNull);
  expect(back.row, row);
}

void main() {
  group('AC-2 README data types', () {
    test('integers: u16 1 and i16 -2 are 01 00 fe ff', () {
      // Arrange
      final layout = scheme(1, [u16(0, 'n'), i16(1, 'd')]);

      // Act, Assert
      bothWays(layout, {'n': 1, 'd': -2}, '01 01 00 fe ff');
    });

    test('integers: every width at its bounds', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'a'),
        i8(1, 'b'),
        u16(2, 'c'),
        i16(3, 'd'),
        u32(4, 'e'),
        i32(5, 'f'),
        u64(6, 'g'),
        i64(7, 'h'),
      ]);
      final row = {
        'a': 255,
        'b': -128,
        'c': 65535,
        'd': -32768,
        'e': 4294967295,
        'f': -2147483648,
        'g': 9223372036854775807,
        'h': -9223372036854775808,
      };

      // Act, Assert
      bothWays(
        layout,
        row,
        '01 ff 80 ffff 0080 ffffffff 00000080 ffffffffffffff7f 0000000000000080',
      );
    });

    test('floats: f32 1.5 is 00 00 c0 3f', () {
      // Arrange
      final layout = scheme(1, [f32(0, 'x')]);

      // Act, Assert
      bothWays(layout, {'x': 1.5}, '01 00 00 c0 3f');
    });

    test('floats: f64 1.5 is the same layout in eight bytes', () {
      // Arrange
      final layout = scheme(1, [f64(0, 'x')]);

      // Act, Assert
      bothWays(layout, {'x': 1.5}, '01 00 00 00 00 00 00 f8 3f');
    });

    test('floats: an int is taken for a float field', () {
      // Arrange
      final layout = scheme(1, [f32(0, 'x')]);

      // Act
      final raw = pack(layout, {'x': 2});

      // Assert
      expect(hex(raw), '0100000040');
    });

    test('floats: NaN and the infinities are written as given', () {
      // Arrange
      final layout = scheme(1, [f32(0, 'a'), f32(1, 'b'), f64(2, 'c')]);

      // Act
      final raw = pack(layout, {
        'a': double.infinity,
        'b': double.negativeInfinity,
        'c': double.nan,
      });
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw).substring(0, 18), '010000807f000080ff');
      expect(back['a'], double.infinity);
      expect(back['b'], double.negativeInfinity);
      expect((back['c']! as double).isNaN, isTrue);
    });

    test('fixed bytes: abc with n = 3 is the three characters', () {
      // Arrange
      final layout = scheme(1, [bytes(0, 'b', 3)]);

      // Act, Assert
      bothWays(layout, {
        'b': Uint8List.fromList([0x61, 0x62, 0x63]),
      }, '01 61 62 63');
    });

    test('fixed bytes: unpack gives a copy, not a view of the packet', () {
      // Arrange
      final layout = scheme(1, [bytes(0, 'b', 3)]);
      final wire = unhex('01616263');

      // Act
      final got = unpackRow(wire, layout).row!['b']! as Uint8List;
      wire[1] = 0;

      // Assert
      expect(got, [0x61, 0x62, 0x63]);
    });

    test('big-endian: u16 1 becomes 00 01', () {
      // Arrange
      final layout = scheme(1, [be(u16(0, 'n'))]);

      // Act, Assert
      bothWays(layout, {'n': 1}, '01 00 01');
    });

    test('big-endian: one number flips, the rest stays little-endian', () {
      // Arrange
      final layout = scheme(1, [
        be(u32(0, 'a')),
        u32(1, 'b'),
        be(f32(2, 'x')),
        be(i64(3, 'd')),
      ]);

      // Act, Assert
      bothWays(layout, {
        'a': 1,
        'b': 1,
        'x': 1.5,
        'd': -2,
      }, '01 00000001 01000000 3fc00000 fffffffffffffffe');
    });

    test('flags: heading 90 sets bit 0 and speed stays clear', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [u16(0, 'heading'), u8(1, 'speed')]),
      ]);

      // Act, Assert
      bothWays(layout, {'heading': 90}, '01 01 5a 00');
    });

    test('bool: bit 0 is the bool and bit 1 a u8 of 7', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [flagBool(0, 'on'), u8(1, 'n')]),
      ]);

      // Act, Assert
      bothWays(layout, {'on': true, 'n': 7}, '01 03 07');
    });

    test('bool: false leaves the bit clear and unpack gives no key', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [flagBool(0, 'on'), u8(1, 'n')]),
      ]);

      // Act
      final raw = pack(layout, {'on': false, 'n': 7});
      final back = unpackRow(raw, layout).row;

      // Assert
      expect(hex(raw), '010207');
      expect(back, {'n': 7});
    });

    test('when: profile 0 writes the shape', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'profile'),
        when(1, eq(0, 0), [u8(1, 'shape')]),
      ]);

      // Act, Assert
      bothWays(layout, {'profile': 0, 'shape': 9}, '01 00 09');
    });

    test('when: profile 1 is 01 01 and the shape given is not written', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'profile'),
        when(1, eq(0, 0), [u8(1, 'shape')]),
      ]);

      // Act
      final raw = pack(layout, {'profile': 1, 'shape': 9});
      final back = unpackRow(raw, layout).row;

      // Assert
      expect(hex(raw), '0101');
      expect(back, {'profile': 1});
    });

    test('when: a bool source matches only when its bit is set', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [flagBool(0, 'on')]),
        when(1, eq(0, true), [u8(1, 'n')]),
      ]);

      // Act
      final set = pack(layout, {'on': true, 'n': 7});
      final clear = pack(layout, {'n': 7});

      // Assert
      expect([hex(set), hex(clear)], ['010107', '0100']);
      expect(unpackRow(set, layout).row, {'on': true, 'n': 7});
    });

    test('when: a source inside a when that is clear is absent', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'kind')]),
        when(2, eq(1, 5), [u8(2, 'v')]),
      ]);

      // Act
      final skipped = pack(layout, {'mode': 0, 'kind': 5, 'v': 9});
      final held = pack(layout, {'mode': 1, 'kind': 5, 'v': 9});

      // Assert
      expect([hex(skipped), hex(held)], ['0100', '01010509']);
      expect(unpackRow(held, layout).row, {'mode': 1, 'kind': 5, 'v': 9});
    });

    test('when under flags sees the member written before it', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [
          u8(0, 'mode'),
          when(1, eq(0, 2), [u16(1, 'extra')]),
        ]),
      ]);

      // Act
      final both = pack(layout, {'mode': 2, 'extra': 258});
      final other = pack(layout, {'mode': 3, 'extra': 258});

      // Assert
      expect([hex(both), hex(other)], ['0103020201', '010103']);
      expect(unpackRow(both, layout).row, {'mode': 2, 'extra': 258});
    });

    test('flags directly inside flags', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [
          flags(0, [u8(0, 'c')]),
        ]),
      ]);

      // Act
      final given = pack(layout, {'c': 2});
      final absent = pack(layout, <String, Object?>{});

      // Assert
      expect([hex(given), hex(absent)], ['01010102', '0100']);
      expect(unpackRow(given, layout).row, {'c': 2});
    });
  });
}
