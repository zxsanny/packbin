import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:packbin/src/ecc/percent.dart';
import 'package:packbin/src/ecc/setting.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import 'vectors.dart';

// AZ-4140 AC-3 (DT-18): every row of fixtures/ecc/percent-vectors.txt, read
// as a file, through the package's internal codec.

const expectedCounts = {
  'pct': 336,
  'encp': 39,
  'inv': 408,
  'limp': 12,
  'fixp': 110,
  'badp': 118,
  'parp': 6,
  'lmtp': 3,
};

void main() {
  final rows = loadRows(percentFile);
  List<EccRow> of(String kind) => [
    for (final r in rows)
      if (r.kind == kind) r,
  ];

  group('fixtures/ecc/percent-vectors.txt', () {
    test('the rows loaded are all the data rows, per kind', () {
      // Act
      final counts = countByKind(rows);

      // Assert
      expect(counts, expectedCounts);
      expect(rows.length, dataLines(percentFile).length);
    });

    test('pct: the parity count of a clear length under p', () {
      // Arrange
      final pct = of('pct');
      final misses = <String>[];

      // Act
      for (final r in pct) {
        if (parityCount(r.number(0), r.number(1)) != r.number(2)) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(pct.length, 336);
      expect(misses, isEmpty);
    });

    test('encp: protect under p is exactly the protected bytes', () {
      // Arrange
      final encp = of('encp');
      final misses = <String>[];

      // Act
      for (final r in encp) {
        if (hex(protectPercent(r.bytes(1), r.number(0))) != hex(r.bytes(2))) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(encp.length, 39);
      expect(misses, isEmpty);
    });

    test('inv: the clear length of a sent length, or none', () {
      // Arrange
      final inv = of('inv');
      final misses = <String>[];

      // Act
      for (final r in inv) {
        final got = clearLength(r.number(0), r.number(1));
        final want = r.args[2] == 'none' ? null : r.number(2);
        if (got != want) misses.add('${r.id}: $got');
      }

      // Assert
      expect(inv.length, 408);
      expect(misses, isEmpty);
    });

    test('limp: protect of zero bytes succeeds or is refused as too_long', () {
      // Arrange
      final limp = of('limp');
      final misses = <String>[];

      // Act
      for (final r in limp) {
        final clear = Uint8List(r.number(1));
        String outcome;
        try {
          final out = protectPercent(clear, r.number(0));
          final n = parityCount(r.number(0), clear.length);
          outcome = out.length == clear.length + n ? 'ok' : 'size';
        } on PackbinException catch (e) {
          // The shared rows say too_long; a pack refuses with a pack error.
          outcome = e.kind == ErrorKind.packError ? 'too_long' : e.kind.term;
        }
        if (outcome != r.args[2]) misses.add('${r.id}: $outcome');
      }

      // Assert
      expect(limp.length, 12);
      expect(misses, isEmpty);
    });

    test('limp: the refusal names the clear length and the limit', () {
      // Act
      final e = thrown(() => protectPercent(Uint8List(252), 1));

      // Assert
      expect(e.kind, ErrorKind.packError);
      expect(e.reason, contains('252'));
      expect(e.reason, contains('251'));
    });

    test('fixp: repair under p returns the clear bytes and the count', () {
      // Arrange
      final fixp = of('fixp');
      final misses = <String>[];

      // Act
      for (final r in fixp) {
        final got = repairPercent(r.bytes(2), r.number(0), r.number(1));
        final ok =
            got.error == null &&
            hex(got.clear!) == hex(r.bytes(3)) &&
            got.count == r.number(4);
        if (!ok) misses.add(r.id);
      }

      // Assert
      expect(fixp.length, 110);
      expect(misses, isEmpty);
    });

    test('badp: repair under p is refused with the row kind', () {
      // Arrange
      final badp = of('badp');
      final misses = <String>[];

      // Act
      for (final r in badp) {
        final got = repairPercent(r.bytes(2), r.number(0), r.number(1));
        final error = got.error;
        if (error == null || word(error) != r.args[3] || got.clear != null) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(badp.length, 118);
      expect(misses, isEmpty);
    });

    test('parp: a count and a percentage in one declaration are refused', () {
      // Arrange
      final parp = of('parp');
      final base = scheme(1, [u8(0, 'a')]);

      // Act
      final errors = <(EccRow, PackbinException)>[];
      for (final r in parp) {
        final p = r.number(0), n = r.number(1);
        errors.add((
          r,
          thrown(() => base.withParitySettings(parity: n, parityPercent: p)),
        ));
      }

      // Assert
      expect(parp.length, 6);
      for (final (r, e) in errors) {
        expect(e.kind, ErrorKind.schemeError, reason: r.id);
        expect(e.name, 'parity', reason: r.id);
      }
    });

    test('lmtp: a limit outside 0 to 16 is refused naming limit', () {
      // Arrange
      final lmtp = of('lmtp');

      // Act
      final errors = [
        for (final r in lmtp) (r, thrown(() => checkLimit(r.number(0), 0, 25))),
      ];

      // Assert
      expect(lmtp.length, 3);
      for (final (r, e) in errors) {
        expect(e.kind, ErrorKind.schemeError, reason: r.id);
        expect(e.name, 'limit', reason: r.id);
      }
    });
  });
}
