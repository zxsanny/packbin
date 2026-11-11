import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:packbin/src/ecc/codec.dart';
import 'package:packbin/src/ecc/setting.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import 'vectors.dart';

// AZ-4140 AC-1 (DT-18): every row of fixtures/ecc/vectors.txt, read as a
// file, through the package's internal codec.

const expectedCounts = {
  'enc': 42,
  'fix': 144,
  'bad': 1128,
  'lim': 7,
  'par': 3,
  'lmt': 4,
};

void main() {
  final rows = loadRows(countFile);
  List<EccRow> of(String kind) => [
    for (final r in rows)
      if (r.kind == kind) r,
  ];

  group('fixtures/ecc/vectors.txt', () {
    test('the rows loaded are all the data rows, per kind', () {
      // Act
      final counts = countByKind(rows);

      // Assert
      expect(counts, expectedCounts);
      expect(rows.length, dataLines(countFile).length);
    });

    test('enc: protect is exactly the protected bytes', () {
      // Arrange
      final enc = of('enc');
      var mismatches = 0;

      // Act
      for (final r in enc) {
        final got = protect(r.bytes(1), r.number(0));
        if (hex(got) != hex(r.bytes(2))) mismatches++;
      }

      // Assert
      expect(enc.length, 42);
      expect(mismatches, 0);
    });

    test('fix: repair returns the clear bytes and the repaired count', () {
      // Arrange
      final fix = of('fix');
      final misses = <String>[];

      // Act
      for (final r in fix) {
        final got = repair(r.bytes(2), r.number(0), r.number(1));
        final ok =
            got.error == null &&
            hex(got.clear!) == hex(r.bytes(3)) &&
            got.count == r.number(4);
        if (!ok) misses.add(r.id);
      }

      // Assert
      expect(fix.length, 144);
      expect(misses, isEmpty);
    });

    test('bad: repair is refused with the row kind', () {
      // Arrange
      final bad = of('bad');
      final misses = <String>[];

      // Act
      for (final r in bad) {
        final got = repair(r.bytes(2), r.number(0), r.number(1));
        final error = got.error;
        if (error == null || word(error) != r.args[3] || got.clear != null) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(bad.length, 1128);
      expect(misses, isEmpty);
    });

    test(
      'bad: a short buffer names the field parity, n and the bytes left',
      () {
        // Arrange
        final shorts = [
          for (final r in of('bad'))
            if (r.args[3] == 'short') r,
        ];

        // Act
        final errors = [
          for (final r in shorts)
            (r, repair(r.bytes(2), r.number(0), r.number(1)).error!),
        ];

        // Assert
        expect(shorts, isNotEmpty);
        for (final (r, error) in errors) {
          expect(error.name, 'parity', reason: r.id);
          expect(error.field, isNull, reason: r.id);
          expect(error.needed, r.number(0), reason: r.id);
          expect(error.left, r.bytes(2).length, reason: r.id);
        }
      },
    );

    test('lim: protect of zero bytes succeeds or is refused as too_long', () {
      // Arrange
      final lim = of('lim');
      final misses = <String>[];

      // Act
      for (final r in lim) {
        final clear = Uint8List(r.number(1));
        String outcome;
        try {
          final out = protect(clear, r.number(0));
          outcome = out.length == clear.length + r.number(0) ? 'ok' : 'size';
        } on PackbinException catch (e) {
          // The shared rows say too_long; a pack refuses with a pack error.
          outcome = e.kind == ErrorKind.packError ? 'too_long' : e.kind.term;
        }
        if (outcome != r.args[2]) misses.add('${r.id}: $outcome');
      }

      // Assert
      expect(lim.length, 7);
      expect(misses, isEmpty);
    });

    test('lim: the refusal names the clear length and the limit', () {
      // Arrange
      final clear = Uint8List(251);

      // Act
      final e = thrown(() => protect(clear, 4));

      // Assert
      expect(e.kind, ErrorKind.packError);
      expect(e.reason, contains('251'));
      expect(e.reason, contains('250'));
    });

    test('par: a count above 32 is refused as a scheme naming parity', () {
      // Arrange
      final par = of('par');

      // Act
      final errors = [
        for (final r in par) (r, thrown(() => checkParity(r.number(0)))),
      ];

      // Assert
      expect(par.length, 3);
      for (final (r, e) in errors) {
        expect(e.kind, ErrorKind.schemeError, reason: r.id);
        expect(e.name, 'parity', reason: r.id);
        expect(e.reason, contains('${r.number(0)}'), reason: r.id);
      }
    });

    test('lmt: a limit above n / 2 is refused as a scheme naming limit', () {
      // Arrange
      final lmt = of('lmt');

      // Act
      final errors = [
        for (final r in lmt)
          (r, thrown(() => checkLimit(r.number(1), r.number(0), 0))),
      ];

      // Assert
      expect(lmt.length, 4);
      for (final (r, e) in errors) {
        expect(e.kind, ErrorKind.schemeError, reason: r.id);
        expect(e.name, 'limit', reason: r.id);
      }
    });
  });
}
