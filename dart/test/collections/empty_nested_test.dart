import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

// AL-7 and AL-8 (loop 100): an empty nested row is the presence mark of
// TypeScript's empty group. Directly under flags or a flag bit it builds and
// `true` sets its bit; anywhere else the scheme is refused with TypeScript's
// words. The bytes and results are the ones typescript/src printed.

typedef Row = Map<String, Object?>;

const words =
    'allowed only directly inside flags or a flag bit; move it into flags';

final class Leaf {}

final class Cell {
  int? h;
  bool? mark;
  Map<String, Object?>? g;
}

Scheme<Row> underFlags() => scheme(1, [
  flags(0, [nested('g', []), u8(0, 'h')]),
]);

Scheme<Row> underFlagBit() {
  final byte = flagByte('m');
  return scheme(1, [byte, byte.bit(nested('g', [])), byte.bit(u8(0, 'h'))]);
}

PackbinException refusal(Object? Function() build) {
  try {
    build();
  } on PackbinException catch (e) {
    return e;
  }
  fail('the scheme was built');
}

void main() {
  for (final (place, layout) in [
    ('flags', underFlags),
    ('a flag bit', underFlagBit),
  ]) {
    group('an empty nested row under $place', () {
      test('true sets the bit and packs the same bytes as TypeScript', () {
        // Arrange
        final s = layout();

        // Act
        final marked = pack(s, {'h': 9, 'g': true});
        final plain = pack(s, {'h': 9});
        final off = pack(s, {'h': 9, 'g': false});

        // Assert
        expect(hex(marked), '010309');
        expect(hex(plain), '010209');
        expect(hex(off), '010209');
      });

      test('a set bit unpacks to true, a clear one to no key', () {
        // Arrange
        final s = layout();

        // Act
        final set = unpackRow(unhex('010309'), s);
        final clear = unpackRow(unhex('010209'), s);

        // Assert
        expect(set.row, {'g': true, 'h': 9});
        expect(clear.row, {'h': 9});
      });

      test('a set bit with the next field missing is short at h', () {
        // Arrange and Act
        final got = unpackRow(unhex('0103'), layout());

        // Assert
        expect(got.error?.kind, ErrorKind.short);
        expect(got.error?.name, 'h');
        expect(got.error?.needed, 1);
        expect(got.error?.left, 0);
      });

      test('a value that is not a bool is refused naming the mark', () {
        // Arrange
        final s = layout();

        // Act
        PackbinException? first;
        PackbinException? second;
        try {
          pack(s, {'h': 9, 'g': <String, Object?>{}});
        } on PackbinException catch (e) {
          first = e;
        }
        try {
          pack(s, {'h': 9, 'g': 1});
        } on PackbinException catch (e) {
          second = e;
        }

        // Assert
        expect(first?.kind, ErrorKind.packError);
        expect(first?.name, 'g');
        expect(second?.kind, ErrorKind.packError);
        expect(second?.name, 'g');
      });

      test('it packs and unpacks as the member-less groupOf does', () {
        // Arrange
        final mark = scheme(1, [
          flags(0, [groupOf(0, 'g', []), u8(0, 'h')]),
        ]);
        final s = underFlags();

        // Act
        final rows = [
          {'h': 9},
          {'h': 9, 'g': true},
        ];

        // Assert
        for (final row in rows) {
          expect(hex(pack(s, row)), hex(pack(mark, row)));
        }
        expect(
          unpackRow(unhex('010309'), s).row,
          unpackRow(unhex('010309'), mark).row,
        );
      });
    });
  }

  group('an empty nested row anywhere else is refused when built', () {
    final places = <String, List<Field> Function()>{
      'a row member': () => [u8(0, 'a'), nested('g', [])],
      'under a when': () => [
        u8(0, 'k'),
        when(1, eq(0, 1), [nested('g', [])]),
      ],
      'in a non-empty group': () => [
        groupOf(0, 'o', [u8(0, 'a'), nested('g', [])]),
      ],
      'a list element': () => [list('g', nested('g', []))],
      'a dict element': () => [dict('g', nested('g', []))],
    };
    places.forEach((place, fields) {
      test('$place: TypeScript words, naming g', () {
        // Arrange and Act
        final e = refusal(() => scheme(1, fields()));

        // Assert
        expect(e.kind, ErrorKind.schemeError);
        expect(e.name, 'g');
        expect(e.reason, 'empty group g: $words');
      });
    });

    test(
      'a typed row cannot bind an empty nested: groupOf is the typed mark',
      () {
        // Arrange and Act
        final e = refusal(
          () => rowScheme<Cell>(1, Cell.new, [
            flags(0, [
              nested(
                'g',
                [],
              ).bind<Cell>(get: (r) => r.g, set: (r, v) => r.g = v),
              u8(0, 'h').bind<Cell>(get: (r) => r.h, set: (r, v) => r.h = v),
            ]),
          ]),
        );

        // Assert
        expect(e.kind, ErrorKind.schemeError);
        expect(e.name, 'g');
        expect(e.reason, contains('presence mark'));
      },
    );

    test(
      'an unbound mark in a typed scheme points at groupOf bound to a bool',
      () {
        // Arrange and Act
        final e = refusal(
          () => rowScheme<Cell>(1, Cell.new, [
            flags(0, [
              nested('g', []),
              u8(0, 'h').bind<Cell>(get: (r) => r.h, set: (r, v) => r.h = v),
            ]),
          ]),
        );

        // Assert
        expect(e.kind, ErrorKind.schemeError);
        expect(e.name, 'g');
        expect(e.reason, contains('groupOf(anchor, name, []).bind'));
        expect(e.reason, isNot(contains('every value field')));
      },
    );

    test('the typed mark is groupOf bound to a bool', () {
      // Arrange
      final s = rowScheme<Cell>(1, Cell.new, [
        flags(0, [
          groupOf(
            0,
            'g',
            [],
          ).bind<Cell>(get: (r) => r.mark, set: (r, v) => r.mark = v),
          u8(0, 'h').bind<Cell>(get: (r) => r.h, set: (r, v) => r.h = v),
        ]),
      ]);

      // Act
      final raw = pack(
        s,
        Cell()
          ..h = 9
          ..mark = true,
      );
      final back = unpackRow(unhex('010309'), s).row!;

      // Assert
      expect(hex(raw), '010309');
      expect(back.mark, isTrue);
      expect(back.h, 9);
    });

    test('an empty nestedRow stays refused: it has no member to bind', () {
      // Arrange and Act
      final e = refusal(() => scheme(1, [nestedRow<Leaf>('g', Leaf.new, [])]));

      // Assert
      expect(e.kind, ErrorKind.schemeError);
      expect(e.name, 'g');
      expect(e.reason, contains('at least one member'));
    });
  });
}
