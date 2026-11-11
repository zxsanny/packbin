import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import '../support/user_rows.dart';

typedef Row = Map<String, Object?>;

void main() {
  group('the README examples of utf8, list and dict', () {
    test('utf8: "zxsanny" is the 7 README bytes both ways', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final wire = pack(layout, {'name': 'zxsanny'});
      final row = readRow(layout, '01 06 2b fc fe e1 19 b2');

      // Assert
      expect(hex(wire), '01062bfcfee119b2');
      expect(row, {'name': 'zxsanny'});
    });

    test('utf8: the empty string is the single byte 00 and is a value', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final wire = pack(layout, {'name': ''});
      final row = readRow(layout, '0100');

      // Assert
      expect(hex(wire), '0100');
      expect(row, {'name': ''});
    });

    test('list: [1, 2] of u16 is count 2, then 01 00, then 02 00', () {
      // Arrange
      final layout = scheme(1, [list('xs', u16(0, 'x'))]);

      // Act
      final wire = pack(layout, {
        'xs': [1, 2],
      });
      final row = readRow(layout, '01 02 00 01 00 02 00');

      // Assert
      expect(hex(wire), '01020001000200');
      expect(row, {
        'xs': [1, 2],
      });
    });

    test('list: an empty list is 00 00 and the next field stays readable', () {
      // Arrange
      final layout = scheme(1, [list('xs', u16(0, 'x')), u8(0, 'after')]);

      // Act
      final wire = pack(layout, {'xs': <int>[], 'after': 7});
      final row = readRow(layout, '01 00 00 07');

      // Assert
      expect(hex(wire), '01000007');
      expect(row, {'xs': <int>[], 'after': 7});
    });

    test('dict: {"b": 1, "a": 2} packs the keys in order, as the README', () {
      // Arrange
      final layout = scheme(1, [dict('m', u8(0, 'v'))]);
      const wireHex = '01 02 00 02 10 61 02 02 10 62 01';

      // Act
      final wire = pack(layout, {
        'm': {'b': 1, 'a': 2},
      });
      final row = readRow(layout, wireHex);

      // Assert
      expect(hex(wire), wireHex.replaceAll(' ', ''));
      expect(row, {
        'm': {'a': 2, 'b': 1},
      });
    });

    test('the first C# example, typed rows: the README packet both ways', () {
      // Arrange
      final layout = userScheme();

      // Act
      final wire = pack(layout, ada());
      final user = readRow(layout, userHex);

      // Assert
      expect(hex(wire), userHex.replaceAll(' ', ''));
      expect(user.username, 'ada');
      expect([for (final r in user.roles) r.roleName], ['user', 'admin']);
      expect(user.access.keys, ['map', 'store']);
      expect(
        [for (final a in user.access['map']!.actions) a.action],
        ['read', 'edit'],
      );
      expect(
        [for (final a in user.access['store']!.actions) a.action],
        ['write'],
      );
    });

    test('the first C# example, map rows: the same README packet', () {
      // Arrange
      final layout = userMapScheme();
      final row = <String, Object?>{
        'username': 'ada',
        'roles': [
          {'roleName': 'user'},
          {'roleName': 'admin'},
        ],
        'access': {
          'store': {
            'actions': [
              {'action': 'write'},
            ],
          },
          'map': {
            'actions': [
              {'action': 'read'},
              {'action': 'edit'},
            ],
          },
        },
      };

      // Act
      final wire = pack(layout, row);
      final back = readRow(layout, userHex);

      // Assert
      expect(hex(wire), userHex.replaceAll(' ', ''));
      expect(hex(pack(layout, back)), userHex.replaceAll(' ', ''));
      expect((back['roles']! as List<Object?>).length, 2);
      expect(back['username'], 'ada');
    });

    test('an unpacked list of scalars packs again to the same bytes', () {
      // Arrange
      final layout = scheme(1, [
        list('xs', u16(0, 'x')),
        dict('m', u8(0, 'v')),
        utf8Field(0, 'name'),
      ]);
      final wire = unhex(
        '01 02 00 01 00 02 00 02 00 02 10 61 02 02 10 62 01 06 2b fc fe e1 19 b2',
      );

      // Act
      final row = readRow(layout, hex(wire));
      final again = pack(layout, row);

      // Assert
      expect(again, Uint8List.fromList(wire));
    });
  });
}
