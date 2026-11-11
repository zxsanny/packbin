import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

Scheme<Row> listOfU8() => scheme(1, [list('xs', u8(0, 'x'))]);

PackbinError refused(Scheme<Row> layout, Row row) =>
    packRefusal(() => pack(layout, row));

void main() {
  group('a wrong element is a pack error naming the field and the index', () {
    test('a String in a list of u8', () {
      // Arrange
      final row = <String, Object?>{
        'xs': [1, 2, 'three', 4],
      };

      // Act
      final error = refused(listOfU8(), row);

      // Assert
      expect(error.kind, ErrorKind.packError);
      expect(error.name, 'xs');
      expect(error.reason, contains('xs[2]'));
      expect(error.reason, contains('String'));
    });

    test('a whole double in a list of u8', () {
      // Arrange
      final row = <String, Object?>{
        'xs': [1, 5.0],
      };

      // Act
      final error = refused(listOfU8(), row);

      // Assert
      expect(error.name, 'xs');
      expect(error.reason, contains('xs[1]'));
      expect(error.reason, contains('double'));
    });

    test('a value out of range names the index', () {
      // Arrange
      final row = <String, Object?>{
        'xs': [1, 256],
      };

      // Act
      final error = refused(listOfU8(), row);

      // Assert
      expect(error.reason, contains('xs[1]'));
      expect(error.reason, contains('256'));
    });

    test('a null item is no value', () {
      // Arrange
      final row = <String, Object?>{
        'xs': [1, null],
      };

      // Act
      final error = refused(listOfU8(), row);

      // Assert
      expect(error.name, 'xs');
      expect(error.reason, 'xs[1]: no value');
    });

    test('an int in a list of utf8', () {
      // Arrange
      final layout = scheme(1, [list('names', utf8Field(0, 'n'))]);

      // Act
      final error = refused(layout, {
        'names': ['a', 7],
      });

      // Assert
      expect(error.name, 'names');
      expect(error.reason, contains('names[1]'));
      expect(error.reason, contains('String'));
    });

    test('a wrong item of an inner list names the outer index', () {
      // Arrange
      final layout = scheme(1, [list('xs', list('ys', u8(0, 'y')))]);

      // Act
      final error = refused(layout, {
        'xs': [
          [1],
          [2, 'x'],
        ],
      });

      // Assert
      expect(error.name, 'xs');
      expect(error.reason, contains('xs[1]'));
      expect(error.reason, contains('ys[1]'));
    });

    test('a wrong value of a dictionary names the key', () {
      // Arrange
      final layout = scheme(1, [dict('m', u8(0, 'v'))]);

      // Act
      final error = refused(layout, {
        'm': {'a': 1, 'b': 'x'},
      });

      // Assert
      expect(error.name, 'm');
      expect(error.reason, contains('m[b]'));
    });

    test('an item that is not a map for a nested row names the index', () {
      // Arrange
      final layout = scheme(1, [
        list('pts', nested('p', [u8(0, 'a')])),
      ]);

      // Act
      final error = refused(layout, {
        'pts': [
          {'a': 1},
          7,
        ],
      });

      // Assert
      expect(error.name, 'p');
      expect(error.reason, contains('pts[1]'));
      expect(error.reason, contains('Map<String, Object?>'));
    });

    test('a member missing in a nested item names that member', () {
      // Arrange
      final layout = scheme(1, [
        list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
      ]);

      // Act
      final error = refused(layout, {
        'pts': [
          {'a': 1, 'b': 2},
          {'a': 3},
        ],
      });

      // Assert
      expect(error.field, 1);
      expect(error.name, 'b');
    });
  });

  group('a value that is no list, no dictionary and no text', () {
    test('a byte run is no list in a map row', () {
      // Arrange
      final row = <String, Object?>{
        'xs': Uint8List.fromList([1, 2]),
      };

      // Act
      final error = refused(listOfU8(), row);

      // Assert
      expect(error.name, 'xs');
      expect(error.reason, contains('expected a list'));
    });

    test('a map is no list', () {
      // Arrange and Act
      final error = refused(listOfU8(), {
        'xs': {'a': 1},
      });

      // Assert
      expect(error.reason, contains('expected a list'));
    });

    test('a missing list is a missing field', () {
      // Arrange and Act
      final error = refused(listOfU8(), {});

      // Assert
      expect(error.name, 'xs');
      expect(error.reason, 'missing xs');
    });

    test('a list of 65,536 items is refused, 65,535 packs', () {
      // Arrange
      final layout = listOfU8();

      // Act
      final bytes = pack(layout, {'xs': List<int>.filled(65535, 1)});
      final error = refused(layout, {'xs': List<int>.filled(65536, 1)});

      // Assert
      expect(bytes.length, 1 + 2 + 65535);
      expect(error.name, 'xs');
      expect(error.reason, contains('65536'));
    });

    test('a non-String value for utf8 names the field', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final error = refused(layout, {'name': 5});

      // Assert
      expect(error.field, 0);
      expect(error.name, 'name');
      expect(error.reason, contains('String'));
    });
  });
}
