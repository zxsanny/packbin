import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

class Wide {
  int n = 0;
}

void main() {
  group('AC-7 64-bit integers', () {
    // The six boundary values of a u64 as wire bytes and as the Dart int with the same bits.
    const boundaries = <String, int>{
      '0000000000000000': 0,
      '0100000000000000': 1,
      'ffffffffffffff7f': 9223372036854775807,
      '0000000000000080': -9223372036854775808,
      'feffffffffffffff': -2,
      'ffffffffffffffff': -1,
    };

    for (final MapEntry(key: wire, value: value) in boundaries.entries) {
      test(
        'u64 $wire reads as $value and packs back to the same 8 bytes, map and typed',
        () {
          // Arrange
          final map = scheme(1, [u64(0, 'n')]);
          final typed = rowScheme(1, Wide.new, [
            u64(0, 'n').bind<Wide>(get: (r) => r.n, set: (r, v) => r.n = v),
          ]);
          final packet = unhex('01$wire');

          // Act
          final row = unpackRow(packet, map).row!;
          final object = unpackRow(packet, typed).row!;
          final again = pack(map, row);
          final againTyped = pack(typed, object);

          // Assert
          expect([row['n'], object.n], [value, value]);
          expect([hex(again), hex(againTyped)], ['01$wire', '01$wire']);
        },
      );
    }

    test('an i64 keeps its sign', () {
      // Arrange
      final layout = scheme(1, [i64(0, 'a'), i64(1, 'b'), i64(2, 'c')]);
      final row = {
        'a': -1,
        'b': -9223372036854775808,
        'c': 9223372036854775807,
      };

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row;

      // Assert
      expect(hex(raw), '01ffffffffffffffff0000000000000080ffffffffffffff7f');
      expect(back, row);
    });

    test('a big-endian u64 holds the same 64 bits', () {
      // Arrange
      final layout = scheme(1, [be(u64(0, 'n'))]);

      // Act
      final back = unpackRow(unhex('01fffffffffffffffe'), layout).row!;
      final again = pack(layout, back);

      // Assert
      expect(back['n'], -2);
      expect(hex(again), '01fffffffffffffffe');
    });
  });
}
