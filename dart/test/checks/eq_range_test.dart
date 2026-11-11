import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Source = ValueField<int> Function(int id, String name);

final sources = <String, Source>{
  'u8': u8,
  'i8': i8,
  'u16': u16,
  'u32': u32,
  'u64': u64,
  'i64': i64,
};

Scheme<Map<String, Object?>> build(String kind, Object value) => scheme(1, [
  sources[kind]!(0, 'mode'),
  when(1, eq(0, value), [u8(1, 'speed')]),
]);

/// kind, value, how the refusal shows the value, the range it shows.
final refusedRows = <(String, Object, String, String)>[
  ('u8', 300, '300', '0 to 255'),
  ('u8', -1, '-1', '0 to 255'),
  ('u8', 256, '256', '0 to 255'),
  ('u8', 'x', '"x"', '0 to 255'),
  ('u8', double.nan, 'NaN', '0 to 255'),
  ('u8', 1.5, '1.5', '0 to 255'),
  ('u8', 5.0, '5.0', '0 to 255'),
  ('u8', true, 'true', '0 to 255'),
  ('u8', 1e30, '1e+30', '0 to 255'),
  ('u8', BigInt.from(5), 'a ${BigInt.from(5).runtimeType}', '0 to 255'),
  ('i8', 128, '128', '-128 to 127'),
  ('i8', -129, '-129', '-128 to 127'),
  ('u16', 65536, '65536', '0 to 65535'),
  ('u16', -1, '-1', '0 to 65535'),
  ('u32', 4294967296, '4294967296', '0 to 4294967295'),
  ('u32', -1, '-1', '0 to 4294967295'),
  ('u64', 1e20, '100000000000000000000.0', '0 to 18446744073709551615'),
  ('u64', 'x', '"x"', '0 to 18446744073709551615'),
  ('i64', 1.5, '1.5', '-9223372036854775808 to 9223372036854775807'),
  ('i64', false, 'false', '-9223372036854775808 to 9223372036854775807'),
];

final builtRows = <(String, int)>[
  ('u8', 0),
  ('u8', 5),
  ('u8', 255),
  ('i8', -128),
  ('i8', 127),
  ('u16', 65535),
  ('u32', 4294967295),
  ('u64', 0),
  ('u64', 1 << 53),
  ('u64', 0x7fffffffffffffff),
  ('i64', -(1 << 63)),
  ('i64', 0x7fffffffffffffff),
];

void main() {
  group('an eq value the integer source can never hold', () {
    for (final (kind, value, shown, range) in refusedRows) {
      test('eq($kind, $shown) is a scheme error naming the when', () {
        // Act
        final error = refusal(() => build(kind, value));

        // Assert
        expect(error.field, 1);
        expect(error.name, 'speed');
        expect(
          error.reason,
          "when 1 tests $kind field 0 ('mode') against $shown; the value must be a whole number from $range",
        );
      });
    }

    for (final (kind, value) in builtRows) {
      test('eq($kind, $value) builds', () {
        // Act
        final layout = build(kind, value);

        // Assert
        expect(layout.typeNumber, 1);
      });
    }

    test(
      'a valid value packs the bytes and a different one skips the body',
      () {
        // Arrange
        final layout = build('u8', 5);

        // Act
        final held = pack(layout, {'mode': 5, 'speed': 9});
        final other = pack(layout, {'mode': 4, 'speed': 9});

        // Assert
        expect([hex(held), hex(other)], ['010509', '0104']);
      },
    );

    test('the refusal is found at any depth, in a when inside a when', () {
      // Act
      final error = refusal(
        () => scheme(1, [
          u8(0, 'mode'),
          when(1, eq(0, 5), [
            u8(1, 'a'),
            when(2, eq(1, 999), [u8(2, 'b')]),
          ]),
        ]),
      );

      // Assert
      expect(error.field, 2);
      expect(
        error.reason,
        "when 2 tests u8 field 1 ('a') against 999; the value must be a whole number from 0 to 255",
      );
    });

    test('a source inside a flag bit or an anchored group is checked too', () {
      // Arrange
      final m = flagByte('m');

      // Act
      final split = refusal(
        () => scheme(1, [
          m,
          m.bit(u8(0, 'mode')),
          when(1, eq(0, 256), [u8(1, 'v')]),
        ]),
      );
      final inGroup = refusal(
        () => scheme(1, [
          groupOf(0, 'g', [i8(0, 'mode')]),
          when(1, eq(0, 128), [u8(1, 'v')]),
        ]),
      );

      // Assert
      expect(split.reason, contains('against 256'));
      expect(inGroup.reason, contains('i8 field 0'));
    });
  });

  group('eq on a u64 or an i64 is the 64-bit pattern of a Dart int', () {
    test('eq(u64, -1) builds and matches 2^64 - 1 on the wire', () {
      // Arrange
      final layout = build('u64', -1);
      final every = unhex('01ffffffffffffffff09');

      // Act
      final raw = pack(layout, {'mode': -1, 'speed': 9});
      final back = unpackRow(every, layout).row;
      final other = pack(layout, {'mode': 1, 'speed': 9});

      // Assert
      expect(hex(raw), '01ffffffffffffffff09');
      expect(back, {'mode': -1, 'speed': 9});
      expect(hex(other), '010100000000000000');
    });

    test('the literal 2^64 - 1 is the same pattern as -1', () {
      // Act
      final layout = build('u64', 0xFFFFFFFFFFFFFFFF);
      final raw = pack(layout, {'mode': -1, 'speed': 1});

      // Assert
      expect(hex(raw), '01ffffffffffffffff01');
    });

    test('eq(u64, 2^63) is the pattern of the least int', () {
      // Arrange
      final layout = build('u64', -9223372036854775808);

      // Act
      final raw = pack(layout, {'mode': -9223372036854775808, 'speed': 2});

      // Assert
      expect(hex(raw), '01000000000000008002');
    });
  });

  group('eq on a bool', () {
    List<Field> onFlag(Object value) => [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, value), [u8(1, 'v')]),
    ];

    test('eq(bool, false) names the when and the field', () {
      // Act
      final error = refusal(() => scheme(1, onFlag(false)));

      // Assert
      expect(error.field, 1);
      expect(
        error.reason,
        'when 1: eq names bool field id 0 (on) and accepts only true, not false',
      );
    });

    for (final value in <Object>[1, 0, 'yes', 'true', <int>[], 1.0]) {
      test('eq(bool, ${value.runtimeType} $value) is refused', () {
        // Act
        final error = refusal(() => scheme(1, onFlag(value)));

        // Assert
        expect(
          error.reason,
          startsWith(
            'when 1: eq names bool field id 0 (on) and accepts only true, not ',
          ),
        );
      });
    }

    test('eq(bool, true) packs 010105 and round-trips', () {
      // Arrange
      final layout = scheme(1, onFlag(true));

      // Act
      final raw = pack(layout, {'on': true, 'v': 5});
      final off = pack(layout, {'on': false, 'v': 5});

      // Assert
      expect([hex(raw), hex(off)], ['010105', '0100']);
      expect(readRow(layout, '010105'), {'on': true, 'v': 5});
    });

    test('a flag bit holding a bool is refused the same way', () {
      // Arrange
      final m = flagByte('m');

      // Act
      final error = refusal(
        () => scheme(1, [
          m,
          m.bit(flagBool(0, 'on')),
          when(1, eq(0, false), [u8(1, 'v')]),
        ]),
      );

      // Assert
      expect(error.reason, startsWith('when 1: eq names bool field id 0 (on)'));
    });
  });

  group('a when names an integer or a bool only', () {
    final others = <String, List<Field>>{
      'f32': [f32(0, 'x')],
      'f64': [f64(0, 'x')],
      'bytes': [bytes(0, 'x', 2)],
    };
    for (final MapEntry(key: kind, value: source) in others.entries) {
      test('a when naming a $kind field is a scheme error', () {
        // Act
        final error = refusal(
          () => scheme(1, [
            ...source,
            when(1, eq(0, 1), [u8(1, 'v')]),
          ]),
        );

        // Assert
        expect(
          error.reason,
          'when 1: eq names field id 0 (x), which is not an integer or a bool',
        );
      });
    }

    test('an empty group mark has no id, so no eq can name it', () {
      // Act
      final error = refusal(
        () => scheme(1, [
          flags(0, [groupOf(0, 'mark', [])]),
          when(0, eq(0, true), [u8(0, 'v')]),
        ]),
      );

      // Assert
      expect(
        error.reason,
        'when 0: eq names field id 0, which is not declared earlier in the same scope',
      );
    });

    test('a when naming an integer or a clear bool still builds', () {
      // Act
      final big = build('u64', 1);
      final negative = build('i64', -1);

      // Assert
      expect([big.typeNumber, negative.typeNumber], [1, 1]);
    });
  });
}
