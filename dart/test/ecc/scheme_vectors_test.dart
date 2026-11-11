import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import 'vectors.dart';

// AZ-4140 AC-1 and AC-3 through a scheme: the rows whose clear message is the
// position packet are packed and unpacked by the real scheme, the refusal
// rows are read by a scheme of that parity, and the limit rows pack a scheme
// with a byte run of the row's length.

const golden = '4001000065cd1d00a3e1110100';

/// A scheme of `length` bytes: the type byte and a run of `length - 1`.
Scheme<Map<String, Object?>> runScheme(int length) =>
    scheme(1, [bytes(0, 'raw', length - 1)]);

void main() {
  final counts = loadRows(countFile);
  final percents = loadRows(percentFile);
  final base = positionMapScheme();

  List<EccRow> of(List<EccRow> rows, String kind) => [
    for (final r in rows)
      if (r.kind == kind) r,
  ];

  group('scheme level, count rows', () {
    test('enc: pack of the position row is the protected bytes', () {
      // Arrange
      final rows = [
        for (final r in of(counts, 'enc'))
          if (hex(r.bytes(1)) == golden) r,
      ];

      // Act
      final misses = [
        for (final r in rows)
          if (hex(pack(base.withParity(r.number(0)), goldenMap())) !=
              hex(r.bytes(2)))
            r.id,
      ];

      // Assert
      expect(rows.length, 7);
      expect(misses, isEmpty);
    });

    test('fix: unpack with the limit gives the row and the count', () {
      // Arrange
      final rows = [
        for (final r in of(counts, 'fix'))
          if (hex(r.bytes(3)) == golden) r,
      ];
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final s = base.withParity(r.number(0));
        final got = unpackRowRepair(r.bytes(2), s, r.number(1));
        if (!equals(goldenMap()).matches(got.row, {}) ||
            got.repaired != r.number(4)) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(rows, isNotEmpty);
      expect(misses, isEmpty);
    });

    test('bad: unpack with the limit is refused with the row kind, no row', () {
      // Arrange
      final rows = of(counts, 'bad');
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final s = base.withParity(r.number(0));
        final got = unpackRowRepair(r.bytes(2), s, r.number(1));
        if (got.row != null ||
            got.repaired != 0 ||
            word(got.error!) != r.args[3]) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(rows.length, 1128);
      expect(misses, isEmpty);
    });

    test('lim: pack of a message of that length succeeds or is too_long', () {
      // Arrange
      final rows = of(counts, 'lim');
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final length = r.number(1);
        final s = runScheme(length).withParity(r.number(0));
        String outcome;
        try {
          final out = pack(s, {'raw': Uint8List(length - 1)});
          outcome = out.length == length + r.number(0) ? 'ok' : 'size';
        } on PackbinException catch (e) {
          // The shared rows say too_long; a pack refuses with a pack error.
          outcome = e.kind == ErrorKind.packError ? 'too_long' : e.kind.term;
        }
        if (outcome != r.args[2]) misses.add('${r.id}: $outcome');
      }

      // Assert
      expect(rows.length, 7);
      expect(misses, isEmpty);
    });

    test('par and lmt: refused when set, before any byte is read', () {
      // Arrange
      final par = of(counts, 'par');
      final lmt = of(counts, 'lmt');

      // Act
      final parErrors = [
        for (final r in par) thrown(() => base.withParity(r.number(0))),
      ];
      final lmtErrors = [
        for (final r in lmt)
          thrown(
            () => unpackRowRepair(
              Uint8List(0),
              base.withParity(r.number(0)),
              r.number(1),
            ),
          ),
      ];

      // Assert
      expect(parErrors.length + lmtErrors.length, 7);
      expect([for (final e in parErrors) e.name], everyElement('parity'));
      expect([for (final e in lmtErrors) e.name], everyElement('limit'));
      expect([
        for (final e in [...parErrors, ...lmtErrors]) e.kind,
      ], everyElement(ErrorKind.schemeError));
    });
  });

  group('scheme level, percentage rows', () {
    test('encp: pack of the position row is the protected bytes', () {
      // Arrange
      final rows = [
        for (final r in of(percents, 'encp'))
          if (hex(r.bytes(1)) == golden) r,
      ];

      // Act
      final misses = [
        for (final r in rows)
          if (hex(pack(base.withParityPercent(r.number(0)), goldenMap())) !=
              hex(r.bytes(2)))
            r.id,
      ];

      // Assert
      expect(rows, isNotEmpty);
      expect(misses, isEmpty);
    });

    test('fixp: unpack with the limit gives the row and the count', () {
      // Arrange
      final rows = [
        for (final r in of(percents, 'fixp'))
          if (hex(r.bytes(3)) == golden) r,
      ];
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final s = base.withParityPercent(r.number(0));
        final got = unpackRowRepair(r.bytes(2), s, r.number(1));
        if (!equals(goldenMap()).matches(got.row, {}) ||
            got.repaired != r.number(4)) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(rows, isNotEmpty);
      expect(misses, isEmpty);
    });

    test('badp: unpack with the limit is refused with the row kind', () {
      // Arrange
      final rows = of(percents, 'badp');
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final s = base.withParityPercent(r.number(0));
        final got = unpackRowRepair(r.bytes(2), s, r.number(1));
        if (got.row != null ||
            got.repaired != 0 ||
            word(got.error!) != r.args[3]) {
          misses.add(r.id);
        }
      }

      // Assert
      expect(rows.length, 118);
      expect(misses, isEmpty);
    });

    test('limp: pack of a message of that length succeeds or is too_long', () {
      // Arrange
      final rows = of(percents, 'limp');
      final misses = <String>[];

      // Act
      for (final r in rows) {
        final length = r.number(1);
        final s = runScheme(length).withParityPercent(r.number(0));
        String outcome;
        try {
          pack(s, {'raw': Uint8List(length - 1)});
          outcome = 'ok';
        } on PackbinException catch (e) {
          // The shared rows say too_long; a pack refuses with a pack error.
          outcome = e.kind == ErrorKind.packError ? 'too_long' : e.kind.term;
        }
        if (outcome != r.args[2]) misses.add('${r.id}: $outcome');
      }

      // Assert
      expect(rows.length, 12);
      expect(misses, isEmpty);
    });

    test('lmtp: a limit outside 0 to 16 is refused when called', () {
      // Arrange
      final rows = of(percents, 'lmtp');
      final s = base.withParityPercent(25);

      // Act
      final errors = [
        for (final r in rows)
          thrown(() => unpackRowRepair(Uint8List(0), s, r.number(0))),
      ];

      // Assert
      expect(rows.length, 3);
      expect([for (final e in errors) e.name], everyElement('limit'));
    });
  });
}
