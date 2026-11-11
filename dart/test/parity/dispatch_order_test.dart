import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import 'parity_support.dart';

// TypeScript table `ecc-dispatch-order.test.ts` (AZ-2694, AZ-2704, loop 40):
// the checks of one unpack call run in one order: no handler, duplicate type
// number, parity mix, limit; then, per packet, the repair (too long,
// uncorrectable), an empty buffer, an unknown type byte and the body. Each
// row says which error wins when two apply.

Scheme<Row> typed(int type, {int parity = 0, int percent = 0}) {
  var s = scheme(type, [u8(0, 'a')]);
  if (parity > 0) s = s.withParity(parity);
  if (percent > 0) s = s.withParityPercent(percent);
  return s;
}

SchemeHandler handler(int type, {int parity = 0, int percent = 0}) =>
    typed(type, parity: parity, percent: percent).on((_) {});

/// A refusal of the call itself: the scheme error's reason.
String callRefusal(Object Function() call) {
  try {
    call();
  } on PackbinException catch (e) {
    expect(e.kind, ErrorKind.schemeError);
    return e.reason;
  }
  fail('the call was not refused');
}

/// What a call returned: its error, or `ok <repaired>`.
String result(Unpacked<Object> r) {
  final e = r.error;
  if (e == null) return 'ok ${r.repaired}';
  return switch (e.kind) {
    ErrorKind.short => 'short ${e.name} ${e.needed} ${e.left}',
    ErrorKind.trailing => 'trailing ${e.left}',
    ErrorKind.unknownType => 'type ${e.actual}',
    ErrorKind.tooLong => 'too_long ${e.left}',
    _ => e.kind.term,
  };
}

final full4 = pack(typed(1, parity: 4), {'a': 7});

Uint8List flip(Uint8List b, List<int> at) {
  final out = Uint8List.fromList(b);
  for (final i in at) {
    out[i] ^= 0xff;
  }
  return out;
}

void main() {
  group('ecc-dispatch-order: the checks of the call', () {
    for (final parity in [0, 4]) {
      test('D1 duplicate type number is refused before any byte is read, '
          'parity $parity', () {
        // Arrange
        var rows = 0;
        final h = typed(1, parity: parity).on((_) => rows++);

        // Act
        final reason = callRefusal(() => unpack(Uint8List(0), [h, h]));

        // Assert
        expect(reason, 'duplicate type number 1');
        expect(rows, 0);
      });

      test(
        'D2 a duplicate type number is refused before a mix of parity counts '
        'and a bad limit, parity $parity',
        () {
          // Arrange
          final h = handler(1, parity: parity);
          final mixed = handler(2, parity: parity == 0 ? 4 : 0);
          final four = Uint8List(4);

          // Act
          final mixOnly = callRefusal(() => unpackRepair(four, [h, mixed], 0));
          final withMix = callRefusal(
            () => unpackRepair(four, [h, mixed, h], 0),
          );
          final withLimit = callRefusal(() => unpackRepair(four, [h, h], 9));

          // Assert
          expect(mixOnly, contains('must declare the same setting'));
          expect(withMix, 'duplicate type number 1');
          expect(withLimit, 'duplicate type number 1');
        },
      );

      test(
        'D3 no handler is refused first, whatever the limit, parity $parity',
        () {
          // Act
          final plain = callRefusal(() => unpack(full4, []));
          final withLimit = callRefusal(() => unpackRepair(full4, [], 9));

          // Assert
          expect(plain, 'unpack needs at least one handler');
          expect(withLimit, 'unpack needs at least one handler');
        },
      );
    }

    test('D4 a mix of counts is refused before a bad limit', () {
      // Act
      final reason = callRefusal(
        () => unpackRepair(full4, [handler(1, parity: 4), handler(2)], 9),
      );

      // Assert
      expect(reason, contains('must declare the same setting'));
    });

    test('D5 a count and a percentage are a mix', () {
      // Act
      final reason = callRefusal(
        () => unpack(full4, [handler(1, percent: 25), handler(2, parity: 4)]),
      );

      // Assert
      expect(reason, contains('25 percent and 4 parity bytes'));
    });

    test('D6 a limit out of range is refused before any byte is read', () {
      // Act
      final count = callRefusal(
        () => unpackRepair(full4, [handler(1, parity: 4)], 3),
      );
      final percent = callRefusal(
        () => unpackRepair(full4, [handler(1, percent: 25)], 17),
      );

      // Assert
      expect(count, contains('expected 0..2 for 4 parity bytes, got 3'));
      expect(percent, contains('expected 0..16 under a parity percentage'));
    });
  });

  group('ecc-dispatch-order: the packet, per TypeScript row', () {
    final a0 = handler(1);
    final b0 = handler(2);
    final a4 = handler(1, parity: 4);

    final rows = <(String, Unpacked<Object> Function(), String)>[
      ('A0 empty buffer', () => unpack(unhex(''), [a0]), 'short  1 0'),
      ('A0 unknown type', () => unpack(unhex('09'), [a0]), 'type 9'),
      ('A0 short body', () => unpack(unhex('01'), [a0]), 'short a 1 0'),
      ('A0 trailing byte', () => unpack(unhex('010203'), [a0]), 'trailing 1'),
      (
        'A0 an unknown type wins over trailing bytes',
        () => unpack(unhex('090203'), [a0]),
        'type 9',
      ),
      (
        'A0 B0 the second handler reads its short body',
        () => unpack(unhex('02'), [a0, b0]),
        'short a 1 0',
      ),
      (
        'A4 empty buffer is short at parity',
        () => unpack(unhex(''), [a4]),
        'short parity 4 0',
      ),
      (
        'A4 three bytes are short at parity',
        () => unpack(unhex('010203'), [a4]),
        'short parity 4 3',
      ),
      (
        'A4 300 bytes are too long before any read',
        () => unpack(Uint8List(300), [a4]),
        'too_long 300',
      ),
      ('A4 an intact packet', () => unpack(full4, [a4]), 'ok 0'),
      (
        'A4 two wrong bytes, limit 0: uncorrectable',
        () => unpack(flip(full4, [1, 2]), [a4]),
        'uncorrectable',
      ),
      (
        'A4 two wrong bytes, limit 2: repaired',
        () => unpackRepair(flip(full4, [1, 2]), [a4], 2),
        'ok 2',
      ),
      (
        'A4 a wrong type byte, limit 0: uncorrectable before the type is read',
        () => unpack(flip(full4, [0]), [a4]),
        'uncorrectable',
      ),
      (
        'A4 a wrong type byte, limit 1: repaired, then dispatched',
        () => unpackRepair(flip(full4, [0]), [a4], 1),
        'ok 1',
      ),
      (
        'A4 an intact packet of another type is an unknown type',
        () => unpack(pack(typed(9, parity: 4), {'a': 7}), [a4]),
        'type 9',
      ),
    ];

    for (final (name, run, expected) in rows) {
      test(name, () => expect(result(run()), expected));
    }
  });
}
