import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

// The buffer of one pack call grows by doubling from 64 bytes. A write that
// is the first past the end of the buffer must land in the grown buffer.

void main() {
  group('a byte or an f64 written at the end of the buffer', () {
    for (final pad in [63, 127, 255, 511]) {
      test('a flags byte after $pad bytes of padding', () {
        // Arrange
        final layout = scheme(1, [
          bytes(0, 'pad', pad),
          flags(1, [u8(1, 'x')]),
        ]);

        // Act
        final raw = pack(layout, {'pad': Uint8List(pad), 'x': 7});
        final back = unpackRow(raw, layout);

        // Assert
        expect(hex(raw.sublist(1 + pad)), '0107');
        expect(back.row!['x'], 7);
      });

      test('a split flag byte after $pad bytes of padding', () {
        // Arrange
        final fb = flagByte('m');
        final layout = scheme(1, [
          bytes(0, 'pad', pad),
          fb,
          fb.bit(u8(1, 'x')),
        ]);

        // Act
        final raw = pack(layout, {'pad': Uint8List(pad), 'x': 7});

        // Assert
        expect(hex(raw.sublist(1 + pad)), '0107');
        expect(unpackRow(raw, layout).row!['x'], 7);
      });

      test('an f64 after $pad bytes of padding', () {
        // Arrange
        final layout = scheme(1, [bytes(0, 'pad', pad), f64(1, 'v')]);

        // Act
        final raw = pack(layout, {'pad': Uint8List(pad), 'v': 1.5});

        // Assert
        expect(hex(raw.sublist(1 + pad)), '000000000000f83f');
        expect(unpackRow(raw, layout).row!['v'], 1.5);
      });
    }
  });
}
