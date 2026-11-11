import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

// AL-1 to AL-3 (loop 100): half of an emoji (an unpaired UTF-16 surrogate) in
// a text or in a dictionary key is written as U+FFFD, as TypeScript's
// TextEncoder does. The packets below were written by running
// typescript/src/index.ts; two keys that become one after the swap are
// refused (TypeScript writes a packet its own unpack refuses).

typedef Row = Map<String, Object?>;

/// The text each lone-half case is read back as.
const halves = {
  'lone high': ('\ud800', '�'),
  'lone low': ('\udc00', '�'),
  'reversed pair': ('\udc00\ud800', '��'),
  'a, lone high, b': ('a\ud800b', 'a�b'),
};

/// context: (text before the half, [packet of each case in `halves` order]).
const contexts = {
  'bare': (
    '',
    ['010410efbfbd', '010410efbfbd', '010710efbfbdefbfbd', '01061061efbfbd62'],
  ),
  'raw form': (
    '中文',
    [
      '010a10e4b8ade69687efbfbd',
      '010a10e4b8ade69687efbfbd',
      '010d10e4b8ade69687efbfbdefbfbd',
      '010c10e4b8ade6968761efbfbd62',
    ],
  ),
  'compact form': (
    'hello world ',
    [
      '010deaa2d673dbe2d43ff977dfde80',
      '010deaa2d673dbe2d43ff977dfde80',
      '01116aa2d673dbe2d43fbffefbfbdfff7dfde8',
      '010e8aa2d673dbe2d429ff977dfdefa0',
    ],
  ),
};

const keyPackets = [
  '0101000410efbfbd01',
  '0101000410efbfbd01',
  '0101000710efbfbdefbfbd01',
  '010100061061efbfbd6201',
];

Scheme<Row> textScheme() => scheme(1, [utf8Field(0, 's')]);
Scheme<Row> dictScheme() => scheme(1, [dict('d', u8(0, 'v'))]);

PackbinException refused(void Function() body) {
  try {
    body();
  } on PackbinException catch (e) {
    return e;
  }
  fail('nothing was thrown');
}

void main() {
  contexts.forEach((context, entry) {
    final (prefix, packets) = entry;
    group('text in the $context', () {
      var i = 0;
      for (final MapEntry(key: name, value: (text, back)) in halves.entries) {
        final packet = packets[i++];
        test('$name packs the bytes TypeScript writes and reads back', () {
          // Arrange
          final s = textScheme();

          // Act
          final raw = pack(s, {'s': '$prefix$text'});
          final got = unpackRow(unhex(packet), s);

          // Assert
          expect(hex(raw), packet);
          expect(got.row, {'s': '$prefix$back'});
        });
      }
    });
  });

  group('a dictionary key', () {
    var i = 0;
    for (final MapEntry(key: name, value: (text, back)) in halves.entries) {
      final packet = keyPackets[i++];
      test('$name packs the bytes TypeScript writes and reads back', () {
        // Arrange
        final s = dictScheme();

        // Act
        final raw = pack(s, {
          'd': {text: 1},
        });
        final got = unpackRow(unhex(packet), s);

        // Assert
        expect(hex(raw), packet);
        expect(got.row, {
          'd': {back: 1},
        });
      });
    }

    final order = {
      'U+FFFF and a lone half: the swapped key sorts first': (
        {'￿': 1, '\ud800': 2},
        '0102000410efbfbd020410efbfbf01',
      ),
      'U+10000 and a lone low half: the swapped key sorts first': (
        {'\u{10000}': 1, '\udc00': 2},
        '0102000410efbfbd020510f090808001',
      ),
      'a and a lone half': (
        {'a': 1, '\ud800': 2},
        '010200021061010410efbfbd02',
      ),
    };
    order.forEach((name, entry) {
      final (keys, packet) = entry;
      test(name, () {
        // Arrange
        final s = dictScheme();

        // Act
        final raw = pack(s, {'d': keys});
        final back = unpackRow(raw, s);

        // Assert
        expect(hex(raw), packet);
        expect(back.ok, isTrue, reason: 'unpack refused Dart\'s own packet');
      });
    });

    test('a packet Dart writes is never refused by its own unpack', () {
      // Arrange
      final s = dictScheme();
      final maps = [
        {'\ud800': 1, '￿': 2, '\u{10000}': 3},
        {'': 1, '\udc00': 2, '\u{1f600}': 3, 'z': 4},
        {'': 1, '\ud83d': 2, 'a': 3},
      ];

      // Act and Assert
      for (final keys in maps) {
        final raw = pack(s, {'d': keys});
        expect(unpackRow(raw, s).ok, isTrue, reason: '$keys');
      }
    });

    test(
      'two keys that are the same once the halves are U+FFFD are refused',
      () {
        // Arrange
        final s = dictScheme();
        final collisions = [
          {'\ud800': 1, '\udc00': 2},
          {'�': 1, '\ud800': 2},
        ];

        for (final keys in collisions) {
          // Act
          final e = refused(() => pack(s, {'d': keys}));

          // Assert
          expect(e.kind, ErrorKind.packError);
          expect(e.field, isNull);
          expect(e.name, 'd');
          expect(e.reason, contains('same once an unpaired surrogate'));
        }
      },
    );
  });

  group('the byte limit counts a lone half as 3 bytes', () {
    test('a text of 6 packet bytes packs under 6 and is refused under 5', () {
      // Arrange
      final text = {'s': '\ud800'};

      // Act
      final fits = pack(textScheme().withLimits(maxBytes: 6), text);
      final e = refused(() => pack(textScheme().withLimits(maxBytes: 5), text));

      // Assert
      expect(hex(fits), '010410efbfbd');
      expect(e.name, 's');
      expect(e.reason, contains('above the limit of 5 bytes'));
    });
  });
}
