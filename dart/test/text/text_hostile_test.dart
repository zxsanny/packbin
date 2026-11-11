import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/src/text/text.dart';
import 'package:test/test.dart';

import 'text_vectors.dart';

/// AC-3 and AC-4 (AZ-4137): hostile buffers give an error value and never an
/// exception; a text with no field bytes is a typed throw on encode.
void main() {
  const texts = [
    'привіт',
    'Привіт, Світе!',
    'hello, world',
    'привіт ok 48.46',
    'привіт 😀',
    'ПРИВЕТ, мир',
    '\u{10ffff}\u0000﻿',
  ];

  TextEncodeException? refusalOf(String text) {
    try {
      encodeText(text);
    } on TextEncodeException catch (e) {
      return e;
    }
    return null;
  }

  test('empty text: the byte 00, and it decodes to an empty String', () {
    // Arrange
    final row = loadTextRows().firstWhere((r) => r.id == 'enc.hand.empty');

    // Act
    final field = encodeText('');
    final read = decodeText(field);

    // Assert
    expect(hex(field), hex(row.bytes));
    expect(hex(field), '00');
    expect(read, isA<TextValue>());
    expect((read as TextValue).value, '');
    expect(read.next, 1);
  });

  test('a count that says more bytes than are left is short', () {
    // Arrange
    final buffers = [
      '05a37aa4',
      '7f',
      'ffff7f',
      '8101'
          '00',
      'ff7f1000',
    ];

    for (final buffer in buffers) {
      // Act
      final read = decodeText(unhex(buffer));

      // Assert
      expect(read, isA<TextFailure>(), reason: buffer);
      expect((read as TextFailure).kind, TextRefusal.short, reason: buffer);
      expect(read.needed, greaterThan(read.left), reason: buffer);
    }
  });

  test('every truncation of an encoded text is an error value', () {
    for (final text in texts) {
      // Arrange
      final field = encodeText(text);

      for (var cut = 0; cut < field.length; cut++) {
        // Act
        final read = decodeText(Uint8List.sublistView(field, 0, cut));

        // Assert
        expect(read, isA<TextFailure>(), reason: '$text cut to $cut');
        expect((read as TextFailure).kind, TextRefusal.short);
      }
    }
  });

  test('a payload cut short under a count that fits never throws', () {
    var values = 0;
    var failures = 0;
    for (final text in texts) {
      // Arrange
      final field = encodeText(text);

      for (var keep = 1; keep < field.length - 1; keep++) {
        final cut = Uint8List(1 + keep)
          ..[0] = keep
          ..setRange(1, 1 + keep, field, 1);

        // Act
        final read = decodeText(cut);

        // Assert
        if (read is TextValue) {
          expect(read.next, cut.length);
          values++;
        } else {
          failures++;
        }
      }
    }
    expect(values + failures, greaterThan(50));
    expect(failures, greaterThan(0));
  });

  test('round trip at an offset inside a larger buffer', () {
    for (final text in texts) {
      // Arrange
      final field = encodeText(text);
      final buffer = Uint8List(3 + field.length + 2)
        ..fillRange(0, 3, 0xff)
        ..setAll(3, field)
        ..fillRange(3 + field.length, 5 + field.length, 0xff);
      final view = Uint8List.sublistView(buffer, 1);

      // Act
      final read = decodeText(buffer, 3);
      final viewed = decodeText(view, 2);

      // Assert
      expect((read as TextValue).value, text);
      expect(read.next, 3 + field.length);
      expect((viewed as TextValue).value, text);
      expect(viewed.next, 2 + field.length);
    }
  });

  test('an offset outside the buffer is short, at its end too', () {
    // Arrange
    final field = encodeText('ok');

    // Act
    final results = [
      decodeText(field, field.length),
      decodeText(field, field.length + 1),
      decodeText(field, -1),
    ];

    // Assert
    for (final read in results) {
      expect((read as TextFailure).kind, TextRefusal.short);
    }
  });

  test('an unpaired surrogate is refused on encode with its index', () {
    // Arrange
    final lone = {
      'a\ud800b': 1,
      '\udc00': 0,
      'x\ud83d': 1,
      '😀\ud83d': 2,
      '\ude00\ud83d': 0,
      '${'a' * 5000}\udfff': 5000,
    };

    for (final MapEntry(key: text, value: index) in lone.entries) {
      // Act
      final refusal = refusalOf(text);

      // Assert
      expect(refusal?.problem, TextEncodeProblem.loneSurrogate, reason: text);
      expect(refusal?.detail, index);
    }
  });

  test('a refused text leaves the encoder working', () {
    // Arrange
    final before = hex(encodeText('привіт'));

    // Act
    final refusal = refusalOf('привіт\ud800');
    final after = hex(encodeText('привіт'));

    // Assert
    expect(refusal, isNotNull);
    expect(after, before);
  });

  test('65,535 UTF-8 bytes encode and decode; one more is refused', () {
    // Arrange
    final most = 'я' * 32767 + 'a';
    final short = 'a' * 4097;
    final over = ['${most}a', 'a' * 65536, '😀' * 16384, 'я' * 70000];

    // Act
    final read = decodeText(encodeText(most));
    final readShort = decodeText(encodeText(short));
    final refusals = over.map(refusalOf).toList();

    // Assert
    expect((read as TextValue).value, most);
    expect((readShort as TextValue).value, short);
    for (var i = 0; i < over.length; i++) {
      expect(refusals[i]?.problem, TextEncodeProblem.tooLong);
      expect(refusals[i]?.detail, utf8.encode(over[i]).length);
    }
  });

  test('a raw payload keeps a leading U+FEFF and refuses bad UTF-8', () {
    // Arrange
    final marked = unhex('0410efbbbf');
    final bad = [
      '0310eda0',
      '0410eda080',
      '0310c080',
      '0510f4908080',
      '0210c3',
    ];

    // Act
    final read = decodeText(marked);
    final kinds = bad.map((b) => decodeText(unhex(b))).toList();

    // Assert
    expect((read as TextValue).value, '﻿');
    for (final k in kinds) {
      expect((k as TextFailure).kind, TextRefusal.utf8);
    }
  });

  test(
    'the cache returns the field of the same text and follows a new one',
    () {
      // Arrange
      final cache = TextCache();

      // Act
      final first = encodeText('привіт', cache);
      final again = encodeText('привіт', cache);
      final other = encodeText('hello', cache);
      final empty = encodeText('', TextCache());

      // Assert
      expect(identical(first, again), isTrue);
      expect(hex(first), hex(encodeText('привіт')));
      expect(hex(other), hex(encodeText('hello')));
      expect(hex(empty), '00');
    },
  );

  test('random and damaged buffers never throw or read past the payload; a '
      'value encodes and decodes to itself', () {
    // Arrange
    final random = Random(4137);
    var values = 0;
    var failures = 0;

    for (var round = 0; round < 20000; round++) {
      final size = random.nextInt(40);
      final buffer = Uint8List(size + 1);
      for (var i = 0; i < size; i++) {
        buffer[i] = random.nextInt(256);
      }
      if (round.isEven && size > 0) buffer[0] = random.nextInt(size);
      buffer[size] = 0x5a;
      final input = Uint8List.sublistView(buffer, 0, size);

      // Act
      final read = decodeText(input);

      // Assert
      if (read is TextValue) {
        values++;
        expect(read.next, lessThanOrEqualTo(size));
        final back = decodeText(encodeText(read.value));
        expect((back as TextValue).value, read.value);
        expect(utf8.encode(read.value).length, lessThanOrEqualTo(6 * size + 8));
      } else {
        failures++;
      }
    }
    expect(values, greaterThan(100));
    expect(failures, greaterThan(100));
  });
}
