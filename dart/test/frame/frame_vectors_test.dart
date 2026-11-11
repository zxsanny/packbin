import 'package:test/test.dart';

import 'frame_vectors.dart';

// AZ-4142 AC-1: every row of fixtures/frame/vectors.txt through the frame
// API, read as a file. Copies of the text with one hex digit of an expected
// output changed fail on that row only.

void main() {
  final text = vectorsFile().readAsStringSync();
  final rows = load(text);

  group('frame vectors (AC-1)', () {
    test('every data row of the file runs and matches: 157 of 157', () {
      // Arrange
      final dataRows = dataLines(text).length;
      final ran = <String, int>{};

      // Act
      final problems = mismatches(rows, ran);

      // Assert
      expect(problems, isEmpty);
      for (final op in ops) {
        expect(ran[op] ?? 0, greaterThan(0), reason: 'op $op ran no row');
      }
      expect(ran.keys.toSet(), ops.toSet());
      final total = ran.values.fold(0, (sum, n) => sum + n);
      expect(total, dataRows);
      expect(total, 157);
      expect(ran, {'keys': 20, 'seal': 35, 'open': 57, 'mac': 42, 'replay': 3});
      expect(rows.map(caseOf).toSet().length, dataRows);
    });

    for (final name in [
      'E1.seal',
      'E2.seal',
      'E3.seal',
      'E3.seal16',
      'E4.mac',
      'E5.mac',
      'E4.keys',
    ]) {
      test('the worked example $name is in the file and matches', () {
        // Arrange
        final row = rowOf(rows, name);

        // Act
        final problems = mismatches([row]);

        // Assert
        expect(problems, isEmpty);
      });
    }

    test('the largest epoch works and the next one is BadValue', () {
      // Arrange
      final maxEpoch = rows
          .where((r) => opOf(r) == 'keys' && r['epoch'] == '16777215')
          .toList();
      final refused = rowOf(rows, 'refuse.seal.epoch1000000');

      // Act
      final problems = mismatches(maxEpoch);
      final result = run(refused)['result'];

      // Assert
      expect(maxEpoch, hasLength(3));
      expect(problems, isEmpty);
      expect(refused['result'], 'BadValue');
      expect(result, 'BadValue');
    });

    for (final (op, field) in [
      ('seal', 'body'),
      ('open', 'plain'),
      ('mac', 'tag'),
      ('keys', 'k_enc'),
      ('replay', 'states'),
    ]) {
      test('a copy with one $op $field digit changed fails on that row', () {
        // Arrange
        final lines = text.split('\n');
        final marker = ' $field=';
        final at = lines.indexWhere(
          (l) => l.startsWith('op=$op ') && l.contains(marker),
        );
        expect(at, isNonNegative, reason: 'no row to change');
        final line = lines[at];
        final digit = line.indexOf(marker) + marker.length;
        final flipped = line[digit] == '0' ? '1' : '0';
        lines[at] =
            line.substring(0, digit) + flipped + line.substring(digit + 1);
        final changed = load(lines.join('\n'));
        final name = caseOf(load(line).single);

        // Act
        final problems = mismatches(changed);

        // Assert
        expect(problems, hasLength(1));
        expect(problems.single, startsWith('$name $field'));
      });
    }
  });
}
