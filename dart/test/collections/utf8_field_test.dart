import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

void main() {
  group('the utf8 field', () {
    test('a Ukrainian text takes the compact form and reads back', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);
      final row = {'name': 'Олександр'};

      // Act
      final wire = pack(layout, row);
      final back = readRow(layout, hex(wire));

      // Assert
      expect(wire.length, lessThan(1 + 1 + 'Олександр'.length * 2));
      expect(back, row);
    });

    test('a text with a leading U+FEFF keeps it', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);
      final row = {'name': '﻿abc'};

      // Act
      final back = readRow(layout, hex(pack(layout, row)));

      // Assert
      expect(back, row);
    });

    test('a text of 65,535 UTF-8 bytes packs, 65,536 is refused naming the '
        'field', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'a'), utf8Field(1, 'name')]);

      // Act
      final wire = pack(layout, {'a': 1, 'name': 'q' * 65535});
      final error = packRefusal(
        () => pack(layout, {'a': 1, 'name': 'q' * 65536}),
      );

      // Assert
      expect(readRow(layout, hex(wire))['name'], 'q' * 65535);
      expect(error.field, 1);
      expect(error.name, 'name');
      expect(error.reason, contains('65536'));
    });

    test('an unpaired surrogate is refused naming the field', () {
      // Arrange
      final layout = scheme(1, [u8(0, 'a'), utf8Field(1, 'name')]);

      // Act
      final lone = packRefusal(() => pack(layout, {'a': 1, 'name': 'x\ud800'}));
      final low = packRefusal(() => pack(layout, {'a': 1, 'name': '\udc00'}));

      // Assert
      expect(lone.field, 1);
      expect(lone.name, 'name');
      expect(lone.reason, contains('unpaired surrogate'));
      expect(low.name, 'name');
    });

    test('an unpaired surrogate in a dictionary key names the dictionary', () {
      // Arrange
      final layout = scheme(1, [dict('m', u8(0, 'v'))]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'm': {'\ud800': 1},
        }),
      );

      // Assert
      expect(error.name, 'm');
      expect(error.reason, contains('unpaired surrogate'));
    });

    test('a null text under flags is no value: its bit is clear', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [utf8Field(0, 'a'), utf8Field(1, 'b')]),
      ]);

      // Act
      final both = pack(layout, {'a': 'x', 'b': ''});
      final one = pack(layout, {'b': ''});
      final back = readRow(layout, hex(both));

      // Assert
      expect(both[1], 0x03);
      expect(one[1], 0x02);
      expect(hex(one), '010200');
      expect(back, {'a': 'x', 'b': ''});
    });

    test('a text in a times round: a lone text goes to every round', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [utf8Field(1, 's')]),
      ]);

      // Act
      final lone = pack(layout, {'n': 2, 's': 'ab'});
      final each = pack(layout, {
        'n': 2,
        's': ['ab', 'c'],
      });
      final back = readRow(layout, hex(each));

      // Assert
      expect(hex(lone), '0102${'03106162' * 2}');
      expect(back['s'], ['ab', 'c']);
    });

    test('a text in a repeat round: one text a round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [u8(0, 'k'), utf8Field(1, 's')]),
      ]);
      final row = <String, Object?>{
        'k': [1, 2],
        's': ['x', 'y'],
      };

      // Act
      final wire = pack(layout, row);
      final back = readRow(layout, hex(wire));

      // Assert
      expect(back, row);
    });

    test('a text of a typed row is bound like any value', () {
      // Arrange
      final layout = rowScheme<_Note>(3, _Note.new, [
        u16(0, 'id').bind<_Note>(get: (r) => r.id, set: (r, v) => r.id = v),
        utf8Field(
          1,
          'title',
        ).bind<_Note>(get: (r) => r.title, set: (r, v) => r.title = v),
      ]);

      // Act
      final wire = pack(
        layout,
        _Note()
          ..id = 1
          ..title = 'zxsanny',
      );
      final back = readRow(layout, hex(wire));

      // Assert
      expect(hex(wire), '030100062bfcfee119b2');
      expect(back.title, 'zxsanny');
    });

    test('a text cannot be named by a when or a count', () {
      // Arrange and Act
      final error = refusal(
        () => scheme(1, [
          utf8Field(0, 'name'),
          when(1, eq(0, 1), [u8(1, 'v')]),
        ]),
      );

      // Assert
      expect(error.field, 1);
      expect(error.reason, contains('not an integer or a bool'));
    });
  });
}

final class _Note {
  int id = 0;
  String title = '';
}
