import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../text/text_vectors.dart';

// AL-9 (loop 100): a text that unpack refuses is a short read with `needed`
// 0 and `left` the bytes from the start of the field to the end of the
// buffer, as TypeScript, Go and Swift give it; a buffer that really ends
// inside the text stays `short` with the bytes needed. Every `bad` row of
// fixtures/text/vectors.txt runs as a text field and, apart from the three
// `short` rows, as a dictionary key (the key's value byte follows it, so
// `left` is one more). The hand-made packets and their values were read by
// running typescript/src/index.ts.

Scheme<Map<String, Object?>> textScheme() => scheme(1, [utf8Field(0, 's')]);
Scheme<Map<String, Object?>> dictScheme() => scheme(1, [dict('d', u8(0, 'v'))]);

PackbinError refusedField(Uint8List field) {
  final got = unpackRow(Uint8List.fromList([1, ...field]), textScheme());
  expect(got.row, isNull);
  return got.error!;
}

PackbinError refusedKey(Uint8List field) {
  final packet = Uint8List.fromList([1, 1, 0, ...field, 0]);
  final got = unpackRow(packet, dictScheme());
  expect(got.row, isNull);
  return got.error!;
}

void main() {
  final bad = loadTextRows().where((r) => r.kind == 'bad').toList();
  final refusing = [
    for (final r in bad)
      if (r.rest[0] != 'short') r,
  ];

  test('the fixture has 32 bad rows: 29 refusals and 3 short reads', () {
    // Arrange and Act
    final kinds = <String, int>{};
    for (final r in bad) {
      kinds[r.rest[0]] = (kinds[r.rest[0]] ?? 0) + 1;
    }

    // Assert
    expect(bad.length, 32);
    expect(refusing.length, 29);
    expect(kinds['short'], 3);
  });

  test('every refusing row is a short read with needed 0 as a text field', () {
    // Arrange
    final misses = <String>[];

    // Act
    for (final r in refusing) {
      final e = refusedField(r.bytes);
      if (e.kind != ErrorKind.short ||
          e.needed != 0 ||
          e.left != r.bytes.length ||
          e.field != 0 ||
          e.name != 's') {
        misses.add('${r.id}: $e');
      }
    }

    // Assert
    expect(misses, isEmpty);
  });

  test('every refusing row is a short read with needed 0 as a dict key', () {
    // Arrange
    final misses = <String>[];

    // Act
    for (final r in refusing) {
      final e = refusedKey(r.bytes);
      if (e.kind != ErrorKind.short ||
          e.needed != 0 ||
          e.left != r.bytes.length + 1 ||
          e.name != 'd') {
        misses.add('${r.id}: $e');
      }
    }

    // Assert
    expect(misses, isEmpty);
  });

  test('the three short rows stay short with the bytes needed', () {
    // Arrange
    final shorts = [
      for (final r in bad)
        if (r.rest[0] == 'short') r,
    ];

    // Act and Assert
    expect(shorts.length, 3);
    for (final r in shorts) {
      final e = refusedField(r.bytes);
      expect(e.kind, ErrorKind.short, reason: r.id);
      expect(e.needed, greaterThan(0), reason: r.id);
    }
  });

  group('hand-made UTF-8 refusals (TypeScript: needed 0, left as given)', () {
    final cases = {
      'overlong C0 80': ('0310c080', 4),
      'overlong E0 80 AF': ('0410e080af', 5),
      'an encoded surrogate ED A0 80': ('0410eda080', 5),
      'above U+10FFFF, F4 90 80 80': ('0510f4908080', 6),
      'a sequence cut by its count, E2 82': ('0310e282', 4),
    };
    cases.forEach((name, entry) {
      final (field, left) = entry;
      test('$name as a field and as a key', () {
        // Arrange
        final bytes = unhex(field);

        // Act
        final asField = refusedField(bytes);
        final asKey = refusedKey(bytes);

        // Assert
        expect(asField.kind, ErrorKind.short);
        expect(asField.needed, 0);
        expect(asField.left, left);
        expect(asKey.kind, ErrorKind.short);
        expect(asKey.needed, 0);
        expect(asKey.left, left + 1);
      });
    });

    test(
      'a buffer that ends inside the text is short with the bytes needed',
      () {
        // Arrange: count 4, two payload bytes (TypeScript: needed 4, left 2)
        final field = unhex('0410e2');

        // Act
        final e = refusedField(field);

        // Assert
        expect(e.kind, ErrorKind.short);
        expect(e.needed, 4);
        expect(e.left, 2);
      },
    );
  });
}
