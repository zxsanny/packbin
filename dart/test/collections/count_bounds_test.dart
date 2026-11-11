import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/user_rows.dart';

typedef Row = Map<String, Object?>;

PackbinError unpackError(Scheme<Object> layout, String wire) {
  final result = unpackRow(unhex(wire), layout);
  expect(result.row, isNull, reason: wire);
  return result.error!;
}

final class Item {
  int a = 0;
}

void main() {
  group('a count is compared with the bytes left before anything is made', () {
    test(
      'a list count of 65,535 with 3 bytes left is short, needing 65,535',
      () {
        // Arrange
        final layout = scheme(1, [list('xs', u8(0, 'x'))]);

        // Act
        final error = unpackError(layout, '01 ff ff 01 02 03');

        // Assert
        expect(error.kind, ErrorKind.short);
        expect(error.kind.term, 'short_packet');
        expect(error.name, 'xs');
        expect(error.needed, 65535);
        expect(error.left, 3);
      },
    );

    test('the needed bytes follow the item size', () {
      // Arrange
      final layout = scheme(1, [list('xs', u16(0, 'x'))]);

      // Act
      final error = unpackError(layout, '01 ff ff 01 02 03');

      // Assert
      expect(error.needed, 131070);
      expect(error.left, 3);
    });

    test('a dictionary pair takes at least its key byte and its item', () {
      // Arrange
      final layout = scheme(1, [dict('m', u8(0, 'v'))]);

      // Act
      final error = unpackError(layout, '01 ff ff 01 02 03');

      // Assert
      expect(error.needed, 2 * 65535);
      expect(error.left, 3);
    });

    test('no item row is made for a count the bytes cannot hold', () {
      // Arrange
      var made = 0;
      Item make() {
        made++;
        return Item();
      }

      final layout = rowScheme<Object>(1, Object.new, [
        list(
          'items',
          nestedRow<Item>('item', make, [
            u8(0, 'a').bind<Item>(get: (i) => i.a, set: (i, v) => i.a = v),
          ]),
        ).bind<Object>(get: (_) => <Item>[], set: (_, v) {}),
      ]);

      // Act
      final error = unpackError(layout, '01 ff ff 01 02 03');

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(made, 0);
    });

    test('a count the bytes can hold makes one row for each item', () {
      // Arrange
      var made = 0;
      Item make() {
        made++;
        return Item();
      }

      final layout = rowScheme<Object>(1, Object.new, [
        list(
          'items',
          nestedRow<Item>('item', make, [
            u8(0, 'a').bind<Item>(get: (i) => i.a, set: (i, v) => i.a = v),
          ]),
        ).bind<Object>(get: (_) => <Item>[], set: (_, v) {}),
      ]);

      // Act
      final result = unpackRow(unhex('01 03 00 01 02 03'), layout);

      // Assert
      expect(result.error, isNull);
      expect(made, 3);
    });

    test('a buffer that ends inside the count is short, needing 2', () {
      // Arrange
      final layout = scheme(1, [list('xs', u8(0, 'x'))]);

      // Act
      final error = unpackError(layout, '01 05');

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(error.needed, 2);
      expect(error.left, 1);
    });

    test('an item that reads no byte is refused, not repeated', () {
      // Arrange
      final layout = scheme(1, [list('xs', bytes(0, 'e', 0))]);

      // Act
      final error = unpackError(layout, '01 01 00 ff');

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(error.needed, 0);
      expect(error.name, 'xs');
    });

    test('bytes after the list are trailing bytes', () {
      // Arrange
      final layout = scheme(1, [list('xs', u8(0, 'x'))]);

      // Act
      final error = unpackError(layout, '01 01 00 07 08');

      // Assert
      expect(error.kind, ErrorKind.trailing);
      expect(error.left, 1);
    });

    test('a text that ends inside its payload is short, naming the field', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final error = unpackError(layout, '01 06 2b fc');

      // Assert
      expect(error.kind, ErrorKind.short);
      expect(error.field, 0);
      expect(error.name, 'name');
      expect(error.needed, 6);
      expect(error.left, 2);
    });

    test('an invalid UTF-8 payload is bad_value naming the field', () {
      // Arrange: invalid_utf8
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final error = unpackError(layout, '01 03 10 c3 28');

      // Assert
      expect(error.kind, ErrorKind.badValue);
      expect(error.field, 0);
      expect(error.name, 'name');
    });
  });

  group('unpack never throws on the bytes of a collection packet', () {
    test('every prefix of the README packet is an error value', () {
      // Arrange
      final wire = unhex(userHex);
      final layout = userMapScheme();
      var errors = 0;

      // Act
      for (var cut = 0; cut < wire.length; cut++) {
        final result = unpackRow(Uint8List.sublistView(wire, 0, cut), layout);
        if (result.error != null) errors++;
      }

      // Assert
      expect(errors, wire.length);
    });

    test('every single-byte change of the README packet gives a value or an '
        'error value', () {
      // Arrange
      final wire = unhex(userHex);
      final layout = userMapScheme();
      var read = 0;

      // Act
      for (var at = 0; at < wire.length; at++) {
        for (final value in [0x00, 0x01, 0x7f, 0x80, 0xff, wire[at] ^ 0x10]) {
          final copy = Uint8List.fromList(wire)..[at] = value;
          final result = unpackRow(copy, layout);
          if (result.error == null) read++;
        }
      }

      // Assert
      expect(read, greaterThan(0));
    });

    test('random bytes of 0 to 40 bytes give a value or an error value', () {
      // Arrange
      final random = Random(4138);
      final layout = userMapScheme();
      var ran = 0;

      // Act
      for (var i = 0; i < 5000; i++) {
        final bytes = Uint8List(random.nextInt(40) + 1);
        for (var k = 0; k < bytes.length; k++) {
          bytes[k] = random.nextInt(256);
        }
        bytes[0] = 1;
        unpackRow(bytes, layout);
        ran++;
      }

      // Assert
      expect(ran, 5000);
    });
  });
}
