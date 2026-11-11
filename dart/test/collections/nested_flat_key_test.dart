import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

List<Field> inner() => [u8(0, 'a'), u8(1, 'b')];

const _hint = 'which is not given; give the value in the nested row\'s Map';

/// A refusal of [row] under [layout] that names the member [member] of the
/// nested row [nestedName].
void expectFlatKeyRefused(
  Scheme<Row> layout,
  Row row,
  String member,
  String nestedName,
  int id,
) {
  final error = packRefusal(() => pack(layout, row));
  expect(error.name, member);
  expect(error.field, id);
  expect(
    error.reason,
    startsWith('$member is a member of nested row $nestedName, $_hint'),
  );
}

void main() {
  group('R3 a flat key that names a member of a nested row', () {
    test('beside a nested row that is not given is refused', () {
      // Arrange
      final layout = scheme(1, [nested('g', inner()), u8(0, 'z')]);

      // Act and Assert
      expectFlatKeyRefused(layout, {'b': 2, 'z': 3}, 'b', 'g', 1);
    });

    test('under a clear flags bit is refused', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [nested('g', inner()), u8(0, 'z')]),
      ]);

      // Act and Assert
      expectFlatKeyRefused(layout, {'a': 1}, 'a', 'g', 0);
    });

    test('under a clear split flag bit is refused', () {
      // Arrange
      final fb = flagByte('m');
      final layout = scheme(1, [fb, fb.bit(nested('g', inner()))]);

      // Act and Assert
      expectFlatKeyRefused(layout, {'b': 2}, 'b', 'g', 1);
    });

    test('inside the map of a group whose nested row is not given', () {
      // Arrange
      final layout = scheme(1, [
        groupOf(0, 'h', [nested('g', inner()), u8(0, 'z')]),
      ]);

      // Act and Assert
      expectFlatKeyRefused(
        layout,
        {
          'h': {'a': 1, 'z': 2},
        },
        'a',
        'g',
        0,
      );
    });

    test('a member of a nested row inside a nested row is named', () {
      // Arrange
      final layout = scheme(1, [
        nested('g', [
          u8(0, 'a'),
          nested('k', [u8(0, 'deep')]),
        ]),
      ]);

      // Act and Assert
      expectFlatKeyRefused(layout, {'deep': 1}, 'deep', 'g', 0);
    });

    test('the flat key beside the given map is not read', () {
      // Arrange
      final layout = scheme(1, [nested('g', inner()), u8(0, 'z')]);

      // Act
      final wire = pack(layout, {
        'g': {'a': 1, 'b': 2},
        'b': 9,
        'z': 3,
      });

      // Assert
      expect(hex(wire), '01010203');
    });

    test('a key the row around declares too is not a flat member', () {
      // Arrange
      final layout = scheme(1, [nested('g', inner()), u8(0, 'b')]);

      // Act
      final wire = pack(layout, {
        'g': {'a': 1, 'b': 2},
        'b': 3,
      });

      // Assert
      expect(hex(wire), '01010203');
    });

    test('a key that names no member is not refused by this rule', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [nested('g', inner())]),
      ]);

      // Act
      final wire = pack(layout, {'other': 1});

      // Assert
      expect(hex(wire), '0100');
    });
  });
}
