import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';

class Small {
  int n = 0;
}

/// The pack error [body] throws; fails when it returns bytes.
PackbinError refusal(Uint8List Function() body) {
  try {
    final raw = body();
    fail('pack returned ${raw.length} bytes');
  } on PackbinException catch (e) {
    return e.error;
  }
}

PackbinError refused(int field, String name, String reason) =>
    PackbinError(ErrorKind.packError, field: field, name: name, reason: reason);

void main() {
  group('AC-5 invalid Dart values', () {
    test('a getter that returns 300 for a u8 is refused naming the field', () {
      // Arrange
      final layout = rowScheme(1, Small.new, [
        u8(0, 'n').bind<Small>(get: (r) => r.n, set: (r, v) => r.n = v),
      ]);

      // Act
      final error = refusal(() => pack(layout, Small()..n = 300));

      // Assert
      expect(error, refused(0, 'n', '300 does not fit in u8'));
      expect(
        error.toString(),
        'packbin: pack refused at field 0 (n): 300 does not fit in u8',
      );
    });

    test('a double for an integer field is refused, a whole 5.0 too', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'n')]);

      // Act
      final whole = refusal(() => pack(layout, {'n': 5.0}));
      final fraction = refusal(() => pack(layout, {'n': 1.5}));

      // Assert
      expect(whole, refused(0, 'n', 'expected an integer for u8, got double'));
      expect(fraction, whole);
    });

    test('a String for an integer or a float field is refused', () {
      // Arrange
      final layout = scheme(1, [u16(0, 'n'), f64(1, 'x')]);

      // Act
      final integer = refusal(() => pack(layout, {'n': '5', 'x': 1.0}));
      final float = refusal(() => pack(layout, {'n': 5, 'x': '1.0'}));

      // Assert
      expect(
        integer,
        refused(0, 'n', 'expected an integer for u16, got String'),
      );
      expect(float, refused(1, 'x', 'expected a number for f64, got String'));
    });

    test('a bool for a number is refused', () {
      // Arrange
      final layout = scheme(1, [i32(0, 'n'), f32(1, 'x')]);

      // Act
      final integer = refusal(() => pack(layout, {'n': true, 'x': 1.0}));
      final float = refusal(() => pack(layout, {'n': 1, 'x': false}));

      // Assert
      expect(integer, refused(0, 'n', 'expected an integer for i32, got bool'));
      expect(float, refused(1, 'x', 'expected a number for f32, got bool'));
    });

    test('a missing required key is refused naming the field', () {
      // Arrange
      final row = goldenMap()..remove('lon');

      // Act
      final error = refusal(() => pack(positionMapScheme(), row));

      // Assert
      expect(error, refused(2, 'lon', 'missing lon'));
    });

    test(
      'a row whose third field is out of range names field 2, typed and map',
      () {
        // Arrange
        final typed = goldenPosition()..lon = 2147483648;
        final map = goldenMap()..['lon'] = 2147483648;

        // Act
        final fromTyped = refusal(() => pack(positionScheme(), typed));
        final fromMap = refusal(() => pack(positionMapScheme(), map));

        // Assert
        expect(fromTyped, refused(2, 'lon', '2147483648 does not fit in i32'));
        expect(fromMap, fromTyped);
      },
    );

    test('a value under a set flag bit is checked as any other', () {
      // Arrange
      final row = goldenMap()..['speed'] = 256;

      // Act
      final error = refusal(() => pack(positionMapScheme(), row));

      // Assert
      expect(error, refused(5, 'speed', '256 does not fit in u8'));
    });

    test(
      'each width refuses one below its minimum and one above its maximum',
      () {
        // Arrange
        final cases = <(Field, int, String)>[
          (u8(0, 'n'), -1, '-1 does not fit in u8'),
          (u8(0, 'n'), 256, '256 does not fit in u8'),
          (i8(0, 'n'), -129, '-129 does not fit in i8'),
          (i8(0, 'n'), 128, '128 does not fit in i8'),
          (u16(0, 'n'), 65536, '65536 does not fit in u16'),
          (i16(0, 'n'), -32769, '-32769 does not fit in i16'),
          (u32(0, 'n'), 4294967296, '4294967296 does not fit in u32'),
          (u32(0, 'n'), -1, '-1 does not fit in u32'),
          (i32(0, 'n'), -2147483649, '-2147483649 does not fit in i32'),
        ];

        // Act
        final errors = [
          for (final (field, value, _) in cases)
            refusal(() => pack(scheme(1, [field]), {'n': value})),
        ];

        // Assert
        expect(errors, [
          for (final (_, _, reason) in cases) refused(0, 'n', reason),
        ]);
      },
    );

    test('a finite value too large for f32 is refused', () {
      // Arrange
      final layout = scheme(1, [f32(0, 'x')]);

      // Act
      final error = refusal(() => pack(layout, {'x': 1e39}));

      // Assert
      expect(error, refused(0, 'x', '1e+39 does not fit in f32'));
    });

    test('fixed bytes of another length or another type are refused', () {
      // Arrange
      final layout = scheme(1, [bytes(0, 'b', 3)]);

      // Act
      final short = refusal(() => pack(layout, {'b': Uint8List(2)}));
      final long = refusal(() => pack(layout, {'b': Uint8List(4)}));
      final list = refusal(() => pack(layout, {'b': 'abc'}));

      // Assert
      expect(short, refused(0, 'b', 'expected 3 bytes, got 2'));
      expect(long, refused(0, 'b', 'expected 3 bytes, got 4'));
      expect(
        list,
        refused(0, 'b', 'expected a Uint8List for bytes(3), got String'),
      );
    });

    test('a bool field takes a bool and nothing else', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [flagBool(0, 'on')]),
      ]);

      // Act
      final number = refusal(() => pack(layout, {'on': 1}));
      final text = refusal(() => pack(layout, {'on': 'yes'}));

      // Assert
      expect(number, refused(0, 'on', 'expected a bool for on, got int'));
      expect(text, refused(0, 'on', 'expected a bool for on, got String'));
    });

    test('a row of another type is refused before any getter runs', () {
      // Arrange
      final Scheme<Object> erased = positionScheme();

      // Act
      final error = refusal(() => pack(erased, goldenMap()));

      // Assert
      expect(error.kind, ErrorKind.packError);
      expect(error.field, 0);
      expect(error.reason, contains('this scheme packs a Position'));
    });

    test('the row is still packed after a refusal: no state is kept', () {
      // Arrange
      final layout = positionMapScheme();
      refusal(() => pack(layout, goldenMap()..['sid'] = -1));

      // Act
      final raw = pack(layout, goldenMap());

      // Assert
      expect(hex(raw), '4001000065cd1d00a3e1110100');
    });
  });
}
