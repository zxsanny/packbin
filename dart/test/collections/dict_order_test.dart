import 'package:packbin/packbin.dart';
import 'package:packbin/src/utf8_order.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

Scheme<Row> dictOfU8() => scheme(1, [dict('m', u8(0, 'v'))]);

PackbinError unpackError(Scheme<Row> layout, String wire) {
  final result = unpackRow(unhex(wire), layout);
  expect(result.row, isNull, reason: wire);
  return result.error!;
}

void main() {
  group('dictionary keys are written ascending by their UTF-8 bytes', () {
    test('keys inserted out of order are written in byte order', () {
      // Arrange
      final map = <String, Object?>{'b': 1, 'c': 3, 'a': 2};

      // Act
      final wire = pack(dictOfU8(), {'m': map});

      // Assert
      expect(hex(wire), '010300021061020210620102106303');
    });

    test(
      'keys whose UTF-16 and UTF-8 orders differ follow the UTF-8 bytes',
      () {
        // Arrange: U+10000 is D800 DC00 in UTF-16 (before U+FFFF there) and
        // F0 90 80 80 in UTF-8 (after U+FFFF, EF BF BF).
        const high = '\u{10000}';
        const bmp = '￿';
        final map = <String, Object?>{high: 1, bmp: 2};

        // Act
        final wire = pack(dictOfU8(), {'m': map});
        final back = readRow(dictOfU8(), hex(wire));

        // Assert
        expect(high.compareTo(bmp), lessThan(0), reason: 'String order');
        expect(compareUtf8(high, bmp), greaterThan(0), reason: 'UTF-8 order');
        expect((back['m']! as Map<String, Object?>).keys, [bmp, high]);
        expect(
          hex(wire).indexOf('efbfbf'),
          lessThan(hex(wire).indexOf('f0908080')),
        );
      },
    );

    test('compareUtf8 orders by code point, prefix first', () {
      // Arrange
      final keys = ['b', '\u{1f600}', 'a', '', 'ab', 'é', ''];

      // Act
      keys.sort(compareUtf8);

      // Assert
      expect(keys, ['', 'a', 'ab', 'b', 'é', '', '\u{1f600}']);
    });

    test('a prefix key comes before the longer key', () {
      // Arrange and Act
      final wire = pack(dictOfU8(), {
        'm': {'ab': 1, 'a': 2},
      });

      // Assert
      expect(hex(wire), '010200021061020310616201');
    });

    test('the same map packs to the same bytes in any insertion order', () {
      // Arrange
      final one = <String, Object?>{'x': 1, 'y': 2, 'é': 3, 'z': 4};
      final two = <String, Object?>{'z': 4, 'é': 3, 'y': 2, 'x': 1};

      // Act
      final a = pack(dictOfU8(), {'m': one});
      final b = pack(dictOfU8(), {'m': two});

      // Assert
      expect(hex(a), hex(b));
    });

    test('a dictionary key that is not a String is refused, naming the field '
        'and the entry', () {
      // Arrange
      final map = <Object?, Object?>{'a': 1, 2: 2};

      // Act
      final error = packRefusal(() => pack(dictOfU8(), {'m': map}));

      // Assert
      expect(error.name, 'm');
      expect(error.reason, contains('m[1]'));
      expect(error.reason, contains('int'));
    });

    test('a value that is not a Map is refused naming the field', () {
      // Arrange and Act
      final error = packRefusal(
        () => pack(dictOfU8(), {
          'm': [1, 2],
        }),
      );

      // Assert
      expect(error.name, 'm');
      expect(error.reason, contains('expected a dictionary'));
    });
  });

  group('unpack refuses a key that is not strictly ascending', () {
    test('a key out of order is a short read with needed 0', () {
      // Arrange: key "b" then key "a", the hostile case dict_keys_out_of_order
      const wire = '01 02 00 02 10 62 00 02 10 61 00';

      // Act
      final error = unpackError(dictOfU8(), wire);

      // Assert: TypeScript gives needed 0, left 0 for this packet
      expect(error.kind, ErrorKind.short);
      expect(error.kind.term, 'short_packet');
      expect(error.name, 'm');
      expect(error.needed, 0);
      expect(error.left, 0);
    });

    test('a key given twice is a short read with needed 0', () {
      // Arrange
      const wire = '01 02 00 02 10 61 00 02 10 61 00';

      // Act
      final error = unpackError(dictOfU8(), wire);

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(error.needed, 0);
      expect(error.left, 0);
    });

    test('the same key in two forms (raw and compact) is a short read', () {
      // Arrange: dict_keys_repeated_forms
      const wire = '01 02 00 02 10 61 00 02 c9 00 00';

      // Act
      final error = unpackError(dictOfU8(), wire);

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(error.needed, 0);
      expect(error.left, 0);
    });

    test(
      'keys that ascend by UTF-8 bytes but not by UTF-16 units are read',
      () {
        // Arrange: U+FFFF (ef bf bf) then U+10000 (f0 90 80 80)
        const wire = '01 02 00 04 10 ef bf bf 01 05 10 f0 90 80 80 02';

        // Act
        final row = readRow(dictOfU8(), wire);

        // Assert
        expect(row['m'], {'￿': 1, '\u{10000}': 2});
      },
    );

    test(
      'keys that ascend by UTF-16 units but not by UTF-8 bytes are refused',
      () {
        // Arrange: U+10000 then U+FFFF
        const wire = '01 02 00 05 10 f0 90 80 80 01 04 10 ef bf bf 02';

        // Act
        final error = unpackError(dictOfU8(), wire);

        // Assert
        expect(error.kind, ErrorKind.short);
        expect(error.needed, 0);
        expect(error.left, 0);
      },
    );

    test('an invalid UTF-8 key is a short read with needed 0, not an exception', () {
      // Arrange: invalid_utf8_dict_key
      const wire = '01 01 00 02 10 ff 00';

      // Act
      final error = unpackError(dictOfU8(), wire);

      // Assert: TypeScript gives needed 0, left 4 (the bytes of the key field)
      expect(error.kind, ErrorKind.short);
      expect(error.name, 'm');
      expect(error.needed, 0);
      expect(error.left, 4);
    });

    test('a leading U+FEFF in a key is a key, not dropped', () {
      // Arrange: raw payload ef bb bf 61 is U+FEFF then "a"
      const wire = '01 01 00 05 10 ef bb bf 61 07';

      // Act
      final row = readRow(dictOfU8(), wire);

      // Assert
      expect(row['m'], {'﻿a': 7});
    });
  });
}
