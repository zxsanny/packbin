import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import 'parity_support.dart';

// TypeScript tables `eq-source-kinds.test.ts` (AZ-2126) and
// `eq-value-checked.test.ts` (AZ-2338): what a `when` may name, which counts
// a round or a counted field may name, and which `eq` values each integer
// source can hold. Rows with another outcome in Dart are marked `diff` and
// pinned in `parity_differences.md`.

/// Builds the scheme and returns the refusal's reason; fails when it builds.
String refusedWith(Object Function() build) => refusal(build).reason;

List<Field> onFlag(Object value) => [
  flags(0, [flagBool(0, 'on')]),
  when(1, eq(0, value), [u8(1, 'v')]),
];

const boolPrefix =
    'when 1: eq names bool field id 0 (on) and accepts only true, not ';

final class Hostile {
  @override
  String toString() => 'leaked';
}

typedef Sources = List<Field> Function();

final whenSources = <(String, Sources, int)>[
  ('f32', () => [f32(0, 'x')], 0),
  ('f64', () => [f64(0, 'x')], 0),
  ('utf8', () => [utf8Field(0, 'x')], 0),
  ('bytes', () => [bytes(0, 'x', 2)], 0),
  ('sized', () => [u8(0, 'n'), sized(1, 'x', 0)], 1),
  ('bits', () => [u8(0, 'n'), bits(1, 'x', 0)], 1),
  ('packed', () => [u8(0, 'n'), packed(1, 1, 'x', 0)], 1),
];

final countSources = <(String, Field Function())>[
  ('bool', () => flags(0, [flagBool(0, 'n')])),
  ('f32', () => f32(0, 'n')),
  ('f64', () => f64(0, 'n')),
  ('utf8', () => utf8Field(0, 'n')),
];

Scheme<Row> build(Field source, Object value) => scheme(1, [
  source,
  when(1, eq(0, value), [u8(1, 'speed')]),
]);

final sources = <String, Field Function()>{
  'u8': () => u8(0, 'mode'),
  'i8': () => i8(0, 'mode'),
  'u16': () => u16(0, 'mode'),
  'u32': () => u32(0, 'mode'),
  'u64': () => u64(0, 'mode'),
  'i64': () => i64(0, 'mode'),
  'u2': () => u2([slot(0, 'mode')]),
};

/// TypeScript's REFUSED table: (kind, value, shown, range); a value Dart
/// spells differently is [dart], the text it shows is [shownDart].
final class Refused {
  const Refused(this.kind, this.value, this.shown, this.range, {this.dart});
  final String kind;
  final Object? value;
  final String shown;
  final String range;
  final Object? dart;
}

final refusedRows = <Refused>[
  const Refused('u8', 300, '300', '0 to 255'),
  const Refused('u8', -1, '-1', '0 to 255'),
  const Refused('u8', 'x', '"x"', '0 to 255'),
  const Refused('u8', double.nan, 'NaN', '0 to 255'),
  const Refused('u8', 1.5, '1.5', '0 to 255'),
  const Refused('u8', true, 'true', '0 to 255'),
  const Refused('u8', 1e30, '1e+30', '0 to 255'),
  const Refused('i8', 128, '128', '-128 to 127'),
  const Refused('i8', -129, '-129', '-128 to 127'),
  const Refused('u16', 65536, '65536', '0 to 65535'),
  const Refused('u32', 4294967296, '4294967296', '0 to 4294967295'),
  const Refused(
    'u64',
    1e20,
    '100000000000000000000.0',
    '0 to 18446744073709551615',
  ),
  const Refused('u2', 4, '4', '0 to 3'),
  const Refused('u2', -1, '-1', '0 to 3'),
];

void main() {
  group('eq-source-kinds: eq on a bool accepts only true', () {
    test(
      'AC-1 eq(bool, false) is a scheme error naming the when and the field',
      () {
        // Act
        final error = refusal(() => scheme(1, onFlag(false)));

        // Assert
        expect(error.reason, '${boolPrefix}false');
        expect(error.field, 1);
      },
    );

    for (final (label, value, shown) in <(String, Object, String)>[
      ('1', 1, '1'),
      ('0', 0, '0'),
      ('"yes"', 'yes', '"yes"'),
      ('"true"', 'true', '"true"'),
      ('{}', <String, Object?>{}, 'Map'),
      ('[true]', [true], 'List'),
    ]) {
      test('AC-1 eq(bool, $label) is a scheme error', () {
        // Act
        final reason = refusedWith(() => scheme(1, onFlag(value)));

        // Assert
        expect(reason, startsWith(boolPrefix));
        expect(reason, contains(shown), reason: 'the value is named');
      });
    }

    test('AC-1 an object is named by its kind, never by its own toString', () {
      // Act
      final reason = refusedWith(() => scheme(1, onFlag(Hostile())));

      // Assert
      expect(reason, startsWith(boolPrefix));
      expect(reason, isNot(contains('leaked')));
    });

    test(
      'AC-1 a flag bit holding a bool is refused like the combined form',
      () {
        // Arrange
        final fb = flagByte('fb');

        // Act
        final reason = refusedWith(
          () => scheme(1, [
            fb,
            fb.bit(flagBool(0, 'on')),
            when(1, eq(0, false), [u8(1, 'v')]),
          ]),
        );

        // Assert
        expect(reason, startsWith('when 1: eq names bool field id 0 (on)'));
      },
    );

    test('AC-2 eq(bool, true) packs 010105 and round-trips', () {
      // Arrange
      final layout = scheme(1, onFlag(true));

      // Act
      final wire = outcome(layout, {'on': true, 'v': 5});

      // Assert
      expect(wire, '010105');
      expect(unpackedRow(layout, wire), {'on': true, 'v': 5});
    });

    test('AC-2 eq(bool, true) with the bool false leaves the body out', () {
      // Act
      final wire = outcome(scheme(1, onFlag(true)), {'on': false, 'v': 5});

      // Assert
      expect(wire, '0100');
    });
  });

  group('eq-source-kinds: a when names an integer or a bool only', () {
    for (final (kind, make, id) in whenSources) {
      test('AC-1 a when naming a $kind field is a scheme error', () {
        // Act
        final reason = refusedWith(
          () => scheme(1, [
            ...make(),
            when(id + 1, eq(id, 1), [u8(id + 1, 'v')]),
          ]),
        );

        // Assert
        expect(
          reason,
          'when ${id + 1}: eq names field id $id (x), which is not an integer or a bool',
        );
      });
    }

    test(
      'a when naming an integer, a u2 slot or a clear bool still builds',
      () {
        // Act and Assert
        expect(build(u64(0, 'k'), 1).typeNumber, 1);
        expect(build(i16(0, 'k'), -1).typeNumber, 1);
        expect(
          scheme(1, [
            u2([slot(0, 'a'), slot(1, 'b')]),
            when(2, eq(1, 1), [u8(2, 'v')]),
          ]).typeNumber,
          1,
        );
      },
    );

    test('an empty-group mark has no id, so no eq can name it', () {
      // Act
      final reason = refusedWith(
        () => scheme(1, [
          flags(0, [groupOf(0, 'mark', [])]),
          when(0, eq(0, true), [u8(0, 'v')]),
        ]),
      );

      // Assert
      expect(
        reason,
        'when 0: eq names field id 0, which is not declared earlier in the '
        'same scope',
      );
    });
  });

  group('eq-source-kinds: a count names an integer field only', () {
    for (final (kind, make) in countSources) {
      test('AC-1 a times count naming a $kind field is a scheme error', () {
        // Act
        final reason = refusedWith(
          () => scheme(1, [
            make(),
            times(1, 0, [u8(1, 'v')]),
          ]),
        );

        // Assert
        expect(
          reason,
          'times 1: count names field id 0 (n), which is not an integer',
        );
      });

      test('AC-1 a sized count naming a $kind field is a scheme error', () {
        // Act
        final reason = refusedWith(() => scheme(1, [make(), sized(1, 'p', 0)]));

        // Assert
        expect(
          reason,
          'sized 1: count names field id 0 (n), which is not an integer',
        );
      });
    }
  });

  group('eq-value-checked: an eq value is checked against the source', () {
    for (final r in refusedRows) {
      test('AC-1..3 eq(${r.kind}, ${r.shown}) is a scheme error naming the '
          'when and the member', () {
        // Act
        final reason = refusedWith(() => build(sources[r.kind]!(), r.value!));

        // Assert
        expect(
          reason,
          "when 1 tests ${r.kind} field 0 ('mode') "
          'against ${r.shown}; the value must be a whole number from '
          '${r.range}',
        );
      });
    }

    final built = <(String, Object)>[
      ('u8', 5),
      ('u8', 255),
      ('u8', 0),
      ('i8', -128),
      ('i8', 127),
      ('u16', 65535),
      ('u32', 4294967295),
      ('u64', 1 << 53),
      ('u2', 3),
      ('i64', -(1 << 63)),
      ('i64', 0x7fffffffffffffff),
      ('u64', (1 << 53) - 1),
    ];
    for (final (kind, value) in built) {
      test('AC-4 eq($kind, $value) builds', () {
        // Act
        final layout = build(sources[kind]!(), value);

        // Assert
        expect(layout.typeNumber, 1);
      });
    }

    test(
      'AC-4 a valid value packs the bytes and another one skips the body',
      () {
        // Arrange
        final layout = build(u8(0, 'mode'), 5);

        // Act
        final held = hex(pack(layout, {'mode': 5, 'speed': 9}));
        final other = hex(pack(layout, {'mode': 4, 'speed': 9}));

        // Assert
        expect([held, other], ['010509', '0104']);
      },
    );

    test('eq(u8, 5.0) is refused: Dart tells 5.0 from 5 (Go-2)', () {
      // Act
      final reason = refusedWith(() => build(u8(0, 'mode'), 5.0));

      // Assert
      expect(
        reason,
        "when 1 tests u8 field 0 ('mode') against 5.0; the value must be a "
        'whole number from 0 to 255',
      );
    });

    test('eq(u8, a BigInt) is refused: a BigInt is no int', () {
      // Act
      final reason = refusedWith(() => build(u8(0, 'mode'), BigInt.from(5)));

      // Assert
      expect(reason, startsWith("when 1 tests u8 field 0 ('mode') against "));
      expect(
        reason,
        endsWith('the value must be a whole number from 0 to 255'),
      );
    });

    test(
      'eq(u64, 100000000000000000000.0) is refused as not a whole number',
      () {
        // Act
        final reason = refusedWith(() => build(u64(0, 'mode'), 1e20));

        // Assert
        expect(reason, contains('against 100000000000000000000.0;'));
      },
    );

    test('eq(u64, -1) builds: the value is the 64-bit pattern of the int', () {
      // Act
      final layout = build(u64(0, 'mode'), -1);

      // Assert
      expect(outcome(layout, {'mode': -1, 'speed': 9}), '01ffffffffffffffff09');
    });

    test('the refusal does not depend on member order: a when in a when', () {
      // Act
      final reason = refusedWith(
        () => scheme(1, [
          u8(0, 'mode'),
          when(1, eq(0, 5), [
            u8(1, 'a'),
            when(2, eq(1, 999), [u8(2, 'b')]),
          ]),
        ]),
      );

      // Assert
      expect(
        reason,
        "when 2 tests u8 field 1 ('a') against 999; the value must be a whole number from 0 to 255",
      );
    });

    test('eq on a bool source keeps the AZ-2126 rule (only true)', () {
      // Act
      final reason = refusedWith(
        () => scheme(1, [
          flags(0, [flagBool(0, 'on')]),
          when(1, eq(0, 1), [u8(1, 'b')]),
        ]),
      );

      // Assert
      expect(
        reason,
        '${boolPrefix.replaceAll('(on)', '(on)')}1'.replaceFirst(
          'when 1: ',
          'when 1: ',
        ),
      );
    });
  });
}
