import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';

final class Leaf {
  int a = 0;
}

final class Holder {
  List<Leaf> items = [];
  List<int> ints = [];
  Leaf? one;
}

NestedField<Leaf> leafRow() => nestedRow<Leaf>('leaf', Leaf.new, [
  u8(0, 'a').bind<Leaf>(get: (l) => l.a, set: (l, v) => l.a = v),
]);

void main() {
  group('the ids of an element are its own', () {
    test('an element starts at id 0 and the row around it goes on', () {
      // Arrange and Act
      final layout = scheme(1, [
        u8(0, 'a'),
        list('xs', u8(0, 'x')),
        dict('m', nested('p', [u8(0, 'a'), u8(1, 'b')])),
        u8(1, 'b'),
        utf8Field(2, 'c'),
      ]);

      // Assert
      expect(layout.typeNumber, 1);
    });

    test('a list element with id 1 is refused naming the id', () {
      // Arrange and Act
      final error = refusal(() => scheme(1, [list('xs', u8(1, 'x'))]));

      // Assert
      expect(error.field, 1);
      expect(error.reason, 'field id: expected 0, got 1');
    });

    test('a nested row with a gap in its ids is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          nested('p', [u8(0, 'a'), u8(2, 'b')]),
        ]),
      );

      // Assert
      expect(error.field, 2);
    });

    test('a utf8 id that is not the next id is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [u8(0, 'a'), utf8Field(2, 'name')]),
      );

      // Assert
      expect(error.field, 2);
      expect(error.name, 'name');
    });
  });

  group('the element of a list or dict', () {
    final cases = <String, Field Function()>{
      'sized': () => sized(0, 'e', 0),
      'bits': () => bits(0, 'e', 0),
      'packed': () => packed(1, 0, 'e', 0),
      'a slot': () => slot(0, 'e'),
      'a bool': () => flagBool(0, 'e'),
    };
    for (final entry in cases.entries) {
      test('${entry.key} is refused when the scheme is built', () {
        // Arrange
        final element = entry.value() as ElementField<Object>;

        // Act
        final error = refusal(() => scheme(1, [list('xs', element)]));

        // Assert
        expect(error.kind, ErrorKind.schemeError);
        expect(error.name, anyOf('xs', 'e'));
      });
    }

    test('a count that names a field outside the element is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          u8(0, 'n'),
          list('xs', nested('p', [sized(0, 'd', 0)])),
        ]),
      );

      // Assert
      expect(error.reason, contains('not declared earlier in the same scope'));
    });

    test('a when that names a field outside the element is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          u8(0, 'n'),
          list(
            'xs',
            nested('p', [
              when(0, eq(0, 1), [u8(0, 'v')]),
            ]),
          ),
        ]),
      );

      // Assert
      expect(error.reason, contains('not declared earlier in the same scope'));
    });

    test('a name declared twice in a nested row is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          list('xs', nested('p', [u8(0, 'a'), u8(1, 'a')])),
        ]),
      );

      // Assert
      expect(error.name, 'a');
      expect(error.reason, contains('declared twice'));
    });

    test('a nested row named like a field of its row is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          u8(0, 'g'),
          nested('g', [u8(0, 'a')]),
        ]),
      );

      // Assert
      expect(error.name, 'g');
    });

    test('a nested row with no member is a mark, refused outside flags', () {
      // Arrange and Act
      final error = refusal(() => scheme(1, [nested('g', [])]));

      // Assert
      expect(error.name, 'g');
      expect(error.reason, startsWith('empty group g: allowed only directly'));
    });

    test('a nestedRow with no member is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [nestedRow<Object>('g', Object.new, [])]),
      );

      // Assert
      expect(error.name, 'g');
      expect(error.reason, contains('at least one member'));
    });

    test('a round in an element is a round of its own row', () {
      // Arrange and Act
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          list(
            'xs',
            nested('p', [
              u8(0, 'n'),
              times(1, 0, [u8(1, 'v')]),
            ]),
          ),
        ]),
      ]);

      // Assert
      expect(layout.typeNumber, 1);
    });

    test('a body with no member inside an element is refused', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          list('items', nested('item', [u8(0, 'n'), times(1, 0, [])])),
        ]),
      );

      // Assert
      expect(error.field, 1);
      expect(error.reason, contains('the body holds no member'));
    });
  });

  group('a typed scheme', () {
    test('needs a list bound to a member of its row', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Holder>(1, Holder.new, [list('ints', u8(0, 'i'))]),
      );

      // Assert
      expect(error.name, 'ints');
      expect(error.reason, contains('needs every list bound'));
    });

    test('refuses a list bound to the member of another row type', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Holder>(1, Holder.new, [
          list(
            'ints',
            u8(0, 'i'),
          ).bind<Leaf>(get: (l) => [l.a], set: (l, v) {}),
        ]),
      );

      // Assert
      expect(error.reason, contains('bound to'));
    });

    test('needs the nested row of a list made with nestedRow', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Holder>(1, Holder.new, [
          list(
            'items',
            nested('leaf', [u8(0, 'a')]),
          ).bind<Holder>(get: (h) => [], set: (h, v) {}),
        ]),
      );

      // Assert
      expect(error.name, 'leaf');
      expect(error.reason, contains('nestedRow'));
    });

    test('needs the members of a nested row bound to its row type', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Holder>(1, Holder.new, [
          list(
            'items',
            nestedRow<Leaf>('leaf', Leaf.new, [u8(0, 'a')]),
          ).bind<Holder>(get: (h) => h.items, set: (h, v) => h.items = v),
        ]),
      );

      // Assert
      expect(error.name, 'a');
      expect(error.reason, contains('needs every value field bound'));
    });

    test('builds with a list of rows, a list of ints and a nested row', () {
      // Arrange and Act
      final layout = rowScheme<Holder>(1, Holder.new, [
        list(
          'items',
          leafRow(),
        ).bind<Holder>(get: (h) => h.items, set: (h, v) => h.items = v),
        list(
          'ints',
          u8(0, 'i'),
        ).bind<Holder>(get: (h) => h.ints, set: (h, v) => h.ints = v),
        leafRow().bind<Holder>(get: (h) => h.one, set: (h, v) => h.one = v),
      ]);

      // Assert
      expect(layout.typeNumber, 1);
    });
  });
}
