import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';

typedef Build = Object Function();

/// The refusal [build] throws: its field id and its reason.
(int?, String) refused(Build build) {
  final e = refusal(build);
  return (e.field, e.reason);
}

void main() {
  group('round nesting is refused when the scheme is built', () {
    final nested = <String, Build>{
      'a times directly in a repeat': () => scheme(1, [
        u8(0, 'n'),
        repeat(1, [
          times(1, 0, [u8(1, 'x')]),
        ]),
      ]),
      'a repeat in a times': () => scheme(1, [
        u8(0, 'n'),
        times(1, 0, [
          repeat(1, [u8(1, 'x')]),
        ]),
      ]),
      'a round under a when in a round': () => scheme(1, [
        u8(0, 'n'),
        repeat(1, [
          u8(1, 'k'),
          when(2, eq(1, 1), [
            repeat(2, [u8(2, 'x')]),
          ]),
        ]),
      ]),
      'a round under flags in a round': () => scheme(1, [
        repeat(0, [
          flags(0, [
            u8(0, 'a'),
            repeat(1, [u8(1, 'x')]),
          ]),
        ]),
      ]),
      'a round under a group in a round': () => scheme(1, [
        repeat(0, [
          u8(0, 'a'),
          groupOf(1, 'g', [
            repeat(1, [u8(1, 'x')]),
          ]),
        ]),
      ]),
    };
    nested.forEach((name, build) {
      test('$name: the scheme error names the inner round', () {
        // Arrange and Act
        final (field, reason) = refused(build);

        // Assert
        expect(field, isNotNull);
        expect(reason, contains('inside a repeat or times round'));
      });
    });
  });

  group('an empty round body is refused', () {
    final empty = <String, Build>{
      'times with no member': () => scheme(1, [u8(0, 'n'), times(1, 0, [])]),
      'repeat with no member': () => scheme(1, [repeat(0, [])]),
      'a body of an empty when': () => scheme(1, [
        u8(0, 'mode'),
        u8(1, 'c'),
        times(2, 1, [when(2, eq(0, 1), [])]),
      ]),
      'a repeat with an empty when': () => scheme(1, [
        u8(0, 'mode'),
        repeat(1, [when(1, eq(0, 1), [])]),
      ]),
      'a when of only an empty when': () => scheme(1, [
        u8(0, 'mode'),
        u8(1, 'c'),
        times(2, 1, [
          when(2, eq(0, 1), [when(2, eq(0, 1), [])]),
        ]),
      ]),
      'a group of only an empty when': () => scheme(1, [
        u8(0, 'n'),
        times(1, 0, [
          groupOf(1, 'g', [when(1, eq(0, 1), [])]),
        ]),
      ]),
    };
    empty.forEach((name, build) {
      test(name, () {
        // Arrange and Act
        final (field, reason) = refused(build);

        // Assert
        expect(field, isNotNull);
        expect(reason, contains('holds no member'));
      });
    });

    test(
      'a zero-width bytes, a flag byte or a flags with no member is a member',
      () {
        // Arrange and Act
        final built = [
          scheme(1, [
            repeat(0, [bytes(0, 'e', 0)]),
          ]),
          scheme(1, [
            repeat(0, [flags(0, [])]),
          ]),
          scheme(1, [
            u8(0, 'n'),
            times(1, 0, [u8(1, 'x')]),
          ]),
        ];

        // Assert
        expect(built, hasLength(3));
      },
    );
  });

  group('a count names an integer read earlier in the same scope', () {
    test(
      'a count that names a later field is refused naming the counted field',
      () {
        // Arrange and Act
        final (field, reason) = refused(
          () => scheme(1, [sized(0, 'payload', 1), u16(1, 'n')]),
        );

        // Assert
        expect(field, 0);
        expect(reason, contains('not declared earlier in the same scope'));
      },
    );

    test('a count that names an id that does not exist is refused', () {
      // Arrange and Act
      final (field, _) = refused(() => scheme(1, [bits(0, 'v', 9)]));

      // Assert
      expect(field, 0);
    });

    test('a float, bytes or bool count is refused as not an integer', () {
      // Arrange
      final builds = <Build>[
        () => scheme(1, [f32(0, 'n'), sized(1, 'p', 0)]),
        () => scheme(1, [bytes(0, 'n', 2), bits(1, 'v', 0)]),
        () => scheme(1, [
          flags(0, [flagBool(0, 'on')]),
          sized(1, 'p', 0),
        ]),
        () => scheme(1, [sized(0, 'a', 0)]),
      ];

      // Act
      final errors = [for (final b in builds) refusal(b)];

      // Assert
      expect(
        errors.map((e) => e.reason),
        everyElement(contains('count names field id 0')),
      );
      expect(errors[0].reason, contains('not an integer'));
      expect(errors[3].reason, contains('not declared earlier'));
    });

    test('a times count names its own anchor id in the refusal', () {
      // Arrange and Act
      final (field, reason) = refused(
        () => scheme(1, [
          times(0, 1, [u8(0, 'x')]),
          u8(1, 'n'),
        ]),
      );

      // Assert
      expect([field, reason], [0, contains('times 0: count names field id 1')]);
    });

    test('a count outside the round is not in the round scope', () {
      // Arrange and Act
      final (_, reason) = refused(
        () => scheme(1, [
          u8(0, 'n'),
          repeat(1, [sized(1, 'p', 0)]),
        ]),
      );

      // Assert
      expect(reason, contains('not declared earlier in the same scope'));
    });

    test('a count inside the round counts in the round', () {
      // Arrange and Act
      final built = scheme(1, [
        repeat(0, [u8(0, 'n'), sized(1, 'p', 0)]),
      ]);

      // Assert
      expect(built.typeNumber, 1);
    });

    test('a when inside a round that names a field outside it is refused', () {
      // Arrange and Act
      final (field, reason) = refused(
        () => scheme(1, [
          u8(0, 'mode'),
          repeat(1, [
            when(1, eq(0, 1), [u8(1, 'v')]),
          ]),
        ]),
      );

      // Assert
      expect(field, 1);
      expect(reason, contains('not declared earlier in the same scope'));
    });

    test('a count behind a when is declared, and counts when it is read', () {
      // Arrange and Act
      final built = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        sized(2, 'v', 1),
      ]);

      // Assert
      expect(built.typeNumber, 1);
    });

    test('a u2 slot is an integer for a count and for a when', () {
      // Arrange and Act
      final built = scheme(1, [
        u2([slot(0, 'a'), slot(1, 'b')]),
        times(2, 1, [u8(2, 'x')]),
        when(3, eq(0, 3), [u8(3, 'y')]),
      ]);

      // Assert
      expect(built.typeNumber, 1);
    });

    test('eq of a slot against 4 is refused, as the u2 holds 0 to 3', () {
      // Arrange and Act
      final (field, reason) = refused(
        () => scheme(1, [
          u2([slot(0, 'a')]),
          when(1, eq(0, 4), [u8(1, 'y')]),
        ]),
      );

      // Assert
      expect(field, 1);
      expect(reason, contains('from 0 to 3'));
    });
  });

  group('the kinds refuse what they cannot hold', () {
    test('packed width 3 and bias -2 are refused naming the field', () {
      // Arrange
      final builds = <Build>[
        () => scheme(1, [u8(0, 'n'), packed(3, 1, 'v', 0)]),
        () => scheme(1, [u8(0, 'n'), packed(1, 1, 'v', 0, bias: -2)]),
        () => scheme(1, [u8(0, 'n'), packed(1, 1, 'v', 0, bias: 1)]),
      ];

      // Act
      final errors = [for (final b in builds) refusal(b)];

      // Assert
      expect(errors.map((e) => e.field), [1, 1, 1]);
      expect(errors.map((e) => e.name), ['v', 'v', 'v']);
    });

    test(
      'a u2 with no slot, or with a member that is not a slot, is refused',
      () {
        // Arrange
        final builds = <Build>[
          () => scheme(1, [u2([])]),
          () => scheme(1, [
            u2([u8(0, 'a')]),
          ]),
        ];

        // Act
        final errors = [for (final b in builds) refusal(b)];

        // Assert
        expect(errors[0].reason, contains('at least one slot'));
        expect(errors[1].reason, contains('not a slot'));
      },
    );

    test('a slot outside a u2 is refused', () {
      // Arrange and Act
      final (field, reason) = refused(() => scheme(1, [slot(0, 'a')]));

      // Assert
      expect([field, reason], [0, contains('only inside u2')]);
    });

    test(
      'ids run through the counted kinds and u2 slots, and a gap is refused',
      () {
        // Arrange
        final builds = <Build>[
          () => scheme(1, [
            u8(0, 'n'),
            u2([slot(1, 'a'), slot(3, 'b')]),
          ]),
          () => scheme(1, [u8(0, 'n'), bits(2, 'v', 0)]),
          () => scheme(1, [
            u8(0, 'n'),
            times(2, 0, [u8(2, 'x')]),
          ]),
        ];

        // Act
        final fields = [for (final b in builds) refusal(b).field];

        // Assert
        expect(fields, [3, 2, 2]);
      },
    );

    test('a bool inside a round is refused: it has no flag bit to live in', () {
      // Arrange and Act
      final (field, reason) = refused(
        () => scheme(1, [
          repeat(0, [flagBool(0, 'on')]),
        ]),
      );

      // Assert
      expect(
        [field, reason],
        [0, contains('allowed only directly inside flags')],
      );
    });

    test('a name declared in a round and outside it is refused', () {
      // Arrange and Act
      final (_, reason) = refused(
        () => scheme(1, [
          u8(0, 'x'),
          repeat(1, [u8(1, 'x')]),
        ]),
      );

      // Assert
      expect(reason, contains('declared twice in one scope'));
    });

    test('a name shared by two slots or a slot and a field is refused', () {
      // Arrange and Act
      final (_, reason) = refused(
        () => scheme(1, [
          u2([slot(0, 'a'), slot(1, 'a')]),
        ]),
      );

      // Assert
      expect(reason, contains('declared twice'));
    });
  });

  group('the zero progress hostile schemes are refused', () {
    test('a bool outside flags in a repeat', () {
      // Arrange and Act
      final (field, _) = refused(
        () => scheme(1, [
          repeat(0, [flagBool(0, 'on')]),
        ]),
      );

      // Assert
      expect(field, 0);
    });

    test('a when naming a field outside its repeat', () {
      // Arrange and Act
      final (field, _) = refused(
        () => scheme(1, [
          u8(0, 'mode'),
          repeat(1, [
            when(1, eq(0, 1), [u8(1, 'v')]),
          ]),
        ]),
      );

      // Assert
      expect(field, 1);
    });
  });
}
