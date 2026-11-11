import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

class Motion {
  int? heading;
  int? speed;
}

List<Field> motionFields() => [
  flags(0, [
    u16(
      0,
      'heading',
    ).bind<Motion>(get: (r) => r.heading, set: (r, v) => r.heading = v),
    u8(
      1,
      'speed',
    ).bind<Motion>(get: (r) => r.speed, set: (r, v) => r.speed = v),
  ]),
];

void main() {
  group('AC-4 no value and zero', () {
    test('a getter that returns null clears the bit and writes no bytes', () {
      // Arrange
      final layout = rowScheme(1, Motion.new, motionFields());

      // Act
      final raw = pack(layout, Motion());

      // Assert
      expect(hex(raw), '0100');
    });

    test('an absent map key clears the bit and writes no bytes', () {
      // Arrange
      final layout = scheme(1, motionFields());

      // Act
      final raw = pack(layout, <String, Object?>{});

      // Assert
      expect(hex(raw), '0100');
    });

    test('a map key that holds null clears the bit and writes no bytes', () {
      // Arrange
      final layout = scheme(1, motionFields());

      // Act
      final raw = pack(layout, {'heading': null, 'speed': null});

      // Assert
      expect(hex(raw), '0100');
    });

    test('a 0 sets the bit and is written, typed and map', () {
      // Arrange
      final typed = rowScheme(1, Motion.new, motionFields());
      final map = scheme(1, motionFields());

      // Act
      final fromTyped = pack(typed, Motion()..heading = 0);
      final fromMap = pack(map, {'heading': 0});

      // Assert
      expect([hex(fromTyped), hex(fromMap)], ['01010000', '01010000']);
    });

    test('unpack tells a 0 from no value, typed and map', () {
      // Arrange
      final typed = rowScheme(1, Motion.new, motionFields());
      final map = scheme(1, motionFields());

      // Act
      final zero = unpackRow(unhex('01010000'), typed).row!;
      final none = unpackRow(unhex('0100'), typed).row!;
      final zeroMap = unpackRow(unhex('01010000'), map).row;
      final noneMap = unpackRow(unhex('0100'), map).row;

      // Assert
      expect(
        [zero.heading, zero.speed, none.heading, none.speed],
        [0, null, null, null],
      );
      expect(
        [zeroMap, noneMap],
        [
          {'heading': 0},
          <String, Object?>{},
        ],
      );
    });

    test('a required field given null is refused, not skipped', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n')]);

      // Act
      Object? thrown;
      try {
        pack(layout, {'n': null});
      } on PackbinException catch (e) {
        thrown = e.error;
      }

      // Assert
      expect(
        thrown,
        const PackbinError(
          ErrorKind.packError,
          field: 0,
          name: 'n',
          reason: 'missing n',
        ),
      );
    });
  });
}
