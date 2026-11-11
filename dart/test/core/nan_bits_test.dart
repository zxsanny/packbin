import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

double _nan32(int bits) => (ByteData(4)..setUint32(0, bits)).getFloat32(0);

double _nan64(int bits) => (ByteData(8)..setUint64(0, bits)).getFloat64(0);

void main() {
  group('a NaN is written as the quiet NaN on every CPU', () {
    test('f32: a NaN with the sign bit set gives 7fc00000', () {
      // Arrange
      final layout = scheme(1, [f32(0, 'x')]);
      final negative = _nan32(0xffc00000);

      // Act
      final wire = pack(layout, {'x': negative});

      // Assert
      expect(negative.isNaN, isTrue);
      expect(hex(wire), '010000c07f');
    });

    test('f64: a NaN with the sign bit set gives 7ff8000000000000', () {
      // Arrange
      final layout = scheme(1, [f64(0, 'x')]);
      final negative = _nan64(0xfff8000000000001);

      // Act
      final wire = pack(layout, {'x': negative});

      // Assert
      expect(negative.isNaN, isTrue);
      expect(hex(wire), '01000000000000f87f');
    });

    test('f32 and f64: double.nan gives the same bytes', () {
      // Act
      final a = pack(scheme(1, [f32(0, 'x')]), {'x': double.nan});
      final b = pack(scheme(1, [f64(0, 'x')]), {'x': double.nan});

      // Assert
      expect(hex(a), '010000c07f');
      expect(hex(b), '01000000000000f87f');
    });
  });
}
